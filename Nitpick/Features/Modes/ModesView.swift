import SwiftData
import SwiftUI

struct ModesView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \ModeRecord.order) private var modes: [ModeRecord]
    @State private var editing: ModeRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                NPEyebrow("Modes")
                Spacer()
                Button("New Mode") { createMode() }
                    .buttonStyle(NPCapsuleButtonStyle(prominent: true))
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(modes, id: \.id) { mode in
                        ModeRowView(
                            mode: mode,
                            isSelected: appState.selectedModeID == mode.id,
                            onSelect: { appState.selectedModeID = mode.id },
                            onEdit: { editing = mode },
                            onDuplicate: { duplicate(mode) },
                            onDelete: { try? appState.store.deleteMode(mode) },
                            onMove: { direction in move(mode, by: direction) }
                        )
                    }
                }
            }
        }
        .padding(16)
        .sheet(item: $editing) { mode in
            ModeEditorView(mode: mode)
                .environment(appState)
        }
    }

    private func createMode() {
        let mode = ModeRecord(
            name: "New Mode",
            iconSystemName: "sparkles",
            instructions: "Improve the transcript's clarity while keeping its meaning.",
            allowedActions: [.dictate, .ask]
        )
        try? appState.store.addMode(mode)
        editing = mode
    }

    private func duplicate(_ mode: ModeRecord) {
        let copy = ModeRecord(
            name: "\(mode.name) copy",
            iconSystemName: mode.iconSystemName,
            instructions: mode.instructions,
            isEnabled: mode.isEnabled,
            allowedActions: mode.allowedActions,
            providerOverride: mode.providerOverride,
            modelOverride: mode.modelOverride,
            targetBundleIDs: mode.targetBundleIDs
        )
        try? appState.store.addMode(copy)
    }

    private func move(_ mode: ModeRecord, by direction: Int) {
        let custom = modes.filter { !$0.isSystemDefault }
        guard let index = custom.firstIndex(where: { $0.id == mode.id }) else { return }
        let target = index + direction
        guard custom.indices.contains(target) else { return }
        let other = custom[target]
        swap(&mode.order, &other.order)
        try? appState.store.save()
    }
}

private struct ModeRowView: View {
    let mode: ModeRecord
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: mode.iconSystemName)
                .frame(width: 26, height: 26)
                .background(
                    isSelected ? NP.success : NP.canvasSecondary, in: Circle()
                )
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(mode.name).font(.callout.weight(.medium))
                    if mode.isSystemDefault {
                        Text("Local only")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(NP.success, in: Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(NP.inkSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if !mode.isSystemDefault {
                Toggle("", isOn: Binding(
                    get: { mode.isEnabled },
                    set: { mode.isEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .accessibilityLabel("Enable \(mode.name)")
                Button { onMove(-1) } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Move \(mode.name) up")
                Button { onMove(1) } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Move \(mode.name) down")
                Button("Edit", action: onEdit)
                    .buttonStyle(NPCapsuleButtonStyle())
                Menu {
                    Button("Duplicate", action: onDuplicate)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
        }
        .npCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var subtitle: String {
        if mode.isSystemDefault {
            return "Transcription and dictionary only. Never uses the network."
        }
        let actions = mode.allowedActions
            .map { $0 == .dictate ? "Dictate" : "Ask" }
            .joined(separator: " + ")
        let model = mode.modelOverride ?? "default model"
        return "\(actions) · \(model)"
    }
}

private struct ModeEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let mode: ModeRecord

    @State private var name = ""
    @State private var icon = "sparkles"
    @State private var instructions = ""
    @State private var allowDictate = true
    @State private var allowAsk = true
    @State private var providerOverride: ProviderID?
    @State private var modelOverride = ""
    @State private var targetBundleIDs = ""

    private static let icons = [
        "sparkles", "envelope", "arrowshape.turn.up.left", "pencil.and.outline",
        "note.text", "bubble.left", "text.badge.checkmark", "globe",
        "briefcase", "graduationcap", "heart", "terminal",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NPEyebrow("Edit Mode")
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(34)), count: 12), spacing: 6
            ) {
                ForEach(Self.icons, id: \.self) { symbol in
                    Button {
                        icon = symbol
                    } label: {
                        Image(systemName: symbol)
                            .frame(width: 30, height: 30)
                            .background(
                                icon == symbol ? NP.success : NP.canvasSecondary,
                                in: RoundedRectangle(cornerRadius: 7)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(icon == symbol ? .isSelected : [])
                }
            }
            NPEyebrow("Instructions")
            TextEditor(text: $instructions)
                .font(.body)
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(NP.card, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(NP.border))
            HStack(spacing: 14) {
                Toggle("Dictate", isOn: $allowDictate)
                Toggle("Ask", isOn: $allowAsk)
            }
            HStack(spacing: 8) {
                Picker("Provider", selection: $providerOverride) {
                    Text("Global default").tag(ProviderID?.none)
                    ForEach(ProviderID.allCases) { provider in
                        Text(provider.displayName).tag(ProviderID?.some(provider))
                    }
                }
                .frame(maxWidth: 220)
                TextField("Model override (optional)", text: $modelOverride)
                    .textFieldStyle(.roundedBorder)
            }
            TextField(
                "Target app bundle IDs, comma separated (optional)",
                text: $targetBundleIDs
            )
            .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(NPCapsuleButtonStyle())
                Button("Save") { save() }
                    .buttonStyle(NPCapsuleButtonStyle(prominent: true))
                    .disabled(name.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 520)
        .background(NP.canvas)
        .onAppear(perform: load)
    }

    private func load() {
        name = mode.name
        icon = mode.iconSystemName
        instructions = mode.instructions
        allowDictate = mode.allowedActions.contains(.dictate)
        allowAsk = mode.allowedActions.contains(.ask)
        providerOverride = mode.providerOverride
        modelOverride = mode.modelOverride ?? ""
        targetBundleIDs = mode.targetBundleIDs.joined(separator: ", ")
    }

    private func save() {
        mode.name = name
        mode.iconSystemName = icon
        mode.instructions = instructions
        var actions: [NitpickAction] = []
        if allowDictate { actions.append(.dictate) }
        if allowAsk { actions.append(.ask) }
        mode.allowedActions = actions.isEmpty ? [.dictate] : actions
        mode.providerOverride = providerOverride
        mode.modelOverride = modelOverride.isEmpty ? nil : modelOverride
        mode.targetBundleIDs = targetBundleIDs
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        try? appState.store.save()
        dismiss()
    }
}
