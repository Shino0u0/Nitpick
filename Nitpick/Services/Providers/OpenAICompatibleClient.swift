import Foundation

/// One client covers all four initial providers: their APIs are
/// OpenAI-compatible (`GET /models`, `POST /chat/completions`, bearer auth).
/// Provider-specific response variance is handled by tolerant decoding; no
/// extra headers are sent because none of the official APIs require them.
struct OpenAICompatibleClient: CloudProviderClient {
    let provider: ProviderID
    let transport: any HTTPTransport

    init(provider: ProviderID, transport: any HTTPTransport = URLSessionTransport()) {
        self.provider = provider
        self.transport = transport
    }

    func validate(apiKey: SecretValue) async throws {
        _ = try await fetchModels(apiKey: apiKey)
    }

    func fetchModels(apiKey: SecretValue) async throws -> [CloudModelDescriptor] {
        let data = try await send(
            path: "models", method: "GET", body: nil as Data?, apiKey: apiKey
        )
        guard let list = try? JSONDecoder().decode(ModelListDTO.self, from: data) else {
            throw ProviderError.malformedResponse
        }
        return list.data.map { normalize($0) }
    }

    func complete(
        request: CompletionRequest, apiKey: SecretValue
    ) async throws -> CompletionResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let body = try encoder.encode(ChatRequestDTO(request))
        let data = try await send(
            path: "chat/completions", method: "POST", body: body, apiKey: apiKey
        )
        guard
            let decoded = try? JSONDecoder().decode(ChatResponseDTO.self, from: data),
            let text = decoded.choices.first?.message.content
        else {
            throw ProviderError.malformedResponse
        }
        return CompletionResponse(text: text)
    }

    // MARK: - Transport

    private func send(
        path: String, method: String, body: Data?, apiKey: SecretValue
    ) async throws -> Data {
        var request = URLRequest(url: provider.baseURL.appending(path: path))
        request.httpMethod = method
        request.httpBody = body
        apiKey.withRaw { request.setValue("Bearer \($0)", forHTTPHeaderField: "Authorization") }
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response): (Data, HTTPURLResponse)
        do {
            (data, response) = try await transport.data(for: request)
        } catch let error as ProviderError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ProviderError.transport
        }

        switch response.statusCode {
        case 200...299: return data
        case 401, 403: throw ProviderError.invalidKey
        case 429: throw ProviderError.rateLimited
        default: throw ProviderError.http(response.statusCode)
        }
    }

    // MARK: - Normalization

    private func normalize(_ model: ModelDTO) -> CloudModelDescriptor {
        CloudModelDescriptor(
            provider: provider,
            modelID: model.id,
            displayName: model.name,
            inputModalities: inputModalities(for: model),
            outputModalities: model.architecture?.outputModalities.map(modalitySet),
            contextLength: model.contextLength ?? model.contextWindow,
            maxOutputTokens: model.topProvider?.maxCompletionTokens ?? model.maxCompletionTokens
        )
    }

    private func inputModalities(for model: ModelDTO) -> Set<InputModality> {
        if let explicit = model.architecture?.inputModalities {
            return modalitySet(explicit)
        }
        if Self.auditedVisionModels.contains(AuditedModel(provider: provider, modelID: model.id)) {
            return [.text, .image]
        }
        return [.unknown]
    }

    private func modalitySet(_ raw: [String]) -> Set<InputModality> {
        let known = raw.compactMap(InputModality.init(rawValue:))
        return known.isEmpty ? [.unknown] : Set(known)
    }

    /// Exact model identifiers whose image-input support was manually
    /// verified against provider documentation. Everything not listed here
    /// and without explicit response metadata stays `.unknown`, so screen
    /// context is never attached on a guess.
    private struct AuditedModel: Hashable {
        var provider: ProviderID
        var modelID: String
    }

    private static let auditedVisionModels: Set<AuditedModel> = [
        AuditedModel(provider: .groq, modelID: "meta-llama/llama-4-scout-17b-16e-instruct"),
        AuditedModel(provider: .groq, modelID: "meta-llama/llama-4-maverick-17b-128e-instruct"),
        AuditedModel(provider: .sambaNova, modelID: "Llama-4-Maverick-17B-128E-Instruct"),
    ]
}

// MARK: - Wire DTOs (stay inside the provider layer)

private struct ModelListDTO: Decodable {
    var data: [ModelDTO]
}

private struct ModelDTO: Decodable {
    var id: String
    var name: String?
    var contextLength: Int?
    var contextWindow: Int?
    var maxCompletionTokens: Int?
    var architecture: ArchitectureDTO?
    var topProvider: TopProviderDTO?

    enum CodingKeys: String, CodingKey {
        case id, name, architecture
        case contextLength = "context_length"
        case contextWindow = "context_window"
        case maxCompletionTokens = "max_completion_tokens"
        case topProvider = "top_provider"
    }
}

private struct ArchitectureDTO: Decodable {
    var inputModalities: [String]?
    var outputModalities: [String]?

    enum CodingKeys: String, CodingKey {
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
    }
}

private struct TopProviderDTO: Decodable {
    var maxCompletionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case maxCompletionTokens = "max_completion_tokens"
    }
}

private struct ChatRequestDTO: Encodable {
    var model: String
    var messages: [MessageDTO]
    var maxTokens: Int?
    var temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }

    init(_ request: CompletionRequest) {
        model = request.modelID
        messages = request.messages.map(MessageDTO.init)
        maxTokens = request.maxTokens
        temperature = request.temperature
    }
}

private struct MessageDTO: Encodable {
    var role: String
    var content: ContentDTO

    init(_ message: ChatMessage) {
        role = message.role.rawValue
        if let png = message.imagePNG {
            content = .parts([
                .text(message.text),
                .imageDataURI("data:image/png;base64,\(png.base64EncodedString())"),
            ])
        } else {
            content = .plain(message.text)
        }
    }
}

private enum ContentDTO: Encodable {
    case plain(String)
    case parts([PartDTO])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .plain(let text): try container.encode(text)
        case .parts(let parts): try container.encode(parts)
        }
    }
}

private enum PartDTO: Encodable {
    case text(String)
    case imageDataURI(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: DynamicKey("type"))
            try container.encode(text, forKey: DynamicKey("text"))
        case .imageDataURI(let uri):
            try container.encode("image_url", forKey: DynamicKey("type"))
            var nested = container.nestedContainer(
                keyedBy: DynamicKey.self, forKey: DynamicKey("image_url")
            )
            try nested.encode(uri, forKey: DynamicKey("url"))
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}

private struct ChatResponseDTO: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            var content: String?
        }
        var message: Message
    }
    var choices: [Choice]
}
