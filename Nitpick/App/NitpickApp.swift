import SwiftUI

@main
struct NitpickApp: App {
    var body: some Scene {
        Window("Nitpick", id: "main") {
            MainWindowPlaceholder()
        }
        .defaultSize(width: 760, height: 520)

        MenuBarExtra("Nitpick", systemImage: "waveform") {
            MenuBarContent()
        }
    }
}

/// Temporary shell while feature tabs are built out. Replaced by the real
/// History / Models / Modes / Dictionary window in the Features phase.
struct MainWindowPlaceholder: View {
    var body: some View {
        Text("Nitpick")
            .font(.title3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Nitpick") { openWindow(id: "main") }
        Divider()
        Button("Quit Nitpick") { NSApp.terminate(nil) }
    }
}
