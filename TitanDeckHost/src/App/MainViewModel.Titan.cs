using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Windows.Input;
using System.Windows.Media;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.App;

/// <summary>One call in the Titan log, as the window shows it.</summary>
public sealed class LogRow
{
    public required TitanLogEntry Entry { get; init; }
    public string Time => Entry.Time.ToLocalTime().ToString("HH:mm:ss.fff");
    public string Who => Entry.Who;
    public string Call => $"{Entry.Method} {Entry.Path}{(Entry.Query.Length > 0 ? "?" + Entry.Query : "")}";
    public string Result => Entry.Who == "CITP"
        ? (Entry.From.Length > 0 ? (Entry.Method == "OUT" ? "to " : "from ") + Entry.From : "")
        : $"{Entry.Status}  ·  {Entry.Milliseconds} ms{(Entry.From.Length > 0 ? "  ·  from " + Entry.From : "")}";
    public string? Note => Entry.Note;
    public bool HasNote => !string.IsNullOrEmpty(Entry.Note);
    public string? State => Entry.State;
    public bool HasState => !string.IsNullOrEmpty(Entry.State);
    public Brush Colour => MainViewModel.BrushFor(Entry.Flagged ? "problem" : Entry.Status is >= 200 and < 300 ? "ok" : "warning");
    /// <summary>The whole entry on one line, for Copy.</summary>
    public string Text => $"{Time}  {Who}  {Call}  -> {Result}{(HasNote ? "  " + Note : "")}{(HasState ? "  | " + State : "")}";
}

/// <summary>Host updates, Fake Titan and the Titan log.</summary>
public sealed partial class MainViewModel
{
    public const int LogRowsShown = 1000;

    private long _lastLogId;
    private bool _installWhenReady;
    private string _updateText = "Checking for updates...";
    private string? _updateNotes;
    private bool _updateAvailable;
    private string _updateButton = "Update";
    private string _fakeFixtures = "12";
    private string _fakePlaybacks = "20";
    private string _fakeLatency = "0";
    private bool _fakeDesk = true;
    private bool _fakeSacn = true;
    private bool _fakeRunning;
    private string _fakeStatus = "Off.";
    private string? _fakeState;
    private string _deskSelection = "";
    private string _pollText = "";
    private bool _autoScroll = true;

    public ObservableCollection<LogRow> LogRows { get; } = new();

    // --- Updates ---

    public string UpdateText { get => _updateText; set => Set(ref _updateText, value); }
    public string? UpdateNotes { get => _updateNotes; set { Set(ref _updateNotes, value); OnPropertyChanged(nameof(HasUpdateNotes)); } }
    public bool HasUpdateNotes => UpdateAvailable && !string.IsNullOrEmpty(UpdateNotes);
    public bool UpdateAvailable { get => _updateAvailable; set { Set(ref _updateAvailable, value); OnPropertyChanged(nameof(HasUpdateNotes)); } }
    public string UpdateButton { get => _updateButton; set => Set(ref _updateButton, value); }

    private ICommand? _updateCommand;
    public ICommand UpdateCommand => _updateCommand ??= new RelayCommand(StartUpdate);
    private ICommand? _checkUpdateCommand;
    public ICommand CheckUpdateCommand => _checkUpdateCommand ??= new RelayCommand(async () =>
    {
        UpdateText = "Checking GitHub...";
        ShowUpdate(await _client.CheckUpdate());
    });

    public async Task RefreshUpdate() => ShowUpdate(await _client.Update());

    private void ShowUpdate(UpdateStatusDto? status)
    {
        if (status is null) return;
        UpdateAvailable = status.Available;
        UpdateNotes = status.Notes;
        UpdateButton = status.Ready is null ? $"Update to {status.Latest}" : $"Install {status.Latest}";
        UpdateText = status switch
        {
            { Downloading: { } part } => $"Downloading TitanDeck Host {status.Latest}... {part:P0}",
            { Available: true, Ready: not null } => $"TitanDeck Host {status.Latest} is downloaded and checked, ready to install (you have {status.Current}).",
            { Available: true } => $"TitanDeck Host {status.Latest} is available (you have {status.Current}).",
            { Problem: { } problem } => $"TitanDeck Host {status.Current}. {problem}",
            { Checked: { } at } => $"TitanDeck Host {status.Current} is up to date (checked {at.ToLocalTime():HH:mm}).",
            _ => $"TitanDeck Host {status.Current}.",
        };
        if (_installWhenReady && status.Ready is { } ready && status.ReadySha256 is { } sha && status.Downloading is null)
        {
            _installWhenReady = false;
            RunInstaller(ready, sha);
        }
        else if (_installWhenReady && status.Downloading is null && status.Ready is null && status.Problem is not null)
        {
            _installWhenReady = false;
            Message = status.Problem;
        }
    }

    private async Task StartUpdate()
    {
        var status = await _client.Update();
        if (status?.Ready is { } ready && status.ReadySha256 is { } sha)
        {
            RunInstaller(ready, sha);
            return;
        }
        _installWhenReady = true;
        ShowUpdate(await _client.DownloadUpdate());
        Message = "Downloading the update from GitHub. It installs by itself when it's checked.";
    }

