using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;

public class ChangelogTests
{
    private static string Root([CallerFilePath] string here = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(here)!, "..", ".."));

    [Fact]
    public void VersionMatchesTopChangelogEntry()
    {
        var props = File.ReadAllText(Path.Combine(Root(), "Directory.Build.props"));
        var version = Regex.Match(props, "<Version>([^<]+)</Version>").Groups[1].Value;
        var changelog = File.ReadAllLines(Path.Combine(Root(), "CHANGELOG.md"));
        var top = changelog.First(l => l.StartsWith("## "));
        Assert.StartsWith($"## {version} - ", top);
        Assert.Matches(@"^\d+\.\d+\.\d+$", version);
    }
}
