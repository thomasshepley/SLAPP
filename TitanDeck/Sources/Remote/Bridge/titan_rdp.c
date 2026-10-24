// Remote/Bridge/titan_rdp.c
//
// FreeRDP 3 client wrapper for TitanDeck. Modelled on FreeRDP's own sample
// client (client/Sample/tf_freerdp.c) and iOS client (client/iOS/FreeRDP).

#include "titan_rdp.h"

#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>

#include <winpr/synch.h>

#include <freerdp/client.h>
#include <freerdp/client/cmdline.h>
#include <freerdp/crypto/certificate.h>
#include <freerdp/freerdp.h>
#include <freerdp/gdi/gdi.h>
#include <freerdp/input.h>

#define TITAN_QUEUE_CAPACITY 256
#define TITAN_LOOP_TIMEOUT_MS 100

typedef enum {
    TITAN_EVENT_MOUSE,
    TITAN_EVENT_KEY
} TitanEventKind;

typedef struct {
    TitanEventKind kind;
    uint16_t flags;
    uint16_t x;
    uint16_t y;
    uint32_t scancode;
    int down;
} TitanEvent;

/// FreeRDP allocates this as the connection's context. rdpClientContext must
/// come first.
typedef struct {
    rdpClientContext common;
    TitanRDP *owner;
} TitanContext;

struct TitanRDP {
    TitanRDPCallbacks callbacks;

    /// Guards `context` against being freed while the main thread copies a frame.
    pthread_mutex_t context_lock;
    rdpContext *context;

    pthread_mutex_t queue_lock;
    TitanEvent queue[TITAN_QUEUE_CAPACITY];
    size_t queue_head;
    size_t queue_count;
    /// Signalled when input is queued or a disconnect is requested.
    HANDLE wake_event;

    pthread_t thread;
    int thread_joinable;
    volatile int stop_requested;
    volatile int connected;
};

// MARK: - Helpers

static void titan_notify_state(TitanRDP *rdp, TitanRDPState state, const char *message) {
    if (rdp->callbacks.on_state)
        rdp->callbacks.on_state(rdp->callbacks.userdata, state, message);
}

static TitanRDP *titan_owner(rdpContext *context) {
    return context ? ((TitanContext *)context)->owner : NULL;
}

static uint32_t titan_clamp_dimension(uint32_t value) {
    if (value < 64)
        return 64;
    if (value > 4096)
        return 4096;
    return value & ~1u; // even sizes keep codecs happy
}

static void titan_enqueue(TitanRDP *rdp, TitanEvent event) {
    if (!rdp || !rdp->connected)
        return;

    pthread_mutex_lock(&rdp->queue_lock);

    // Coalesce pointer moves so a fast drag can't flood the queue.
    if (rdp->queue_count > 0 && event.kind == TITAN_EVENT_MOUSE && event.flags == PTR_FLAGS_MOVE) {
        TitanEvent *last =
            &rdp->queue[(rdp->queue_head + rdp->queue_count - 1) % TITAN_QUEUE_CAPACITY];
        if (last->kind == TITAN_EVENT_MOUSE && last->flags == PTR_FLAGS_MOVE) {
            *last = event;
            pthread_mutex_unlock(&rdp->queue_lock);
            return;
        }
    }

    if (rdp->queue_count < TITAN_QUEUE_CAPACITY) {
        rdp->queue[(rdp->queue_head + rdp->queue_count) % TITAN_QUEUE_CAPACITY] = event;
        rdp->queue_count++;
    }
    pthread_mutex_unlock(&rdp->queue_lock);
    SetEvent(rdp->wake_event);
}

