using System.IO;
using System.Windows.Input;
using Microsoft.Win32;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.App;

/// <summary>The Patch report card: the patch the Host read from Titan's newest report.</summary>
public sealed partial class MainViewModel
{
    private string _patchText = "Looking for Titan's patch report...";
    private string _patchDetail = "";
    private string? _patchProblem;
    private bool _askingTitan;

    public string PatchText { get => _patchText; set => Set(ref _patchText, value); }
    public string PatchDetail { get => _patchDetail; set { Set(ref _patchDetail, value); OnPropertyChanged(nameof(HasPatchDetail)); } }
    public bool HasPatchDetail => PatchDetail.Length > 0;
    public string? PatchProblem { get => _patchProblem; set { Set(ref _patchProblem, value); OnPropertyChanged(nameof(HasPatchProblem)); } }
    public bool HasPatchProblem => !string.IsNullOrEmpty(PatchProblem);
    public string AskTitanButton => _askingTitan ? "Asking Titan..." : "Ask Titan to write one";

    private ICommand? _reloadPatchCommand;
    public ICommand ReloadPatchCommand => _reloadPatchCommand ??= new RelayCommand(async () => ShowPatch(await _client.ReloadPatch()));

    private ICommand? _importPatchCommand;
    public ICommand ImportPatchCommand => _importPatchCommand ??= new RelayCommand(async () =>
    {
        var picker = new OpenFileDialog
        {
            Title = "Titan patch report",
            Filter = "Titan reports (*.csv;*.xml;*.htm;*.html)|*.csv;*.xml;*.htm;*.html|All files (*.*)|*.*",
        };
        if (picker.ShowDialog() != true) return;
        var file = new FileInfo(picker.FileName);
        if (file.Length > TitanPatch.MaxReportBytes)
        {
            PatchProblem = "That file is too big to be a patch report.";
            return;
        }
        ShowPatch(await _client.ImportPatch(file.Name, await File.ReadAllTextAsync(file.FullName)));
    });

    private ICommand? _askTitanCommand;
    public ICommand AskTitanCommand => _askTitanCommand ??= new RelayCommand(async () =>
    {
        if (_askingTitan) return;
        _askingTitan = true;
        OnPropertyChanged(nameof(AskTitanButton));
        try
        {
            ShowPatch(await _client.AskTitanForPatch());
        }
        finally
        {
            _askingTitan = false;
            OnPropertyChanged(nameof(AskTitanButton));
        }
    });

    private void ShowPatch(PatchDto? patch)
    {
        if (patch is null)
        {
            PatchText = "The Host service isn't answering.";
            PatchDetail = "";
            PatchProblem = null;
            return;
        }
        PatchProblem = patch.Problem;
        if (patch.Fixtures.Count == 0)
        {
            PatchText = "No patch yet.";
            PatchDetail = patch.Folders.Count == 0 ? "" : "Looking in: " + string.Join("; ", patch.Folders.Take(4));
            return;
        }
        var known = patch.Fixtures.Count(f => f.Intensity is not null);
        PatchText = $"{patch.Fixtures.Count} fixture{(patch.Fixtures.Count == 1 ? "" : "s")} from {patch.Source}" +
                    (patch.Written is { } written ? $" ({written.ToLocalTime():d MMM HH:mm})" : "") +
                    $". Intensity channel known for {known} ({patch.Personalities} personalities on this PC).";
        PatchDetail = string.Join("\n", patch.Fixtures.Take(6).Select(f =>
            $"{f.User}  {f.Model ?? "?"}{(f.Mode is null ? "" : $" ({f.Mode})")}  {f.Universe}.{f.Address}" +
            (f.Intensity is { Count: > 0 } i ? $"  -  intensity on {string.Join(", ", i.Select(o => $"{f.Universe}.{f.Address + o}"))}" : "")))
            + (patch.Fixtures.Count > 6 ? $"\n... and {patch.Fixtures.Count - 6} more" : "");
    }
}