    /// <summary>Checks the file once more, then runs the installer. Windows asks
    /// for permission; the installer closes the Host, updates it and opens it again.</summary>
    private void RunInstaller(string path, string sha256)
    {
        try
        {
            using (var file = File.OpenRead(path))
            {
                var hash = Convert.ToHexString(SHA256.HashData(file)).ToLowerInvariant();
                if (hash != sha256.ToLowerInvariant())
                {
                    Message = "The downloaded update didn't check out, so it wasn't run. Press Update to fetch it again.";
                    return;
                }
            }
            Process.Start(new ProcessStartInfo(path, "/SILENT /SUPPRESSMSGBOXES /NORESTART /UPDATE=1")
            {
                UseShellExecute = true,
                Verb = "runas",
            });
            Message = "Installing the update. TitanDeck Host closes for a moment and opens again.";
        }
        catch (Win32Exception)
        {
            Message = "The update needs Windows' permission to install. Press Update again and choose Yes.";
        }
        catch (IOException error)
        {
            Message = "Couldn't open the downloaded update: " + error.Message;
        }
    }

    // --- Fake Titan ---

    public string FakeFixtures { get => _fakeFixtures; set => Set(ref _fakeFixtures, value); }
    public string FakePlaybacks { get => _fakePlaybacks; set => Set(ref _fakePlaybacks, value); }
    public string FakeLatency { get => _fakeLatency; set => Set(ref _fakeLatency, value); }
    public bool FakeDesk { get => _fakeDesk; set => Set(ref _fakeDesk, value); }
    public bool FakeSacn { get => _fakeSacn; set => Set(ref _fakeSacn, value); }
    public bool FakeRunning
    {
        get => _fakeRunning;
        set { Set(ref _fakeRunning, value); OnPropertyChanged(nameof(FakeButton)); OnPropertyChanged(nameof(FakeStopped)); }
    }
    public bool FakeStopped => !FakeRunning;
    public string FakeButton => FakeRunning ? "Stop Fake Titan" : "Start Fake Titan";
    public string FakeStatus { get => _fakeStatus; set => Set(ref _fakeStatus, value); }
    public string? FakeState { get => _fakeState; set { Set(ref _fakeState, value); OnPropertyChanged(nameof(HasFakeState)); } }
    public bool HasFakeState => FakeRunning && !string.IsNullOrEmpty(FakeState);
    public string DeskSelection { get => _deskSelection; set => Set(ref _deskSelection, value); }

    private ICommand? _fakeToggleCommand;
    public ICommand FakeToggleCommand => _fakeToggleCommand ??= new RelayCommand(async () =>
    {
        if (FakeRunning)
        {
            ShowFake(await _client.StopFakeTitan());
            return;
        }
        static int Number(string text, int fallback) => int.TryParse(text.Trim(), out var n) ? n : fallback;
        FakeStatus = "Starting...";
        ShowFake(await _client.StartFakeTitan(new FakeTitanStartRequest(
            Number(FakeFixtures, 12), Number(FakePlaybacks, 20), FakeDesk, FakeSacn, Number(FakeLatency, 0))));
    });

    private ICommand? _deskSelectCommand;
    public ICommand DeskSelectCommand => _deskSelectCommand ??= new RelayCommand(async () =>
        Message = await _client.DeskSelect(DeskSelection) ?? "Fake Titan didn't answer.");

    private ICommand? _deskClearCommand;
    public ICommand DeskClearCommand => _deskClearCommand ??= new RelayCommand(async () =>
    {
        DeskSelection = "";
        Message = await _client.DeskSelect("") ?? "Fake Titan didn't answer.";
    });

    private void ShowFake(FakeTitanStatusDto? status)
    {
        if (status is null) return;
        FakeRunning = status.Running;
        FakeState = status.State;
        FakeStatus = status switch
        {
            { Problem: { } problem } => problem,
            { Running: true } => $"Running on port {string.Join(" and ", status.Ports)} with {status.Fixtures} fixtures and " +
                                 $"{status.Playbacks} playbacks{(status.Sacn ? ", sending sACN universe 1" : "")}. Put this PC's " +
                                 $"address in TitanDeck's Titan PC address{(status.Desk ? "; the desk link works as with real Titan" : "")}.",
            _ => "Off.",
        };
    }

    // --- Titan log ---

    public string PollText { get => _pollText; set => Set(ref _pollText, value); }
    public bool AutoScroll { get => _autoScroll; set => Set(ref _autoScroll, value); }

    private ICommand? _clearLogCommand;
    public ICommand ClearLogCommand => _clearLogCommand ??= new RelayCommand(async () =>
    {
        await _client.ClearTitanLog();
        LogRows.Clear();
        PollText = "";
    });

    private ICommand? _copyLogCommand;
    public ICommand CopyLogCommand => _copyLogCommand ??= new RelayCommand(() =>
    {
        System.Windows.Clipboard.SetText(string.Join(Environment.NewLine, LogRows.Select(r => r.Text)));
        Message = $"Copied {LogRows.Count} log lines.";
        return Task.CompletedTask;
    });

    /// <summary>Every second: new log lines, Fake Titan's state, CITP's selection, a download's progress.</summary>
    public async Task RefreshLive()
    {
        if (await _client.TitanLog(_lastLogId) is { } log)
        {
            foreach (var entry in log.Entries)
            {
                LogRows.Add(new LogRow { Entry = entry });
                _lastLogId = Math.Max(_lastLogId, entry.Id);
            }
            while (LogRows.Count > LogRowsShown) LogRows.RemoveAt(0);
            PollText = log.Polls.Count == 0 ? "" : "Polling (counted, not listed): " +
                string.Join("   ", log.Polls.Select(p => $"{p.Path.Split('/').Last()} x{p.Count:N0} ({p.LastStatus})"));
        }
        ShowFake(await _client.FakeTitan());
        if (CitpEnabled) await RefreshCitp();
        if (_installWhenReady || UpdateText.StartsWith("Downloading", StringComparison.Ordinal)) await RefreshUpdate();
    }
}
