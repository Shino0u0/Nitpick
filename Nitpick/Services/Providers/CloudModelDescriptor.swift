import Foundation

enum InputModality: String, Codable, Sendable {
    case text
    case image
    /// Provider supplied no capability metadata and the model is not in the
    /// audited table. Treated conservatively as text-only: screen context is
    /// never attached to an unknown-capability model.
    case unknown
}

/// Provider-neutral model description shown in the Models tab and used for
/// capability gating. Persisted (without secrets) in the model cache.
struct CloudModelDescriptor: Codable, Equatable, Sendable, Identifiable {
    var provider: ProviderID
    var modelID: String
    var displayName: String?
    var inputModalities: Set<InputModality>
    var outputModalities: Set<InputModality>?
    var contextLength: Int?
    var maxOutputTokens: Int?

    var id: String { "\(provider.rawValue)/\(modelID)" }

    /// True only with explicit provider metadata or an audited table entry.
    var supportsImageInput: Bool { inputModalities.contains(.image) }
}
