import Foundation
import CryptoKit
import SwiftASN1
import X509

struct DeveloperCertificateMetadata: Sendable {
    let subjectCommonName: String?
    let issuerCommonName: String?
    let notValidBefore: Date
    let notValidAfter: Date
    let sha256Fingerprint: String

    func isValid(at date: Date) -> Bool {
        date >= notValidBefore && date <= notValidAfter
    }
}

struct DeveloperCertificateInspectionReport: Sendable {
    let certificates: [DeveloperCertificateMetadata]
    let errors: [String]
    let warnings: [String]
    let evaluatedAt: Date

    var usableCertificates: [DeveloperCertificateMetadata] {
        certificates.filter {
            $0.isValid(at: evaluatedAt)
        }
    }

    var hasUsableCertificate: Bool {
        !usableCertificates.isEmpty
    }
}

enum DeveloperCertificateInspectorError: LocalizedError {
    case tooManyCertificates
    case certificateTooLarge
    case invalidCertificate

    var errorDescription: String? {
        switch self {
        case .tooManyCertificates:
            return "The profile contains too many developer certificates."
        case .certificateTooLarge:
            return "A developer certificate exceeds the size limit."
        case .invalidCertificate:
            return "A developer certificate could not be parsed."
        }
    }
}

enum DeveloperCertificateInspector {

    private static let maximumCertificateCount = 16
    private static let maximumCertificateSize = 1024 * 1024

    static func inspect(
        certificates: [Data],
        now: Date = Date()
    ) throws -> DeveloperCertificateInspectionReport {

        guard certificates.count <= maximumCertificateCount else {
            throw DeveloperCertificateInspectorError.tooManyCertificates
        }

        var metadata: [DeveloperCertificateMetadata] = []

        for data in certificates {
            guard !data.isEmpty,
                  data.count <= maximumCertificateSize else {
                throw DeveloperCertificateInspectorError.certificateTooLarge
            }

            do {
                let node = try DER.parse(Array(data))
                let certificate = try Certificate(derEncoded: node)

                let fingerprint = SHA256.hash(data: data)
                    .map { String(format: "%02x", $0) }
                    .joined()

                metadata.append(
                    DeveloperCertificateMetadata(
                        subjectCommonName: commonName(certificate.subject),
                        issuerCommonName: commonName(certificate.issuer),
                        notValidBefore: certificate.notValidBefore,
                        notValidAfter: certificate.notValidAfter,
                        sha256Fingerprint: fingerprint
                    )
                )
            } catch {
                throw DeveloperCertificateInspectorError.invalidCertificate
            }
        }

        let validCertificates = metadata.filter {
            $0.isValid(at: now)
        }

        var errors: [String] = []
        var warnings: [String] = []

        if metadata.isEmpty {
            errors.append(
                "The provisioning profile contains no developer certificates."
            )
        } else if validCertificates.isEmpty {
            errors.append(
                "None of the developer certificates are currently valid."
            )
        }

        if validCertificates.count < metadata.count {
            warnings.append(
                "One or more developer certificates are outside their validity period."
            )
        }

        return DeveloperCertificateInspectionReport(
            certificates: metadata,
            errors: errors,
            warnings: warnings,
            evaluatedAt: now
        )
    }

    private static func commonName(
        _ distinguishedName: DistinguishedName
    ) -> String? {

        for relativeName in distinguishedName {
            for attribute in relativeName {
                if attribute.type == .RDNAttributeType.commonName {
                    return String(attribute.value)
                }
            }
        }

        return nil
    }
}
