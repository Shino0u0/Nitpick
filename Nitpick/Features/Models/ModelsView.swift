import SwiftUI

struct ModelsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedProvider: ProviderID = .groq

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NPEyebrow("Providers")
            providerStrip
            ProviderCard(provider: selectedProvider)
                .id(selectedProvider)
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var providerStrip: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 8) {
                ForEach(ProviderID.allCases) { provider in
                    Button {
                        selectedProvider = provider
                    } label: {
                        HStack(spacing: 6) {
                            connectionDot(for: provider)
                            Text(provider.displayName)
                        }
                        .font(.callout.weight(
                            selectedProvider == provider ? .semibold : .regular
                        ))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selectedProvider == provider ? NP.rail : NP.card,
                            in: Capsule()
                        )
                        .foregroundStyle(
                            selectedProvider == provider ? Color.white : NP.ink
                        )
                        .overlay(Capsule().strokeBorder(NP.border))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        selectedProvider == provider ? .isSelected : []
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func connectionDot(for provider: ProviderID) -> some View {
        let connected = (try? appState.store.providerConfigurations())?
            .first { $0.providerID == provider }?.isConnected ?? false
        return Circle()
            .fill(connected ? Color.green : NP.border)
            .frame(width: 6, height: 6)
            .accessibilityLabel(connected ? "Connected" : "Not connected")
    }
}

private struct ProviderCard: View {
    @Environment(AppState.self) private var appState
    let provider: ProviderID

    @State private var keyInput = ""
    @State private var isTesting = false
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var models: [CloudModelDescriptor] = []
    @State private var lastRefresh: Date?

    private var configuration: ProviderConfiguration? {
        try? appState.store.providerConfiguration(for: provider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(provider.displayName).font(.title3.weight(.semibold))
                Spacer()
                Link("Dashboard", destination: provider.dashboardURL)
                    .font(.callout)
            }

            keySection
            if configuration?.isConnected == true {
                modelSection
            }
            if let statusMessage {
                Label(
                    statusMessage,
                    systemImage: statusIsError
                        ? "exclamationmark.circle" : "checkmark.circle"
                )
                .font(.callout)
                .foregroundStyle(statusIsError ? .red : .green)
            }
        }
        .npCard()
        .onAppear(perform: loadCached)
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            NPEyebrow(configuration?.isConnected == true ? "Replace key" : "API key")
            HStack(spacing: 8) {
                SecureField("Paste your \(provider.displayName) API key", text: $keyInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 340)
                Button(isTesting ? "Testing…" : "Test Connection") {
                    testAndSave()
                }
                .buttonStyle(NPCapsuleButtonStyle(prominent: true))
                .disabled(keyInput.isEmpty || isTesting)
                if configuration?.isConnected == true {
                    Button("Remove Key") { removeKey() }
                        .buttonStyle(NPCapsuleButtonStyle())
                }
            }
            Text("Saved to your Mac's Keychain only after a successful test. The full key is never shown again.")
                .font(.caption)
                .foregroundStyle(NP.inkSecondary)
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                NPEyebrow("Default model")
                Spacer()
                if let lastRefresh {
                    Text("Refreshed \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(NP.inkSecondary)
                }
                Button {
                    Task { await refreshModels() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh models")
            }
            if models.isEmpty {
                Text("No models loaded yet - refresh to fetch.")
                    .font(.callout)
                    .foregroundStyle(NP.inkSecondary)
            } else {
                Picker(
                    "Model",
                    selection: Binding(
                        get: { configuration?.selectedModelID ?? "" },
                        set: { select(modelID: $0) }
                    )
                ) {
                    Text("Choose a model").tag("")
                    ForEach(models) { model in
                        Text(modelLabel(model)).tag(model.modelID)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 420)
                if let selected = configuration?.selectedModelID, !selected.isEmpty,
                    !models.contains(where: { $0.modelID == selected }) {
                    Label(
                        "The selected model is no longer offered. Choose a new one.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.callout)
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    private func modelLabel(_ model: CloudModelDescriptor) -> String {
        var label = model.displayName ?? model.modelID
        var traits: [String] = []
        if let context = model.contextLength { traits.append("\(context / 1000)k ctx") }
        if model.supportsImageInput { traits.append("vision") }
        if !traits.isEmpty { label += "  (\(traits.joined(separator: ", ")))" }
        return label
    }

    // MARK: - Actions

    private func loadCached() {
        let entry = appState.modelCache.load(for: provider)
        models = entry?.models ?? []
        lastRefresh = entry?.fetchedAt
        if configuration?.isConnected == true,
            entry.map({ $0.isStale() }) ?? true {
            Task { await refreshModels() }
        }
    }

    private func testAndSave() {
        let candidate = SecretValue(keyInput)
        isTesting = true
        statusMessage = nil
        Task {
            defer { isTesting = false }
            let client = OpenAICompatibleClient(provider: provider)
            do {
                try await client.validate(apiKey: candidate)
                // Validation passed: only now overwrite any previous key.
                try KeychainStore().save(key: candidate, provider: provider)
                keyInput = ""
                if let configuration {
                    configuration.isConnected = true
                    try? appState.store.save()
                }
                statusIsError = false
                statusMessage = "Connected"
                await refreshModels()
            } catch ProviderError.invalidKey {
                statusIsError = true
                statusMessage = "Invalid key. Any previously saved key is unchanged."
            } catch {
                statusIsError = true
                statusMessage = "Connection failed. Any previously saved key is unchanged."
            }
        }
    }

    private func removeKey() {
        try? KeychainStore().delete(provider: provider)
        try? appState.modelCache.remove(for: provider)
        try? appState.store.removeProvider(provider)
        models = []
        statusIsError = false
        statusMessage = "Key removed from Keychain"
    }

    private func refreshModels() async {
        guard let key = try? KeychainStore().read(provider: provider) else { return }
        do {
            let fetched = try await OpenAICompatibleClient(provider: provider)
                .fetchModels(apiKey: key)
            models = fetched.sorted { $0.modelID < $1.modelID }
            lastRefresh = .now
            try? appState.modelCache.store(fetched, for: provider, fetchedAt: .now)
            if let configuration {
                configuration.lastModelRefresh = .now
                try? appState.store.save()
            }
        } catch {
            // Keep stale models visible on transient failure (SPEC 9.4).
            statusIsError = true
            statusMessage = "Refresh failed - showing cached models"
        }
    }

    private func select(modelID: String) {
        guard let configuration else { return }
        configuration.selectedModelID = modelID.isEmpty ? nil : modelID
        if let settings = try? appState.store.settings() {
            settings.defaultProviderID = provider
            settings.defaultModelID = modelID.isEmpty ? nil : modelID
        }
        try? appState.store.save()
    }
}
