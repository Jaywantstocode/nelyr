import AppKit
import Foundation

enum SelectionTextReader {
    static func read(from pasteboard: NSPasteboard) -> String? {
        let modern = pasteboard.string(forType: .string)
        let legacy = pasteboard.string(forType: NSPasteboard.PasteboardType("NSStringPboardType"))
        let text = (modern ?? legacy ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

@MainActor
final class SelectionCaptureService: NSObject {
    static let shared = SelectionCaptureService()

    @objc func saveSelectionToDailyDesk(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = validatedSelection(from: pasteboard, error: error) else { return }
        guard DailyDeskModel.shared.captureIdea(text) else {
            error.pointee = "Nelyr could not write the selection to your Obsidian vault." as NSString
            return
        }
        NotificationService.shared.sendCaptureSaved(preview: text)
    }

    @objc func reviewSelectionInDailyDesk(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = validatedSelection(from: pasteboard, error: error) else { return }
        CapturePanelController.shared.show(prefilledText: text)
    }

    private func validatedSelection(
        from pasteboard: NSPasteboard,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) -> String? {
        guard let text = SelectionTextReader.read(from: pasteboard) else {
            error.pointee = "Nelyr could not read any selected text." as NSString
            return nil
        }
        guard VaultManager.shared.vaultURL != nil else {
            error.pointee = "Open Nelyr and choose an Obsidian vault before saving selections." as NSString
            return nil
        }
        return text
    }
}
