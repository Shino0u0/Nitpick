import SwiftData
import SwiftUI

@main
struct NitpickApp: App {
    @State private var appState: AppState?
    @State private var startupError: String?

    init() {
        do {
            _appState = State(initialValue: try AppState())
        } catch {
            _startupError = State(initialValue: "\(error)")
        }
    }

    var body: some Scene {
        Window("Vortex", id: "main") {
            if let appState {
                MainWindowView()
                    .environment(appState)
                    .modelContainer(appState.store.container)
            } else {
                Text("Vortex could not open its local database.\n\(startupError ?? "")")
                    .padding(40)
            }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 560)

        MenuBarExtra("Vortex", systemImage: "waveform") {
            if let appState {
                MenuBarContent()
                    .environment(appState)
                    .modelContainer(appState.store.container)
            }
        }
    }
}

private struct MenuBarContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ModeRecord.order) private var modes: [ModeRecord]

    var body: some View {
        Button("Start Dictation") { appState.startAction(.dictate) }
            .keyboardShortcut("d", modifiers: [.command, .option])
        Button("Ask") { appState.startAction(.ask) }
            .keyboardShortcut("a", modifiers: [.command, .option])
        Divider()
        Picker("Mode", selection: Binding(
            get: { appState.selectedModeID },
            set: { appState.selectedModeID = $0 }
        )) {
            ForEach(modes.filter { $0.isEnabled || $0.isSystemDefault }, id: \.id) { mode in
                Label(mode.name, systemImage: mode.iconSystemName)
                    .tag(Optional(mode.id))
            }
        }
        .pickerStyle(.inline)
        Divider()
        Button("Open Vortex") {
            openWindow(id: "main")
            NSApp.activate()
        }
        Divider()
        Button("Quit Vortex") { NSApp.terminate(nil) }
    }
}
