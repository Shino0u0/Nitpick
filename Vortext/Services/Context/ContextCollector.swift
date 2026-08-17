import AppKit
import Foundation
import ScreenCaptureKit

/// The application that was frontmost when the action started.
struct TargetApp: Equatable, Sendable {
    var pid: pid_t
    var bundleID: String?
    var name: String?

    @MainActor
    static func frontmost() -> TargetApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return TargetApp(
            pid: app.processIdentifier,
            bundleID: app.bundleIdentifier,
            name: app.localizedName
        )
    }
}

protocol ContextCollecting: Sendable {
    /// One action-scoped snapshot. `storedKeyHashes` feeds the clipboard
    /// secret guard; `includeScreen` is set by the pipeline only when the
    /// resolved model supports image input and consent exists.
    func collect(
        target: TargetApp?,
        sources: [ContextSource],
        storedKeyHashes: Set<String>,
        includeScreen: Bool
    ) async -> ContextSnapshot
}

struct SystemContextCollector: ContextCollecting {
    func collect(
        target: TargetApp?,
        sources: [ContextSource],
        storedKeyHashes: Set<String>,
        includeScreen: Bool
    ) async -> ContextSnapshot {
        var snapshot = ContextSnapshot()

        if sources.contains(.app), let target {
            snapshot.appName = target.name
            snapshot.appBundleID = target.bundleID
        }

        if sources.contains(.time) {
            snapshot.localTime = Date.now.formatted(
                date: .abbreviated, time: .shortened
            )
        }

        if sources.contains(.clipboard) {
            let clipboard = await readClipboard(storedKeyHashes: storedKeyHashes)
            snapshot.clipboardText = clipboard.text
            snapshot.clipboardTruncated = clipboard.truncated
            snapshot.clipboardOmittedReason = clipboard.omittedReason
        }

        if sources.contains(.screen), includeScreen, let target {
            snapshot.screenPNG = await captureWindow(of: target)
        }

        return snapshot
    }

    @MainActor
    private func readClipboard(
        storedKeyHashes: Set<String>
    ) -> (text: String?, truncated: Bool, omittedReason: String?) {
        guard let raw = NSPasteboard.general.string(forType: .string) else {
            return (nil, false, nil)
        }
        switch SecretGuard.evaluate(
            raw, storedKeyHashes: storedKeyHashes, sourceIsKeyEditor: false
        ) {
        case .allowed(let text, let truncated):
            return (text, truncated, nil)
        case .omitted:
            return (nil, false, "Clipboard omitted - possible secret")
        }
    }

    /// One image of the target app's frontmost eligible window, Vortext
    /// windows excluded, memory-only. Nil on any failure or missing
    /// Screen Recording permission.
    private func captureWindow(of target: TargetApp) async -> Data? {
        guard
            let content = try? await SCShareableContent.excludingDesktopWindows(
                true, onScreenWindowsOnly: true
            )
        else { return nil }
        let window = content.windows.first { window in
            window.owningApplication?.processID == target.pid
                && window.windowLayer == 0
                && window.frame.width > 40 && window.frame.height > 40
        }
        guard let window else { return nil }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width)
        configuration.height = Int(window.frame.height)
        configuration.showsCursor = false
        guard
            let image = try? await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: configuration
            )
        else { return nil }

        let representation = NSBitmapImageRep(cgImage: image)
        return representation.representation(using: .png, properties: [:])
    }
}
