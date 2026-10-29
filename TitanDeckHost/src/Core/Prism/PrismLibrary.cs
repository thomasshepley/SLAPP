using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Xml;
using System.Xml.Linq;

namespace TitanDeckHost.Core.Prism;

/// <summary>A clip in a Prism bank: its place (from 0), the number in its name if it has one, and its file.</summary>
public sealed record PrismClip(int Index, int? Number, string Name, string? Path);

/// <summary>A Prism bank (Titan's Folder) and its clips (Titan's File), in Prism's order.</summary>
public sealed record PrismBank(int Index, int? Number, string Name, IReadOnlyList<PrismClip> Clips);

/// <summary>
/// Reads which clips Prism has in which bank (TitanDeck's FX tab, Host 0.18).
/// Prism's own files aren't documented, so this reads any JSON or XML file
/// and looks for lists whose entries point at video or image files: each
/// innermost such list is a bank, named by the nearest thing above it with a
/// name. Lists under something called "bank" win over others (a project's
/// list of every media file isn't a bank). Elements that point at a media
/// entry by id are followed to its file. A plain folder of media works too:
/// each subfolder is a bank (Ai-style "001 Fire" names give the numbers).
/// Pure (no I/O), so it's tested.
/// </summary>
public static class PrismLibrary
{
    public static readonly IReadOnlySet<string> MediaExtensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        ".mov", ".mp4", ".m4v", ".avi", ".mkv", ".webm", ".mpg", ".mpeg", ".wmv", ".mxf", ".aim", ".hap", ".dxv",
        ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tif", ".tiff", ".tga", ".webp",
    };

    private static readonly string[] NameKeys = ["name", "title", "label", "displayName", "displayname", "caption"];
    private static readonly string[] OrderKeys = ["index", "slot", "position", "order", "number", "id"];

    public static bool IsMedia(string? path) =>
        !string.IsNullOrWhiteSpace(path) && path.Length < 1024 && path.IndexOfAny(['\n', '\r', '<', '>', '"']) < 0
        && MediaExtensions.Contains(System.IO.Path.GetExtension(path.Trim()));

    /// <summary>The banks in a JSON or XML file's text; null if it's neither.</summary>
    public static IReadOnlyList<PrismBank>? Parse(string text)
    {
        var root = Tree(text);
        return root is null ? null : Banks(root);
    }

    /// <summary>JSON as it is, XML as objects (attributes, then child elements as lists by name, text as "_text").</summary>
    public static JsonNode? Tree(string text)
    {
        var trimmed = text.TrimStart('﻿', ' ', '\t', '\r', '\n');
        if (trimmed.StartsWith('{') || trimmed.StartsWith('['))
        {
            try { return JsonNode.Parse(trimmed, documentOptions: new JsonDocumentOptions { AllowTrailingCommas = true, CommentHandling = JsonCommentHandling.Skip }); }
            catch (JsonException) { return null; }
        }
        if (trimmed.StartsWith('<'))
        {
            try
            {
                var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null };
                using var reader = XmlReader.Create(new StringReader(trimmed), settings);
                var root = XDocument.Load(reader).Root;
                return root is null ? null : new JsonObject { [root.Name.LocalName] = new JsonArray(FromXml(root)) };
            }
            catch (XmlException) { return null; }
        }
        return null;
    }

    private static JsonObject FromXml(XElement element)
    {
        var obj = new JsonObject();
        foreach (var attribute in element.Attributes())
            if (!attribute.IsNamespaceDeclaration) obj[attribute.Name.LocalName] = attribute.Value;
        foreach (var group in element.Elements().GroupBy(e => e.Name.LocalName))
        {
            var key = obj.ContainsKey(group.Key) ? group.Key + "_" : group.Key;
            obj[key] = new JsonArray(group.Select(e => (JsonNode)FromXml(e)).ToArray());
        }
        if (!element.HasElements && !string.IsNullOrWhiteSpace(element.Value)) obj["_text"] = element.Value.Trim();
        return obj;
    }

    private sealed record Candidate(JsonArray List, string KeyPath, string Name, bool UnderBank);

    /// <summary>The banks in a parsed tree, in document order.</summary>
    public static IReadOnlyList<PrismBank> Banks(JsonNode root)
    {
        var ids = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        CollectIds(root, ids);
        var found = new List<Candidate>();
        Walk(root, "", [], ids, found, false);
        var banks = found.Any(c => c.UnderBank) ? found.Where(c => c.UnderBank).ToList() : found;
        return banks.Select((bank, i) =>
        {
            var clips = Clips(bank.List, ids);
            return new PrismBank(i, null, bank.Name.Length > 0 ? bank.Name : $"Bank {i + 1}", clips);
        }).Where(b => b.Clips.Count > 0).Select((b, i) => b with { Index = i }).ToList();
    }

    /// <summary>
    /// Walks the tree; true if a bank was found at or under this node. Inside
    /// a list of media entries, a one-entry list is the entry's own file (as
    /// XML has it), not a bank.
    /// </summary>
    private static bool Walk(JsonNode? node, string keyPath, List<JsonObject> owners, Dictionary<string, string> ids,
                             List<Candidate> found, bool inMediaList)
    {
        switch (node)
        {
            case JsonObject obj:
            {
                owners.Add(obj);
                var any = false;
                foreach (var (key, value) in obj.ToList())
                    any |= Walk(value, keyPath + "/" + key, owners, ids, found, inMediaList);
                owners.RemoveAt(owners.Count - 1);
                return any;
            }
            case JsonArray list:
            {
                var objects = list.OfType<JsonObject>().ToList();
                var withMedia = objects.Count(o => MediaOf(o, ids) is not null);
                // Inner lists first: a bank is the innermost list of media.
                var insertAt = found.Count;
                var inner = false;
                foreach (var item in list)
                    inner |= Walk(item, keyPath, owners, ids, found, withMedia >= 2 && withMedia * 2 >= objects.Count);
                if (inner) return true;
                if (withMedia == 0 || withMedia * 2 < objects.Count) return false;
                if (inMediaList && list.Count == 1) return false;
                var name = owners.AsEnumerable().Reverse().Select(o => NameOf(o)).FirstOrDefault(n => n is not null) ?? "";
                var underBank = keyPath.Contains("bank", StringComparison.OrdinalIgnoreCase)
                                || keyPath.Contains("playlist", StringComparison.OrdinalIgnoreCase);
                found.Insert(insertAt, new Candidate(list, keyPath, name, underBank));
                return true;
            }
            default:
                return false;
        }
    }

    private static List<PrismClip> Clips(JsonArray list, Dictionary<string, string> ids)
    {
        var items = list.OfType<JsonObject>().Select(o => (Item: o, Path: MediaOf(o, ids), Order: OrderOf(o))).Where(x => x.Path is not null).ToList();
        if (items.All(x => x.Order is not null) && items.Select(x => x.Order).Distinct().Count() == items.Count)
            items = items.OrderBy(x => x.Order).ToList();
        return items.Select((x, i) => new PrismClip(i, null, NameOf(x.Item) ?? Stem(x.Path!), x.Path!.Trim())).ToList();
    }

    /// <summary>The media file an element points at: a path in it (or a single nested object), or a media entry's id.</summary>
    private static string? MediaOf(JsonObject obj, Dictionary<string, string> ids, int depth = 3)
    {
        foreach (var (_, value) in obj)
            if (Text(value) is { } text && IsMedia(text)) return text;
        foreach (var (key, value) in obj)
            if (Text(value) is { } text && key.Contains("id", StringComparison.OrdinalIgnoreCase) && ids.TryGetValue(text, out var path))
                return path;
        if (depth == 0) return null;
        foreach (var (_, value) in obj)
        {
            var inner = value switch
            {
                JsonObject o => o,
                JsonArray { Count: 1 } a => a[0] as JsonObject,
                _ => null,
            };
            if (inner is not null && MediaOf(inner, ids, depth - 1) is { } path) return path;
        }
        return null;
    }

    /// <summary>Every object with a media file and an id-like key: id to file.</summary>
    private static void CollectIds(JsonNode? node, Dictionary<string, string> ids)
    {
        switch (node)
        {
            case JsonObject obj:
                var path = obj.Select(p => Text(p.Value)).FirstOrDefault(IsMedia);
                if (path is not null)
                    foreach (var (key, value) in obj)
                        if (key.Contains("id", StringComparison.OrdinalIgnoreCase) && Text(value) is { Length: > 0 } id && !IsMedia(id))
                            ids.TryAdd(id, path);
                foreach (var (_, value) in obj) CollectIds(value, ids);
                break;
            case JsonArray list:
                foreach (var item in list) CollectIds(item, ids);
                break;
        }
    }

    /// <summary>A plain value as text: a string or number, an XML element's text, or a one-entry list of one.</summary>
    private static string? Text(JsonNode? node) => node switch
    {
        JsonValue v when v.TryGetValue(out string? s) => s,
        JsonValue v when v.TryGetValue(out long n) => n.ToString(CultureInfo.InvariantCulture),
        JsonObject o when o.Count == 1 && o.ContainsKey("_text") => Text(o["_text"]),
        JsonArray { Count: 1 } a => Text(a[0]),
        _ => null,
    };

    private static string? NameOf(JsonObject obj)
    {
        foreach (var key in NameKeys)
            if (obj.FirstOrDefault(p => p.Key.Equals(key, StringComparison.OrdinalIgnoreCase)).Value is { } value
                && Text(value) is { } text && !string.IsNullOrWhiteSpace(text) && !IsMedia(text))
                return text.Trim();
        return null;
    }

    private static double? OrderOf(JsonObject obj)
    {
        foreach (var key in OrderKeys)
            if (obj.FirstOrDefault(p => p.Key.Equals(key, StringComparison.OrdinalIgnoreCase)).Value is { } value
                && Text(value) is { } text && double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var n))
                return n;
        return null;
    }

    private static string Stem(string path) =>
        System.IO.Path.GetFileNameWithoutExtension(path.Trim().Replace('\\', '/').Split('/').Last());

    /// <summary>
    /// A folder of media as banks: files in each subfolder (relative paths,
    /// either slash) are a bank, files at the top a bank of their own. In name
    /// order, and when every name starts with a number ("001 Fire") that's its number.
    /// </summary>
    public static IReadOnlyList<PrismBank> FromFolder(IEnumerable<string> relativeFiles)
    {
        var groups = relativeFiles
            .Select(f => f.Replace('\\', '/').Trim('/'))
            .Where(IsMedia)
            .GroupBy(f => f.Contains('/') ? f[..f.IndexOf('/')] : "")
            .OrderBy(g => Leading(g.Key) ?? int.MaxValue).ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
            .ToList();
        var bankNumbers = groups.All(g => Leading(g.Key) is not null);
        return groups.Select((group, i) =>
        {
            var files = group.OrderBy(f => Leading(FileName(f)) ?? int.MaxValue).ThenBy(f => f, StringComparer.OrdinalIgnoreCase).ToList();
            var clipNumbers = files.All(f => Leading(FileName(f)) is not null);
            var clips = files.Select((f, j) => new PrismClip(j, clipNumbers ? Leading(FileName(f)) : null, Stem(f), f)).ToList();
            var name = group.Key.Length == 0 ? "(top folder)" : group.Key;
            return new PrismBank(i, bankNumbers ? Leading(group.Key) : null, name, clips);
        }).ToList();
    }

    private static string FileName(string path) => path.Split('/').Last();

    /// <summary>The number a name starts with ("001 Fire" is 1), if it does.</summary>
    public static int? Leading(string name)
    {
        var digits = new string(name.TakeWhile(char.IsAsciiDigit).ToArray());
        return digits.Length is > 0 and < 7 ? int.Parse(digits, CultureInfo.InvariantCulture) : null;
    }
}
