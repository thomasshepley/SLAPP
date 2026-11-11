using System.Net.Http;
using System.Net.Http.Json;
using System.Runtime.InteropServices;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.App;

/// <summary>
/// Types the deck's keypad on this PC for Titan, so the keys land on the
/// desk's own command line. Runs in the window app because the service can't
/// type on the desktop: it waits on the service for lines, types each one
/// whole with SendInput as real scan codes, and tells the service what
/// happened (Host 0.19), so the deck hears "typed" only when it was. A line
/// isn't typed at all unless Titan is the window in front (the keys would go
/// to whatever was), and it stops at the first key Windows refuses. Only
/// <see cref="DeskKeys"/> keys are ever typed.
/// </summary>
internal static class DeskTyper
{
    public static async Task Run(CancellationToken stop)
    {
        ReleaseModifiers();
        // Never by way of Windows' proxy settings (see LocalHttp): a proxy
        // search holding this up for a few seconds is a keypad line refused
        // as too old.
        using var http = Core.Net.LocalHttp.Client(TimeSpan.FromSeconds(30), HostClient.Local);
        while (!stop.IsCancellationRequested)
        {
            try
            {
                var jobs = await http.GetFromJsonAsync<DeskTypeJob[]>("desk/jobs/wait", stop) ?? [];
                foreach (var job in jobs)
                {
                    var problem = await Task.Run(() => TypeLine(job.Keys), stop);   // off the window's thread
                    await http.PostAsJsonAsync("desk/jobs/done", new DeskJobDoneRequest(job.Id, problem is null, problem), stop);
                }
            }
            catch (OperationCanceledException) when (stop.IsCancellationRequested)
            {
                return;
            }
            catch (Exception)
            {
                // Service stopped or restarting: try again shortly.
                try { await Task.Delay(TimeSpan.FromSeconds(2), stop); }
                catch (OperationCanceledException) { return; }
            }
        }
    }

    /// <summary>Types a whole line; null when every key went in, else why it stopped.</summary>
    private static string? TypeLine(IReadOnlyList<string> keys)
    {
        if (ForegroundProblem() is { } elsewhere) return elsewhere;
        for (var i = 0; i < keys.Count; i++)
        {
            if (Type(keys[i])) continue;
            return i == 0
                ? "Windows didn't let TitanDeck Host type on Titan. If Titan runs as administrator, TitanDeck Host must too."
                : $"Windows stopped the typing after {i} of {keys.Count} keys, so the line is only part typed on the desk.";
        }
        return null;
    }

    /// <summary>
    /// Why the keys wouldn't reach Titan: null when the window in front is
    /// Titan's (or can't be told, as before 0.19). Typed keys go to whichever
    /// window is in front.
    /// </summary>
    private static string? ForegroundProblem()
    {
        try
        {
            var window = GetForegroundWindow();
            if (window == IntPtr.Zero) return null;
            GetWindowThreadProcessId(window, out var id);
            if (id == 0) return null;
            using var process = System.Diagnostics.Process.GetProcessById((int)id);
            var name = process.ProcessName;
            return DeskKeys.IsTitanProcess(name)
                ? null
                : $"Titan isn't the window in front on the PC ({name} is), so nothing was typed. Tap Titan's screen once, then press the key again.";
        }
        catch (Exception)
        {
            return null;   // the process went, or Windows wouldn't say: type as before
        }
    }

    /// One key, as a hand would press it: down, held, up, then a gap, and a
    /// longer one after Enter so Titan has taken the line before the next key.
    /// 0.10-0.16 held keys 20 ms with a 15 ms gap, and in a fast run (a faded
    /// flash's "@ 64 Enter @ 48 Enter...") Titan missed the odd "@" or Enter,
    /// which turned a level into a fixture number. No modifiers are ever held
    /// (see <see cref="DeskKeys"/>). False when Windows refused the press.
    private static bool Type(string name)
    {
        if (!DeskKeys.All.TryGetValue(name, out var key)) return false;
        var down = Send(Scan(key.Scancode, key.Extended, up: false));
        Thread.Sleep(HoldMs);
        // The key always comes back up, even if Windows refused the press.
        Send(Scan(key.Scancode, key.Extended, up: true));
        Thread.Sleep(name == "enter" ? AfterEnterMs : GapMs);
        return down;
    }

    private const int HoldMs = 35;
    private const int GapMs = 30;
    private const int AfterEnterMs = 90;

    /// <summary>
    /// Lets go of Alt, Ctrl and Shift (both sides) in case an older Host left
    /// one down: 0.11 typed Alt+C for Clear, and afterwards none of the desk's
    /// own buttons worked. A key-up for a key that isn't down does nothing.
    /// </summary>
    public static void ReleaseModifiers()
    {
        (ushort Scan, bool Extended)[] modifiers = [(0x38, false), (0x38, true), (0x1D, false), (0x1D, true), (0x2A, false), (0x36, false)];
        foreach (var (scan, extended) in modifiers) Send(Scan(scan, extended, up: true));
    }

    /// <summary>False when Windows didn't take it (it blocks typing into a window with more rights).</summary>
    private static bool Send(Input input) => SendInput(1, [input], Marshal.SizeOf<Input>()) == 1;

    private static Input Scan(ushort scancode, bool extended, bool up) => new()
    {
        Type = InputKeyboard,
        Union = new InputUnion
        {
            Keyboard = new KeyboardInput
            {
                Scan = scancode,
                Flags = KeyeventfScancode | (extended ? KeyeventfExtendedKey : 0) | (up ? KeyeventfKeyUp : 0),
            },
        },
    };

    private const uint InputKeyboard = 1;
    private const uint KeyeventfExtendedKey = 0x0001;
    private const uint KeyeventfKeyUp = 0x0002;
    private const uint KeyeventfScancode = 0x0008;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, Input[] inputs, int size);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [StructLayout(LayoutKind.Sequential)]
    private struct Input
    {
        public uint Type;
        public InputUnion Union;
    }

    // The mouse member is there so the union is its real (largest) size.
    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MouseInput Mouse;
        [FieldOffset(0)] public KeyboardInput Keyboard;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MouseInput
    {
        public int X;
        public int Y;
        public uint Data;
        public uint Flags;
        public uint Time;
        public IntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardInput
    {
        public ushort Vk;
        public ushort Scan;
        public uint Flags;
        public uint Time;
        public IntPtr ExtraInfo;
    }
}
