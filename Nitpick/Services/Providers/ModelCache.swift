import Foundation

/// Disk cache of the last successful model list per provider so Models shows
/// something immediately on launch. Stores descriptors and a fetch date only;
/// never request headers or key material.
struct ModelCache {
    struct Entry: Codable, Equatable, Sendable {
        var models: [CloudModelDescriptor]
        var fetchedAt: Date

        /// Cache older than 24 hours refreshes in the background when the
        /// provider is opened; stale models stay visible on network failure.
        func isStale(asOf now: Date = .now) -> Bool {
            now.timeIntervalSince(fetchedAt) > 24 * 3600
        }
    }

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func standard() -> ModelCache {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return ModelCache(directory: base.appending(path: "Nitpick/ModelCache"))
    }

    func store(
        _ models: [CloudModelDescriptor], for provider: ProviderID, fetchedAt: Date
    ) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let entry = Entry(models: models, fetchedAt: fetchedAt)
        try JSONEncoder().encode(entry).write(to: fileURL(provider), options: .atomic)
    }

    func load(for provider: ProviderID) -> Entry? {
        guard let data = try? Data(contentsOf: fileURL(provider)) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    func remove(for provider: ProviderID) throws {
        let url = fileURL(provider)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func fileURL(_ provider: ProviderID) -> URL {
        directory.appending(path: "\(provider.rawValue).json")
    }
}
