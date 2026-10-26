namespace TitanDeckHost.Core.Citp;

/// <summary>One line for the Titan log: which way, what, a note, and whether it's worth a red flag.</summary>
public sealed record CitpLogLine(bool Outgoing, string What, string? Note, bool Flagged);

/// <summary>
/// One CITP connection with Titan, as a visualiser that only listens.
/// It says who it is, opens a show (so Titan will share its selection) and
/// asks for Titan's fixture list, which turns Titan's fixture identifiers
/// into the user numbers TitanDeck selects by. After that it only listens:
/// a selection from Titan (CAEX FixtureSelection, or FSEL from older
/// consoles) becomes <see cref="Selection"/>. Everything Titan asks of it
/// is refused with a NACK, and every packet it sends goes through
/// <see cref="CitpAllowlist"/>, so it can't ever send Titan a patch.
/// Not thread-safe: the connection's read loop drives it; readers take a
/// <see cref="Snapshot"/>.
/// </summary>
public sealed class CitpSession
{
    /// <summary>The CAEX requests a visualiser can be asked; all refused.</summary>
    private static readonly HashSet<uint> Requests =
    [
        CitpMessages.GetLiveViewStatus, CitpMessages.GetLiveViewImage, CitpMessages.SetCueRecordingCapabilities,
        CitpMessages.SetRecorderClearingCapabilities, CitpMessages.SetFixtureTransformationSpace,
        CitpMessages.ShowSyncVersion, CitpMessages.FixtureListRequest, CitpMessages.GetLaserFeedList,
    ];

    /// <summary>Patch messages a console sends about its own patch. Read for the fixture numbers, never answered.</summary>
    private static readonly HashSet<uint> PatchNews =
    [
        CitpMessages.FixtureModify, CitpMessages.FixtureModifyV2, CitpMessages.FixtureIdentify, CitpMessages.FixtureConsoleStatus,
    ];

    public const string ShowName = "TitanDeck";

    private readonly string _ourName;
    private readonly Action<CitpPacket> _send;
    private readonly Action<CitpLogLine> _log;
    private readonly Dictionary<uint, int> _userNumbers = [];
    private List<int> _selection = [];
    private ushort _nextRequest = 1;
    private bool _askedForFixtures;

    public CitpSession(string ourName, Action<CitpPacket> send, Action<CitpLogLine> log)
    {
        _ourName = ourName;
        _send = send;
        _log = log;
    }

    public string? PeerName { get; private set; }
    public string? PeerShow { get; private set; }
    public bool PeerInShow { get; private set; }
    public bool HaveFixtureList { get; private set; }
    public int FixtureCount => _userNumbers.Count;
    /// <summary>Titan's selection as user numbers, in Titan's order.</summary>
    public IReadOnlyList<int> Selection => _selection;
    /// <summary>Set when the selection had to be guessed, or couldn't be matched.</summary>
    public string? Problem { get; private set; }
    public DateTimeOffset? LastHeard { get; private set; }

    public CitpSessionSnapshot Snapshot() =>
        new(PeerName, PeerShow, PeerInShow, HaveFixtureList, FixtureCount, _selection.ToList(), Problem, LastHeard);

    /// <summary>A TCP connection is up: name ourselves (always first) and open our show.</summary>
    public void Start()
    {
        Send(CitpMessages.Name(_ourName), null);
        Send(CitpMessages.CaexEnterShow(ShowName), "so Titan shares its selection");
    }

    /// <summary>The connection is closing politely.</summary>
    public void Stop() => Send(CitpMessages.CaexLeaveShow(), null);

    public void Receive(CitpPacket packet, DateTimeOffset now)
    {
        LastHeard = now;
        var what = CitpMessages.Describe(packet);
        switch (packet.Layer)
        {
            case "PINF":
                if (CitpMessages.ReadName(packet) is { } name)
                {
                    PeerName = name;
                    Log(false, what, $"\"{name}\"");
                }
                else if (CitpMessages.ReadLocation(packet) is { } location)
                {
                    PeerName ??= location.Name;
                    Log(false, what, $"{location.Type} \"{location.Name}\" ({location.State})");
                }
                else Log(false, what, "ignored");
                return;
            case "FSEL":
                ReceiveFsel(packet, what);
                return;
            case "CAEX":
                ReceiveCaex(packet, what);
                return;
            default:
                Log(false, what, "ignored (not a layer TitanDeck uses)");
                return;
        }
    }

