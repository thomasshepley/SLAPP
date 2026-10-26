using System.Collections.ObjectModel;
using TitanDeckHost.Core.Api;

namespace TitanDeckHost.App;

/// <summary>One choice in the network list; a null Id is Automatic.</summary>
public sealed record AdapterChoice(string? Id, string Label);

/// <summary>The Network card: which adapter TitanDeck uses, and the address to type into it.</summary>
public sealed partial class MainViewModel
{
    private string? _selectedAdapterId;
    private bool _showingNetwork;
    private string _networkText = "";
    private string? _networkProblem;

    public ObservableCollection<AdapterChoice> AdapterChoices { get; } = new();

    /// <summary>Picking one in the list switches the Host over straight away.</summary>
    public string? SelectedAdapterId
    {
        get => _selectedAdapterId;
        set
        {
            if (_selectedAdapterId == value) return;
            Set(ref _selectedAdapterId, value);
            if (!_showingNetwork) _ = ChooseNetwork(value);
        }
    }

    public string NetworkText { get => _networkText; set => Set(ref _networkText, value); }
    public string? NetworkProblem { get => _networkProblem; set { Set(ref _networkProblem, value); OnPropertyChanged(nameof(HasNetworkProblem)); } }
    public bool HasNetworkProblem => !string.IsNullOrEmpty(NetworkProblem);

    private async Task ChooseNetwork(string? id)
    {
        ShowNetwork(await _client.ChooseNetwork(id));
        Message = id is null
            ? "TitanDeck Host is on every network adapter."
            : "Switched. On the iPad: Settings > TitanDeck Host > Change address, or pair again from the list.";
    }

    private void ShowNetwork(NetworkDto? network)
    {
        if (network is null) return;
        _showingNetwork = true;
        try
        {
            var choices = new List<AdapterChoice> { new(null, "Automatic (every adapter)") };
            choices.AddRange(network.Adapters.Select(a =>
                new AdapterChoice(a.Id, $"{a.Name}  -  {string.Join(", ", a.Addresses)}{(a.Up ? "" : "  (not connected)")}  -  {a.Description}")));
            // A chosen adapter that's gone still shows, so the list explains itself.
            if (network.Chosen is { } chosen && choices.All(c => c.Id != chosen))
                choices.Add(new AdapterChoice(chosen, $"{network.ChosenName ?? "Chosen adapter"}  (not found)"));
            if (!choices.SequenceEqual(AdapterChoices))
            {
                AdapterChoices.Clear();
                foreach (var choice in choices) AdapterChoices.Add(choice);
            }
            SelectedAdapterId = network.Chosen;
            var addresses = network.Announcing.Count == 0 ? "no address yet" : string.Join(" or ", network.Announcing);
            NetworkText = network.Chosen is null || network.Problem is not null
                ? $"TitanDeck finds this PC on every adapter: {addresses}. Pick the show network's adapter if the iPad lands on the wrong one."
                : $"TitanDeck connects to {addresses} ({network.ChosenName}): the address for the Host, Titan and the remote desktop.";
            NetworkProblem = network.Problem;
        }
        finally
        {
            _showingNetwork = false;
        }
    }
}
