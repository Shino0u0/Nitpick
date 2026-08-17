import AppKit
import ApplicationServices
import Foundation

enum InsertionOutcome: Equatable, Sendable {
    case inserted
    /// Accessibility unavailable or insertion failed; text was placed on the
    /// clipboard and the UI must show "Copied - paste into your app".
    case copiedToClipboard
}

protocol TextInserting: Sendable {
    func insert(_ text: String) async -> InsertionOutcome
}

/// Inserts into the focused element of the frontmost app via Accessibility;
/// falls back to the pasteboard when trust is missing or insertion fails.
struct AccessibilityTextInserter: TextInserting {
    func insert(_ text: String) async -> InsertionOutcome {
        if AXIsProcessTrusted(), await insertViaAccessibility(text) {
            return .inserted
        }
        await copyToPasteboard(text)
        return .copiedToClipboard
    }

    @MainActor
    private func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focused
        )
        guard status == .success, let focused else { return false }
        let element = unsafeDowncast(focused, to: AXUIElement.self)
        // Replacing the current selection inserts at the caret when nothing
        // is selected.
        let set = AXUIElementSetAttributeValue(
            element, kAXSelectedTextAttribute as CFString, text as CFString
        )
        return set == .success
    }

    @MainActor
    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