    private void ReceiveCaex(CitpPacket packet, string what)
    {
        var code = packet.Content;
        if (code == CitpMessages.Nack)
        {
            var reason = packet.Payload.Length > 0 ? packet.Payload[0] : CitpMessages.UnknownRequest;
            Log(false, what, $"Titan said no ({NackReason(reason)}) to request {packet.RequestIndex}", flagged: true);
            if (_askedForFixtures && !HaveFixtureList)
                Problem = "Titan wouldn't send its fixture list, so fixture numbers are a guess (Titan's CITP ids).";
            return;
        }
        if (Requests.Contains(code))
        {
            Log(false, what, null);
            Send(CitpMessages.CaexNack(CitpMessages.Refused, packet.RequestIndex),
                code == CitpMessages.FixtureListRequest ? "refused: TitanDeck Host never sends Titan a patch" : "refused");
            return;
        }
        if (CitpMessages.ReadEnterShow(packet) is { } show)
        {
            PeerShow = show;
            PeerInShow = true;
            Log(false, what, $"\"{show}\"");
            AskForFixtures();
            return;
        }
        if (code == CitpMessages.LeaveShow)
        {
            PeerInShow = false;
            Log(false, what, "selection stops until Titan opens a show again");
            return;
        }
        if (CitpMessages.ReadFixtureList(packet) is { } list)
        {
            if (list.Type == 0) _userNumbers.Clear();   // the whole patch; 1 = added, 2 = exchanged
            foreach (var fixture in list.Fixtures) _userNumbers[fixture.Identifier] = fixture.Channel;
            HaveFixtureList = true;
            Problem = null;
            Log(false, what, $"{list.Fixtures.Count} fixture{(list.Fixtures.Count == 1 ? "" : "s")} ({ListType(list.Type)}), {FixtureCount} known"
                + Sample(list.Fixtures));
            return;
        }
        if (code is CitpMessages.FixtureList or CitpMessages.FixtureListV2)
        {
            Log(false, what, "couldn't be read", flagged: true);
            return;
        }
        if (CitpMessages.ReadFixtureRemove(packet) is { } removed)
        {
            foreach (var id in removed) _userNumbers.Remove(id);
            Log(false, what, $"{removed.Count} removed from Titan's patch (only noted, never answered)");
            return;
        }
        if (CitpMessages.ReadFixtureSelection(packet) is { } ids)
        {
            SetSelection(ids, what);
            return;
        }
        if (PatchNews.Contains(code))
        {
            Log(false, what, "only noted, never answered");
            return;
        }
        Log(false, what, "ignored");
    }

    private void ReceiveFsel(CitpPacket packet, string what)
    {
        if (CitpMessages.ReadSelect(packet) is { } select)
        {
            var ids = select.Ids.Select(i => (uint)i).ToList();
            if (select.Complete) SetSelection(ids, what);
            else
            {
                var added = Resolve(ids);
                SetSelection(null, what, _selection.Concat(added.Where(u => !_selection.Contains(u))).ToList());
            }
            return;
        }
        if (CitpMessages.ReadDeselect(packet) is { } deselect)
        {
            if (deselect.Count == 0) SetSelection([], what);
            else
            {
                var gone = Resolve(deselect.Select(i => (uint)i).ToList());
                SetSelection(null, what, _selection.Where(u => !gone.Contains(u)).ToList());
            }
            return;
        }
        Log(false, what, "ignored");
    }

    private void AskForFixtures()
    {
        if (_askedForFixtures) return;
        _askedForFixtures = true;
        Send(CitpMessages.CaexFixtureListRequest(_nextRequest++), "for the fixture numbers (read only)");
    }

    private void SetSelection(IReadOnlyList<uint>? ids, string what, List<int>? userNumbers = null)
    {
        var selection = userNumbers ?? Resolve(ids!);
        var changed = !selection.SequenceEqual(_selection);
        _selection = selection;
        var shown = selection.Count == 0 ? "nothing selected" : "fixtures " + string.Join(", ", selection.Take(40)) + (selection.Count > 40 ? "..." : "");
        var raw = ids is null || !HaveFixtureList ? "" : $" (Titan ids {string.Join(", ", ids.Take(12))}{(ids.Count > 12 ? "..." : "")})";
        Log(false, what, shown + raw + (changed ? "" : ", unchanged"));
    }

