
import Foundation
import Security
import SwiftUI

struct ImportedCertificate: Identifiable {
    let id = UUID()
    let identity: SecIdentity
    let displayName: String
}

@MainActor
final class CertificateStore: ObservableObject {
    @Published private(set) var certificates: [ImportedCertificate] = []

    func importPKCS12(from url: URL, password: String) throws {
        let hasAccess = url.startAccessingSecurityScopedResource()

        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

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
            ]
        else {
            throw CertificateStoreError.identityNotFound
        }

        let identity = identityValue as! SecIdentity

        var certificate: SecCertificate?

        let certificateStatus = SecIdentityCopyCertificate(
            identity,
            &certificate
        )

        guard
            certificateStatus == errSecSuccess,
            let certificate
        else {
            throw CertificateStoreError.certificateNotFound
        }

        let displayName =
            SecCertificateCopySubjectSummary(certificate) as String?
            ?? url.deletingPathExtension().lastPathComponent

        certificates.append(
            ImportedCertificate(
                identity: identity,
                displayName: displayName
            )
        )
    }

    func remove(_ certificate: ImportedCertificate) {
        certificates.removeAll { $0.id == certificate.id }
    }
}

enum CertificateStoreError: LocalizedError {
    case importFailed(OSStatus)
    case identityNotFound
    case certificateNotFound

    var errorDescription: String? {
        switch self {
        case .importFailed(let status):
            if status == errSecAuthFailed {
                return "The certificate password is incorrect or the file is invalid."
            }

            return "Certificate import failed. Security error: \(status)."

        case .identityNotFound:
            return "No signing identity was found in this PKCS#12 file."

        case .certificateNotFound:
            return "The certificate could not be read from the signing identity."
        }
    }
}
