using System.Buffers.Binary;
using System.Text;
using TitanDeckHost.Core.Sacn;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class SacnTests
{
    private static readonly Guid Titan = Guid.Parse("6d1b2c3a-0000-4000-8000-00000000a001");
    private static readonly Guid Backup = Guid.Parse("6d1b2c3a-0000-4000-8000-00000000b002");
    private static readonly DateTimeOffset T0 = new(2026, 10, 24, 21, 0, 0, TimeSpan.Zero);

    /// <summary>A real E1.31 data packet, byte for byte.</summary>
    internal static byte[] Data(int universe, byte[] levels, Guid? cid = null, byte priority = 100, byte sequence = 0,
        byte options = 0, byte startCode = 0, string name = "Titan")
    {
        var p = new byte[126 + levels.Length];
        BinaryPrimitives.WriteUInt16BigEndian(p, 0x0010);
        "ASC-E1.17\0\0\0"u8.CopyTo(p.AsSpan(4));
        BinaryPrimitives.WriteUInt16BigEndian(p.AsSpan(16), (ushort)(0x7000 | (p.Length - 16)));
        BinaryPrimitives.WriteUInt32BigEndian(p.AsSpan(18), 0x04);
        (cid ?? Titan).TryWriteBytes(p.AsSpan(22, 16), bigEndian: true, out _);
        BinaryPrimitives.WriteUInt16BigEndian(p.AsSpan(38), (ushort)(0x7000 | (p.Length - 38)));
        BinaryPrimitives.WriteUInt32BigEndian(p.AsSpan(40), 0x02);
        Encoding.UTF8.GetBytes(name).CopyTo(p.AsSpan(44));
        p[108] = priority;
        p[111] = sequence;
        p[112] = options;
        BinaryPrimitives.WriteUInt16BigEndian(p.AsSpan(113), (ushort)universe);
        BinaryPrimitives.WriteUInt16BigEndian(p.AsSpan(115), (ushort)(0x7000 | (p.Length - 115)));
        p[117] = 0x02;
        p[118] = 0xA1;
        BinaryPrimitives.WriteUInt16BigEndian(p.AsSpan(121), 1);
        BinaryPrimitives.WriteUInt16BigEndian(p.AsSpan(123), (ushort)(levels.Length + 1));
        p[125] = startCode;
        levels.CopyTo(p.AsSpan(126));
        return p;
    }

    private static byte[] Discovery(params int[] universes)
    {
        var p = new byte[120 + universes.Length * 2];
        BinaryPrimitives.WriteUInt16BigEndian(p, 0x0010);
        "ASC-E1.17\0\0\0"u8.CopyTo(p.AsSpan(4));
        BinaryPrimitives.WriteUInt32BigEndian(p.AsSpan(18), 0x08);
        BinaryPrimitives.WriteUInt32BigEndian(p.AsSpan(40), 0x02);
        BinaryPrimitives.WriteUInt16BigEndian(p.AsSpan(112), (ushort)(0x7000 | (p.Length - 112)));
        BinaryPrimitives.WriteUInt32BigEndian(p.AsSpan(114), 0x01);
        for (int i = 0; i < universes.Length; i++)
            BinaryPrimitives.WriteUInt16BigEndian(p.AsSpan(120 + i * 2), (ushort)universes[i]);
        return p;
    }

    private static byte[] Levels(params (int Address, byte Level)[] set)
    {
        var levels = new byte[512];
        foreach (var (address, level) in set) levels[address - 1] = level;
        return levels;
    }

    [Fact]
    public void ReadsADataPacket()
    {
        var data = SacnPacket.ParseData(Data(3, Levels((1, 255), (101, 128)), priority: 120, sequence: 7));
        Assert.NotNull(data);
        Assert.Equal(3, data.Universe);
        Assert.Equal("Titan", data.SourceName);
        Assert.Equal(Titan, data.Cid);
        Assert.Equal(120, data.Priority);
        Assert.Equal(7, data.Sequence);
        Assert.Equal(512, data.Levels.Length);
        Assert.Equal(255, data.Levels[0]);
        Assert.Equal(128, data.Levels[100]);
        Assert.Equal([239, 255, 0, 3], SacnPacket.MulticastGroup(3));
        Assert.Equal([239, 255, 250, 214], SacnPacket.MulticastGroup(SacnPacket.DiscoveryUniverse));
    }

    [Fact]
    public void IgnoresJunkAndShortPackets()
    {
        Assert.Null(SacnPacket.ParseData([]));
        Assert.Null(SacnPacket.ParseData(new byte[200]));
        var packet = Data(1, Levels());
        Assert.Null(SacnPacket.ParseData(packet.AsSpan(0, 300)));   // says 512 slots, carries fewer
        packet[4] = (byte)'X';
        Assert.Null(SacnPacket.ParseData(packet));
        Assert.Null(SacnPacket.ParseData(Data(0, Levels())));
        Assert.Null(SacnPacket.ParseDiscovery(Data(1, Levels())));
    }

    [Fact]
    public void ReadsUniverseDiscovery()
    {
        Assert.Equal([1, 2, 7], SacnPacket.ParseDiscovery(Discovery(1, 2, 7)));
        var store = new DmxUniverses();
        Assert.Equal([5, 6], store.Accept(Discovery(5, 6), T0));
        Assert.Equal([5, 6], store.Known(T0));
    }

    [Fact]
    public void KeepsTheLatestLevelsAndASlice()
    {
        var store = new DmxUniverses();
        store.Accept(Data(1, Levels((10, 50)), sequence: 1), T0);
        store.Accept(Data(1, Levels((10, 200)), sequence: 2), T0.AddMilliseconds(25));
        var u = store.Get(1, T0.AddMilliseconds(30));
        Assert.NotNull(u);
        Assert.Equal(200, u.Levels[9]);
        Assert.Equal(["Titan"], u.Sources);
        Assert.Equal(TimeSpan.FromMilliseconds(5), u.Age);
        Assert.Equal([0, 200, 0], u.Slice(9, 3));
        Assert.Equal(2, u.Slice(511, 10).Length);   // clipped at the end of the universe
        Assert.Null(store.Get(2, T0));
        Assert.Equal([1], store.Known(T0));
    }

    [Fact]
    public void DropsLateOutOfOrderPackets()
    {
        var store = new DmxUniverses();
        store.Accept(Data(1, Levels((1, 90)), sequence: 10), T0);
        store.Accept(Data(1, Levels((1, 10)), sequence: 9), T0.AddMilliseconds(20));
        Assert.Equal(90, store.Get(1, T0.AddMilliseconds(20))!.Levels[0]);
        store.Accept(Data(1, Levels((1, 11)), sequence: 11), T0.AddMilliseconds(40));
        Assert.Equal(11, store.Get(1, T0.AddMilliseconds(40))!.Levels[0]);
        store.Accept(Data(1, Levels((1, 12)), sequence: 200), T0.AddMilliseconds(60));
        Assert.Equal(12, store.Get(1, T0.AddMilliseconds(60))!.Levels[0]);   // a jump forward is fine
        store.Accept(Data(1, Levels((1, 13)), sequence: 0), T0.AddMilliseconds(80));
        Assert.Equal(13, store.Get(1, T0.AddMilliseconds(80))!.Levels[0]);   // wraps round
    }

    [Fact]
    public void IgnoresPreviewAndOtherStartCodes()
    {
        var store = new DmxUniverses();
        store.Accept(Data(1, Levels((1, 255)), options: 0x80), T0);
        store.Accept(Data(1, Levels((1, 255)), startCode: 0xDD), T0);
        Assert.Null(store.Get(1, T0));
    }

    [Fact]
    public void HighestPriorityWinsThenHighestLevel()
    {
        var store = new DmxUniverses();
        store.Accept(Data(1, Levels((1, 40), (2, 200)), cid: Titan, priority: 100), T0);
        store.Accept(Data(1, Levels((1, 90), (2, 10)), cid: Backup, priority: 100, name: "Backup"), T0);
        var both = store.Get(1, T0)!;
        Assert.Equal([90, 200], both.Slice(1, 2));   // HTP at equal priority
        Assert.Equal(["Titan", "Backup"], both.Sources);

        store.Accept(Data(1, Levels((1, 5)), cid: Backup, priority: 150, name: "Backup", sequence: 1), T0);
        Assert.Equal([5, 0], store.Get(1, T0)!.Slice(1, 2));
    }

    [Fact]
    public void SourcesTimeOutOrTerminate()
    {
        var store = new DmxUniverses();
        store.Accept(Data(1, Levels((1, 255))), T0);
        Assert.NotNull(store.Get(1, T0.AddSeconds(2)));
        Assert.Null(store.Get(1, T0.AddSeconds(3)));
        Assert.Empty(store.Known(T0.AddSeconds(3)));

        store.Accept(Data(1, Levels((1, 255)), sequence: 1), T0.AddSeconds(4));
        store.Accept(Data(1, Levels((1, 255)), sequence: 2, options: 0x40), T0.AddSeconds(4));
        Assert.Null(store.Get(1, T0.AddSeconds(4)));

        // After a timeout an old sequence number is fine again (Titan restarted).
        store.Accept(Data(2, Levels((1, 1)), sequence: 50), T0);
        store.Accept(Data(2, Levels((1, 2)), sequence: 40), T0.AddSeconds(5));
        Assert.Equal(2, store.Get(2, T0.AddSeconds(5))!.Levels[0]);
    }
}
