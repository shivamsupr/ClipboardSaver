import AppKit
import ServiceManagement
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var saveMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var shortcutRecorderWindow: ShortcutRecorderWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up notification delegate so notifications show while app is foreground
        UNUserNotificationCenter.current().delegate = self

        promptForAccessibilityIfNeeded()
        setupStatusItem()
        setupMenu()
        setupHotKey()
        setupServices()
    }

    // MARK: - Accessibility Permission

    private func promptForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // Allow notifications to display even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Status Bar Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipboardSaver") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "CB"
            }
        }
    }

    // MARK: - Menu Setup

    private func setupMenu() {
        menu = NSMenu()

        // Save Clipboard Image
        saveMenuItem = NSMenuItem(title: "Save Clipboard Image", action: #selector(saveClipboardImage), keyEquivalent: "")
        saveMenuItem.target = self
        updateSaveMenuItemShortcutDisplay()
        menu.addItem(saveMenuItem)

        // Change Shortcut
        let changeShortcutItem = NSMenuItem(title: "Change Shortcut...", action: #selector(openShortcutRecorder), keyEquivalent: "")
        changeShortcutItem.target = self
        menu.addItem(changeShortcutItem)

        menu.addItem(NSMenuItem.separator())

        // Default Save Location
        let saveLocationItem = NSMenuItem(title: "Default Save Location...", action: #selector(changeSaveLocation), keyEquivalent: "")
        saveLocationItem.target = self
        menu.addItem(saveLocationItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login
        launchAtLoginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem.target = self
        launchAtLoginMenuItem.state = PreferencesManager.shared.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginMenuItem)

        // About
        let aboutItem = NSMenuItem(title: "About ClipboardSaver", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit ClipboardSaver", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateSaveMenuItemShortcutDisplay() {
        if let shortcut = PreferencesManager.shared.shortcut {
            saveMenuItem.title = "Save Clipboard Image\t\(shortcut.displayString)"
        } else {
            saveMenuItem.title = "Save Clipboard Image\tNo shortcut set"
        }
    }

    // MARK: - Hot Key Setup

    private func setupHotKey() {
        HotKeyManager.shared.onHotKeyPressed = { [weak self] in
            self?.saveClipboardImage()
        }
        HotKeyManager.shared.registerFromPreferences()
    }

    // MARK: - Services (right-click context menu)

    private func setupServices() {
        // Register this object as the services provider
        NSApp.servicesProvider = self

        // Tell the system what pasteboard types we accept via Services
        NSApp.registerServicesMenuSendTypes(
            [.tiff, .png],
            returnTypes: []
        )

        // Force the system to refresh the Services menu
        NSUpdateDynamicServices()
    }

    /// Service handler — called when user picks "Save Clipboard Image" from right-click → Services
    @objc func handleSaveService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        // Check if the service pasteboard has image data
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        var foundImage = false

        for type in imageTypes {
            if let data = pboard.data(forType: type), let _ = NSImage(data: data) {
                foundImage = true
                break
            }
        }

        if foundImage {
            // The service pasteboard has an image — but ClipboardManager reads from
            // the general pasteboard. Copy the service data to general pasteboard first.
            // Actually, if the user right-clicked an image and chose the service,
            // the image context is on this pboard. Let's save directly from it.
            ClipboardManager.shared.saveFromPasteboard(pboard)
        } else {
            // Fall back to the general clipboard
            ClipboardManager.shared.saveClipboardImage()
        }
    }

    // MARK: - URL Scheme Handler (triggered by Finder extension)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "clipboardsaver" && url.host == "save" {
                saveClipboardImage()
                return
            }
        }
    }

    // MARK: - Menu Actions

    @objc private func saveClipboardImage() {
        ClipboardManager.shared.saveClipboardImage()
    }

    @objc private func openShortcutRecorder() {
        let window = ShortcutRecorderWindow()
        window.onShortcutRecorded = { [weak self] shortcut in
            PreferencesManager.shared.shortcut = shortcut
            if let s = shortcut {
                HotKeyManager.shared.register(shortcut: s)
            } else {
                HotKeyManager.shared.unregister()
            }
            self?.updateSaveMenuItemShortcutDisplay()
        }
        window.beginRecording()
        shortcutRecorderWindow = window // keep a strong reference
    }

    @objc private func changeSaveLocation() {
        let panel = NSOpenPanel()
        panel.title = "Choose Default Save Location"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: PreferencesManager.shared.saveDirectory)
        panel.level = .floating

        NSApp.activate(ignoringOtherApps: true)

        if panel.runModal() == .OK, let url = panel.url {
            PreferencesManager.shared.saveDirectory = url.path
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let newValue = !PreferencesManager.shared.launchAtLogin
        PreferencesManager.shared.launchAtLogin = newValue
        launchAtLoginMenuItem.state = newValue ? .on : .off

        if #available(macOS 13.0, *) {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("ClipboardSaver: Failed to update login item: \(error)")
            }
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "ClipboardSaver"
        alert.informativeText = "Version 1.0\n\nA simple menu bar utility to save clipboard images to disk.\n\nSet a global keyboard shortcut to quickly save any image from your clipboard.\n\nDefault shortcut: \u{2303}\u{2318}G"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        HotKeyManager.shared.unregister()
        NSApp.terminate(nil)
    }
}