static void titan_drain_queue(TitanRDP *rdp, rdpInput *input) {
    TitanEvent pending[TITAN_QUEUE_CAPACITY];
    size_t count = 0;

    pthread_mutex_lock(&rdp->queue_lock);
    ResetEvent(rdp->wake_event);
    while (rdp->queue_count > 0) {
        pending[count++] = rdp->queue[rdp->queue_head];
        rdp->queue_head = (rdp->queue_head + 1) % TITAN_QUEUE_CAPACITY;
        rdp->queue_count--;
    }
    pthread_mutex_unlock(&rdp->queue_lock);

    for (size_t i = 0; i < count; i++) {
        const TitanEvent *event = &pending[i];
        switch (event->kind) {
        case TITAN_EVENT_MOUSE:
            (void)freerdp_input_send_mouse_event(input, event->flags, event->x, event->y);
            break;
        case TITAN_EVENT_KEY:
            (void)freerdp_input_send_keyboard_event_ex(input, event->down ? TRUE : FALSE, FALSE,
                                                       event->scancode);
            break;
        }
    }
}

static void titan_clear_queue(TitanRDP *rdp) {
    pthread_mutex_lock(&rdp->queue_lock);
    rdp->queue_head = 0;
    rdp->queue_count = 0;
    pthread_mutex_unlock(&rdp->queue_lock);
}

// MARK: - FreeRDP callbacks

static BOOL titan_begin_paint(rdpContext *context) {
    rdpGdi *gdi = context->gdi;
    if (!gdi || !gdi->primary || !gdi->primary->hdc || !gdi->primary->hdc->hwnd)
        return TRUE;
    HGDI_WND hwnd = gdi->primary->hdc->hwnd;
    if (hwnd->invalid)
        hwnd->invalid->null = TRUE;
    hwnd->ninvalid = 0;
    return TRUE;
}

static BOOL titan_end_paint(rdpContext *context) {
    TitanRDP *rdp = titan_owner(context);
    rdpGdi *gdi = context->gdi;
    if (!rdp || !gdi || !gdi->primary || !gdi->primary->hdc || !gdi->primary->hdc->hwnd)
        return TRUE;
    HGDI_WND hwnd = gdi->primary->hdc->hwnd;
    if (!hwnd->invalid || hwnd->invalid->null)
        return TRUE;
    if (rdp->callbacks.on_frame)
        rdp->callbacks.on_frame(rdp->callbacks.userdata, hwnd->invalid->x, hwnd->invalid->y,
                                hwnd->invalid->w, hwnd->invalid->h);
    return TRUE;
}

static BOOL titan_desktop_resize(rdpContext *context) {
    TitanRDP *rdp = titan_owner(context);
    if (!rdp || !context->gdi)
        return FALSE;

    const uint32_t width = freerdp_settings_get_uint32(context->settings, FreeRDP_DesktopWidth);
    const uint32_t height = freerdp_settings_get_uint32(context->settings, FreeRDP_DesktopHeight);

    pthread_mutex_lock(&rdp->context_lock);
    const BOOL ok = gdi_resize(context->gdi, width, height);
    pthread_mutex_unlock(&rdp->context_lock);

    if (ok && rdp->callbacks.on_resize)
        rdp->callbacks.on_resize(rdp->callbacks.userdata, width, height);
    return ok;
}

/// FreeRDP may hand over the whole certificate as PEM; reduce it to a SHA-256
/// fingerprint so the app stores and compares something short and stable.
static char *titan_fingerprint(const char *fingerprint, DWORD flags) {
    if (!fingerprint)
        return NULL;
    if (!(flags & VERIFY_CERT_FLAG_FP_IS_PEM))
        return _strdup(fingerprint);

    rdpCertificate *certificate = freerdp_certificate_new_from_pem(fingerprint);
    if (!certificate)
        return NULL;
    char *result = freerdp_certificate_get_fingerprint_by_hash(certificate, "sha256");
    freerdp_certificate_free(certificate);
    return result;
}

static DWORD titan_check_certificate(freerdp *instance, const char *host, UINT16 port,
                                     const char *fingerprint, DWORD flags, int changed) {
    TitanRDP *rdp = titan_owner(instance->context);
    if (!rdp || !rdp->callbacks.on_certificate)
        return 0;

    char *digest = titan_fingerprint(fingerprint, flags);
    const int accepted =
        rdp->callbacks.on_certificate(rdp->callbacks.userdata, host, port, digest ? digest : "",
                                      changed);
    free(digest);
    // 2 = accept for this session only. The app keeps its own trusted list.
    return accepted ? 2 : 0;
}

