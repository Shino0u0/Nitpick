import Foundation
import Testing
@testable import Vortext

struct ModelCacheTests {
    private func makeCache() throws -> ModelCache {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "nitpick-tests-\(UUID().uuidString)")
        return ModelCache(directory: dir)
    }

    private func descriptor(_ id: String, provider: ProviderID = .groq) -> CloudModelDescriptor {
        CloudModelDescriptor(provider: provider, modelID: id, inputModalities: [.unknown])
    }

    @Test func roundTripsModels() throws {
        let cache = try makeCache()
        let models = [descriptor("m1"), descriptor("m2")]
        let now = Date(timeIntervalSince1970: 1_000_000)
        try cache.store(models, for: .groq, fetchedAt: now)

        let loaded = try #require(cache.load(for: .groq))
        #expect(loaded.models == models)
        #expect(loaded.fetchedAt == now)
    }

    @Test func missingProviderLoadsNil() throws {
        let cache = try makeCache()
        #expect(cache.load(for: .cerebras) == nil)
    }

    @Test func providersAreIsolated() throws {
        let cache = try makeCache()
        try cache.store([descriptor("g")], for: .groq, fetchedAt: .now)
        #expect(cache.load(for: .openRouter) == nil)
    }

    @Test func stalenessIs24Hours() throws {
        let cache = try makeCache()
        let now = Date()
        try cache.store([descriptor("m")], for: .groq, fetchedAt: now.addingTimeInterval(-23 * 3600))
        #expect(try #require(cache.load(for: .groq)).isStale(asOf: now) == false)

        try cache.store([descriptor("m")], for: .groq, fetchedAt: now.addingTimeInterval(-25 * 3600))
        #expect(try #require(cache.load(for: .groq)).isStale(asOf: now) == true)
    }

    @Test func removeDeletesProviderCache() throws {
        let cache = try makeCache()
        try cache.store([descriptor("m")], for: .groq, fetchedAt: .now)
        try cache.remove(for: .groq)
        #expect(cache.load(for: .groq) == nil)
    }

    @Test func storedFileContainsNoAuthData() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "nitpick-tests-\(UUID().uuidString)")
        let cache = ModelCache(directory: dir)
        try cache.store([descriptor("m")], for: .groq, fetchedAt: .now)
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )
        for file in contents {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(!text.lowercased().contains("authorization"))
            #expect(!text.lowercased().contains("bearer"))
        }
    }
}
