namespace TitanDeckHost.Service;

/// <summary>Where the Host keeps things on the PC.</summary>
public sealed class HostPaths
{
    /// <summary>C:\ProgramData\TitanDeck Host - pairing, uploaded rdpwrap.ini, the RDP Wrapper package.</summary>
    public string Data { get; }
    /// <summary>Public Documents\TitanDeck\To PC - files sent from the iPad.</summary>
    public string ToPC { get; }
    /// <summary>Public Documents\TitanDeck\To iPad - drop files here to send them to the iPad.</summary>
    public string ToIPad { get; }
    /// <summary>To iPad\Sent - files the iPad has picked up.</summary>
    public string ToIPadSent { get; }

    public string PairingFile => Path.Combine(Data, "pairing.json");
    public string UploadedIni => Path.Combine(Data, "rdpwrap-from-ipad.ini");
    /// <summary>The newest rdpwrap.ini at the time this Host version was built.</summary>
    public string BundledIni => Path.Combine(AppContext.BaseDirectory, "rdpwrap", "rdpwrap.ini");
    /// <summary>Folder the official RDP Wrapper release is unpacked into before installing.</summary>
    public string RdpWrapperPackage => Path.Combine(Data, "RDP Wrapper package");

    public HostPaths()
    {
        Data = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "TitanDeck Host");
        var documents = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments), "TitanDeck");
        ToPC = Path.Combine(documents, "To PC");
        ToIPad = Path.Combine(documents, "To iPad");
        ToIPadSent = Path.Combine(ToIPad, "Sent");
        foreach (var folder in new[] { Data, ToPC, ToIPad, ToIPadSent }) Directory.CreateDirectory(folder);
    }
}
