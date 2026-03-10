import Carbon
import AppKit

class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x434C5053), id: 1) // "CLPS"

    var onHotKeyPressed: (() -> Void)?

    private init() {}

    func registerFromPreferences() {
        if let shortcut = PreferencesManager.shared.shortcut {
            register(shortcut: shortcut)
        }
    }

    func register(shortcut: KeyboardShortcut) {
        unregister()

        // Install event handler if not already installed
        if eventHandler == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

            let handlerBlock: EventHandlerUPP = { _, event, _ -> OSStatus in
                HotKeyManager.shared.onHotKeyPressed?()
                return noErr
            }

            InstallEventHandler(
                GetApplicationEventTarget(),
                handlerBlock,
                1,
                &eventType,
                nil,
                &eventHandler
            )
        }

        // Convert Carbon modifiers to the format RegisterEventHotKey expects
        var carbonMods: UInt32 = 0
        if shortcut.modifiers & UInt32(cmdKey) != 0 { carbonMods |= UInt32(cmdKey) }
        if shortcut.modifiers & UInt32(optionKey) != 0 { carbonMods |= UInt32(optionKey) }
        if shortcut.modifiers & UInt32(controlKey) != 0 { carbonMods |= UInt32(controlKey) }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { carbonMods |= UInt32(shiftKey) }

        let myHotKeyID = hotKeyID
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            carbonMods,
            myHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            NSLog("ClipboardSaver: Failed to register hotkey, status: \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
