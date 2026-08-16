import Foundation

struct ChatMessage: Equatable, Sendable {
    enum Role: String, Sendable {
        case system
        case user
        case assistant
    }

    var role: Role
    var text: String
    /// Attached only when the resolved model capability includes image input
    /// and the user granted screen context. Never persisted.
    var imagePNG: Data?

    init(role: Role, text: String, imagePNG: Data? = nil) {
        self.role = role
        self.text = text
        self.imagePNG = imagePNG
    }
}

struct CompletionRequest: Sendable {
    var modelID: String
    var messages: [ChatMessage]
    var maxTokens: Int?
    var temperature: Double?

    init(
        modelID: String,
        messages: [ChatMessage],
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        self.modelID = modelID
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

struct CompletionResponse: Equatable, Sendable {
    var text: String
}

/// Deliberately key-free payloads: no case carries the API key or request
/// headers, so error descriptions can never leak credentials.
enum ProviderError: Error, Equatable {
    case invalidKey
    case rateLimited
    case http(Int)
    case malformedResponse
    case transport
}

protocol CloudProviderClient: Sendable {
    func validate(apiKey: SecretValue) async throws
    func fetchModels(apiKey: SecretValue) async throws -> [CloudModelDescriptor]
    func complete(request: CompletionRequest, apiKey: SecretValue) async throws
        -> CompletionResponse
}

/// Seam over URLSession so provider tests run against recorded fixtures.
protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        session = URLSession(configuration: configuration)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.transport
        }
        return (data, http)
    }
}