static DWORD titan_verify_certificate(freerdp *instance, const char *host, UINT16 port,
                                      const char *common_name, const char *subject,
                                      const char *issuer, const char *fingerprint, DWORD flags) {
    WINPR_UNUSED(common_name);
    WINPR_UNUSED(subject);
    WINPR_UNUSED(issuer);
    return titan_check_certificate(instance, host, port, fingerprint, flags, 0);
}

static DWORD titan_verify_changed_certificate(freerdp *instance, const char *host, UINT16 port,
                                              const char *common_name, const char *subject,
                                              const char *issuer, const char *new_fingerprint,
                                              const char *old_subject, const char *old_issuer,
                                              const char *old_fingerprint, DWORD flags) {
    WINPR_UNUSED(common_name);
    WINPR_UNUSED(subject);
    WINPR_UNUSED(issuer);
    WINPR_UNUSED(old_subject);
    WINPR_UNUSED(old_issuer);
    WINPR_UNUSED(old_fingerprint);
    return titan_check_certificate(instance, host, port, new_fingerprint, flags, 1);
}

static BOOL titan_pre_connect(freerdp *instance) {
    rdpContext *context = instance->context;
    if (PubSub_SubscribeChannelConnected(context->pubSub,
                                         freerdp_client_OnChannelConnectedEventHandler) < 0)
        return FALSE;
    if (PubSub_SubscribeChannelDisconnected(context->pubSub,
                                            freerdp_client_OnChannelDisconnectedEventHandler) < 0)
        return FALSE;
    // Channels are loaded by titan_load_channels, which FreeRDP calls after this.
    return TRUE;
}

// FreeRDPKit leaves out device redirection (rdpdr). freerdp_client_load_addins
// asks for rdpdr whenever network auto-detect, heartbeats or multitransport are
// on, and fails pre-connect when it isn't there ("A configuration error
// prevented a connection..."). Those features don't need rdpdr to work, so
// hide them while the add-ins load, then put them back.
static BOOL titan_load_channels(freerdp *instance) {
    rdpSettings *settings = instance->context->settings;
    const FreeRDP_Settings_Keys_Bool keys[] = { FreeRDP_NetworkAutoDetect,
                                                FreeRDP_SupportHeartbeatPdu,
                                                FreeRDP_SupportMultitransport };
    BOOL saved[ARRAYSIZE(keys)];
    for (size_t i = 0; i < ARRAYSIZE(keys); i++) {
        saved[i] = freerdp_settings_get_bool(settings, keys[i]);
        if (!freerdp_settings_set_bool(settings, keys[i], FALSE))
            return FALSE;
    }
    BOOL ok = freerdp_client_load_addins(instance->context->channels, settings);
    for (size_t i = 0; i < ARRAYSIZE(keys); i++)
        ok = freerdp_settings_set_bool(settings, keys[i], saved[i]) && ok;
    return ok;
}

static BOOL titan_post_connect(freerdp *instance) {
    rdpContext *context = instance->context;
    TitanRDP *rdp = titan_owner(context);

    pthread_mutex_lock(&rdp->context_lock);
    const BOOL ok = gdi_init(instance, PIXEL_FORMAT_BGRA32);
    pthread_mutex_unlock(&rdp->context_lock);
    if (!ok)
        return FALSE;

    context->update->BeginPaint = titan_begin_paint;
    context->update->EndPaint = titan_end_paint;
    context->update->DesktopResize = titan_desktop_resize;

    if (rdp->callbacks.on_resize)
        rdp->callbacks.on_resize(rdp->callbacks.userdata, context->gdi->width,
                                 context->gdi->height);
    return TRUE;
}

