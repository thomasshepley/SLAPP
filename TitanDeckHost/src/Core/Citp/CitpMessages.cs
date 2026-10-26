namespace TitanDeckHost.Core.Citp;

/// <summary>A peer's PINF/PLoc announcement (UDP multicast, port 4809).</summary>
public sealed record CitpLocation(ushort ListeningTcpPort, string Type, string Name, string State);

/// <summary>One fixture from a CAEX FixtureList: the console's identifier and its user number ("Channel").</summary>
public sealed record CaexFixture(uint Identifier, string Manufacturer, string Model, string Mode, ushort ChannelCount,
                                 bool Patched, int Universe, int UniverseChannel, ushort Channel);

/// <summary>
/// The CITP messages TitanDeck Host reads and the few it may write, laid out
/// exactly as the CITP specification (bitbucket.org/lars_wernlund/citp) and
/// Capture's CAEX specification G (capture.se, Support/Developers) give them.
/// </summary>
public static class CitpMessages
{
    public const int Port = 4809;
    /// <summary>The multicast group since 2014, and the one before (Titan's manual still lists the old one).</summary>
    public static readonly string[] MulticastGroups = ["239.224.0.180", "224.0.0.180"];

    public static readonly uint PLoc = CitpPacket.Code("PLoc");
    public static readonly uint PNam = CitpPacket.Code("PNam");
    public static readonly uint Sele = CitpPacket.Code("Sele");
    public static readonly uint DeSe = CitpPacket.Code("DeSe");

    // CAEX content codes (numbers, not text).
    public const uint Nack = 0xFFFFFFFF;
    public const uint GetLiveViewStatus = 0x00000100;
    public const uint GetLiveViewImage = 0x00000200;
    public const uint SetCueRecordingCapabilities = 0x00010100;
    public const uint SetRecorderClearingCapabilities = 0x00010300;
    public const uint EnterShow = 0x00020100;
    public const uint LeaveShow = 0x00020101;
    public const uint ShowSyncVersion = 0x00020102;
    public const uint EnterShowV2 = 0x00020103;
    public const uint SetFixtureTransformationSpace = 0x00020150;
    public const uint FixtureListRequest = 0x00020200;
    public const uint FixtureList = 0x00020201;
    public const uint FixtureModify = 0x00020202;
    public const uint FixtureRemove = 0x00020203;
    public const uint FixtureIdentify = 0x00020204;
    public const uint FixtureListV2 = 0x00020205;
    public const uint FixtureModifyV2 = 0x00020206;
    public const uint FixtureSelection = 0x00020300;
    public const uint FixtureConsoleStatus = 0x00020400;
    public const uint GetLaserFeedList = 0x00030100;

    /// <summary>NACK reasons.</summary>
    public const byte UnknownRequest = 0x00, Malformed = 0x01, InternalError = 0x02, Refused = 0x03;

    public static string CaexName(uint code) => code switch
    {
        Nack => "NACK",
        GetLiveViewStatus => "GetLiveViewStatus",
        GetLiveViewImage => "GetLiveViewImage",
        SetCueRecordingCapabilities => "SetCueRecordingCapabilities",
        SetRecorderClearingCapabilities => "SetRecorderClearingCapabilities",
        EnterShow => "EnterShow",
        EnterShowV2 => "EnterShow v2",
        LeaveShow => "LeaveShow",
        ShowSyncVersion => "ShowSyncVersion",
        SetFixtureTransformationSpace => "SetFixtureTransformationSpace",
        FixtureListRequest => "FixtureListRequest",
        FixtureList => "FixtureList",
        FixtureListV2 => "FixtureList v2",
        FixtureModify => "FixtureModify",
        FixtureModifyV2 => "FixtureModify v2",
        FixtureRemove => "FixtureRemove",
        FixtureIdentify => "FixtureIdentify",
        FixtureSelection => "FixtureSelection",
        FixtureConsoleStatus => "FixtureConsoleStatus",
        GetLaserFeedList => "GetLaserFeedList",
        _ => $"0x{code:X8}",
    };

