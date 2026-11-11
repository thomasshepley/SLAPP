namespace TitanDeckHost.Core.Net;

/// <summary>
/// HTTP clients for calls that never leave this PC (the Host window to the
/// service, the service to Titan's WebAPI on 127.0.0.1). They never go near
/// Windows' proxy settings (Host 0.19.1): .NET otherwise asks Windows to
/// "automatically detect" a proxy, again every two minutes, and on a show
/// network with no internet or DNS that search can hold a call up for
/// seconds - long enough for a keypad line to be refused as too old, or for
/// the window to decide the service isn't there. A proxy that is set would
/// be worse: the call would be sent to it and never arrive.
/// </summary>
public static class LocalHttp
{
    public static SocketsHttpHandler Handler() => new()
    {
        UseProxy = false,
        // This PC answers or refuses straight away; never wait long to find out.
        ConnectTimeout = TimeSpan.FromSeconds(3),
    };

    public static HttpClient Client(TimeSpan timeout, Uri? baseAddress = null) => new(Handler())
    {
        Timeout = timeout,
        BaseAddress = baseAddress,
    };
}