static void titan_post_disconnect(freerdp *instance) {
    rdpContext *context = instance->context;
    TitanRDP *rdp = titan_owner(context);

    PubSub_UnsubscribeChannelConnected(context->pubSub,
                                       freerdp_client_OnChannelConnectedEventHandler);
    PubSub_UnsubscribeChannelDisconnected(context->pubSub,
                                          freerdp_client_OnChannelDisconnectedEventHandler);

    if (rdp)
        pthread_mutex_lock(&rdp->context_lock);
    gdi_free(instance);
    if (rdp)
        pthread_mutex_unlock(&rdp->context_lock);
}

static BOOL titan_client_new(freerdp *instance, rdpContext *context) {
    WINPR_UNUSED(context);
    instance->PreConnect = titan_pre_connect;
    instance->PostConnect = titan_post_connect;
    instance->PostDisconnect = titan_post_disconnect;
    instance->LoadChannels = titan_load_channels;
    instance->VerifyCertificateEx = titan_verify_certificate;
    instance->VerifyChangedCertificateEx = titan_verify_changed_certificate;
    return TRUE;
}

// MARK: - Connection thread

static void *titan_run(void *arg) {
    TitanRDP *rdp = (TitanRDP *)arg;
    rdpContext *context = rdp->context;
    freerdp *instance = context->instance;
    int lost = 0;

    titan_notify_state(rdp, TITAN_RDP_STATE_CONNECTING, NULL);

    if (!freerdp_connect(instance)) {
        const UINT32 code = freerdp_get_last_error(context);
        const char *reason = freerdp_get_last_error_string(code);
        pthread_mutex_lock(&rdp->context_lock);
        rdp->context = NULL;
        pthread_mutex_unlock(&rdp->context_lock);
        freerdp_client_context_free(context);
        titan_notify_state(rdp, rdp->stop_requested ? TITAN_RDP_STATE_DISCONNECTED
                                                    : TITAN_RDP_STATE_FAILED,
                           rdp->stop_requested ? NULL : (reason ? reason : "Could not connect"));
        return NULL;
    }

    titan_clear_queue(rdp);
    rdp->connected = 1;
    titan_notify_state(rdp, TITAN_RDP_STATE_CONNECTED, NULL);

    while (!rdp->stop_requested && !freerdp_shall_disconnect_context(context)) {
        HANDLE handles[MAXIMUM_WAIT_OBJECTS] = { 0 };
        DWORD count = freerdp_get_event_handles(context, handles, ARRAYSIZE(handles) - 1);
        if (count == 0) {
            lost = 1;
            break;
        }
        handles[count++] = rdp->wake_event;

        const DWORD status = WaitForMultipleObjects(count, handles, FALSE, TITAN_LOOP_TIMEOUT_MS);
        if (status == WAIT_FAILED) {
            lost = 1;
            break;
        }
        if (!freerdp_check_event_handles(context)) {
            lost = !rdp->stop_requested;
            break;
        }
        titan_drain_queue(rdp, context->input);
    }

    rdp->connected = 0;
    titan_clear_queue(rdp);
    freerdp_disconnect(instance);

    pthread_mutex_lock(&rdp->context_lock);
    rdp->context = NULL;
    pthread_mutex_unlock(&rdp->context_lock);
    freerdp_client_context_free(context);

    if (lost)
        titan_notify_state(rdp, TITAN_RDP_STATE_FAILED, "Connection lost");
    else
        titan_notify_state(rdp, TITAN_RDP_STATE_DISCONNECTED, NULL);
    return NULL;
}

// MARK: - Public API

TitanRDP *titan_rdp_new(TitanRDPCallbacks callbacks) {
    // A dropped socket must not kill the app.
    signal(SIGPIPE, SIG_IGN);

    TitanRDP *rdp = calloc(1, sizeof(TitanRDP));
    if (!rdp)
        return NULL;
    rdp->callbacks = callbacks;
    pthread_mutex_init(&rdp->context_lock, NULL);
    pthread_mutex_init(&rdp->queue_lock, NULL);
    rdp->wake_event = CreateEventA(NULL, TRUE, FALSE, NULL);
    if (!rdp->wake_event) {
        pthread_mutex_destroy(&rdp->context_lock);
        pthread_mutex_destroy(&rdp->queue_lock);
        free(rdp);
        return NULL;
    }
    return rdp;
}

