import Foundation
import Security
import Testing
@testable import Nitpick

struct SecretValueTests {
    @Test func neverRevealsContentInDescriptions() {
        let secret = SecretValue("gsk_live_secret123")
        #expect(!"\(secret)".contains("secret123"))
        #expect(!String(reflecting: secret).contains("secret123"))
    }

    @Test func rawAccessIsScoped() {
        let secret = SecretValue("abc")
        let length = secret.withRaw { $0.count }
        #expect(length == 3)
    }

    @Test func equatableAndEmptiness() {
        #expect(SecretValue("x") == SecretValue("x"))
        #expect(SecretValue("x") != SecretValue("y"))
        #expect(SecretValue("").isEmpty)
    }
}

final class FakeSecItemClient: SecItemClient {
    var addQueries: [[String: Any]] = []
    var updateCalls: [(query: [String: Any], attributes: [String: Any])] = []
    var deleteQueries: [[String: Any]] = []
    var copyQueries: [[String: Any]] = []

    var addStatus: OSStatus = errSecSuccess
    var updateStatus: OSStatus = errSecSuccess
    var deleteStatus: OSStatus = errSecSuccess
    var copyResult: (OSStatus, AnyObject?) = (errSecItemNotFound, nil)

    func add(_ query: [String: Any]) -> OSStatus {
        addQueries.append(query)
        return addStatus
    }

    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        updateCalls.append((query, attributes))
        return updateStatus
    }

    func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) {
        copyQueries.append(query)
        return copyResult
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        deleteQueries.append(query)
        return deleteStatus
    }
}

struct KeychainStoreTests {
    private func makeStore() -> (KeychainStore, FakeSecItemClient) {
        let fake = FakeSecItemClient()
        return (KeychainStore(client: fake), fake)
    }

    @Test func saveBuildsDeviceOnlyUnsyncedQuery() throws {
        let (store, fake) = makeStore()
        try store.save(key: SecretValue("k123"), provider: .groq)

        let query = try #require(fake.addQueries.first)
        #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(query[kSecAttrService as String] as? String == KeychainStore.service)
        #expect(query[kSecAttrAccount as String] as? String == "groq")
        #expect(
            query[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(query[kSecValueData as String] as? Data == Data("k123".utf8))
    }

    @Test func saveFallsBackToUpdateOnDuplicate() throws {
        let (store, fake) = makeStore()
        fake.addStatus = errSecDuplicateItem
        try store.save(key: SecretValue("k2"), provider: .cerebras)

        let call = try #require(fake.updateCalls.first)
        #expect(call.query[kSecAttrAccount as String] as? String == "cerebras")
        #expect(call.attributes[kSecValueData as String] as? Data == Data("k2".utf8))
    }

    @Test func saveFailureMapsStatus() {
        let (store, fake) = makeStore()
        fake.addStatus = errSecInteractionNotAllowed
        #expect(throws: KeychainError.saveFailed(errSecInteractionNotAllowed)) {
            try store.save(key: SecretValue("k"), provider: .groq)
        }
    }

    @Test func readReturnsStoredSecret() throws {
        let (store, fake) = makeStore()
        fake.copyResult = (errSecSuccess, Data("stored".utf8) as AnyObject)
        let secret = try store.read(provider: .openRouter)
        #expect(secret == SecretValue("stored"))
        let query = try #require(fake.copyQueries.first)
        #expect(query[kSecAttrAccount as String] as? String == "openRouter")
        #expect(query[kSecReturnData as String] as? Bool == true)
    }

    @Test func readMissingItemReturnsNil() throws {
        let (store, _) = makeStore()
        #expect(try store.read(provider: .groq) == nil)
    }

    @Test func readFailureMapsStatus() {
        let (store, fake) = makeStore()
        fake.copyResult = (errSecAuthFailed, nil)
        #expect(throws: KeychainError.readFailed(errSecAuthFailed)) {
            try store.read(provider: .groq)
        }
    }

    @Test func deleteIsIdempotent() throws {
        let (store, fake) = makeStore()
        fake.deleteStatus = errSecItemNotFound
        try store.delete(provider: .sambaNova)
        let query = try #require(fake.deleteQueries.first)
        #expect(query[kSecAttrAccount as String] as? String == "sambaNova")
    }

    @Test func deleteFailureMapsStatus() {
        let (store, fake) = makeStore()
        fake.deleteStatus = errSecInteractionNotAllowed
        #expect(throws: KeychainError.deleteFailed(errSecInteractionNotAllowed)) {
            try store.delete(provider: .groq)
        }
    }
}
