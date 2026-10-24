using TitanDeckHost.Core.Files;

public class FileNameTests
{
    [Theory]
    [InlineData("Plot.pdf", "Plot.pdf")]
    [InlineData("../../Windows/System32/evil.dll", "evil.dll")]
    [InlineData("..\\..\\boot.ini", "boot.ini")]
    [InlineData("C:\\Users\\x\\a.txt", "a.txt")]
    [InlineData("what?.txt", "what_.txt")]
    [InlineData("a<b>c:d\"e|f*.png", "a_b_c_d_e_f_.png")]
    [InlineData("CON.txt", "_CON.txt")]
    [InlineData("nul", "_nul")]
    [InlineData("trailing. . ", "trailing")]
    [InlineData("..", "file")]
    [InlineData("", "file")]
    [InlineData(null, "file")]
    [InlineData(".hidden", ".hidden")]
    public void Cleans(string? input, string expected) => Assert.Equal(expected, SafeFileName.Clean(input));

    [Fact]
    public void LongNamesKeepTheirExtension()
    {
        var cleaned = SafeFileName.Clean(new string('a', 400) + ".jpeg");
        Assert.Equal(SafeFileName.MaxLength, cleaned.Length);
        Assert.EndsWith(".jpeg", cleaned);
    }

    [Fact]
    public void ControlCharactersAreReplaced() => Assert.Equal("a_b.txt", SafeFileName.Clean("a\u0001b.txt"));

    [Fact]
    public void UniqueNames()
    {
        var taken = new HashSet<string> { "Plot.pdf", "Plot (2).pdf" };
        Assert.Equal("Plot (3).pdf", SafeFileName.Unique("Plot.pdf", taken.Contains));
        Assert.Equal("Rig.pdf", SafeFileName.Unique("Rig.pdf", taken.Contains));
    }
}