void titan_rdp_free(TitanRDP *rdp) {
    if (!rdp)
        return;
    titan_rdp_disconnect(rdp);
    if (rdp->thread_joinable) {
        pthread_join(rdp->thread, NULL);
        rdp->thread_joinable = 0;
    }
    (void)CloseHandle(rdp->wake_event);
    pthread_mutex_destroy(&rdp->context_lock);
    pthread_mutex_destroy(&rdp->queue_lock);
    free(rdp);
}

static BOOL titan_set_string(rdpSettings *settings, FreeRDP_Settings_Keys_String key,
                             const char *value) {
    if (!value || !value[0])
        return TRUE;
    return freerdp_settings_set_string(settings, key, value);
}

int titan_rdp_connect(TitanRDP *rdp, const char *host, uint16_t port, const char *username,
                      const char *domain, const char *password, uint32_t width, uint32_t height,
                      const TitanRDPOptions *options) {
    if (!rdp || !host || !host[0])
        return -1;

    // Reap a finished connection; refuse if one is still running.
    if (rdp->thread_joinable) {
        pthread_mutex_lock(&rdp->context_lock);
        const int running = rdp->context != NULL;
        pthread_mutex_unlock(&rdp->context_lock);
        if (running)
            return -1;
        pthread_join(rdp->thread, NULL);
        rdp->thread_joinable = 0;
    }

    RDP_CLIENT_ENTRY_POINTS entry = { 0 };
    entry.Version = RDP_CLIENT_INTERFACE_VERSION;
    entry.Size = sizeof(RDP_CLIENT_ENTRY_POINTS_V1);
    entry.ContextSize = sizeof(TitanContext);
    entry.ClientNew = titan_client_new;

    rdpContext *context = freerdp_client_context_new(&entry);
    if (!context)
        return -1;
    ((TitanContext *)context)->owner = rdp;

    rdpSettings *settings = context->settings;
    const BOOL has_password = password && password[0];
    const UINT32 connection_type =
        options && options->connection_type >= CONNECTION_TYPE_MODEM && options->connection_type <= CONNECTION_TYPE_LAN
            ? options->connection_type
            : CONNECTION_TYPE_LAN;
    const BOOL ok =
        freerdp_settings_set_string(settings, FreeRDP_ServerHostname, host) &&
        freerdp_settings_set_uint32(settings, FreeRDP_ServerPort, port ? port : 3389) &&
        titan_set_string(settings, FreeRDP_Username, username) &&
        titan_set_string(settings, FreeRDP_Domain, domain) &&
        titan_set_string(settings, FreeRDP_Password, password) &&
        freerdp_settings_set_bool(settings, FreeRDP_AutoLogonEnabled, has_password) &&
        freerdp_settings_set_uint32(settings, FreeRDP_DesktopWidth, titan_clamp_dimension(width)) &&
        freerdp_settings_set_uint32(settings, FreeRDP_DesktopHeight,
                                    titan_clamp_dimension(height)) &&
        freerdp_settings_set_uint32(settings, FreeRDP_ColorDepth, 32) &&
        freerdp_settings_set_bool(settings, FreeRDP_SoftwareGdi, TRUE) &&
        // GFX pipeline without H.264: Titan's UI is mostly static, so the
        // progressive/planar codecs are lower latency than video.
        freerdp_settings_set_bool(settings, FreeRDP_SupportGraphicsPipeline, TRUE) &&
        freerdp_settings_set_bool(settings, FreeRDP_GfxH264, FALSE) &&
        freerdp_settings_set_bool(settings, FreeRDP_GfxAVC444, FALSE) &&
        freerdp_settings_set_bool(settings, FreeRDP_GfxAVC444v2, FALSE) &&
        // Software codecs for servers (or GFX fallbacks) that use them.
        freerdp_settings_set_bool(settings, FreeRDP_RemoteFxCodec, TRUE) &&
        freerdp_settings_set_bool(settings, FreeRDP_NSCodec, TRUE) &&
        // Reconnects are handled by the app (with backoff), not by FreeRDP.
        freerdp_settings_set_bool(settings, FreeRDP_AutoReconnectionEnabled, FALSE) &&
        freerdp_set_connection_type(settings, connection_type);
    if (!ok) {
        freerdp_client_context_free(context);
        return -1;
    }

    rdp->stop_requested = 0;
    rdp->connected = 0;
    titan_clear_queue(rdp);
    ResetEvent(rdp->wake_event);

    pthread_mutex_lock(&rdp->context_lock);
    rdp->context = context;
    pthread_mutex_unlock(&rdp->context_lock);

    if (pthread_create(&rdp->thread, NULL, titan_run, rdp) != 0) {
        pthread_mutex_lock(&rdp->context_lock);
        rdp->context = NULL;
        pthread_mutex_unlock(&rdp->context_lock);
        freerdp_client_context_free(context);
        return -1;
    }
    rdp->thread_joinable = 1;
    return 0;
}

