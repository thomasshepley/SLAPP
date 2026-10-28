using System.Net.Http;
using System.Net.Http.Json;
using System.Runtime.InteropServices;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.App;

/// <summary>
/// Types the deck's keypad on this PC for Titan, which captures the keyboard
/// while it runs, so the keys land on the desk's own command line. Runs in the
/// window app because the service can't type on the desktop: it waits on the
/// service for keys and sends them with SendInput as real scan codes. Only
/// <see cref="DeskKeys"/> keys are ever typed.
/// </summary>
internal static class DeskTyper
{
    public static async Task Run(CancellationToken stop)
    {
        ReleaseModifiers();
        using var http = new HttpClient
        {
            BaseAddress = new Uri($"http://127.0.0.1:{Protocol.LocalPort}/local/"),
            Timeout = TimeSpan.FromSeconds(30),
        };
        while (!stop.IsCancellationRequested)
        {
            try
            {
                var keys = await http.GetFromJsonAsync<string[]>("desk/keys/wait", stop) ?? [];
                await Task.Run(() => { foreach (var key in keys) Type(key); }, stop);   // off the window's thread
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

    /// One key, as a hand would press it: down and up as separate events with
    /// a short gap. Titan's Alt shortcuts (<see cref="DeskKeys.Shortcuts"/>)
    /// go as one SendInput burst, so nothing can come between Alt going down
    /// and coming up, and every modifier is let go again after it.
    private static void Type(string name)
    {
        if (DeskKeys.Shortcuts.TryGetValue(name, out var shortcut))
        {
            Input[] burst =
            [
                Scan(shortcut.Modifier.Scancode, shortcut.Modifier.Extended, up: false),
                Scan(shortcut.Key.Scancode, shortcut.Key.Extended, up: false),
                Scan(shortcut.Key.Scancode, shortcut.Key.Extended, up: true),
                Scan(shortcut.Modifier.Scancode, shortcut.Modifier.Extended, up: true),
            ];
            SendInput((uint)burst.Length, burst, Marshal.SizeOf<Input>());
            Thread.Sleep(30);
            ReleaseModifiers();
            return;
        }
        if (!DeskKeys.All.TryGetValue(name, out var key)) return;
        Send(Scan(key.Scancode, key.Extended, up: false));
        Thread.Sleep(20);
        Send(Scan(key.Scancode, key.Extended, up: true));
        Thread.Sleep(15);
    }

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

    private static void Send(Input input) => SendInput(1, [input], Marshal.SizeOf<Input>());

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
