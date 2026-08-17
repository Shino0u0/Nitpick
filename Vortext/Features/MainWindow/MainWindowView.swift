import SwiftUI

struct MainWindowView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.onboardingCompleted {
            tabs
        } else {
            OnboardingView()
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            railView
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(NP.canvas)
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var railView: some View {
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(NP.accent)
                    .font(.title3)
                Text("Vortext")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 18)

            ForEach(MainTab.allCases) { tab in
                Button {
                    appState.selectedTab = tab
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: tab.systemImage)
                            .frame(width: 16)
                        Text(tab.rawValue)
                        Spacer(minLength: 0)
                    }
                    .font(.callout.weight(appState.selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(
                        appState.selectedTab == tab ? NP.accent : .white.opacity(0.72)
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        appState.selectedTab == tab
                            ? Color.white.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(
                    appState.selectedTab == tab ? .isSelected : []
                )
            }

            Spacer()

            Button {
                appState.startAction(.dictate)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "mic.fill")
                    Text("Dictate")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(NP.rail)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(hex: 0xC8FF4D), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 176)
        .frame(maxHeight: .infinity)
        .background(NP.rail)
    }

    @ViewBuilder
    private var content: some View {
        switch appState.selectedTab {
        case .history: HistoryView()
        case .models: ModelsView()
        case .modes: ModesView()
        case .dictionary: DictionaryView()
        }
    }
}
