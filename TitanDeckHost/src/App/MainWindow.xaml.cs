using System.Collections.Specialized;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace TitanDeckHost.App;

public partial class MainWindow : Window
{
    private readonly MainViewModel _model;
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(3) };
    /// <summary>The Titan log, Fake Titan and a download's progress: every second.</summary>
    private readonly DispatcherTimer _live = new() { Interval = TimeSpan.FromSeconds(1) };
    private bool _refreshingLive;
    private bool _scrollQueued;
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
        _model.LogRows.CollectionChanged += (_, change) =>
        {
            // Newest at the bottom: once per batch of new rows, after the list
            // has laid them out (scrolling straight away, mid-update, could
            // land on the oldest instead).
            if (change.Action != NotifyCollectionChangedAction.Add || !_model.AutoScroll || _scrollQueued) return;
            _scrollQueued = true;
            Dispatcher.BeginInvoke(DispatcherPriority.Background, () =>
            {
                _scrollQueued = false;
                if (_model.AutoScroll) ScrollViewerOf(LogList)?.ScrollToEnd();
            });
        };
        Loaded += async (_, _) =>
        {
            await _model.Refresh();
            _timer.Start();
            _live.Start();
        };
    }

    /// <summary>The list's own scroll viewer (not the window's).</summary>
    private static ScrollViewer? ScrollViewerOf(DependencyObject parent)
    {
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(parent); i++)
        {
            var child = VisualTreeHelper.GetChild(parent, i);
            if (child is ScrollViewer viewer) return viewer;
            if (ScrollViewerOf(child) is { } found) return found;
        }
        return null;
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
