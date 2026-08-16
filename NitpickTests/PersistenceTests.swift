import Foundation
import SwiftData
import Testing
@testable import Nitpick

struct PersistenceTests {
    private func makeStore() throws -> AppStore {
        try AppStore(inMemory: true)
    }

    // MARK: Default Mode

    @Test func seedsPermanentDefaultMode() throws {
        let store = try makeStore()
        let modes = try store.modes()
        #expect(modes.count == 1)
        let def = try #require(modes.first)
        #expect(def.name == "Default")
        #expect(def.isSystemDefault)
        #expect(def.order == 0)
    }

    @Test func seedingIsIdempotent() throws {
        let store = try makeStore()
        try store.seedIfNeeded()
        try store.seedIfNeeded()
        #expect(try store.modes().filter(\.isSystemDefault).count == 1)
    }

    @Test func defaultModeCannotBeDeleted() throws {
        let store = try makeStore()
        let def = try #require(try store.modes().first)
        #expect(throws: AppStoreError.defaultModeIsImmutable) {
            try store.deleteMode(def)
        }
        #expect(try store.modes().count == 1)
    }

    @Test func customModesOrderAfterDefault() throws {
        let store = try makeStore()
        let custom = ModeRecord(
            name: "Email", iconSystemName: "envelope", instructions: "Rewrite as email.",
            allowedActions: [.dictate, .ask]
        )
        try store.addMode(custom)
        let modes = try store.modes()
        #expect(modes.first?.isSystemDefault == true)
        #expect(modes.last?.name == "Email")
        #expect(modes.last!.order > 0)
    }

    // MARK: History + audio cascade

    @Test func deletingHistoryEntryDeletesItsAudioFile() throws {
        let store = try makeStore()
        let audio = FileManager.default.temporaryDirectory
            .appending(path: "nitpick-audio-\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: audio)

        let entry = HistoryEntry(
            action: .dictate, status: .succeeded,
            originalTranscript: "hi", finalOutput: "hi",
            audioFileURL: audio
        )
        try store.addHistory(entry)
        try store.deleteHistory(entry)

        #expect(try store.history().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: audio.path))
    }

    @Test func clearHistoryDeletesAllAudio() throws {
        let store = try makeStore()
        var urls: [URL] = []
        for i in 0..<3 {
            let audio = FileManager.default.temporaryDirectory
                .appending(path: "nitpick-audio-\(UUID().uuidString)-\(i).wav")
            try Data([0x00]).write(to: audio)
            urls.append(audio)
            try store.addHistory(
                HistoryEntry(
                    action: .ask, status: .succeeded,
                    originalTranscript: "q", finalOutput: "a", audioFileURL: audio
                )
            )
        }
        try store.clearHistory()
        #expect(try store.history().isEmpty)
        for url in urls {
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test func historyRecordsContextFlagsNotPayloads() throws {
        let store = try makeStore()
        let entry = HistoryEntry(
            action: .ask, status: .succeeded,
            originalTranscript: "q", finalOutput: "a",
            usedContext: [.clipboard, .screen]
        )
        try store.addHistory(entry)
        let loaded = try #require(try store.history().first)
        #expect(loaded.usedContext == [.clipboard, .screen])
    }

    @Test func failedEntryKeepsErrorCategoryOnly() throws {
        let store = try makeStore()
        let entry = HistoryEntry(
            action: .dictate, status: .failed,
            originalTranscript: "kept transcript", finalOutput: nil,
            errorCategory: .providerRateLimited
        )
        try store.addHistory(entry)
        let loaded = try #require(try store.history().first)
        #expect(loaded.errorCategory == .providerRateLimited)
        #expect(loaded.originalTranscript == "kept transcript")
    }
}
