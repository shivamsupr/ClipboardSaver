import AppKit
import Carbon

class ShortcutRecorderWindow: NSWindow {
    private var instructionLabel: NSTextField!
    private var shortcutLabel: NSTextField!
    private var clearButton: NSButton!
    private var doneButton: NSButton!
    private var isRecording = false
    private var localMonitor: Any?
    private var recordedShortcut: KeyboardShortcut?

    var onShortcutRecorded: ((KeyboardShortcut?) -> Void)?

    init() {
        let windowRect = NSRect(x: 0, y: 0, width: 380, height: 180)
        super.init(
            contentRect: windowRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Record Shortcut"
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.center()

        setupUI()
    }

    private func setupUI() {
        guard let contentView = self.contentView else { return }
        contentView.wantsLayer = true

        // Instruction label
        instructionLabel = NSTextField(labelWithString: "Press your desired keyboard shortcut")
        instructionLabel.font = NSFont.systemFont(ofSize: 13)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.alignment = .center
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(instructionLabel)

        // Shortcut display field
        shortcutLabel = NSTextField(string: "")
        shortcutLabel.isEditable = false
        shortcutLabel.isBordered = true
        shortcutLabel.bezelStyle = .roundedBezel
        shortcutLabel.alignment = .center
        shortcutLabel.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .medium)
        shortcutLabel.placeholderString = "Press your shortcut..."
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shortcutLabel)

        // Buttons
        clearButton = NSButton(title: "Clear", target: self, action: #selector(clearShortcut))
        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(clearButton)

        doneButton = NSButton(title: "Done", target: self, action: #selector(doneRecording))
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(doneButton)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            instructionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),

            shortcutLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 16),
            shortcutLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shortcutLabel.widthAnchor.constraint(equalToConstant: 260),
            shortcutLabel.heightAnchor.constraint(equalToConstant: 36),

            doneButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            doneButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            doneButton.widthAnchor.constraint(equalToConstant: 80),

            clearButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            clearButton.trailingAnchor.constraint(equalTo: doneButton.leadingAnchor, constant: -12),
            clearButton.widthAnchor.constraint(equalToConstant: 80),
        ])

        // Load existing shortcut
        if let existing = PreferencesManager.shared.shortcut {
            recordedShortcut = existing
            shortcutLabel.stringValue = existing.displayString
        }
    }

    func beginRecording() {
        isRecording = true

        // Temporarily unregister the global hotkey so it doesn't fire during recording
        HotKeyManager.shared.unregister()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil // consume the event
        }

        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }

        // Require at least one modifier key (Cmd, Option, Control, or Shift)
        let modFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modFlags.isEmpty else { return }

        // Don't accept modifier-only presses
        let keyCode = event.keyCode
        let modifierOnlyKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63] // modifier key codes
        guard !modifierOnlyKeys.contains(keyCode) else { return }

        // Convert NSEvent modifier flags to Carbon modifier flags
        var carbonMods: UInt32 = 0
        if modFlags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if modFlags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if modFlags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if modFlags.contains(.shift) { carbonMods |= UInt32(shiftKey) }

        let shortcut = KeyboardShortcut(keyCode: UInt32(keyCode), modifiers: carbonMods)
        recordedShortcut = shortcut
        shortcutLabel.stringValue = shortcut.displayString
    }

    @objc private func clearShortcut() {
        recordedShortcut = nil
        shortcutLabel.stringValue = ""
        shortcutLabel.placeholderString = "Press your shortcut..."
    }

    @objc private func doneRecording() {
        stopRecording()
        onShortcutRecorded?(recordedShortcut)
        close()
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    override func close() {
        stopRecording()
        // Re-register shortcut from preferences (will use whatever was saved by the delegate)
        HotKeyManager.shared.registerFromPreferences()
        super.close()
    }
}
