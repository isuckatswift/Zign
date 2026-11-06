
import Foundation
import Security
import CryptoKit

struct StoredSigningIdentity: Identifiable {
    let id: String
    let identity: SecIdentity
    let displayName: String
}

final class KeychainIdentityStore {

    private let labelPrefix = "com.isuckatswift.Zign.identity."

    func save(identity: SecIdentity) throws -> StoredSigningIdentity {
        let storedIdentity = try makeStoredIdentity(identity)

        let query: [String: Any] = [
            kSecValueRef as String: identity,
            kSecAttrLabel as String: labelPrefix + storedIdentity.id
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            if let existing = try load(identifier: storedIdentity.id) {
                return existing
            }
        }

        guard status == errSecSuccess else {
            throw KeychainIdentityStoreError.keychainFailure(status)
        }

        return storedIdentity
    }

    func loadAll() throws -> [StoredSigningIdentity] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        if status == errSecItemNotFound {
            return []
        }

        guard status == errSecSuccess else {
            throw KeychainIdentityStoreError.keychainFailure(status)
        }

        guard let identities = result as? [SecIdentity] else {
            throw KeychainIdentityStoreError.invalidResult
        }

        return try identities.map {
            try makeStoredIdentity($0)
        }
    }

    func load(identifier: String) throws -> StoredSigningIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: labelPrefix + identifier,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainIdentityStoreError.keychainFailure(status)
        }

        guard let identity = result as? SecIdentity else {
            throw KeychainIdentityStoreError.invalidResult
        }

        return try makeStoredIdentity(identity)
    }

    func remove(identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: labelPrefix + identifier
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess ||
              status == errSecItemNotFound else {
            throw KeychainIdentityStoreError.keychainFailure(status)
        }
    }

    private func makeStoredIdentity(
        _ identity: SecIdentity
    ) throws -> StoredSigningIdentity {

        var certificate: SecCertificate?

        let status = SecIdentityCopyCertificate(
            identity,
            &certificate
        )

        guard status == errSecSuccess,
              let certificate else {
            throw KeychainIdentityStoreError.certificateUnavailable
        }

        let certificateData = SecCertificateCopyData(certificate) as Data

        let digest = SHA256.hash(data: certificateData)

        let identifier = digest
            .map { String(format: "%02x", $0) }
            .joined()

        let displayName =
            SecCertificateCopySubjectSummary(certificate) as String?
            ?? "Unknown Certificate"

        return StoredSigningIdentity(
            id: identifier,
            identity: identity,
            displayName: displayName
        )
    }
}

enum KeychainIdentityStoreError: LocalizedError {

    case keychainFailure(OSStatus)
    case certificateUnavailable
    case invalidResult

    var errorDescription: String? {
        switch self {

        case .keychainFailure(let status):
            return "Keychain operation failed. Security error: \(status)."

        case .certificateUnavailable:
            return "The signing identity does not contain a readable certificate."

        case .invalidResult:
            return "The keychain returned an unexpected result."
        }
    }
}
