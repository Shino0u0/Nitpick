import AppKit
import SwiftUI

/// Compact response panel for Ask answers: editable text plus copy.
@MainActor
final class AskPanelController {
    private let panel: NSPanel

    init(appState: AppState) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable, .utilityWindow, .resizable],
            backing: .buffered, defer: false
        )
        panel.title = "Vortex"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(
            rootView: AskResponseView().environment(appState)
        )
    }

    func show() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

struct AskResponseView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        VStack(alignment: .leading, spacing: 10) {
            NPEyebrow("Answer")
            TextEditor(
                text: Binding(
                    get: { appState.askResponse ?? "" },
                    set: { appState.askResponse = $0 }
                )
            )
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(NP.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(NP.border))
            HStack {
                Spacer()
                Button("Copy") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(appState.askResponse ?? "", forType: .string)
                }
                .buttonStyle(NPCapsuleButtonStyle(prominent: true))
            }
        }
        .padding(14)
        .frame(minWidth: 380, minHeight: 220)
        .background(NP.canvas)
    }
}
