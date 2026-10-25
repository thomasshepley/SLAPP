using System.ComponentModel;
using System.Windows;
using System.Windows.Threading;

namespace TitanDeckHost.App;

public partial class MainWindow : Window
{
    private readonly MainViewModel _model;
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(3) };
    /// <summary>The Titan log, Fake Titan and a download's progress: every second.</summary>
    private readonly DispatcherTimer _live = new() { Interval = TimeSpan.FromSeconds(1) };
    private bool _refreshingLive;
    private readonly Action _closed;

    public MainWindow(HostClient client, Action closed)
    {
        InitializeComponent();
        _closed = closed;
        _model = new MainViewModel(client);
        DataContext = _model;
        _timer.Tick += async (_, _) => { if (!_model.Busy) await _model.Refresh(); };
        _live.Tick += async (_, _) =>
        {
            if (_refreshingLive) return;
            _refreshingLive = true;
            try { await _model.RefreshLive(); }
            finally { _refreshingLive = false; }
        };
        _model.LogRows.CollectionChanged += (_, _) =>
        {
            if (_model.AutoScroll && _model.LogRows.Count > 0) LogList.ScrollIntoView(_model.LogRows[^1]);
        };
        Loaded += async (_, _) =>
        {
            await _model.Refresh();
            _timer.Start();
            _live.Start();
        };
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        // Closing the window leaves the Host in the tray; the service keeps running regardless.
        _timer.Stop();
        _live.Stop();
        _closed();
        base.OnClosing(e);
    }
}
