using System.Buffers.Binary;
using System.Text;

namespace TitanDeckHost.Core.Citp;

/// <summary>
/// One CITP message: the 20-byte CITP header, then a layer code (PINF, FSEL,
/// CAEX...), then that layer's content code and payload. Little-endian
/// throughout. Codes are 4 ASCII bytes in order ("PINF", "PLoc") except
/// CAEX's, which are numbers (0x00020300).
/// </summary>
public sealed record CitpPacket(string Layer, uint Content, ushort RequestIndex, byte[] Payload)
{
    public const int HeaderSize = 20;
    /// <summary>Layer header (4-byte content code) included.</summary>
    public const int MinimumSize = HeaderSize + 4;
    /// <summary>Anything bigger is nonsense or not CITP: drop the connection rather than buffer it.</summary>
    public const int MaximumSize = 4 * 1024 * 1024;

    public static uint Code(string fourCharacters)
    {
        if (fourCharacters.Length != 4) throw new ArgumentException("CITP codes are 4 characters.", nameof(fourCharacters));
        return BinaryPrimitives.ReadUInt32LittleEndian(Encoding.ASCII.GetBytes(fourCharacters));
    }

    public static string CodeText(uint code)
    {
        Span<byte> bytes = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(bytes, code);
        return bytes.ToArray().All(b => b is >= 0x20 and < 0x7F) ? Encoding.ASCII.GetString(bytes) : $"0x{code:X8}";
    }

    public string ContentText => CodeText(Content);

    public byte[] ToBytes()
    {
        var size = MinimumSize + Payload.Length;
        var bytes = new byte[size];
        var span = bytes.AsSpan();
        Encoding.ASCII.GetBytes("CITP").CopyTo(span);
        span[4] = 1;   // version 1.0
        span[5] = 0;
        BinaryPrimitives.WriteUInt16LittleEndian(span[6..], RequestIndex);
        BinaryPrimitives.WriteUInt32LittleEndian(span[8..], (uint)size);
        BinaryPrimitives.WriteUInt16LittleEndian(span[12..], 1);   // message part count
        BinaryPrimitives.WriteUInt16LittleEndian(span[14..], 0);   // message part
        Encoding.ASCII.GetBytes(Layer).CopyTo(span[16..]);
        BinaryPrimitives.WriteUInt32LittleEndian(span[20..], Content);
        Payload.CopyTo(span[24..]);
        return bytes;
    }

    /// <summary>The size a packet starting here says it is, once its header has arrived; null for not CITP.</summary>
    public static int? DeclaredSize(ReadOnlySpan<byte> start)
    {
        if (start.Length < HeaderSize) return 0;
        if (!start[..4].SequenceEqual("CITP"u8)) return null;
        var size = BinaryPrimitives.ReadUInt32LittleEndian(start[8..]);
        return size is >= MinimumSize and <= MaximumSize ? (int)size : null;
    }

    public static CitpPacket? Parse(ReadOnlySpan<byte> bytes)
    {
        if (DeclaredSize(bytes) is not { } size || size == 0 || bytes.Length < size) return null;
        var layer = Encoding.ASCII.GetString(bytes[16..20]);
        var content = BinaryPrimitives.ReadUInt32LittleEndian(bytes[20..]);
        var index = BinaryPrimitives.ReadUInt16LittleEndian(bytes[6..]);
        return new CitpPacket(layer, content, index, bytes[24..size].ToArray());
    }
}

/// <summary>Reads CITP's field types out of a payload.</summary>
public ref struct CitpReader(ReadOnlySpan<byte> data)
{
    private readonly ReadOnlySpan<byte> _data = data;
    private int _at;

    public readonly int Remaining => _data.Length - _at;

    public byte U8() => _data[_at++];

    public ushort U16()
    {
        var value = BinaryPrimitives.ReadUInt16LittleEndian(_data[_at..]);
        _at += 2;
        return value;
    }

    public uint U32()
    {
        var value = BinaryPrimitives.ReadUInt32LittleEndian(_data[_at..]);
        _at += 4;
        return value;
    }

    public ulong U64()
    {
        var value = BinaryPrimitives.ReadUInt64LittleEndian(_data[_at..]);
        _at += 8;
        return value;
    }

    public float F32()
    {
        var value = BinaryPrimitives.ReadSingleLittleEndian(_data[_at..]);
        _at += 4;
        return value;
    }

    /// <summary>ucs1: null-terminated 8-bit text.</summary>
    public string Ucs1()
    {
        var end = _data[_at..].IndexOf((byte)0);
        if (end < 0) end = Remaining;
        var text = Encoding.Latin1.GetString(_data.Slice(_at, end));
        _at += Math.Min(end + 1, Remaining);
        return text;
    }

    /// <summary>utf8: null-terminated UTF-8 text (CAEX v2).</summary>
    public string Utf8()
    {
        var end = _data[_at..].IndexOf((byte)0);
        if (end < 0) end = Remaining;
        var text = Encoding.UTF8.GetString(_data.Slice(_at, end));
        _at += Math.Min(end + 1, Remaining);
        return text;
    }

    /// <summary>ucs2: null-terminated UTF-16LE text.</summary>
    public string Ucs2()
    {
        var start = _at;
        while (_at + 1 < _data.Length && (_data[_at] != 0 || _data[_at + 1] != 0)) _at += 2;
        var text = Encoding.Unicode.GetString(_data[start.._at]);
        _at = Math.Min(_at + 2, _data.Length);
        return text;
    }

    public void Skip(int count) => _at += count;
}

/// <summary>Builds a payload from CITP's field types.</summary>
public sealed class CitpWriter
{
    private readonly MemoryStream _bytes = new();

    public CitpWriter U8(byte value)
    {
        _bytes.WriteByte(value);
        return this;
    }

    public CitpWriter U16(ushort value)
    {
        Span<byte> b = stackalloc byte[2];
        BinaryPrimitives.WriteUInt16LittleEndian(b, value);
        _bytes.Write(b);
        return this;
    }

    public CitpWriter U32(uint value)
    {
        Span<byte> b = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(b, value);
        _bytes.Write(b);
        return this;
    }

    public CitpWriter Ucs1(string text)
    {
        _bytes.Write(Encoding.Latin1.GetBytes(text));
        _bytes.WriteByte(0);
        return this;
    }

    public CitpWriter U64(ulong value)
    {
        Span<byte> b = stackalloc byte[8];
        BinaryPrimitives.WriteUInt64LittleEndian(b, value);
        _bytes.Write(b);
        return this;
    }

    public CitpWriter F32(float value)
    {
        Span<byte> b = stackalloc byte[4];
        BinaryPrimitives.WriteSingleLittleEndian(b, value);
        _bytes.Write(b);
        return this;
    }

    public CitpWriter Utf8(string text)
    {
        _bytes.Write(Encoding.UTF8.GetBytes(text));
        _bytes.WriteByte(0);
        return this;
    }

    public CitpWriter Ucs2(string text)
    {
        _bytes.Write(Encoding.Unicode.GetBytes(text));
        _bytes.WriteByte(0);
        _bytes.WriteByte(0);
        return this;
    }

    public byte[] ToArray() => _bytes.ToArray();
}
