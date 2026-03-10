import Foundation
import Carbon

// MARK: - Shortcut Model

struct KeyboardShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32  // Carbon modifier flags

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("^") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("\u{2325}") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("\u{21E7}") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("\u{2318}") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
}

func keyCodeToString(_ keyCode: UInt32) -> String {
    let mapping: [UInt32: String] = [
        0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
        0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
        0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
        0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
        0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
        0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
        0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
        0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
        0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
        0x2F: ".", 0x30: "Tab", 0x31: "Space", 0x32: "`",
        0x33: "Delete", 0x24: "Return",
        0x35: "Esc",
        0x60: "F5", 0x61: "F6", 0x62: "F7", 0x63: "F3",
        0x64: "F8", 0x65: "F9", 0x67: "F11", 0x69: "F13",
        0x6B: "F14", 0x6D: "F10", 0x6F: "F12", 0x71: "F15",
        0x76: "F4", 0x78: "F2", 0x7A: "F1",
        0x7B: "\u{2190}", 0x7C: "\u{2192}", 0x7D: "\u{2193}", 0x7E: "\u{2191}",
    ]
    return mapping[keyCode] ?? "Key(\(keyCode))"
}

// MARK: - Preferences Manager

class PreferencesManager {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
        static let hasShortcut = "hasShortcut"
        static let saveDirectory = "saveDirectory"
        static let launchAtLogin = "launchAtLogin"
    }

    // Default shortcut: Cmd+Ctrl+G (keyCode 5 = G, cmdKey|controlKey = 0x100|0x1000 = 4352)
    static let defaultShortcut = KeyboardShortcut(keyCode: 5, modifiers: UInt32(cmdKey) | UInt32(controlKey))

    private init() {
        // Register defaults
        let defaultSaveDir = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads/clipboard-images")
        defaults.register(defaults: [
            Keys.hasShortcut: true,
            Keys.shortcutKeyCode: Int(PreferencesManager.defaultShortcut.keyCode),
            Keys.shortcutModifiers: Int(PreferencesManager.defaultShortcut.modifiers),
            Keys.saveDirectory: defaultSaveDir,
            Keys.launchAtLogin: false,
        ])
    }

    // MARK: - Keyboard Shortcut

    var shortcut: KeyboardShortcut? {
        get {
            guard defaults.bool(forKey: Keys.hasShortcut) else { return nil }
            let keyCode = UInt32(defaults.integer(forKey: Keys.shortcutKeyCode))
            let modifiers = UInt32(defaults.integer(forKey: Keys.shortcutModifiers))
            return KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
        }
        set {
            if let s = newValue {
                defaults.set(true, forKey: Keys.hasShortcut)
                defaults.set(Int(s.keyCode), forKey: Keys.shortcutKeyCode)
                defaults.set(Int(s.modifiers), forKey: Keys.shortcutModifiers)
            } else {
                defaults.set(false, forKey: Keys.hasShortcut)
                defaults.removeObject(forKey: Keys.shortcutKeyCode)
                defaults.removeObject(forKey: Keys.shortcutModifiers)
            }
        }
    }

    // MARK: - Save Directory

    var saveDirectory: String {
        get { defaults.string(forKey: Keys.saveDirectory) ?? (NSHomeDirectory() as NSString).appendingPathComponent("Downloads/clipboard-images") }
        set { defaults.set(newValue, forKey: Keys.saveDirectory) }
    }

    // MARK: - Launch at Login

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }
}