    /// <summary>Titan's identifiers to user numbers. Before (or without) a fixture list, the id is taken as the user number.</summary>
    private List<int> Resolve(IReadOnlyList<uint> ids)
    {
        if (!HaveFixtureList)
        {
            Problem = _askedForFixtures && Problem is not null ? Problem
                : "Titan hasn't sent its fixture list yet, so fixture numbers are a guess (Titan's CITP ids).";
            return ids.Where(i => i is > 0 and <= int.MaxValue).Select(i => (int)i).Distinct().ToList();
        }
        var unknown = ids.Where(i => !_userNumbers.ContainsKey(i)).ToList();
        Problem = unknown.Count == 0 ? null : $"{unknown.Count} selected fixture{(unknown.Count == 1 ? " isn't" : "s aren't")} in Titan's fixture list.";
        return ids.Where(_userNumbers.ContainsKey).Select(i => _userNumbers[i]).Where(u => u > 0).Distinct().ToList();
    }

    private void Send(CitpPacket packet, string? note)
    {
        CitpPacket checkedPacket;
        try
        {
            checkedPacket = CitpAllowlist.Check(packet);
        }
        catch (InvalidOperationException error)
        {
            Log(true, CitpMessages.Describe(packet), "BLOCKED: " + error.Message, flagged: true);
            return;
        }
        _send(checkedPacket);
        Log(true, CitpMessages.Describe(checkedPacket), note);
    }

    private void Log(bool outgoing, string what, string? note, bool flagged = false) =>
        _log(new CitpLogLine(outgoing, what, note, flagged));

    private static string Sample(IReadOnlyList<CaexFixture> fixtures) =>
        fixtures.Count == 0 ? "" : ": " + string.Join(", ", fixtures.Take(5).Select(f => $"id {f.Identifier} = {f.Channel} {f.Model}".TrimEnd()))
            + (fixtures.Count > 5 ? "..." : "");

    private static string ListType(byte type) => type switch
    {
        0 => "the whole patch",
        1 => "new",
        2 => "exchanged",
        _ => $"type {type}",
    };

    private static string NackReason(byte reason) => reason switch
    {
        CitpMessages.UnknownRequest => "unknown request",
        CitpMessages.Malformed => "malformed",
        CitpMessages.InternalError => "internal error",
        CitpMessages.Refused => "refused",
        _ => $"reason {reason}",
    };
}

public sealed record CitpSessionSnapshot(string? PeerName, string? PeerShow, bool PeerInShow, bool HaveFixtureList,
    int FixtureCount, IReadOnlyList<int> Selection, string? Problem, DateTimeOffset? LastHeard);

/// <summary>Cuts a TCP byte stream into CITP packets (each says its own size).</summary>
public sealed class CitpFramer
{
    private byte[] _buffer = new byte[64 * 1024];
    private int _length;

    /// <summary>Adds bytes; returns the whole packets now available. Throws <see cref="InvalidDataException"/> for a stream that isn't CITP.</summary>
    public List<CitpPacket> Add(ReadOnlySpan<byte> bytes)
    {
        if (_length + bytes.Length > _buffer.Length)
        {
            if (_length + bytes.Length > CitpPacket.MaximumSize + 64 * 1024) throw new InvalidDataException("CITP packet too big.");
            Array.Resize(ref _buffer, Math.Max(_buffer.Length * 2, _length + bytes.Length));
        }
        bytes.CopyTo(_buffer.AsSpan(_length));
        _length += bytes.Length;
        var packets = new List<CitpPacket>();
        var at = 0;
        while (true)
        {
            var size = CitpPacket.DeclaredSize(_buffer.AsSpan(at, _length - at));
            if (size is null) throw new InvalidDataException("That isn't CITP.");
            if (size == 0 || _length - at < size) break;
            packets.Add(CitpPacket.Parse(_buffer.AsSpan(at, size.Value))!);
            at += size.Value;
        }
        if (at > 0)
        {
            _buffer.AsSpan(at, _length - at).CopyTo(_buffer);
            _length -= at;
        }
        return packets;
    }
}
