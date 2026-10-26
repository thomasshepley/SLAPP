using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using TitanDeckHost.Core.Api;

namespace TitanDeckHost.App;

/// <summary>
/// Test or Show. Show hides the test tools (asking Titan for a report) so the
/// window is just the production tool. Following the selection over CITP
/// carries on in both.
/// </summary>
public sealed partial class MainViewModel
{
    private bool _isShowMode;

    public bool IsShowMode
    {
        get => _isShowMode;
        set
        {
            Set(ref _isShowMode, value);
            OnPropertyChanged(nameof(IsTestMode));
            OnPropertyChanged(nameof(ModeBadge));
            OnPropertyChanged(nameof(ModeBadgeColour));
            OnPropertyChanged(nameof(ModeText));
        }
    }

    public bool IsTestMode => !IsShowMode;
    public string ModeBadge => IsShowMode ? "SHOW" : "TEST";
    public Brush ModeBadgeColour => IsShowMode ? BrushFor("ok") : BrushFor("warning");
    public string ModeText => IsShowMode
        ? "Show mode: the production tools only. Test features are off; CITP selection carries on."
        : "Test mode: the test features are available. Switch to Show for a show.";

    private ICommand? _showModeCommand;
    public ICommand ShowModeCommand => _showModeCommand ??= new RelayCommand(async () =>
    {
        if (IsShowMode) return;
        var answer = MessageBox.Show(
            "All test features will be disabled if you confirm this.\n\nThe test tools are hidden. Following the selection over CITP carries on. You can switch back to Test at any time.",
            "Switch to Show mode?", MessageBoxButton.OKCancel, MessageBoxImage.Warning, MessageBoxResult.Cancel);
        if (answer != MessageBoxResult.OK) return;
        ShowMode(await _client.SetMode("show"));
        Message = IsShowMode ? "Show mode: test features are off." : "Couldn't switch to Show mode: is the Host service running?";
    });

    private ICommand? _testModeCommand;
    public ICommand TestModeCommand => _testModeCommand ??= new RelayCommand(async () =>
    {
        if (IsTestMode) return;
        var answer = MessageBox.Show("The test features come back.",
            "Switch to Test mode?", MessageBoxButton.OKCancel, MessageBoxImage.Question, MessageBoxResult.Cancel);
        if (answer != MessageBoxResult.OK) return;
        ShowMode(await _client.SetMode("test"));
    });

    private void ShowMode(ModeDto? mode)
    {
        if (mode is not null) IsShowMode = mode.Mode == "show";
    }
}
