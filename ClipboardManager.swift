import AppKit
import UserNotifications

class ClipboardManager {
    static let shared = ClipboardManager()

    private init() {
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func saveClipboardImage() {
        saveFromPasteboard(NSPasteboard.general)
    }

    func saveFromPasteboard(_ pasteboard: NSPasteboard) {
        guard let image = getImageFromPasteboard(pasteboard) else {
            showNotification(title: "ClipboardSaver", body: "No image found on clipboard")
            return
        }

        guard let pngData = convertToPNG(image: image) else {
            showNotification(title: "ClipboardSaver", body: "Failed to convert image to PNG")
            return
        }

        showSavePanel(pngData: pngData)
    }

    private func getImageFromPasteboard(_ pasteboard: NSPasteboard) -> NSImage? {
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]

        for type in imageTypes {
            if let data = pasteboard.data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }

        // Also check for file URLs pointing to images
        if let items = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
           let image = items.first as? NSImage {
            return image
        }

        return nil
    }

    private func convertToPNG(image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }

    private func showSavePanel(pngData: Data) {
        let saveDir = PreferencesManager.shared.saveDirectory
        ensureDirectoryExists(saveDir)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let defaultFilename = "clipboard-\(timestamp).png"

        let panel = NSSavePanel()
        panel.title = "Save Clipboard Image"
        panel.nameFieldStringValue = defaultFilename
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: saveDir)
        panel.level = .floating

        // Bring app to front for the save dialog
        NSApp.activate(ignoringOtherApps: true)

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            do {
                try pngData.write(to: url)
            } catch {
                showNotification(title: "ClipboardSaver", body: "Failed to save image: \(error.localizedDescription)")
            }
        }
    }

    private func ensureDirectoryExists(_ path: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
