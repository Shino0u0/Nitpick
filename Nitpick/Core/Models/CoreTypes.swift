import Foundation

/// The two user-facing actions. Dictate inserts into the target app; Ask
/// shows the answer in Nitpick's response panel.
enum NitpickAction: String, Codable, Sendable {
    case dictate
    case ask
}

/// The four initial cloud providers, all OpenAI-compatible over HTTPS.
/// Raw values are stable identifiers used for Keychain accounts, SwiftData
/// references, and the model cache; never rename them.
enum ProviderID: String, Codable, CaseIterable, Sendable, Identifiable {
    case groq
    case openRouter
    case sambaNova
    case cerebras

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: "Groq"
        case .openRouter: "OpenRouter"
        case .sambaNova: "SambaNova"
        case .cerebras: "Cerebras"
        }
    }

    var baseURL: URL {
        switch self {
        case .groq: URL(string: "https://api.groq.com/openai/v1")!
        case .openRouter: URL(string: "https://openrouter.ai/api/v1")!
        case .sambaNova: URL(string: "https://api.sambanova.ai/v1")!
        case .cerebras: URL(string: "https://api.cerebras.ai/v1")!
        }
    }

    var dashboardURL: URL {
        switch self {
        case .groq: URL(string: "https://console.groq.com")!
        case .openRouter: URL(string: "https://openrouter.ai/settings/keys")!
        case .sambaNova: URL(string: "https://cloud.sambanova.ai")!
        case .cerebras: URL(string: "https://cloud.cerebras.ai")!
        }
    }
}
