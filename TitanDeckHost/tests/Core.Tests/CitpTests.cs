using TitanDeckHost.Core.Citp;
using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class CitpTests
{
    // --- Packets ---

    [Fact]
    public void CodesAreTheirAsciiBytesInOrder()
    {
        Assert.Equal(0x464E4950u, CitpPacket.Code("PINF"));   // 'P' 'I' 'N' 'F' little-endian
        Assert.Equal("PLoc", CitpPacket.CodeText(CitpMessages.PLoc));
        Assert.Equal(0x656c6553u, CitpMessages.Sele);
        Assert.Equal(0x65536544u, CitpMessages.DeSe);
    }

    [Fact]
    public void HeaderIsLaidOutAsTheSpecSays()
    {
        var bytes = CitpMessages.Name("TD").ToBytes();
        Assert.Equal("CITP"u8.ToArray(), bytes[..4]);
        Assert.Equal(1, bytes[4]);   // version 1.0
        Assert.Equal(0, bytes[5]);
        Assert.Equal(0, BitConverter.ToUInt16(bytes, 6));   // request index
        Assert.Equal((uint)bytes.Length, BitConverter.ToUInt32(bytes, 8));   // whole packet
        Assert.Equal(27u, BitConverter.ToUInt32(bytes, 8));   // 20 + 4 + "TD\0"
        Assert.Equal(1, BitConverter.ToUInt16(bytes, 12));   // one part
        Assert.Equal(0, BitConverter.ToUInt16(bytes, 14));
        Assert.Equal("PINF"u8.ToArray(), bytes[16..20]);
        Assert.Equal("PNam"u8.ToArray(), bytes[20..24]);
        Assert.Equal(new byte[] { (byte)'T', (byte)'D', 0 }, bytes[24..]);
    }

    [Fact]
    public void LocationRoundTrips()
    {
        var packet = CitpPacket.Parse(CitpMessages.Location(4435, "Visualizer", "TitanDeck Host", "Running").ToBytes())!;
        Assert.Equal(new CitpLocation(4435, "Visualizer", "TitanDeck Host", "Running"), CitpMessages.ReadLocation(packet));
        Assert.Equal("PINF PLoc", CitpMessages.Describe(packet));
    }

    [Fact]
    public void NotCitpIsRefused()
    {
        Assert.Null(CitpPacket.Parse("HTTP/1.1 200 OK\r\n\r\nhello there"u8));
        Assert.Null(CitpPacket.DeclaredSize("GET / HTTP/1.1\r\nHost: x\r\n"u8));
        Assert.Equal(0, CitpPacket.DeclaredSize("CITP"u8));   // header still coming
    }

    [Fact]
    public void NackAnswersTheRequest()
    {
        var packet = CitpPacket.Parse(CitpMessages.CaexNack(CitpMessages.Refused, 7).ToBytes())!;
        Assert.Equal("CAEX", packet.Layer);
        Assert.Equal(CitpMessages.Nack, packet.Content);
        Assert.Equal(7, packet.RequestIndex);
        Assert.Equal(new byte[] { 3 }, packet.Payload);
    }

    // --- The allowlist: TitanDeck Host must never be able to patch Titan ---

    [Fact]
    public void OnlyHarmlessPacketsMayBeSent()
    {
        Assert.True(CitpAllowlist.MaySend(CitpMessages.Name("x")));
        Assert.True(CitpAllowlist.MaySend(CitpMessages.Location(1, "Visualizer", "x", "y")));
        Assert.True(CitpAllowlist.MaySend(CitpMessages.CaexEnterShow("x")));
        Assert.True(CitpAllowlist.MaySend(CitpMessages.CaexLeaveShow()));
        Assert.True(CitpAllowlist.MaySend(CitpMessages.CaexFixtureListRequest(1)));
        Assert.True(CitpAllowlist.MaySend(CitpMessages.CaexNack(3, 1)));
    }

    [Theory]
    [InlineData(CitpMessages.FixtureList)]
    [InlineData(CitpMessages.FixtureListV2)]
    [InlineData(CitpMessages.FixtureModify)]
    [InlineData(CitpMessages.FixtureModifyV2)]
    [InlineData(CitpMessages.FixtureRemove)]
    [InlineData(CitpMessages.FixtureIdentify)]
    [InlineData(CitpMessages.FixtureSelection)]
    [InlineData(CitpMessages.FixtureConsoleStatus)]
    [InlineData(CitpMessages.EnterShowV2)]
    [InlineData(CitpMessages.ShowSyncVersion)]
    [InlineData(CitpMessages.SetFixtureTransformationSpace)]
    [InlineData(0x12345678u)]
    public void PatchAndSelectionMessagesCantBeSent(uint caex)
    {
        var packet = new CitpPacket("CAEX", caex, 0, []);
        Assert.False(CitpAllowlist.MaySend(packet));
        Assert.Throws<InvalidOperationException>(() => CitpAllowlist.Check(packet));
    }

    [Fact]
    public void OnlyAnEmptySelectionCanBeSent()
    {
        Assert.True(CitpAllowlist.MaySend(CitpMessages.CaexClearSelection()));
        Assert.True(CitpAllowlist.MaySend(CitpMessages.FselDeselectAll()));
        Assert.Equal([0, 0], CitpMessages.CaexClearSelection().Payload);
        Assert.Equal(Array.Empty<uint>(), CitpMessages.ReadFixtureSelection(CitpMessages.CaexClearSelection()));
        // A selection with fixtures in it never goes out, whichever layer.
        var one = new CitpWriter().U16(1).U32(7).ToArray();
        Assert.False(CitpAllowlist.MaySend(new CitpPacket("CAEX", CitpMessages.FixtureSelection, 0, one)));
        Assert.False(CitpAllowlist.MaySend(new CitpPacket("FSEL", CitpMessages.DeSe, 0, new CitpWriter().U16(1).U16(7).ToArray())));
        Assert.False(CitpAllowlist.MaySend(new CitpPacket("FSEL", CitpMessages.Sele, 0, new CitpWriter().U8(1).U8(0).U16(0).ToArray())));
    }

    [Fact]
    public void ClearSelectionSendsOnlyTheEmptySelection()
    {
        var sent = new List<CitpPacket>();
        var session = new CitpSession("TitanDeck Host", sent.Add, _ => { });
        session.ClearSelection();
        Assert.Equal(2, sent.Count);
        Assert.All(sent, p => Assert.True(CitpAllowlist.MaySend(p)));
        Assert.Equal("CAEX", sent[0].Layer);
        Assert.Equal("FSEL", sent[1].Layer);
    }

    [Theory]
    [InlineData("FPTC", "Ptch")]
    [InlineData("FPTC", "UPtc")]
    [InlineData("FPTC", "SPtc")]
    [InlineData("FSEL", "Sele")]
    [InlineData("FSEL", "DeSe")]
    [InlineData("SDMX", "ChBk")]
    [InlineData("SDMX", "UNam")]
    [InlineData("PINF", "PPos")]
    [InlineData("MSEX", "SInf")]
    public void OtherLayersCantBeSent(string layer, string content) =>
        Assert.False(CitpAllowlist.MaySend(new CitpPacket(layer, CitpPacket.Code(content), 0, [])));

    // --- A session with Titan ---

    private sealed class Rig
    {
        public readonly List<CitpPacket> Sent = [];
        public readonly List<CitpLogLine> Log = [];
        public readonly CitpSession Session;

        public Rig()
        {
            Session = new CitpSession("TitanDeck Host", p => Sent.Add(CitpPacket.Parse(p.ToBytes())!), Log.Add);
        }

        public void Hear(CitpPacket packet) => Session.Receive(CitpPacket.Parse(packet.ToBytes())!, DateTimeOffset.UnixEpoch);
    }

    private static CitpPacket Caex(uint code, byte[] payload, ushort index = 0) => new("CAEX", code, index, payload);

    /// <summary>A v1 FixtureList as Titan would send it: (identifier, user number) pairs.</summary>
    private static CitpPacket FixtureList(byte type, params (uint Id, ushort Channel)[] fixtures)
    {
        var w = new CitpWriter().U8(type).U16((ushort)fixtures.Length);
        foreach (var (id, channel) in fixtures)
        {
            w.U32(id).Ucs2("Robe").Ucs2("MegaPointe").Ucs2("Mode 1").U16(39).U8(0)
             .U8(1).U8(0).U16(4).U32(0xDEADBEEF)   // one identifier block, 4 bytes
             .U8(1).U8(2).U16(101)   // patched, universe 2, channel 101
             .Ucs2("").U16(channel).Ucs2("C1").Ucs2("note");
            for (var i = 0; i < 6; i++) w.F32(i);
        }
        return Caex(CitpMessages.FixtureList, w.ToArray());
    }

    private static CitpPacket FixtureListV2(params (uint Id, ushort Channel)[] fixtures)
    {
        var w = new CitpWriter().U8(0).U16((ushort)fixtures.Length);
        foreach (var (id, channel) in fixtures)
        {
            w.U32(id).Utf8("Ayrton").Utf8("Perseo").Utf8("Std").U16(42).U8(0)
             .U8(0)
             .U8(1).U16(300).U16(1)   // patched, universe 300 (16-bit in v2), channel 1
             .Utf8("").U16(channel).Utf8("").Utf8("Key").Utf8("DSC").Utf8("").Utf8("ext-1");
            for (var i = 0; i < 6; i++) w.F32(0);
        }
        return Caex(CitpMessages.FixtureListV2, w.ToArray());
    }

    private static CitpPacket Selection(params uint[] ids)
    {
        var w = new CitpWriter().U16((ushort)ids.Length);
        foreach (var id in ids) w.U32(id);
        return Caex(CitpMessages.FixtureSelection, w.ToArray());
    }

    [Fact]
    public void StartNamesItselfThenOpensAShow()
    {
        var rig = new Rig();
        rig.Session.Start();
        Assert.Equal(["PINF PNam", "CAEX EnterShow"], rig.Sent.Select(CitpMessages.Describe));
        Assert.Equal("TitanDeck Host", CitpMessages.ReadName(rig.Sent[0]));
        Assert.Equal(CitpSession.ShowName, CitpMessages.ReadEnterShow(rig.Sent[1]));
    }

    [Fact]
    public void TitansShowGetsAFixtureListRequestOnce()
    {
        var rig = new Rig();
        rig.Hear(Caex(CitpMessages.EnterShow, new CitpWriter().Ucs2("My Show").ToArray()));
        rig.Hear(Caex(CitpMessages.EnterShowV2, new CitpWriter().Utf8("My Show").ToArray()));
        var request = Assert.Single(rig.Sent);
        Assert.Equal(CitpMessages.FixtureListRequest, request.Content);
        Assert.NotEqual(0, request.RequestIndex);   // 0 means "no answer wanted"
        Assert.True(rig.Session.PeerInShow);
        Assert.Equal("My Show", rig.Session.PeerShow);
    }

    [Fact]
    public void TitansRequestsAreRefused()
    {
        var rig = new Rig();
        rig.Hear(Caex(CitpMessages.FixtureListRequest, [], index: 9));
        rig.Hear(Caex(CitpMessages.ShowSyncVersion, new CitpWriter().U16(2).ToArray(), index: 10));
        rig.Hear(Caex(CitpMessages.GetLiveViewStatus, [], index: 11));
        Assert.Equal(3, rig.Sent.Count);
        Assert.All(rig.Sent, p => Assert.Equal(CitpMessages.Nack, p.Content));
        Assert.All(rig.Sent, p => Assert.Equal(new byte[] { CitpMessages.Refused }, p.Payload));
        Assert.Equal([9, 10, 11], rig.Sent.Select(p => (int)p.RequestIndex));
    }

    [Fact]
    public void SelectionIsMappedToUserNumbersThroughTheFixtureList()
    {
        var rig = new Rig();
        rig.Hear(FixtureList(0, (1001, 1), (1002, 2), (1005, 45)));
        Assert.Equal(3, rig.Session.FixtureCount);
        rig.Hear(Selection(1005, 1001));
        Assert.Equal([45, 1], rig.Session.Selection);   // Titan's order
        Assert.Null(rig.Session.Problem);
        rig.Hear(Selection());
        Assert.Empty(rig.Session.Selection);
    }

    [Fact]
    public void UnknownFixturesAreLeftOutAndSaid()
    {
        var rig = new Rig();
        rig.Hear(FixtureList(0, (1001, 1)));
        rig.Hear(Selection(1001, 9999));
        Assert.Equal([1], rig.Session.Selection);
        Assert.Contains("1 selected fixture isn't", rig.Session.Problem);
    }

    [Fact]
    public void WithoutAFixtureListTheIdIsTheGuess()
    {
        var rig = new Rig();
        rig.Hear(Selection(3, 4));
        Assert.Equal([3, 4], rig.Session.Selection);
        Assert.Contains("guess", rig.Session.Problem);
    }

    [Fact]
    public void AddedFixturesMergeAndRemovedOnesGo()
    {
        var rig = new Rig();
        rig.Hear(FixtureList(0, (1, 10)));
        rig.Hear(FixtureList(1, (2, 20)));
        Assert.Equal(2, rig.Session.FixtureCount);
        rig.Hear(Caex(CitpMessages.FixtureRemove, new CitpWriter().U16(1).U32(1).ToArray()));
        Assert.Equal(1, rig.Session.FixtureCount);
        rig.Hear(FixtureList(0, (5, 50)));   // the whole patch again: replaces
        Assert.Equal(1, rig.Session.FixtureCount);
        Assert.Empty(rig.Sent);   // none of that is ever answered
    }

    [Fact]
    public void FixtureListV2IsRead()
    {
        var list = CitpMessages.ReadFixtureList(FixtureListV2((7, 301), (8, 302)))!.Value;
        Assert.Equal(2, list.Fixtures.Count);
        Assert.Equal(new CaexFixture(7, "Ayrton", "Perseo", "Std", 42, true, 300, 1, 301), list.Fixtures[0]);
        Assert.Equal(302, list.Fixtures[1].Channel);
    }

    [Fact]
    public void FixtureListV1IsRead()
    {
        var list = CitpMessages.ReadFixtureList(FixtureList(0, (1001, 12)))!.Value;
        Assert.Equal(new CaexFixture(1001, "Robe", "MegaPointe", "Mode 1", 39, true, 2, 101, 12), Assert.Single(list.Fixtures));
    }

    [Fact]
    public void TitansFixtureListIsAPatch()
    {
        CaexFixture Fixture(ushort user, int universe, int channel, bool patched = true) =>
            new(user, "Robe", "Robin 600", "Mode 1", 37, patched, universe, channel, user);
        // 1-based: nothing at 0 on a patched fixture.
        var patch = CitpPatch.From([Fixture(101, 1, 1), Fixture(102, 2, 38), Fixture(103, 0, 0, patched: false)]);
        Assert.Equal(2, patch.Count);
        Assert.Equal(new PatchFixture(101, "Robin 600", "Mode 1", 1, 1, 37), patch[0]);
        Assert.Equal((2, 38), (patch[1].Line, patch[1].Address));
        // 0-based: a patched fixture at universe 0, channel 0 is universe 1, address 1.
        var zero = CitpPatch.From([Fixture(1, 0, 0), Fixture(2, 0, 37)]);
        Assert.Equal([(1, 1), (1, 38)], zero.Select(f => (f.Line, f.Address)));
        Assert.Empty(CitpPatch.From([new CaexFixture(9, "", "", "", 1, true, 1, 1, 0)]));   // no user number
    }

    [Fact]
    public void TheWholePatchIsPassedOnWhenItChanges()
    {
        IReadOnlyList<CaexFixture>? patched = null;
        var session = new CitpSession("TitanDeck Host", _ => { }, _ => { }, fixtures => patched = fixtures);
        session.Receive(CitpPacket.Parse(FixtureList(0, (1001, 12), (1002, 13)).ToBytes())!, DateTimeOffset.UnixEpoch);
        Assert.Equal([12, 13], patched!.Select(f => (int)f.Channel).Order());
        session.Receive(CitpPacket.Parse(FixtureList(1, (1003, 14)).ToBytes())!, DateTimeOffset.UnixEpoch);
        Assert.Equal(3, patched!.Count);   // 1 = added: kept with the rest
    }

    [Fact]
    public void ACutShortFixtureListIsFlaggedNotThrown()
    {
        var whole = FixtureList(0, (1, 1), (2, 2));
        var cut = Caex(CitpMessages.FixtureList, whole.Payload[..(whole.Payload.Length - 30)]);
        Assert.Null(CitpMessages.ReadFixtureList(cut));
        var rig = new Rig();
        rig.Hear(cut);
        Assert.Contains(rig.Log, l => l.Flagged && l.What == "CAEX FixtureList");
        Assert.Equal(0, rig.Session.FixtureCount);
    }

    [Fact]
    public void FselSelectsAddsAndDeselects()
    {
        var rig = new Rig();
        static CitpPacket Sele(bool complete, params ushort[] ids)
        {
            var w = new CitpWriter().U8(complete ? (byte)1 : (byte)0).U8(0).U16((ushort)ids.Length);
            foreach (var id in ids) w.U16(id);
            return new CitpPacket("FSEL", CitpMessages.Sele, 0, w.ToArray());
        }
        static CitpPacket DeSe(params ushort[] ids)
        {
            var w = new CitpWriter().U16((ushort)ids.Length);
            foreach (var id in ids) w.U16(id);
            return new CitpPacket("FSEL", CitpMessages.DeSe, 0, w.ToArray());
        }
        rig.Hear(Sele(true, 1, 2));
        rig.Hear(Sele(false, 3));
        Assert.Equal([1, 2, 3], rig.Session.Selection);
        rig.Hear(DeSe(2));
        Assert.Equal([1, 3], rig.Session.Selection);
        rig.Hear(DeSe());
        Assert.Empty(rig.Session.Selection);
    }

    [Fact]
    public void WhateverTitanSendsTheSessionOnlyAnswersWithAllowedPackets()
    {
        var rig = new Rig();
        rig.Session.Start();
        var random = new Random(4809);
        uint[] codes = [.. typeof(CitpMessages).GetFields().Where(f => f.FieldType == typeof(uint) && f.IsLiteral)
            .Select(f => (uint)f.GetRawConstantValue()!)];
        foreach (var code in codes)
        {
            for (var n = 0; n < 20; n++)
            {
                var junk = new byte[random.Next(0, 64)];
                random.NextBytes(junk);
                rig.Hear(Caex(code, junk, (ushort)random.Next(0, 100)));
            }
            rig.Hear(Caex(code, []));
        }
        rig.Session.Stop();
        Assert.All(rig.Sent, p => Assert.True(CitpAllowlist.MaySend(p), CitpMessages.Describe(p)));
        Assert.DoesNotContain(rig.Log, l => l.Note?.StartsWith("BLOCKED") == true);
    }

    // --- TCP framing ---

    [Fact]
    public void FramerJoinsSplitPacketsAndSplitsJoinedOnes()
    {
        var a = CitpMessages.Name("Titan").ToBytes();
        var b = Selection(1, 2, 3).ToBytes();
        var stream = a.Concat(b).ToArray();
        var framer = new CitpFramer();
        Assert.Empty(framer.Add(stream.AsSpan(0, 5)));
        var first = framer.Add(stream.AsSpan(5, a.Length));   // the rest of a, and the start of b
        Assert.Equal("PINF PNam", CitpMessages.Describe(Assert.Single(first)));
        var second = framer.Add(stream.AsSpan(5 + a.Length));
        Assert.Equal([1u, 2u, 3u], CitpMessages.ReadFixtureSelection(Assert.Single(second)));
        Assert.Equal(2, new CitpFramer().Add(stream).Count);
    }

    [Fact]
    public void FramerRefusesAStreamThatIsntCitp() =>
        Assert.Throws<InvalidDataException>(() => new CitpFramer().Add("GET / HTTP/1.1\r\nHost: titan\r\n\r\n"u8));
}
