
import XCTest
import Foundation
@testable import Zign

final class ProvisioningProfileCertificateInspectorEdgeCaseTests: XCTestCase {

    func testRejectsInvalidEmbeddedCertificate() {
        let invalidCertificate = der(
            0x30,
            Data([0x01])
        )

        let cms = makeCMS(certificates: [invalidCertificate])

        XCTAssertThrowsError(
            try ProvisioningProfileCertificateInspector.inspect(data: cms)
        ) { error in
            XCTAssertEqual(
                error as? ProvisioningProfileCertificateInspectorError,
                .invalidCertificate
            )
        }
    }

    func testRejectsTrailingBytesAfterCMS() {
        var cms = makeCMS(certificates: [])
        cms.append(contentsOf: [0x00, 0x00])

        XCTAssertThrowsError(
            try ProvisioningProfileCertificateInspector.inspect(data: cms)
        ) { error in
            XCTAssertEqual(
                error as? ProvisioningProfileCertificateInspectorError,
                .invalidCMS
            )
        }
    }

    func testRejectsMoreThanSixteenCertificates() {
        let certificates = (0..<17).map { _ in
            der(0x30, Data([0x01]))
        }

        let cms = makeCMS(certificates: certificates)

        XCTAssertThrowsError(
            try ProvisioningProfileCertificateInspector.inspect(data: cms)
        ) { error in
            XCTAssertEqual(
                error as? ProvisioningProfileCertificateInspectorError,
                .missingCertificates
            )
        }
    }

    private func makeCMS(certificates: [Data]) -> Data {
        let signedDataOID = Data([
            0x2A, 0x86, 0x48, 0x86, 0xF7,
            0x0D, 0x01, 0x07, 0x02
        ])

        let dataOID = Data([
            0x2A, 0x86, 0x48, 0x86, 0xF7,
            0x0D, 0x01, 0x07, 0x01
        ])

        let encapsulatedContent = der(
            0x30,
            der(0x06, dataOID)
        )

        let certificateSet = der(
            0xA0,
            certificates.reduce(into: Data()) { result, certificate in
                result.append(certificate)
            }
        )

        let signedData = der(
            0x30,
            der(0x02, Data([0x01])) +
            der(0x31, Data()) +
            encapsulatedContent +
            certificateSet +
            der(0x31, Data())
        )

        return der(
            0x30,
            der(0x06, signedDataOID) +
            der(0xA0, signedData)
        )
    }

    private func der(_ tag: UInt8, _ content: Data) -> Data {
        var result = Data([tag])
        let count = content.count

        if count < 128 {
            result.append(UInt8(count))
        } else {
            var value = count
            var bytes: [UInt8] = []

            while value > 0 {
                bytes.insert(UInt8(value & 0xFF), at: 0)
                value >>= 8
            }

            result.append(0x80 | UInt8(bytes.count))
            result.append(contentsOf: bytes)
        }

        result.append(content)
        return result
    }
}
