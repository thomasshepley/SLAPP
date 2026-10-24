// Remote/Bridge/titan_rdp.h
//
// A small C wrapper around FreeRDP 3 so Swift never touches FreeRDP's own types.
// One TitanRDP is one connection. It runs on its own thread; callbacks arrive on
// that thread, so Swift hops to the main actor before touching UI.

#ifndef TITAN_RDP_H
#define TITAN_RDP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TitanRDP TitanRDP;

typedef enum {
    TITAN_RDP_STATE_DISCONNECTED = 0,
    TITAN_RDP_STATE_CONNECTING = 1,
    TITAN_RDP_STATE_CONNECTED = 2,
    TITAN_RDP_STATE_FAILED = 3
} TitanRDPState;

typedef enum {
    TITAN_RDP_BUTTON_LEFT = 0,
    TITAN_RDP_BUTTON_RIGHT = 1,
    TITAN_RDP_BUTTON_MIDDLE = 2
} TitanRDPButton;

typedef struct {
    void *userdata;
    /// State change. `message` is a short reason on failure, otherwise NULL.
    void (*on_state)(void *userdata, TitanRDPState state, const char *message);
    /// Part of the desktop changed. Read it with titan_rdp_copy_frame.
    void (*on_frame)(void *userdata, int32_t x, int32_t y, int32_t width, int32_t height);
    /// The desktop size changed (also sent once after connecting).
    void (*on_resize)(void *userdata, uint32_t width, uint32_t height);
    /// Server certificate check. Return 1 to accept, 0 to reject.
    /// `changed` is 1 when the server's certificate differs from the stored one.
    int (*on_certificate)(void *userdata, const char *host, uint16_t port,
                          const char *fingerprint, int changed);
} TitanRDPCallbacks;

/// Picture options for titan_rdp_connect. Zero fields mean the defaults.
typedef struct TitanRDPOptions {
    /// FreeRDP connection type, which sets the visual effects Windows draws:
    /// 6 LAN (everything), 4 broadband high (no wallpaper or animations),
    /// 2 broadband low (plain: no themes, font smoothing or window contents
    /// while dragging). 0 means LAN.
    uint32_t connection_type;
} TitanRDPOptions;

/// Creates a connection object. Nothing happens until titan_rdp_connect.
TitanRDP *titan_rdp_new(TitanRDPCallbacks callbacks);

/// Disconnects if needed, waits for the connection thread, and frees everything.
/// Callbacks never fire after this returns.
void titan_rdp_free(TitanRDP *rdp);

/// Starts connecting on a background thread. Returns 0 on success (the result
/// arrives through on_state), or -1 if a connection is already running or the
/// arguments are unusable.
int titan_rdp_connect(TitanRDP *rdp, const char *host, uint16_t port, const char *username,
                      const char *domain, const char *password, uint32_t width, uint32_t height,
                      const TitanRDPOptions *options);

/// Asks the connection to close. on_state reports DISCONNECTED when it has.
void titan_rdp_disconnect(TitanRDP *rdp);

/// Copies the current desktop (32-bit BGRA, premultiplied, top row first) into
/// `dest`. Returns 0 and fills width/height/stride, or -1 if there's no frame yet
/// or `dest_size` is too small (width/height/stride are still filled so the
/// caller can resize its buffer and try again).
int titan_rdp_copy_frame(TitanRDP *rdp, uint8_t *dest, size_t dest_size, uint32_t *width,
                         uint32_t *height, uint32_t *stride);

/// Input. Coordinates are desktop pixels. Safe to call from any thread: events
/// are queued and sent from the connection thread.
void titan_rdp_mouse_move(TitanRDP *rdp, uint16_t x, uint16_t y);
void titan_rdp_mouse_button(TitanRDP *rdp, TitanRDPButton button, int down, uint16_t x,
                            uint16_t y);
/// Vertical wheel. Positive scrolls up (away from the user), in wheel units
/// (120 = one notch). Clamped to +/-255 per event.
void titan_rdp_mouse_wheel(TitanRDP *rdp, int32_t delta, uint16_t x, uint16_t y);
/// RDP scancode (set 1). Extended keys have 0x100 added, as in FreeRDP.
void titan_rdp_key(TitanRDP *rdp, uint32_t scancode, int down);

#ifdef __cplusplus
}
#endif

#endif /* TITAN_RDP_H */
