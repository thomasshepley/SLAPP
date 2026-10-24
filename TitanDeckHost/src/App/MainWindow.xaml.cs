using System.ComponentModel;
using System.Windows;
using System.Windows.Threading;

namespace TitanDeckHost.App;

public partial class MainWindow : Window
{
    private readonly MainViewModel _model;
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(3) };
    private readonly Action _closed;

    public MainWindow(HostClient client, Action closed)
    {
        InitializeComponent();
        _closed = closed;
        _model = new MainViewModel(client);
        DataContext = _model;
        _timer.Tick += async (_, _) => { if (!_model.Busy) await _model.Refresh(); };
        Loaded += async (_, _) =>
        {
            await _model.Refresh();
            _timer.Start();
        };
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        // Closing the window leaves the Host in the tray; the service keeps running regardless.
        _timer.Stop();
        _closed();
        base.OnClosing(e);
    }
}
