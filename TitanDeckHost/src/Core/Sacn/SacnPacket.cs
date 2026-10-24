using System.Buffers.Binary;
using System.Text;

namespace TitanDeckHost.Core.Sacn;

/// <summary>
/// Reads sACN (ANSI E1.31) packets: the DMX levels Titan streams over the
/// network, and the universe discovery list it may send. Only what the Host
/// needs to know a fixture's live level; anything else comes back null.
/// </summary>
public static class SacnPacket
{
    /// <summary>sACN's UDP port.</summary>
    public const int Port = 5568;
    /// <summary>The universe discovery packets go to (239.255.250.214).</summary>
    public const int DiscoveryUniverse = 64214;
    public const int MaxUniverse = 63999;

    private static ReadOnlySpan<byte> AcnId => "ASC-E1.17\0\0\0"u8;
    private const uint RootData = 0x04;
    private const uint RootExtended = 0x08;
    private const uint FramingData = 0x02;
    private const uint FramingDiscovery = 0x02;
    private const uint DiscoveryList = 0x01;

    /// <summary>The multicast group a universe is sent to: 239.255.hi.lo.</summary>
    public static byte[] MulticastGroup(int universe) => [239, 255, (byte)(universe >> 8), (byte)universe];

    /// <summary>A data packet, or null if it's anything else or malformed.
    /// Levels are copied, so the receive buffer can be reused.</summary>
    public static SacnData? ParseData(ReadOnlySpan<byte> packet)
    {
        if (!IsRoot(packet, RootData) || packet.Length < 126) return null;
        if (BinaryPrimitives.ReadUInt32BigEndian(packet[40..]) != FramingData) return null;
        if (packet[117] != 0x02 || packet[118] != 0xA1) return null;   // DMP set property, 1-byte data
        if (BinaryPrimitives.ReadUInt16BigEndian(packet[119..]) != 0
            || BinaryPrimitives.ReadUInt16BigEndian(packet[121..]) != 1) return null;
        int count = BinaryPrimitives.ReadUInt16BigEndian(packet[123..]);   // start code + slots
        if (count < 1 || count > 513 || packet.Length < 125 + count) return null;
        int universe = BinaryPrimitives.ReadUInt16BigEndian(packet[113..]);
        if (universe is < 1 or > MaxUniverse) return null;
        var options = packet[112];
        return new SacnData(
            Cid: new Guid(packet.Slice(22, 16), bigEndian: true),
            SourceName: Name(packet.Slice(44, 64)),
            Priority: packet[108],
            Sequence: packet[111],
            Preview: (options & 0x80) != 0,
            Terminated: (options & 0x40) != 0,
            Universe: universe,
            StartCode: packet[125],
            Levels: packet.Slice(126, count - 1).ToArray());
    }

    /// <summary>The universes a source says it's sending, from a universe
    /// discovery packet (one page of up to 512), or null.</summary>
    public static IReadOnlyList<int>? ParseDiscovery(ReadOnlySpan<byte> packet)
    {
        if (!IsRoot(packet, RootExtended) || packet.Length < 120) return null;
        if (BinaryPrimitives.ReadUInt32BigEndian(packet[40..]) != FramingDiscovery) return null;
        if (BinaryPrimitives.ReadUInt32BigEndian(packet[114..]) != DiscoveryList) return null;
        int layerLength = BinaryPrimitives.ReadUInt16BigEndian(packet[112..]) & 0x0FFF;
        int end = Math.Min(packet.Length, 112 + layerLength);
        var universes = new List<int>();
        for (int i = 120; i + 1 < end; i += 2)
        {
            int u = BinaryPrimitives.ReadUInt16BigEndian(packet[i..]);
            if (u is >= 1 and <= MaxUniverse) universes.Add(u);
        }
        return universes;
    }

    private static bool IsRoot(ReadOnlySpan<byte> packet, uint vector) =>
        packet.Length >= 44
        && BinaryPrimitives.ReadUInt16BigEndian(packet) == 0x0010
        && packet.Slice(4, 12).SequenceEqual(AcnId)
        && BinaryPrimitives.ReadUInt32BigEndian(packet[18..]) == vector;

    private static string Name(ReadOnlySpan<byte> field)
    {
        int end = field.IndexOf((byte)0);
        return Encoding.UTF8.GetString(end < 0 ? field : field[..end]);
    }
}

public sealed record SacnData(Guid Cid, string SourceName, byte Priority, byte Sequence, bool Preview,
    bool Terminated, int Universe, byte StartCode, byte[] Levels);
