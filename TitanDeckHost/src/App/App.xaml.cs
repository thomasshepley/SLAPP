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
    private const string InstanceName = @"Local\TitanDeckHost.App";
    private const string QuitName = @"Local\TitanDeckHost.App.Quit";
    private const string ShowName = @"Local\TitanDeckHost.App.Show";
    private Mutex? _singleInstance;
    private EventWaitHandle? _quitSignal;
    private EventWaitHandle? _showSignal;
    private Forms.NotifyIcon? _tray;
    private MainWindow? _window;
    private readonly HostClient _client = new();
    private readonly CancellationTokenSource _typing = new();

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        _singleInstance = new Mutex(true, InstanceName, out var first);
        if (e.Args.Contains("--quit"))
        {
            // The installer: asks the running copy to close (taking its tray
            // icon with it) and waits until it has.
            if (!first)
            {
                Signal(QuitName);
                try { _singleInstance.WaitOne(TimeSpan.FromSeconds(5)); }
                catch (AbandonedMutexException) { }
            }
            Shutdown();
            return;
        }
        if (!first)
        {
            // Already running: bring its window up (from the tray at login, just stay out of the way).
            if (!e.Args.Contains("--tray")) Signal(ShowName);
            Shutdown();
            return;
        }
        _quitSignal = Listen(QuitName, Quit);
        _showSignal = Listen(ShowName, ShowWindow);

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
        // Hidden before it's disposed, so Windows takes the icon away now
        // rather than leaving it until the mouse passes over it.
        if (_tray is not null) _tray.Visible = false;
        _tray?.Dispose();
        _quitSignal?.Dispose();
        _showSignal?.Dispose();
        _singleInstance?.Dispose();
        base.OnExit(e);
    }

    /// <summary>Sets another copy's named signal, if it's listening.</summary>
    private static void Signal(string name)
    {
        if (EventWaitHandle.TryOpenExisting(name, out var handle))
        {
            using (handle) handle.Set();
        }
    }

    /// <summary>Runs <paramref name="act"/> on the window's thread each time the named signal is set.</summary>
    private EventWaitHandle Listen(string name, Action act)
    {
        var handle = new EventWaitHandle(false, EventResetMode.AutoReset, name);
        var thread = new Thread(() =>
        {
            try
            {
                while (handle.WaitOne()) Dispatcher.Invoke(act);
            }
            catch (ObjectDisposedException) { }
            catch (TaskCanceledException) { }   // the app is closing
        }) { IsBackground = true, Name = name };
        thread.Start();
        return handle;
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
