namespace TitanDeckHost.Core.Net;

/// <summary>Windows Firewall's LocalPorts format: "3389", "3389,4430", "1000-2000" or "*".</summary>
public static class PortList
{
    public static bool Contains(string? ports, int port)
    {
        if (string.IsNullOrWhiteSpace(ports)) return false;
        foreach (var part in ports.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
        {
            if (part == "*") return true;
            var range = part.Split('-', StringSplitOptions.TrimEntries);
            if (range.Length == 2 && int.TryParse(range[0], out var low) && int.TryParse(range[1], out var high)
                && port >= low && port <= high) return true;
            if (int.TryParse(part, out var single) && single == port) return true;
        }
        return false;
    }
}
