
import Foundation
import Security
import SwiftUI

@MainActor
final class CertificateStore: ObservableObject {
    @Published private(set) var certificates: [StoredSigningIdentity] = []
    @Published private(set) var isLoading = false

    private let keychainStore = KeychainIdentityStore()

    private let importQueue = DispatchQueue(
        label: "com.isuckatswift.Zign.certificate-import",
        qos: .userInitiated
    )

    func loadCertificates() async throws {
        isLoading = true
        defer { isLoading = false }

        certificates = try await keychainStore.loadAll()
    }

    func importPKCS12(
        from url: URL,
        password: String
    ) async throws {
        let hasAccess = url.startAccessingSecurityScopedResource()

        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard hasAccess else {
            throw CertificateStoreError.accessDenied
        }

        let identity = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<SecIdentity, Error>) in

            importQueue.async {
                do {
                    let data = try Data(contentsOf: url)

                    let options = [
                        kSecImportExportPassphrase as String: password
                    ] as CFDictionary

                    var importedItems: CFArray?

                    let status = SecPKCS12Import(
                        data as CFData,
                        options,
                        &importedItems
                    )

                    guard status == errSecSuccess else {
                        throw CertificateStoreError.importFailed(status)
                    }

                    guard
                        let items = importedItems as? [[String: Any]],
                        let firstItem = items.first,
                        let identityValue = firstItem[
                            kSecImportItemIdentity as String
                        ],
                        CFGetTypeID(identityValue as CFTypeRef)
                            == SecIdentityGetTypeID()
                    else {
                        throw CertificateStoreError.identityNotFound
                    }

                    let identity = identityValue as! SecIdentity
                    continuation.resume(returning: identity)

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        let storedIdentity = try await keychainStore.save(
            identity: identity
        )

        if !certificates.contains(where: {
            $0.id == storedIdentity.id
        }) {
            certificates.append(storedIdentity)
        }
    }

    func remove(_ certificate: StoredSigningIdentity) async throws {
        try await keychainStore.remove(identifier: certificate.id)

        certificates.removeAll {
            $0.id == certificate.id
        }
    }
}

enum CertificateStoreError: LocalizedError {
    case accessDenied
    case importFailed(OSStatus)
    case identityNotFound

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Zign could not access the selected certificate file."

        case .importFailed(let status):
            if status == errSecAuthFailed {
                return "The certificate password is incorrect or the file is invalid."
            }

            return "Certificate import failed. Security error: \(status)."

        case .identityNotFound:
            return "No valid signing identity was found in this PKCS#12 file."
        }
    }
}
