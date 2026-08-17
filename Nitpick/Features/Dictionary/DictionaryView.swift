import SwiftData
import SwiftUI

struct DictionaryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \DictionaryEntryRecord.phrase)
    private var entries: [DictionaryEntryRecord]
    @State private var search = ""
    @State private var newPhrase = ""
    @State private var newReplacement = ""
    @State private var testInput = ""

    private var filtered: [DictionaryEntryRecord] {
        guard !search.isEmpty else { return entries }
        return entries.filter {
            $0.phrase.localizedCaseInsensitiveContains(search)
                || $0.replacement.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                NPEyebrow("Dictionary")
                Spacer()
                TextField("Search", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            }

            addRow

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(filtered, id: \.id) { entry in
                        DictionaryRowView(entry: entry) {
                            try? appState.store.deleteDictionaryEntry(entry)
                        } onChange: {
                            entry.updatedAt = .now
                            try? appState.store.save()
                        }
                    }
                    if filtered.isEmpty {
                        Text(
                            entries.isEmpty
                                ? "Add a phrase like \"my email\" and Vortext will replace it every time you say it."
                                : "No matches."
                        )
                        .font(.callout)
                        .foregroundStyle(NP.inkSecondary)
                        .padding(.top, 20)
                    }
                }
            }

            testField
        }
        .padding(16)
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("Spoken phrase", text: $newPhrase)
                .textFieldStyle(.roundedBorder)
            Image(systemName: "arrow.right")
                .foregroundStyle(NP.inkSecondary)
            TextField("Replacement", text: $newReplacement)
                .textFieldStyle(.roundedBorder)
            Button("Add") {
                try? appState.store.addDictionaryEntry(
                    DictionaryEntryRecord(
                        phrase: newPhrase, replacement: newReplacement
                    )
                )
                newPhrase = ""
                newReplacement = ""
            }
            .buttonStyle(NPCapsuleButtonStyle(prominent: true))
            .disabled(newPhrase.isEmpty || newReplacement.isEmpty)
        }
    }

    private var testField: some View {
        VStack(alignment: .leading, spacing: 5) {
            NPEyebrow("Try it")
            TextField("Type a sentence to preview replacements", text: $testInput)
                .textFieldStyle(.roundedBorder)
            if !testInput.isEmpty {
                let rules = entries.map(\.asRule)
                Text(DictionaryEngine.apply(rules, to: testInput))
                    .font(.callout)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NP.success.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct DictionaryRowView: View {
    let entry: DictionaryEntryRecord
    let onDelete: () -> Void
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField(
                "Phrase",
                text: Binding(
                    get: { entry.phrase },
                    set: { entry.phrase = $0; onChange() }
                )
            )
            .textFieldStyle(.plain)
            .font(.callout)
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(NP.inkSecondary)
            TextField(
                "Replacement",
                text: Binding(
                    get: { entry.replacement },
                    set: { entry.replacement = $0; onChange() }
                )
            )
            .textFieldStyle(.plain)
            .font(.callout.weight(.medium))
            Spacer()
            Toggle(
                "Case sensitive",
                isOn: Binding(
                    get: { entry.isCaseSensitive },
                    set: { entry.isCaseSensitive = $0; onChange() }
                )
            )
            .toggleStyle(.checkbox)
            .controlSize(.small)
            Toggle(
                "",
                isOn: Binding(
                    get: { entry.isEnabled },
                    set: { entry.isEnabled = $0; onChange() }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .accessibilityLabel("Enable \(entry.phrase)")
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(NP.inkSecondary)
            .accessibilityLabel("Delete \(entry.phrase)")
        }
        .npCard()
    }
}
