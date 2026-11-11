namespace TitanDeckHost.Core.Api;

/// <summary>What Windows says about the TitanDeck Host service.</summary>
public enum WindowsServiceState
{
    /// <summary>Windows wouldn't say.</summary>
    Unknown,
    NotInstalled,
    Stopped,
    Starting,
    Running,
    Stopping,
}

/// <summary>What the Host window shows when it and the service aren't talking properly.</summary>
/// <param name="Button">"Start the service", "Restart the service", or null for no button.</param>
/// <param name="Restart">The button stops the service first.</param>
/// <param name="Severe">Red (the Host can't work); otherwise amber.</param>
/// <param name="Reachable">The service answers, so the rest of the window still works.</param>
public sealed record ServiceTrouble(string Headline, string Detail, string? Button, bool Restart, bool Severe, bool Reachable);

/// <summary>
/// Says what's actually wrong between the Host window and the service (Host
/// 0.19.1). The window used to say "the service isn't running" for anything
/// short of a good answer - a slow answer, an error, a call that never left
/// the window - even while Windows showed the service running, which sent
/// everyone looking in the wrong place. Now it puts together three things:
/// whether the service answered a ping, whether its status came back, and
/// what Windows says about the service. Pure, so it's tested.
/// </summary>
public static class ServiceHealth
{
    public const string Address = "127.0.0.1:4432";

    /// <summary>Null when all is well.</summary>
    /// <param name="pingProblem">Why the ping wasn't answered, or null if it was.</param>
    /// <param name="statusProblem">Why the status didn't come back, or null if it did.</param>
    public static ServiceTrouble? Diagnose(WindowsServiceState windows, string? pingProblem, string? statusProblem)
    {
        if (pingProblem is null)
        {
            if (statusProblem is null) return null;
            return new ServiceTrouble(
                "TitanDeck Host is running, but couldn't check this PC",
                $"The service answers, but its checklist didn't come back ({statusProblem}). It's asked again every few seconds. " +
                "Pairing, files and the deck's keypad don't depend on it.",
                Button: null, Restart: false, Severe: false, Reachable: true);
        }
        return windows switch
        {
            WindowsServiceState.NotInstalled => new ServiceTrouble(
                "The TitanDeck Host service isn't installed",
                "Windows has no \"TitanDeck Host\" service. Run the TitanDeck Host installer again.",
                Button: null, Restart: false, Severe: true, Reachable: false),
            WindowsServiceState.Stopped => new ServiceTrouble(
                "The TitanDeck Host service isn't running",
                "Press Start the service (Windows asks for permission), or start \"TitanDeck Host\" in Services.",
                Button: "Start the service", Restart: false, Severe: true, Reachable: false),
            WindowsServiceState.Starting => new ServiceTrouble(
                "The TitanDeck Host service is starting...",
                "Windows is starting it. This window finds it by itself in a few seconds.",
                Button: null, Restart: false, Severe: false, Reachable: false),
            WindowsServiceState.Stopping => new ServiceTrouble(
                "The TitanDeck Host service is stopping...",
                "Windows is stopping it (an update does this). If it stays like this, restart the PC.",
                Button: null, Restart: false, Severe: false, Reachable: false),
            WindowsServiceState.Running => new ServiceTrouble(
                "The service is running, but this window can't reach it",
                $"Windows says the TitanDeck Host service is running, but it didn't answer this window on {Address} ({pingProblem}). " +
                "Press Restart the service (Windows asks for permission). If it comes back like this, that wording in brackets says why.",
                Button: "Restart the service", Restart: true, Severe: true, Reachable: false),
            _ => new ServiceTrouble(
                "This window can't reach the TitanDeck Host service",
                $"It didn't answer on {Address} ({pingProblem}), and Windows wouldn't say whether it's running. " +
                "Press Start the service (Windows asks for permission), or look for \"TitanDeck Host\" in Services.",
                Button: "Start the service", Restart: false, Severe: true, Reachable: false),
        };
    }

    /// <summary>A call's failure in a few plain words, for the brackets above.</summary>
    public static string Describe(Exception error) => error switch
    {
        OperationCanceledException => "no answer in time",
        HttpRequestException { StatusCode: { } status } => $"it answered {(int)status}",
        HttpRequestException { InnerException: System.Net.Sockets.SocketException socket } => socket.SocketErrorCode switch
        {
            System.Net.Sockets.SocketError.ConnectionRefused => "nothing is listening there",
            System.Net.Sockets.SocketError.TimedOut => "the connection timed out",
            System.Net.Sockets.SocketError.AccessDenied => "Windows blocked the connection",
            var code => $"{code}: {socket.Message}",
        },
        HttpRequestException { InnerException: { } inner } => Trim(inner.Message),
        System.Text.Json.JsonException => "its answer wasn't what this window expects - the window and the service may be different versions",
        _ => Trim(error.Message),
    };

    private static string Trim(string message)
    {
        var line = message.ReplaceLineEndings(" ").Trim().TrimEnd('.');
        return line.Length <= 160 ? line : line[..160] + "...";
    }
}
