using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Windows.Input;
using System.Windows.Media;
using TitanDeckHost.Core.Api;

namespace TitanDeckHost.App;

public sealed class CheckRow
{
    public required CheckDto Check { get; init; }
    public string Title => Check.Title;
    public string Detail => Check.Detail;
    public string? FixTitle => Check.FixTitle;
    public bool HasFix => Check.Fix is not null;
    public required ICommand FixCommand { get; init; }
    public Brush Colour => MainViewModel.BrushFor(Check.State);
}

public sealed class DeviceRow
{
    public required DeviceDto Device { get; init; }
    public string Name => Device.Name;
    public string Seen => Device.LastSeen is { } seen ? $"Last seen {seen.ToLocalTime():ddd HH:mm}" : $"Paired {Device.PairedAt.ToLocalTime():d MMM}";
    public required ICommand RemoveCommand { get; init; }
}

/// <summary>The dashboard: status, checklist with fixes, pairing and folders.</summary>
public sealed partial class MainViewModel : INotifyPropertyChanged
{
    private readonly HostClient _client;
    private string _headline = "Looking for the TitanDeck Host service...";
    private string _subtitle = "";
    private Brush _headlineColour = Brushes.Gray;
    private string? _code;
    private string _codeHint = "";
    private string _message = "";
    private bool _busy;
    private int _filesWaiting;

    public MainViewModel(HostClient client)
    {
        _client = client;
        NewCodeCommand = new RelayCommand(async () =>
        {
            Apply(await _client.NewCode());
        });
        OpenToPCCommand = new RelayCommand(async () => App.OpenFolder((await _client.Folders())?.ToPC));
        BestCommand = new RelayCommand(() => SetQuality("best"));
        BalancedCommand = new RelayCommand(() => SetQuality("balanced"));
        WeakSignalCommand = new RelayCommand(() => SetQuality("weakSignal"));
        OpenToIPadCommand = new RelayCommand(async () => App.OpenFolder((await _client.Folders())?.ToIPad));
    }

    public ObservableCollection<CheckRow> Checks { get; } = new();
    public ObservableCollection<DeviceRow> Devices { get; } = new();
    public ICommand NewCodeCommand { get; }
    public ICommand OpenToPCCommand { get; }
    public ICommand OpenToIPadCommand { get; }
    public ICommand BestCommand { get; }
    public ICommand BalancedCommand { get; }
    public ICommand WeakSignalCommand { get; }

    private string _qualityText = "";
    /// <summary>"Now: Best - high quality, 60 fps".</summary>
    public string QualityText { get => _qualityText; set => Set(ref _qualityText, value); }

    public string Headline { get => _headline; set => Set(ref _headline, value); }
    public string Subtitle { get => _subtitle; set => Set(ref _subtitle, value); }
    public Brush HeadlineColour { get => _headlineColour; set => Set(ref _headlineColour, value); }
    /// <summary>"482 913" while a pairing code is live.</summary>
    public string? Code { get => _code; set { Set(ref _code, value); OnPropertyChanged(nameof(HasCode)); } }
    public bool HasCode => Code is not null;

    private string? _serviceButton;
    private bool _restartService;
    private bool _reachable = true;
    /// <summary>"Start the service" or "Restart the service" when the window can't reach it, else null.</summary>
    public string? ServiceButton { get => _serviceButton; set { Set(ref _serviceButton, value); OnPropertyChanged(nameof(HasServiceButton)); } }
    public bool HasServiceButton => ServiceButton is not null;

