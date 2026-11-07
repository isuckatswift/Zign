
import Foundation
import CryptoKit
import SwiftASN1
import X509

struct ProvisioningProfileCertificateMetadata {
    let subjectCommonName: String?
    let issuerCommonName: String?
    let notValidBefore: Date
    let notValidAfter: Date
    let sha256Fingerprint: String
}

enum ProvisioningProfileCertificateInspectorError: LocalizedError, Equatable {
    case fileTooLarge
    case invalidCMS
    case missingCertificates
    case invalidCertificate
    case invalidDER

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "The provisioning profile exceeds the size limit."
        case .invalidCMS:
            return "The CMS structure is invalid."
        case .missingCertificates:
            return "No embedded certificates were found."
        case .invalidCertificate:
            return "An embedded certificate could not be parsed."
        case .invalidDER:
            return "The CMS contains malformed DER data."
        }
    }
}

private struct CertificateTLV {
    let tag: UInt8
    let content: Range<Int>
    let encoded: Range<Int>
    let nextOffset: Int
}

enum ProvisioningProfileCertificateInspector {

    private static let maximumFileSize = 10 * 1024 * 1024

    private static let signedDataOID = Data([
        0x2A, 0x86, 0x48, 0x86, 0xF7,
        0x0D, 0x01, 0x07, 0x02
    ])

    static func inspect(
        data: Data
    ) throws -> [ProvisioningProfileCertificateMetadata] {

        guard !data.isEmpty else {
            throw ProvisioningProfileCertificateInspectorError.invalidCMS
        }

        guard data.count <= maximumFileSize else {
            throw ProvisioningProfileCertificateInspectorError.fileTooLarge
        }

        var offset = 0

        let root = try readElement(
            in: data,
            at: &offset,
            limit: data.count
        )

        guard root.tag == 0x30,
              root.nextOffset == data.count else {
            throw ProvisioningProfileCertificateInspectorError.invalidCMS
        }

        let rootChildren = try children(of: root, in: data)

        guard rootChildren.count == 2,
              rootChildren[0].tag == 0x06,
              Data(data[rootChildren[0].content]) == signedDataOID,
              rootChildren[1].tag == 0xA0 else {
            throw ProvisioningProfileCertificateInspectorError.invalidCMS
        }

        let explicitChildren = try children(
            of: rootChildren[1],
            in: data
        )

        guard explicitChildren.count == 1,
              let signedData = explicitChildren.first,
              signedData.tag == 0x30 else {
            throw ProvisioningProfileCertificateInspectorError.invalidCMS
        }

        let signedDataChildren = try children(
            of: signedData,
            in: data
        )

        guard signedDataChildren.count >= 4,
              signedDataChildren[0].tag == 0x02,
              signedDataChildren[1].tag == 0x31,
              signedDataChildren[2].tag == 0x30,
              signedDataChildren.last?.tag == 0x31 else {
            throw ProvisioningProfileCertificateInspectorError.invalidCMS
        }

        guard signedDataChildren.count > 4,
              signedDataChildren[3].tag == 0xA0 else {
            throw ProvisioningProfileCertificateInspectorError.missingCertificates
        }

        let certificateSet = signedDataChildren[3]

        // CRLs are optional. SignedData may contain:
        // version, digestAlgorithms, encapContentInfo,
        // certificates, signerInfos
        // or:
        // version, digestAlgorithms, encapContentInfo,
        // certificates, crls, signerInfos
        if signedDataChildren.count > 6 ||
           (signedDataChildren.count == 6 &&
            signedDataChildren[4].tag != 0xA1) {
            throw ProvisioningProfileCertificateInspectorError.invalidCMS
        }

        let certificateElements = try children(
            of: certificateSet,
            in: data
        )

        guard !certificateElements.isEmpty,
              certificateElements.count <= 16 else {
            throw ProvisioningProfileCertificateInspectorError.missingCertificates
        }

        var results: [ProvisioningProfileCertificateMetadata] = []

        for element in certificateElements {
            guard element.tag == 0x30 else {
                throw ProvisioningProfileCertificateInspectorError.invalidCertificate
            }

            let certificateDER = Data(data[element.encoded])

            do {
                let node = try DER.parse(Array(certificateDER))
                let certificate = try Certificate(derEncoded: node)

                let fingerprint = SHA256.hash(data: certificateDER)
                    .map { String(format: "%02x", $0) }
                    .joined()

                results.append(
                    ProvisioningProfileCertificateMetadata(
                        subjectCommonName: commonName(
                            certificate.subject
                        ),
                        issuerCommonName: commonName(
                            certificate.issuer
                        ),
                        notValidBefore: certificate.notValidBefore,
                        notValidAfter: certificate.notValidAfter,
                        sha256Fingerprint: fingerprint
                    )
                )
            } catch {
                throw ProvisioningProfileCertificateInspectorError.invalidCertificate
            }
        }

        guard !results.isEmpty else {
            throw ProvisioningProfileCertificateInspectorError.missingCertificates
        }

        return results
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

    private static func children(
        of element: CertificateTLV,
        in data: Data
    ) throws -> [CertificateTLV] {

        var result: [CertificateTLV] = []
        var offset = element.content.lowerBound
        let limit = element.content.upperBound

        while offset < limit {
            let child = try readElement(
                in: data,
                at: &offset,
                limit: limit
            )

            result.append(child)
        }

        guard offset == limit else {
            throw ProvisioningProfileCertificateInspectorError.invalidDER
        }

        return result
    }

    private static func readElement(
        in data: Data,
        at offset: inout Int,
        limit: Int
    ) throws -> CertificateTLV {

        guard offset < limit,
              limit <= data.count else {
            throw ProvisioningProfileCertificateInspectorError.invalidDER
        }

        let start = offset
        let tag = data[offset]
        offset += 1

        guard offset < limit else {
            throw ProvisioningProfileCertificateInspectorError.invalidDER
        }

        let firstLength = data[offset]
        offset += 1

        let length: Int

        if firstLength & 0x80 == 0 {
            length = Int(firstLength)
        } else {
            let byteCount = Int(firstLength & 0x7F)

            guard byteCount > 0,
                  byteCount <= 4,
                  offset + byteCount <= limit,
                  data[offset] != 0 else {
                throw ProvisioningProfileCertificateInspectorError.invalidDER
            }

            var decodedLength = 0

            for _ in 0..<byteCount {
                guard decodedLength <= Int.max / 256 else {
                    throw ProvisioningProfileCertificateInspectorError.invalidDER
                }

                decodedLength = decodedLength * 256 + Int(data[offset])
                offset += 1
            }

            guard decodedLength >= 128 else {
                throw ProvisioningProfileCertificateInspectorError.invalidDER
            }

            length = decodedLength
        }

        guard length <= limit - offset else {
            throw ProvisioningProfileCertificateInspectorError.invalidDER
        }

        let contentStart = offset
        let contentEnd = contentStart + length
        offset = contentEnd

        return CertificateTLV(
            tag: tag,
            content: contentStart..<contentEnd,
            encoded: start..<contentEnd,
            nextOffset: contentEnd
        )
    }
}
