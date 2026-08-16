import Foundation
import Testing
@testable import Nitpick

// MARK: - Sanitized fixtures (no real keys, shapes match provider docs)

private let groqModelsFixture = """
{"object":"list","data":[
  {"id":"llama-3.3-70b-versatile","object":"model","owned_by":"Meta","context_window":131072},
  {"id":"meta-llama/llama-4-scout-17b-16e-instruct","object":"model","owned_by":"Meta","context_window":131072}
]}
"""

private let openRouterModelsFixture = """
{"data":[
  {"id":"anthropic/claude-sonnet-4.5","name":"Claude Sonnet 4.5","context_length":1000000,
   "architecture":{"input_modalities":["text","image"],"output_modalities":["text"]},
   "top_provider":{"max_completion_tokens":64000}},
  {"id":"some/text-only-model","name":"Text Only","context_length":32768,
   "architecture":{"input_modalities":["text"],"output_modalities":["text"]}}
]}
"""

private let completionFixture = """
{"id":"chatcmpl-1","object":"chat.completion",
 "choices":[{"index":0,"message":{"role":"assistant","content":"Improved text."},"finish_reason":"stop"}]}
"""

// MARK: - Fake transport

final class FakeTransport: HTTPTransport, @unchecked Sendable {
    var requests: [URLRequest] = []
    var responses: [(Data, Int)] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let (data, status) = responses.isEmpty ? (Data(), 200) : responses.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return (data, response)
    }
}

struct ProviderClientTests {
    private let key = SecretValue("test-key-not-real")

    private func makeClient(
        _ provider: ProviderID, fixture: String, status: Int = 200
    ) -> (OpenAICompatibleClient, FakeTransport) {
        let transport = FakeTransport()
        transport.responses = [(Data(fixture.utf8), status)]
        return (OpenAICompatibleClient(provider: provider, transport: transport), transport)
    }

    // MARK: Model discovery

    @Test func fetchModelsRequestsModelsEndpointWithBearer() async throws {
        let (client, transport) = makeClient(.groq, fixture: groqModelsFixture)
        _ = try await client.fetchModels(apiKey: key)

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://api.groq.com/openai/v1/models")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key-not-real")
    }

    @Test func groqModelsNormalizeWithAuditedVision() async throws {
        let (client, _) = makeClient(.groq, fixture: groqModelsFixture)
        let models = try await client.fetchModels(apiKey: key)

        #expect(models.count == 2)
        let plain = try #require(models.first { $0.modelID == "llama-3.3-70b-versatile" })
        #expect(plain.provider == .groq)
        #expect(plain.inputModalities == [.unknown])
        #expect(!plain.supportsImageInput)
        #expect(plain.contextLength == 131072)

        let scout = try #require(
            models.first { $0.modelID == "meta-llama/llama-4-scout-17b-16e-instruct" }
        )
        #expect(scout.supportsImageInput)
    }

    @Test func openRouterModelsNormalizeFromExplicitMetadata() async throws {
        let (client, _) = makeClient(.openRouter, fixture: openRouterModelsFixture)
        let models = try await client.fetchModels(apiKey: key)

        let vision = try #require(models.first { $0.modelID == "anthropic/claude-sonnet-4.5" })
        #expect(vision.displayName == "Claude Sonnet 4.5")
        #expect(vision.supportsImageInput)
        #expect(vision.inputModalities.contains(.text))
        #expect(vision.contextLength == 1_000_000)
        #expect(vision.maxOutputTokens == 64000)

        let textOnly = try #require(models.first { $0.modelID == "some/text-only-model" })
        #expect(!textOnly.supportsImageInput)
        #expect(textOnly.inputModalities == [.text])
    }

    @Test func validateSucceedsOnModelList() async throws {
        let (client, _) = makeClient(.cerebras, fixture: groqModelsFixture)
        try await client.validate(apiKey: key)
    }

    // MARK: Completion

    @Test func completePostsChatCompletion() async throws {
        let (client, transport) = makeClient(.sambaNova, fixture: completionFixture)
        let request = CompletionRequest(
            modelID: "Meta-Llama-3.3-70B-Instruct",
            messages: [
                ChatMessage(role: .system, text: "Improve the text."),
                ChatMessage(role: .user, text: "helo world"),
            ]
        )
        let response = try await client.complete(request: request, apiKey: key)
        #expect(response.text == "Improved text.")

        let sent = try #require(transport.requests.first)
        #expect(sent.url?.absoluteString == "https://api.sambanova.ai/v1/chat/completions")
        #expect(sent.httpMethod == "POST")
        let body = try #require(sent.httpBody)
        let json = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        #expect(json["model"] as? String == "Meta-Llama-3.3-70B-Instruct")
        #expect((json["messages"] as? [[String: Any]])?.count == 2)
    }

    @Test func completeEncodesImageAsDataURI() async throws {
        let (client, transport) = makeClient(.openRouter, fixture: completionFixture)
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let request = CompletionRequest(
            modelID: "anthropic/claude-sonnet-4.5",
            messages: [ChatMessage(role: .user, text: "what is on screen", imagePNG: png)]
        )
        _ = try await client.complete(request: request, apiKey: key)

        let body = try #require(transport.requests.first?.httpBody)
        let text = String(decoding: body, as: UTF8.self)
        #expect(text.contains("data:image/png;base64,\(png.base64EncodedString())"))
        #expect(text.contains("image_url"))
    }

    // MARK: Errors

    @Test func unauthorizedMapsToInvalidKey() async {
        let (client, _) = makeClient(.groq, fixture: "{}", status: 401)
        await #expect(throws: ProviderError.invalidKey) {
            _ = try await client.fetchModels(apiKey: key)
        }
    }

    @Test func rateLimitMapsToRateLimited() async {
        let (client, _) = makeClient(.groq, fixture: "{}", status: 429)
        await #expect(throws: ProviderError.rateLimited) {
            _ = try await client.fetchModels(apiKey: key)
        }
    }

    @Test func serverErrorMapsToHTTPStatus() async {
        let (client, _) = makeClient(.groq, fixture: "oops", status: 500)
        await #expect(throws: ProviderError.http(500)) {
            _ = try await client.fetchModels(apiKey: key)
        }
    }

    @Test func malformedBodyMapsToMalformedResponse() async {
        let (client, _) = makeClient(.groq, fixture: "not json")
        await #expect(throws: ProviderError.malformedResponse) {
            _ = try await client.fetchModels(apiKey: key)
        }
    }

    @Test func errorsNeverContainTheKey() async {
        let (client, _) = makeClient(.groq, fixture: "{}", status: 401)
        do {
            _ = try await client.fetchModels(apiKey: key)
            Issue.record("expected throw")
        } catch {
            #expect(!String(describing: error).contains("test-key-not-real"))
            #expect(!String(reflecting: error).contains("test-key-not-real"))
        }
    }
}
