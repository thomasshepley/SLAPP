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

    /// One key, as a hand would press it: each event on its own with a short
    /// gap, and Alt held down before (and let go after) its key. Sent all at
    /// once, Titan saw the C of Alt+C (Clear) without the Alt.
    private static void Type(string name)
    {
        if (!DeskKeys.All.TryGetValue(name, out var key)) return;
        const ushort alt = 0x38;
        if (key.Alt)
        {
            Send(Scan(alt, extended: false, up: false));
            Thread.Sleep(40);
        }
        Send(Scan(key.Scancode, key.Extended, up: false));
        Thread.Sleep(20);
        Send(Scan(key.Scancode, key.Extended, up: true));
        if (key.Alt)
        {
            Thread.Sleep(40);
            Send(Scan(alt, extended: false, up: true));
        }
        Thread.Sleep(15);
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
