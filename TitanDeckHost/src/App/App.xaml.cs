using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
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
        _tray?.Dispose();
        _singleInstance?.Dispose();
        base.OnExit(e);
    }

    /// <summary>A small blue rounded square with "TD", drawn at runtime.</summary>
    private static Icon MakeIcon()
    {
        using var bitmap = new Bitmap(32, 32);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            using var path = new GraphicsPath();
            const int r = 8;
            path.AddArc(0, 0, r, r, 180, 90);
            path.AddArc(31 - r, 0, r, r, 270, 90);
            path.AddArc(31 - r, 31 - r, r, r, 0, 90);
            path.AddArc(0, 31 - r, r, r, 90, 90);
            path.CloseFigure();
            using var fill = new SolidBrush(Color.FromArgb(10, 132, 255));
            g.FillPath(fill, path);
            using var font = new Font("Segoe UI", 12, System.Drawing.FontStyle.Bold, GraphicsUnit.Pixel);
            var size = g.MeasureString("TD", font);
            g.DrawString("TD", font, Brushes.White, (32 - size.Width) / 2, (32 - size.Height) / 2);
        }
        return Icon.FromHandle(bitmap.GetHicon());
    }
}
