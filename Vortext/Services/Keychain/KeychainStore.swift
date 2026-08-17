import Foundation
import Security

enum KeychainError: Error, Equatable {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
}

/// Seam over the four SecItem calls so tests can assert query construction
/// and status mapping without touching the real Keychain.
protocol SecItemClient: AnyObject {
    func add(_ query: [String: Any]) -> OSStatus
    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus
    func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?)
    func delete(_ query: [String: Any]) -> OSStatus
}

final class SystemSecItemClient: SecItemClient {
    func add(_ query: [String: Any]) -> OSStatus {
        SecItemAdd(query as CFDictionary, nil)
    }

    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) {
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result)
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}

/// One generic-password item per provider: device-only, unlocked-only,
/// never synchronized, no shared access group.
struct KeychainStore {
    static let service = "io.github.shino0u0.Vortext"

    private let client: SecItemClient

    init(client: SecItemClient = SystemSecItemClient()) {
        self.client = client
    }

    func save(key: SecretValue, provider: ProviderID) throws {
        var query = baseQuery(for: provider)
        query[kSecAttrAccessible as String] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        query[kSecValueData as String] = key.withRaw { Data($0.utf8) }

        let status = client.add(query)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributes: [String: Any] = [
                kSecValueData as String: key.withRaw { Data($0.utf8) }
            ]
            let updateStatus = client.update(baseQuery(for: provider), attributes)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.saveFailed(updateStatus)
            }
        default:
            throw KeychainError.saveFailed(status)
        }
    }

    func read(provider: ProviderID) throws -> SecretValue? {
        var query = baseQuery(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne as String

        let (status, result) = client.copyMatching(query)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8)
            else { throw KeychainError.invalidData }
            return SecretValue(string)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.readFailed(status)
        }
    }

    func delete(provider: ProviderID) throws {
        let status = client.delete(baseQuery(for: provider))
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    private func baseQuery(for provider: ProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: provider.rawValue,
            kSecAttrSynchronizable as String: false,
        ]
    }
}
