import AppKit
import SwiftUI

/// Floating, nonactivating capsule panel: recording stays visible without
/// stealing focus from the target app.
@MainActor
final class RecorderPanelController {
    private let panel: NSPanel

    init(appState: AppState) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 56),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(
            rootView: RecorderPillView().environment(appState)
        )
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.minY + 24
            )
        )
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

struct RecorderPillView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            actionButton
            waveform
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Image(systemName: appState.selectedMode?.iconSystemName ?? "waveform")
                        .font(.caption2)
                    Text(appState.activeAction == .dictate ? "Dictate" : "Ask")
                        .font(.caption.weight(.semibold))
                }
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            contextIndicators
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(NP.rail, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .colorScheme(.dark)
        .frame(maxWidth: 320)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Vortext recorder, \(statusText)")
    }

    private var statusText: String {
        switch appState.recorderState {
        case .idle: "Ready"
        case .recording: "Recording"
        case .processing(let step): step
        case .notice(let text): text
        }
    }

    private var actionButton: some View {
        Button {
            switch appState.recorderState {
            case .recording: appState.stopAndProcess()
            default: appState.cancelAction()
            }
        } label: {
            Image(
                systemName: appState.recorderState == .recording
                    ? "stop.fill" : "xmark"
            )
            .font(.footnote.weight(.bold))
            .foregroundStyle(NP.rail)
            .frame(width: 26, height: 26)
            .background(Color(hex: 0xC8FF4D), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            appState.recorderState == .recording ? "Stop recording" : "Cancel"
        )
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 2) {
            let levels = appState.recorderLevels.suffix(18)
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(Color(hex: 0xC8FF4D).opacity(0.9))
                    .frame(width: 2.5, height: max(3, CGFloat(level) * 26))
            }
            if levels.isEmpty {
                Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 3)
            }
        }
        .frame(width: 88, height: 28, alignment: .center)
        .animation(reduceMotion ? nil : .linear(duration: 0.08), value: appState.recorderLevels)
        .accessibilityHidden(true)
    }

    private var contextIndicators: some View {
        let usesCloud = !(appState.selectedMode?.isSystemDefault ?? true)
        let settings = try? appState.store.settings()
        let consented = (settings?.contextConsentGranted ?? false) && usesCloud
        let enabled = Set(settings?.enabledContextSources ?? [])
        return HStack(spacing: 4) {
            if consented {
                contextDot("app.badge", active: enabled.contains(.app), label: "App")
                contextDot("doc.on.clipboard", active: enabled.contains(.clipboard), label: "Clipboard")
                contextDot("clock", active: enabled.contains(.time), label: "Time")
                contextDot("rectangle.dashed", active: enabled.contains(.screen), label: "Screen")
            }
        }
    }

    private func contextDot(_ symbol: String, active: Bool, label: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 9))
            .foregroundStyle(active ? Color(hex: 0xC8FF4D) : .white.opacity(0.3))
            .accessibilityLabel("\(label) context \(active ? "on" : "off")")
    }
}
