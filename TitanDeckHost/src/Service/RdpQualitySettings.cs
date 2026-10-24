using System.Runtime.Versioning;
using Microsoft.Win32;
using TitanDeckHost.Core.Rdp;

namespace TitanDeckHost.Service;

/// <summary>Reads and writes the remote desktop picture settings in the
/// registry (policies + the frame-rate cap). Changes apply to the next
/// connection, so the iPad reconnects after setting them.</summary>
[SupportedOSPlatform("windows")]
public static class RdpQualitySettings
{
    public static RdpServerQuality Read() => RdpServerQuality.FromRegistry(
        WindowsProbe.ReadInt(RdpServerQuality.PolicyKey, "ImageQuality"),
        WindowsProbe.ReadInt(RdpServerQuality.PolicyKey, "GraphicsProfile"),
        WindowsProbe.ReadInt(RdpServerQuality.WinStationsKey, "DWMFRAMEINTERVAL"));

    public static RdpServerQuality Apply(RdpServerQuality quality)
    {
        foreach (var write in quality.RegistryWrites())
        {
            using var key = Registry.LocalMachine.CreateSubKey(write.Key, writable: true);
            if (write.Value is { } value) key.SetValue(write.Name, value, RegistryValueKind.DWord);
            else key.DeleteValue(write.Name, throwOnMissingValue: false);
        }
        return Read();
    }
}