    private ICommand? _serviceCommand;
    /// <summary>Starts the service, or stops and starts it (Windows asks for permission: the window runs as the signed-in user).</summary>
    public ICommand ServiceCommand => _serviceCommand ??= new RelayCommand(async () =>
    {
        var restart = _restartService;
        try
        {
            var system = Environment.ExpandEnvironmentVariables(@"%SystemRoot%\System32");
            var info = restart
                ? new System.Diagnostics.ProcessStartInfo(Path.Combine(system, "cmd.exe"), "/c \"net stop TitanDeckHost & net start TitanDeckHost\"")
                : new System.Diagnostics.ProcessStartInfo(Path.Combine(system, "net.exe"), "start TitanDeckHost");
            info.UseShellExecute = true;
            info.Verb = "runas";
            info.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
            using var start = System.Diagnostics.Process.Start(info);
            Message = restart ? "Restarting the TitanDeck Host service..." : "Starting the TitanDeck Host service...";
            if (start is not null) await start.WaitForExitAsync();
            await Refresh();
            Message = _reachable
                ? "The TitanDeck Host service is running."
                : "That didn't cure it. What's at the top of this window says what Windows and the service each say; " +
                  "Windows' Event Viewer (Windows Logs > Application, source \"TitanDeck Host\") has the service's side.";
        }
        catch (System.ComponentModel.Win32Exception)
        {
            Message = "That needs Windows' permission. Press the button again and choose Yes.";
        }
    });

    /// <summary>What Windows says about the service. Reading it needs no permission.</summary>
    private static WindowsServiceState ServiceState()
    {
        try
        {
            using var service = new System.ServiceProcess.ServiceController("TitanDeckHost");
            return service.Status switch
            {
                System.ServiceProcess.ServiceControllerStatus.Running => WindowsServiceState.Running,
                System.ServiceProcess.ServiceControllerStatus.Stopped => WindowsServiceState.Stopped,
                System.ServiceProcess.ServiceControllerStatus.Paused => WindowsServiceState.Stopped,
                System.ServiceProcess.ServiceControllerStatus.StartPending => WindowsServiceState.Starting,
                System.ServiceProcess.ServiceControllerStatus.ContinuePending => WindowsServiceState.Starting,
                System.ServiceProcess.ServiceControllerStatus.StopPending => WindowsServiceState.Stopping,
                System.ServiceProcess.ServiceControllerStatus.PausePending => WindowsServiceState.Stopping,
                _ => WindowsServiceState.Unknown,
            };
        }
        catch (InvalidOperationException error) when (error.InnerException is System.ComponentModel.Win32Exception { NativeErrorCode: 1060 })
        {
            return WindowsServiceState.NotInstalled;   // "the specified service does not exist"
        }
        catch (Exception)
        {
            return WindowsServiceState.Unknown;
        }
    }

    public string CodeHint { get => _codeHint; set => Set(ref _codeHint, value); }
    public string Message { get => _message; set => Set(ref _message, value); }
    public bool Busy { get => _busy; set => Set(ref _busy, value); }
    public int FilesWaiting { get => _filesWaiting; set { Set(ref _filesWaiting, value); OnPropertyChanged(nameof(FilesWaitingText)); } }
    public string FilesWaitingText => FilesWaiting switch
    {
        0 => "Nothing waiting for the iPad.",
        1 => "1 file waiting for the iPad.",
        var n => $"{n} files waiting for the iPad.",
    };

    /// <summary>
    /// Three things, so the top of the window says what's actually wrong (Host
    /// 0.19.1): does the service answer at all (a ping with no work behind
    /// it), did its checklist come back, and what does Windows say about the
    /// service. Before, anything short of a good checklist read "the service
    /// isn't running", even with Windows showing it running.
    /// </summary>
    public async Task Refresh()
    {
        var pingProblem = await _client.Ping();
        StatusResponse? status = null;
        string? statusProblem = null;
        if (pingProblem is null) (status, statusProblem) = await _client.Status();
        var windows = pingProblem is null ? WindowsServiceState.Running : await Task.Run(ServiceState);
        var trouble = ServiceHealth.Diagnose(windows, pingProblem, statusProblem);
        ServiceButton = trouble?.Button;
        _restartService = trouble?.Restart ?? false;
        _reachable = trouble?.Reachable ?? true;
        if (trouble is not null)
        {
            Headline = trouble.Headline;
            Subtitle = trouble.Detail;
            HeadlineColour = BrushFor(trouble.Severe ? "problem" : "warning");
            if (!trouble.Reachable)
            {
                Checks.Clear();
                return;
            }
        }
        // The service answers: the rest of the window works even if the checklist didn't come back.
        if (status is not null) ShowStatus(status);
        Apply(await _client.Pairing());
        ShowQuality(await _client.Quality());
        await RefreshUpdate();
        ShowPatch(await _client.Patch());
        ShowMode(await _client.Mode());
        ShowNetwork(await _client.Network());
        ShowCitp(await _client.Citp());
    }

