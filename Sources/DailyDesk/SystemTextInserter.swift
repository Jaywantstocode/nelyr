import AppKit
import ApplicationServices

@MainActor
final class SystemTextInserter: TextInserting {
    static let shared = SystemTextInserter()

    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func selectedText() -> String? {
        guard isAccessibilityTrusted, let element = focusedElement(), !elementIsSecure(element) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &value
        ) == .success else { return nil }
        let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }

    func insert(
        _ text: String,
        into processIdentifier: pid_t?,
        directly: Bool
    ) -> TextInsertionResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard directly, isAccessibilityTrusted else { return .copied }
        guard !focusedElementIsSecure() else { return .secureField }

        if let processIdentifier,
           NSRunningApplication(processIdentifier: processIdentifier)?.isTerminated != false {
            return .copied
        }

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return .copied
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return .inserted
    }

    private func focusedElementIsSecure() -> Bool {
        guard let element = focusedElement() else { return false }
        return elementIsSecure(element)
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success,
        let value else { return nil }
        return (value as! AXUIElement)
    }

    private func elementIsSecure(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        var subroleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue)
        let role = roleValue as? String ?? ""
        let subrole = subroleValue as? String ?? ""
        return role.localizedCaseInsensitiveContains("secure")
            || subrole.localizedCaseInsensitiveContains("secure")
    }
}
