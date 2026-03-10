import FinderSync

class FinderSyncExtension: FIFinderSync {
    override init() {
        super.init()
        // Monitor home directory so context menu appears in all typical Finder locations
        let home = FileManager.default.homeDirectoryForCurrentUser
        FIFinderSyncController.default().directoryURLs = [
            home,
            URL(fileURLWithPath: "/Volumes"),
            URL(fileURLWithPath: "/tmp"),
            URL(fileURLWithPath: "/Applications")
        ]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let item = NSMenuItem(
            title: "Save Clipboard Image",
            action: #selector(saveClipboardImage(_:)),
            keyEquivalent: ""
        )
        item.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Save Clipboard Image")
        menu.addItem(item)
        return menu
    }

    @objc func saveClipboardImage(_ sender: AnyObject?) {
        guard let url = URL(string: "clipboardsaver://save") else { return }
        NSWorkspace.shared.open(url)
    }
}
