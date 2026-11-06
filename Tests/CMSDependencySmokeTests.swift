
import Foundation
import XCTest
import Crypto
@_spi(CMS) import X509

final class CMSDependencySmokeTests: XCTestCase {

    private static let rootKey = Certificate.PrivateKey(
        P256.Signing.PrivateKey()
    )

    private static let rootName = try! DistinguishedName {
        CommonName("Zign Test Root CA")
    }

    private static let rootCertificate = try! Certificate(
        version: .v3,
        serialNumber: .init(),
        publicKey: rootKey.publicKey,
        notValidBefore: Date().addingTimeInterval(-60),
        notValidAfter: Date().addingTimeInterval(60 * 60 * 24 * 365),
        issuer: rootName,
        subject: rootName,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try! Certificate.Extensions {
            Critical(
                BasicConstraints.isCertificateAuthority(maxPathLength: nil)
            )
        },
        issuerPrivateKey: rootKey
    )

    private static let signerKey = Certificate.PrivateKey(
        P256.Signing.PrivateKey()
    )

    private static let signerName = try! DistinguishedName {
        CommonName("Zign Test Signer")
    }

    private static let signerCertificate = try! Certificate(
        version: .v3,
        serialNumber: .init(),
        publicKey: signerKey.publicKey,
        notValidBefore: Date().addingTimeInterval(-60),
        notValidAfter: Date().addingTimeInterval(60 * 60 * 24 * 365),
        issuer: rootName,
        subject: signerName,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try! Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
        },
        issuerPrivateKey: rootKey
    )

    private let payload = Data(
        "Zign CMS verification test".utf8
    )

    private func makeAttachedSignature() throws -> [UInt8] {
        try CMS.sign(
            payload,
            certificate: Self.signerCertificate,
            privateKey: Self.signerKey,
            detached: false
        )
    }

    func testAcceptsValidAttachedSignature() async throws {
        let signature = try makeAttachedSignature()

        let result = await CMS.isValidAttachedSignature(
            signatureBytes: signature,
            trustRoots: CertificateStore([Self.rootCertificate])
        ) {
            RFC5280Policy()
        }

        if case .success = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("A valid signature from the trusted test chain was rejected.")
        }
    }

    func testRejectsModifiedSignature() async throws {
        var signature = try makeAttachedSignature()

        guard !signature.isEmpty else {
            XCTFail("The generated CMS signature was empty.")
            return
        }

        signature[signature.count - 1] ^= 0x01

        let result = await CMS.isValidAttachedSignature(
            signatureBytes: signature,
            trustRoots: CertificateStore([Self.rootCertificate])
        ) {
            RFC5280Policy()
        }

        if case .failure = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("A modified CMS signature was accepted.")
        }
    }

    func testRejectsUntrustedSigner() async throws {
        let signature = try makeAttachedSignature()

        let result = await CMS.isValidAttachedSignature(
            signatureBytes: signature,
            trustRoots: CertificateStore()
        ) {
            RFC5280Policy()
        }

        if case .failure = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("A signature from an untrusted signer was accepted.")
        }
    }
}
