// Remote/RDPKeyboard.swift
import Foundation

/// A hardware keyboard (Magic Keyboard, Smart Keyboard, Bluetooth) on the
/// remote desktop: iPadOS reports each key by its USB HID usage, Windows
/// wants the PC/AT set-1 scan code for the same physical key (0x100 set for
/// the E0-prefixed "extended" keys, as FreeRDP expects). Keys are positional,
/// so a UK or other layout types correctly as long as Windows uses the same
/// layout. Pure, so it's tested.
enum RDPKeyboard {
    /// What the Command key does on the PC.
    enum CommandKey: String, Codable, CaseIterable, Hashable {
        /// Ctrl, so Cmd-C, Cmd-V, Cmd-Z, Cmd-S work as on a Mac.
        case control
        /// The Windows key.
        case windows

        var title: String {
            switch self {
            case .control: "Ctrl"
            case .windows: "Windows key"
            }
        }
    }

    /// Held this long before a key starts repeating, then every `repeatInterval`.
    /// Windows doesn't repeat keys from a remote desktop itself.
    static let repeatDelay: TimeInterval = 0.45
    static let repeatInterval: TimeInterval = 1.0 / 30

    private static let extended: UInt32 = 0x100

    /// The scan code for a HID usage, or nil for a key Windows has no use for
    /// (or that iPadOS keeps for itself).
    static func scancode(hidUsage usage: Int, command: CommandKey = .control) -> UInt32? {
        switch usage {
        case 0xE3: return command == .windows ? extended | 0x5B : 0x1D             // left Command
        case 0xE7: return command == .windows ? extended | 0x5C : extended | 0x1D  // right Command
        default: return table[usage]
        }
    }

    /// Shift, Ctrl, Option/Alt, Command: they don't repeat.
    static func isModifier(hidUsage usage: Int) -> Bool {
        (0xE0...0xE7).contains(usage) || usage == 0x39   // and Caps Lock
    }

    private static let table: [Int: UInt32] = {
        var t: [Int: UInt32] = [:]
        // a-z (HID 0x04-0x1D)
        let letters: [UInt32] = [0x1E, 0x30, 0x2E, 0x20, 0x12, 0x21, 0x22, 0x23, 0x17, 0x24, 0x25, 0x26, 0x32,
                                 0x31, 0x18, 0x19, 0x10, 0x13, 0x1F, 0x14, 0x16, 0x2F, 0x11, 0x2D, 0x15, 0x2C]
        for (i, code) in letters.enumerated() { t[0x04 + i] = code }
        // 1-9, 0 (HID 0x1E-0x27)
        for i in 0..<10 { t[0x1E + i] = UInt32(0x02 + i) }
        let main: [Int: UInt32] = [
            0x28: 0x1C, 0x29: 0x01, 0x2A: 0x0E, 0x2B: 0x0F, 0x2C: 0x39,   // Return, Esc, Backspace, Tab, Space
            0x2D: 0x0C, 0x2E: 0x0D, 0x2F: 0x1A, 0x30: 0x1B, 0x31: 0x2B,   // - = [ ] \
            0x32: 0x2B, 0x33: 0x27, 0x34: 0x28, 0x35: 0x29,               // non-US #, ; ' `
            0x36: 0x33, 0x37: 0x34, 0x38: 0x35, 0x39: 0x3A,               // , . / Caps Lock
            0x64: 0x56,                                                   // non-US \ (left of Z on ISO)
            // Modifiers (Command is above)
            0xE0: 0x1D, 0xE1: 0x2A, 0xE2: 0x38,                           // left Ctrl, Shift, Option (Alt)
            0xE4: extended | 0x1D, 0xE5: 0x36, 0xE6: extended | 0x38,     // right Ctrl, Shift, Option (AltGr)
            // Navigation
            0x46: extended | 0x37, 0x47: 0x46,                            // Print Screen, Scroll Lock
            0x49: extended | 0x52, 0x4A: extended | 0x47, 0x4B: extended | 0x49,   // Insert, Home, Page Up
            0x4C: extended | 0x53, 0x4D: extended | 0x4F, 0x4E: extended | 0x51,   // Delete, End, Page Down
            0x4F: extended | 0x4D, 0x50: extended | 0x4B,                 // Right, Left
            0x51: extended | 0x50, 0x52: extended | 0x48,                 // Down, Up
            0x65: extended | 0x5D,                                        // Menu (application) key
            // Keypad
            0x53: 0x45, 0x54: extended | 0x35, 0x55: 0x37, 0x56: 0x4A, 0x57: 0x4E, 0x58: extended | 0x1C,
            0x59: 0x4F, 0x5A: 0x50, 0x5B: 0x51, 0x5C: 0x4B, 0x5D: 0x4C, 0x5E: 0x4D,
            0x5F: 0x47, 0x60: 0x48, 0x61: 0x49, 0x62: 0x52, 0x63: 0x53, 0x67: 0x59,
            // Japanese keys
            0x87: 0x73, 0x88: 0x70, 0x89: 0x7D, 0x8A: 0x79, 0x8B: 0x7B,
        ]
        t.merge(main) { _, new in new }
        // F1-F12 (HID 0x3A-0x45), F13-F24 (0x68-0x73)
        let f1to12: [UInt32] = [0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40, 0x41, 0x42, 0x43, 0x44, 0x57, 0x58]
        for (i, code) in f1to12.enumerated() { t[0x3A + i] = code }
        let f13to24: [UInt32] = [0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x76]
        for (i, code) in f13to24.enumerated() { t[0x68 + i] = code }
        return t
    }()
}

/// The keys held down on the PC, so none is left stuck when the view loses
/// the keyboard (app to the background, Settings opened, disconnect).
struct HeldKeys {
    private(set) var scancodes: [Int: UInt32] = [:]

    /// Records a key going down; false if it was already down (iPadOS repeats nothing itself).
    mutating func press(hidUsage: Int, scancode: UInt32) -> Bool {
        scancodes.updateValue(scancode, forKey: hidUsage) == nil
    }

    /// The scan code to release, if that key was down.
    mutating func release(hidUsage: Int) -> UInt32? {
        scancodes.removeValue(forKey: hidUsage)
    }

    /// Everything still down, to release, and forgets them.
    mutating func releaseAll() -> [UInt32] {
        defer { scancodes = [:] }
        return Array(scancodes.values)
    }
}
