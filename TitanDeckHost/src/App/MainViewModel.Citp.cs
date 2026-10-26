using System.Windows;
using System.Windows.Input;
using TitanDeckHost.Core.Api;

namespace TitanDeckHost.App;

/// <summary>
/// The "Follow selection via CITP" card (Test and Show): the switch, who's
/// announcing CITP on the network, and what Titan has selected.
/// </summary>
public sealed partial class MainViewModel
{
    private bool _citpEnabled;
    private string _citpText = "Off.";
    private string? _citpDetail;
    private string? _citpProblem;

    public bool CitpEnabled { get => _citpEnabled; set { Set(ref _citpEnabled, value); OnPropertyChanged(nameof(CitpButton)); } }
    public string CitpButton => CitpEnabled ? "Switch off" : "Switch on";
    public string CitpText { get => _citpText; set => Set(ref _citpText, value); }
    public string? CitpDetail { get => _citpDetail; set { Set(ref _citpDetail, value); OnPropertyChanged(nameof(HasCitpDetail)); } }
    public bool HasCitpDetail => !string.IsNullOrEmpty(CitpDetail);
    public string? CitpProblem { get => _citpProblem; set { Set(ref _citpProblem, value); OnPropertyChanged(nameof(HasCitpProblem)); } }
    public bool HasCitpProblem => !string.IsNullOrEmpty(CitpProblem);

    private ICommand? _citpToggleCommand;
    public ICommand CitpToggleCommand => _citpToggleCommand ??= new RelayCommand(async () =>
    {
        if (!CitpEnabled)
        {
            var answer = MessageBox.Show(
                "TitanDeck Host will appear to Titan as a CITP visualiser (like Capture) so Titan shares its selection.\n\n"
                + "It never sends Titan a patch, but Titan may still ask about syncing with a visualiser: say no to anything that offers to change the patch.",
                "Follow selection via CITP?", MessageBoxButton.OKCancel, MessageBoxImage.Warning, MessageBoxResult.Cancel);
            if (answer != MessageBoxResult.OK) return;
        }
        var status = await _client.SetCitp(!CitpEnabled);
        if (status is null) Message = "Couldn't change CITP: is the Host service running?";
        ShowCitp(status);
    });

    public async Task RefreshCitp() => ShowCitp(await _client.Citp());

    private void ShowCitp(CitpStatusDto? citp)
    {
        if (citp is null) return;
        CitpEnabled = citp.Enabled;
        CitpProblem = citp.Problem;
        if (!citp.Enabled)
        {
            CitpText = "Off.";
            CitpDetail = null;
            return;
        }
        var listening = citp.ListeningPort is { } port ? $"on TCP {port}" : "starting";
        CitpText = citp.Connected is { } connected
            ? $"Linked with {connected}{(citp.PeerShow is { } show ? $", show \"{show}\"" : "")}. {citp.Fixtures} fixtures known. "
              + (citp.Selection.Count == 0 ? "Nothing selected." : $"Selected: {Shorten(citp.Selection)}.")
            : $"Waiting for Titan to connect ({listening}). In Titan, look for TitanDeck Host under the CITP / visualiser connections.";
        CitpDetail = citp.Peers.Count == 0
            ? "Nothing is announcing CITP yet."
            : string.Join("\n", citp.Peers.Select(p =>
                $"{p.Type} \"{p.Name}\" at {p.Address}{(p.TcpPort > 0 ? ":" + p.TcpPort : "")} - {p.State}{(p.OnThisPc ? "" : " (another PC, ignored)")}"));
    }

    private static string Shorten(IReadOnlyList<int> fixtures) =>
        string.Join(", ", fixtures.Take(20)) + (fixtures.Count > 20 ? $" and {fixtures.Count - 20} more" : "");
}
