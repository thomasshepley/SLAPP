using System.Collections.ObjectModel;
using System.ComponentModel;
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
public sealed class MainViewModel : INotifyPropertyChanged
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
        OpenToIPadCommand = new RelayCommand(async () => App.OpenFolder((await _client.Folders())?.ToIPad));
    }

    public ObservableCollection<CheckRow> Checks { get; } = new();
    public ObservableCollection<DeviceRow> Devices { get; } = new();
    public ICommand NewCodeCommand { get; }
    public ICommand OpenToPCCommand { get; }
    public ICommand OpenToIPadCommand { get; }

    public string Headline { get => _headline; set => Set(ref _headline, value); }
    public string Subtitle { get => _subtitle; set => Set(ref _subtitle, value); }
    public Brush HeadlineColour { get => _headlineColour; set => Set(ref _headlineColour, value); }
    /// <summary>"482 913" while a pairing code is live.</summary>
    public string? Code { get => _code; set { Set(ref _code, value); OnPropertyChanged(nameof(HasCode)); } }
    public bool HasCode => Code is not null;
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

    public async Task Refresh()
    {
        var status = await _client.Status();
        if (status is null)
        {
            Headline = "The TitanDeck Host service isn't running";
            Subtitle = "Restart the PC, or start \"TitanDeck Host\" in Services.";
            HeadlineColour = BrushFor("problem");
            Checks.Clear();
            return;
        }

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
        Apply(await _client.Pairing());
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
