using System.Diagnostics;
using System.Drawing;
using System.Threading;
using System.Windows;
using Forms = System.Windows.Forms;

namespace TitanDeckHost.App;

/// <summary>Lives in the tray; the dashboard window opens from the icon. Starts
/// at login (installer's Run key) with --tray, so only the icon appears.</summary>
public partial class App : Application
{
    private Mutex? _singleInstance;
    private Forms.NotifyIcon? _tray;
    private MainWindow? _window;
    private readonly HostClient _client = new();
    private readonly CancellationTokenSource _typing = new();

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        _singleInstance = new Mutex(true, @"Local\TitanDeckHost.App", out var first);
        if (!first)
        {
            // Already running: the existing copy's icon is in the tray.
            Shutdown();
            return;
        }

        _tray = new Forms.NotifyIcon
        {
            Icon = MakeIcon(),
            Text = "TitanDeck Host",
            Visible = true,
            ContextMenuStrip = new Forms.ContextMenuStrip(),
        };
        _tray.ContextMenuStrip.Items.Add("Open TitanDeck Host", null, (_, _) => ShowWindow());
        _tray.ContextMenuStrip.Items.Add("Open \"To PC\" folder", null, async (_, _) => OpenFolder((await _client.Folders())?.ToPC));
        _tray.ContextMenuStrip.Items.Add("Open \"To iPad\" folder", null, async (_, _) => OpenFolder((await _client.Folders())?.ToIPad));
        _tray.ContextMenuStrip.Items.Add(new Forms.ToolStripSeparator());
        _tray.ContextMenuStrip.Items.Add("Close window and icon", null, (_, _) => Quit());
        _tray.DoubleClick += (_, _) => ShowWindow();

        // Types the deck's keypad on this PC for Titan (see DeskTyper).
        _ = DeskTyper.Run(_typing.Token);

        if (!e.Args.Contains("--tray")) ShowWindow();
    }

    private void ShowWindow()
    {
        _window ??= new MainWindow(_client, () => _window = null);
        _window.Show();
        if (_window.WindowState == WindowState.Minimized) _window.WindowState = WindowState.Normal;
        _window.Activate();
    }

    public static void OpenFolder(string? path)
    {
        if (string.IsNullOrEmpty(path)) return;
        Process.Start(new ProcessStartInfo("explorer.exe", $"\"{path}\"") { UseShellExecute = true });
    }

    private void Quit()
    {
        if (_tray is not null) _tray.Visible = false;
        _tray?.Dispose();
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _typing.Cancel();
        _tray?.Dispose();
        _singleInstance?.Dispose();
        base.OnExit(e);
    }

    /// <summary>A small blue rounded square with "TD", drawn at runtime.</summary>
    /// <summary>The Host icon (the TitanDeck keys with HOST on), at the tray's size.</summary>
    private static Icon MakeIcon()
    {
        var resource = GetResourceStream(new Uri("pack://application:,,,/Assets/TitanDeckHost.ico"));
        using var stream = resource!.Stream;
        return new Icon(stream, Forms.SystemInformation.SmallIconSize);
    }
}