void titan_rdp_disconnect(TitanRDP *rdp) {
    if (!rdp)
        return;
    rdp->stop_requested = 1;
    pthread_mutex_lock(&rdp->context_lock);
    if (rdp->context)
        (void)freerdp_abort_connect_context(rdp->context);
    pthread_mutex_unlock(&rdp->context_lock);
    SetEvent(rdp->wake_event);
}

int titan_rdp_copy_frame(TitanRDP *rdp, uint8_t *dest, size_t dest_size, uint32_t *width,
                         uint32_t *height, uint32_t *stride) {
    if (!rdp)
        return -1;

    int result = -1;
    pthread_mutex_lock(&rdp->context_lock);
    rdpGdi *gdi = rdp->context ? rdp->context->gdi : NULL;
    if (gdi && gdi->primary_buffer) {
        const size_t needed = (size_t)gdi->stride * gdi->height;
        if (width)
            *width = gdi->width;
        if (height)
            *height = gdi->height;
        if (stride)
            *stride = gdi->stride;
        if (dest && dest_size >= needed) {
            memcpy(dest, gdi->primary_buffer, needed);
            result = 0;
        }
    }
    pthread_mutex_unlock(&rdp->context_lock);
    return result;
}

void titan_rdp_mouse_move(TitanRDP *rdp, uint16_t x, uint16_t y) {
    TitanEvent event = { .kind = TITAN_EVENT_MOUSE, .flags = PTR_FLAGS_MOVE, .x = x, .y = y };
    titan_enqueue(rdp, event);
}

void titan_rdp_mouse_button(TitanRDP *rdp, TitanRDPButton button, int down, uint16_t x,
                            uint16_t y) {
    uint16_t flags = PTR_FLAGS_BUTTON1;
    if (button == TITAN_RDP_BUTTON_RIGHT)
        flags = PTR_FLAGS_BUTTON2;
    else if (button == TITAN_RDP_BUTTON_MIDDLE)
        flags = PTR_FLAGS_BUTTON3;
    if (down)
        flags |= PTR_FLAGS_DOWN;
    TitanEvent event = { .kind = TITAN_EVENT_MOUSE, .flags = flags, .x = x, .y = y };
    titan_enqueue(rdp, event);
}

void titan_rdp_mouse_wheel(TitanRDP *rdp, int32_t delta, uint16_t x, uint16_t y) {
    if (delta == 0)
        return;
    if (delta > 255)
        delta = 255;
    if (delta < -255)
        delta = -255;
    // 9-bit two's complement: the sign bit is PTR_FLAGS_WHEEL_NEGATIVE.
    const uint16_t flags = (uint16_t)(PTR_FLAGS_WHEEL | ((uint16_t)delta & WheelRotationMask));
    TitanEvent event = { .kind = TITAN_EVENT_MOUSE, .flags = flags, .x = x, .y = y };
    titan_enqueue(rdp, event);
}

void titan_rdp_key(TitanRDP *rdp, uint32_t scancode, int down) {
    TitanEvent event = { .kind = TITAN_EVENT_KEY, .scancode = scancode, .down = down };
    titan_enqueue(rdp, event);
}
