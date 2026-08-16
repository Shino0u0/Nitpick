import Foundation
import SwiftData

enum AppStoreError: Error, Equatable {
    case defaultModeIsImmutable
}

/// Facade over the SwiftData container. Owns Default Mode
/// seeding/immutability and the History-audio cascade. Not Sendable: each
/// user creates its own instance's context on one isolation domain (the app
/// uses it from the main actor; tests use it locally).
final class AppStore {
    let container: ModelContainer
    private let context: ModelContext

    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(
            for: ModeRecord.self, HistoryEntry.self, DictionaryEntryRecord.self,
            ProviderConfiguration.self, AppSettings.self,
            configurations: configuration
        )
        context = ModelContext(container)
        try seedIfNeeded()
    }

    func seedIfNeeded() throws {
        guard try modes().first(where: \.isSystemDefault) == nil else { return }
        context.insert(
            ModeRecord(
                name: "Default",
                iconSystemName: "waveform",
                instructions: "",
                order: 0,
                allowedActions: [.dictate],
                isSystemDefault: true
            )
        )
        try context.save()
    }

    // MARK: - Modes

    func modes() throws -> [ModeRecord] {
        try context.fetch(
            FetchDescriptor<ModeRecord>(sortBy: [SortDescriptor(\.order)])
        )
    }

    func addMode(_ mode: ModeRecord) throws {
        let maxOrder = try modes().map(\.order).max() ?? 0
        mode.order = maxOrder + 1
        context.insert(mode)
        try context.save()
    }

    func deleteMode(_ mode: ModeRecord) throws {
        guard !mode.isSystemDefault else { throw AppStoreError.defaultModeIsImmutable }
        context.delete(mode)
        try context.save()
    }

    // MARK: - History

    func history() throws -> [HistoryEntry] {
        try context.fetch(
            FetchDescriptor<HistoryEntry>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
    }

    func addHistory(_ entry: HistoryEntry) throws {
        context.insert(entry)
        try context.save()
    }

    func deleteHistory(_ entry: HistoryEntry) throws {
        deleteAudioFile(of: entry)
        context.delete(entry)
        try context.save()
    }

    func clearHistory() throws {
        for entry in try history() {
            deleteAudioFile(of: entry)
            context.delete(entry)
        }
        try context.save()
    }

    private func deleteAudioFile(of entry: HistoryEntry) {
        guard let url = entry.audioFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Dictionary

    func dictionaryEntries() throws -> [DictionaryEntryRecord] {
        try context.fetch(
            FetchDescriptor<DictionaryEntryRecord>(sortBy: [SortDescriptor(\.phrase)])
        )
    }

    func activeRules() throws -> [DictionaryRule] {
        try dictionaryEntries().map(\.asRule)
    }

    // MARK: - Settings

    func settings() throws -> AppSettings {
        if let existing = try context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let fresh = AppSettings()
        context.insert(fresh)
        try context.save()
        return fresh
    }

    func save() throws {
        try context.save()
    }
}
