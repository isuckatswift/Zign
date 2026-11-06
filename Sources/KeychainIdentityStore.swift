
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

    // All Keychain operations are serialized on a background queue.
    private let keychainQueue = DispatchQueue(
        label: "com.isuckatswift.Zign.keychain",
        qos: .userInitiated
    )

    // MARK: - Public API

    func save(
        identity: SecIdentity
    ) async throws -> StoredSigningIdentity {

        try await withCheckedThrowingContinuation { continuation in
            keychainQueue.async {
                do {
                    let stored = try self.saveSynchronously(
                        identity: identity
                    )
                    continuation.resume(returning: stored)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func loadAll() async throws -> [StoredSigningIdentity] {

        try await withCheckedThrowingContinuation { continuation in
            keychainQueue.async {
                do {
                    let identities = try self.loadAllSynchronously()
                    continuation.resume(returning: identities)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func load(
        identifier: String
    ) async throws -> StoredSigningIdentity? {

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<StoredSigningIdentity?, Error>) in

            keychainQueue.async {
                do {
                    let identity = try self.loadSynchronously(
                        identifier: identifier
                    )
                    continuation.resume(returning: identity)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func remove(identifier: String) async throws {

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            keychainQueue.async {
                do {
                    try self.removeSynchronously(identifier: identifier)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Synchronous Keychain Operations
    // These methods are only called from keychainQueue.

    private func saveSynchronously(
        identity: SecIdentity
    ) throws -> StoredSigningIdentity {

        let storedIdentity = try makeStoredIdentity(identity)

        let query: [String: Any] = [
            kSecValueRef as String: identity,
            kSecAttrLabel as String: labelPrefix + storedIdentity.id
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            if let existing = try loadSynchronously(
                identifier: storedIdentity.id
            ) {
                return existing
            }
        }

        guard status == errSecSuccess else {
            throw KeychainIdentityStoreError.keychainFailure(status)
        }

        return storedIdentity
    }

    private func loadAllSynchronously() throws -> [StoredSigningIdentity] {

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

        guard let result,
              CFGetTypeID(result) == CFArrayGetTypeID(),
              let identities = result as? [Any] else {
            throw KeychainIdentityStoreError.invalidResult
        }

        var storedIdentities: [StoredSigningIdentity] = []
        var seenIdentifiers = Set<String>()

        for item in identities {

            let itemReference = item as CFTypeRef

            guard CFGetTypeID(itemReference) == SecIdentityGetTypeID() else {
                continue
            }

            let identity = itemReference as! SecIdentity

            let candidate = try makeStoredIdentity(identity)

            // Only include identities that can be retrieved using
            // Zign's own exact Keychain label.
            guard let zignIdentity = try loadSynchronously(
                identifier: candidate.id
            ) else {
                continue
            }

            guard !seenIdentifiers.contains(zignIdentity.id) else {
                continue
            }

            seenIdentifiers.insert(zignIdentity.id)
            storedIdentities.append(zignIdentity)
        }

        return storedIdentities
    }

    private func loadSynchronously(
        identifier: String
    ) throws -> StoredSigningIdentity? {

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

        guard let result,
              CFGetTypeID(result) == SecIdentityGetTypeID() else {
            throw KeychainIdentityStoreError.invalidResult
        }

        let identity = result as! SecIdentity

        return try makeStoredIdentity(identity)
    }

    private func removeSynchronously(
        identifier: String
    ) throws {

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

    // MARK: - Identity Metadata

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

// MARK: - Errors

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