    /// <summary>"PINF PLoc", "CAEX FixtureSelection"...</summary>
    public static string Describe(CitpPacket packet) =>
        packet.Layer == "CAEX" ? "CAEX " + CaexName(packet.Content) : $"{packet.Layer} {packet.ContentText}";

    // --- PINF ---

    public static CitpPacket Location(ushort tcpPort, string type, string name, string state) =>
        new("PINF", PLoc, 0, new CitpWriter().U16(tcpPort).Ucs1(type).Ucs1(name).Ucs1(state).ToArray());

    public static CitpLocation? ReadLocation(CitpPacket packet)
    {
        if (packet.Layer != "PINF" || packet.Content != PLoc || packet.Payload.Length < 2) return null;
        var reader = new CitpReader(packet.Payload);
        return new CitpLocation(reader.U16(), reader.Ucs1(), reader.Ucs1(), reader.Ucs1());
    }

    public static CitpPacket Name(string name) => new("PINF", PNam, 0, new CitpWriter().Ucs1(name).ToArray());

    public static string? ReadName(CitpPacket packet) =>
        packet.Layer == "PINF" && packet.Content == PNam ? new CitpReader(packet.Payload).Ucs1() : null;

    // --- FSEL: identifiers are 16-bit and "in most consoles map directly to a Channel" ---

    /// <summary>Sele: (complete, ids). Complete means "only these".</summary>
    public static (bool Complete, IReadOnlyList<int> Ids)? ReadSelect(CitpPacket packet)
    {
        if (packet.Layer != "FSEL" || packet.Content != Sele || packet.Payload.Length < 4) return null;
        var reader = new CitpReader(packet.Payload);
        var complete = reader.U8() != 0;
        reader.Skip(1);
        var count = reader.U16();
        if (reader.Remaining < count * 2) return null;
        var ids = new List<int>(count);
        for (var i = 0; i < count; i++) ids.Add(reader.U16());
        return (complete, ids);
    }

    /// <summary>DeSe: the ids to deselect; empty = deselect everything.</summary>
    public static IReadOnlyList<int>? ReadDeselect(CitpPacket packet)
    {
        if (packet.Layer != "FSEL" || packet.Content != DeSe || packet.Payload.Length < 2) return null;
        var reader = new CitpReader(packet.Payload);
        var count = reader.U16();
        if (reader.Remaining < count * 2) return null;
        var ids = new List<int>(count);
        for (var i = 0; i < count; i++) ids.Add(reader.U16());
        return ids;
    }

    // --- CAEX: the only ones TitanDeck Host ever writes ---

    public static CitpPacket CaexEnterShow(string showName) =>
        new("CAEX", EnterShow, 0, new CitpWriter().Ucs2(showName).ToArray());

    public static CitpPacket CaexLeaveShow() => new("CAEX", LeaveShow, 0, []);

    public static CitpPacket CaexFixtureListRequest(ushort requestIndex) => new("CAEX", FixtureListRequest, requestIndex, []);

    /// <summary>A NACK, answering the request whose RequestIndex was <paramref name="inResponseTo"/>.</summary>
    public static CitpPacket CaexNack(byte reason, ushort inResponseTo) =>
        new("CAEX", Nack, inResponseTo, new CitpWriter().U8(reason).ToArray());

    // --- CAEX: read ---

    /// <summary>EnterShow (ucs2 name) or EnterShow v2 (utf8 name).</summary>
    public static string? ReadEnterShow(CitpPacket packet)
    {
        if (packet.Layer != "CAEX") return null;
        if (packet.Content == EnterShow) return new CitpReader(packet.Payload).Ucs2();
        if (packet.Content == EnterShowV2) return new CitpReader(packet.Payload).Utf8();
        return null;
    }

    public static IReadOnlyList<uint>? ReadFixtureSelection(CitpPacket packet)
    {
        if (packet.Layer != "CAEX" || packet.Content != FixtureSelection) return null;
        return ReadIds32(packet.Payload);
    }