    private void ShowStatus(StatusResponse status)
    {
        Headline = status.Overall switch
        {
            "ok" => "Ready for TitanDeck",
            "warning" => "Working - a couple of things to look at",
            _ => "Needs attention",
        };
        HeadlineColour = BrushFor(status.Overall);
        Subtitle = $"{status.WindowsVersion}  ·  Remote Desktop build {status.TermsrvVersion}  ·  Host {status.HostVersion}";
        FilesWaiting = status.FilesWaitingForIPad;

        Checks.Clear();
        foreach (var check in status.Checks)
        {
            Checks.Add(new CheckRow
            {
                Check = check,
                FixCommand = new RelayCommand(async () => await RunFix(check)),
            });
        }
    }

    private async Task SetQuality(string preset)
    {
        var result = await _client.SetQuality(preset);
        ShowQuality(result);
        Message = result is null ? "Couldn't change the picture settings." : "Picture settings changed. They apply when the iPad next connects (TitanDeck reconnects by itself when you change them there).";
    }

    private void ShowQuality(RdpQualityDto? quality)
    {
        if (quality is null) return;
        var name = quality.Preset switch
        {
            "best" => "Best",
            "balanced" => "Balanced",
            "weakSignal" => "Weak signal",
            _ => "Custom",
        };
        QualityText = $"Now: {name} - {quality.ImageQuality} quality, {quality.FrameRate} fps" +
                      (quality.Profile == "minimumBandwidth" ? ", lowest bandwidth" : "");
    }

    private async Task RunFix(CheckDto check)
    {
        if (check.Fix is null || Busy) return;
        Busy = true;
        Message = $"{check.FixTitle}: {check.Title}...";
        var result = await _client.Fix(check.Fix);
        Message = result.Success ? result.Message : $"Didn't work: {result.Message}";
        Busy = false;
        await Refresh();
    }

    private void Apply(PairingInfo? pairing)
    {
        if (pairing is null) return;
        Code = pairing.Code is { Length: 6 } code ? $"{code[..3]} {code[3..]}" : null;
        CodeHint = pairing.Expires is { } expires
            ? $"Type this in TitanDeck (Settings > TitanDeck Host). Works once, until {expires.ToLocalTime():HH:mm}."
            : "Pair an iPad or iPhone to send files and fix things from it.";
        Devices.Clear();
        foreach (var device in pairing.Devices)
        {
            Devices.Add(new DeviceRow
            {
                Device = device,
                RemoveCommand = new RelayCommand(async () =>
                {
                    await _client.Revoke(device.Id);
                    Apply(await _client.Pairing());
                }),
            });
        }
    }

    public static Brush BrushFor(string state) => state switch
    {
        "ok" => (Brush)System.Windows.Application.Current.Resources["Ok"],
        "warning" => (Brush)System.Windows.Application.Current.Resources["Warning"],
        _ => (Brush)System.Windows.Application.Current.Resources["Problem"],
    };

    public event PropertyChangedEventHandler? PropertyChanged;

    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        OnPropertyChanged(name);
    }

    private void OnPropertyChanged(string? name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public sealed class RelayCommand : ICommand
{
    private readonly Func<Task> _run;
    public RelayCommand(Func<Task> run) => _run = run;
    public event EventHandler? CanExecuteChanged { add { } remove { } }
    public bool CanExecute(object? parameter) => true;
    public async void Execute(object? parameter) => await _run();
}