    /// <summary>FixtureRemove: the identifiers the console took out of its patch.</summary>
    public static IReadOnlyList<uint>? ReadFixtureRemove(CitpPacket packet) =>
        packet.Layer == "CAEX" && packet.Content == FixtureRemove ? ReadIds32(packet.Payload) : null;

    /// <summary>{uint16 count; uint32 ids[]}</summary>
    private static List<uint>? ReadIds32(byte[] payload)
    {
        if (payload.Length < 2) return null;
        var reader = new CitpReader(payload);
        var count = reader.U16();
        if (reader.Remaining < count * 4) return null;
        var ids = new List<uint>(count);
        for (var i = 0; i < count; i++) ids.Add(reader.U32());
        return ids;
    }

    /// <summary>FixtureList (v1 or v2): its type (0 = the whole patch, 1 = new, 2 = exchanged) and fixtures.</summary>
    public static (byte Type, IReadOnlyList<CaexFixture> Fixtures)? ReadFixtureList(CitpPacket packet)
    {
        if (packet.Layer != "CAEX" || (packet.Content != FixtureList && packet.Content != FixtureListV2)) return null;
        var v2 = packet.Content == FixtureListV2;
        try
        {
            var reader = new CitpReader(packet.Payload);
            var type = reader.U8();
            var count = reader.U16();
            var fixtures = new List<CaexFixture>(count);
            for (var i = 0; i < count; i++)
            {
                var id = reader.U32();
                var manufacturer = v2 ? reader.Utf8() : reader.Ucs2();
                var model = v2 ? reader.Utf8() : reader.Ucs2();
                var mode = v2 ? reader.Utf8() : reader.Ucs2();
                var channels = reader.U16();
                reader.U8();   // IsDimmer
                var identifiers = reader.U8();
                for (var j = 0; j < identifiers; j++)
                {
                    reader.U8();   // IdentifierType
                    reader.Skip(reader.U16());
                }
                var patched = reader.U8() != 0;
                int universe = v2 ? reader.U16() : reader.U8();
                int universeChannel = reader.U16();
                if (v2) reader.Utf8(); else reader.Ucs2();   // Unit
                var channel = reader.U16();
                if (v2) reader.Utf8(); else reader.Ucs2();   // Circuit
                if (v2)
                {
                    reader.Utf8();   // Purpose
                    reader.Utf8();   // Focus
                }
                if (v2) reader.Utf8(); else reader.Ucs2();   // Note
                if (v2) reader.Utf8();   // ExternalIdentifier
                reader.Skip(24);   // float[3] Position, float[3] Angles
                if (reader.Remaining < 0) return null;   // cut short: malformed
                fixtures.Add(new CaexFixture(id, manufacturer, model, mode, channels, patched, universe, universeChannel, channel));
            }
            return (type, fixtures);
        }
        catch (Exception error) when (error is ArgumentOutOfRangeException or IndexOutOfRangeException)
        {
            return null;   // cut short: malformed
        }
    }
}

/// <summary>
/// The safety catch. Capture can patch Titan (Titan applies Capture's patch
/// changes by itself), so TitanDeck Host may only ever send these: who it is
/// (PLoc, PNam), that it has a "show" open or closed, a request for Titan's
/// fixture list, and a refusal. Never a fixture list, patch change,
/// selection, identify or DMX. Every packet goes through <see cref="Check"/>.
/// </summary>
public static class CitpAllowlist
{
    public static bool MaySend(CitpPacket packet) => packet.Layer switch
    {
        "PINF" => packet.Content == CitpMessages.PLoc || packet.Content == CitpMessages.PNam,
        "CAEX" => packet.Content is CitpMessages.EnterShow or CitpMessages.LeaveShow
            or CitpMessages.FixtureListRequest or CitpMessages.Nack,
        _ => false,
    };

    public static CitpPacket Check(CitpPacket packet) =>
        MaySend(packet) ? packet : throw new InvalidOperationException($"TitanDeck Host never sends {CitpMessages.Describe(packet)}.");
}
