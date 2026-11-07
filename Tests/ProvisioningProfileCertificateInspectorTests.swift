
import XCTest
import Foundation
@testable import Zign

final class ProvisioningProfileCertificateInspectorTests: XCTestCase {

    func testRejectsMalformedCMS() {
        XCTAssertThrowsError(
            try ProvisioningProfileCertificateInspector.inspect(
                data: Data([0x30, 0x82, 0xFF])
            )
        )
    }

    func testRejectsCMSWithoutCertificates() {
        let data = makeCMSWithoutCertificates()

        XCTAssertThrowsError(
            try ProvisioningProfileCertificateInspector.inspect(
                data: data
            )
        ) { error in
            XCTAssertEqual(
                error as? ProvisioningProfileCertificateInspectorError,
                .missingCertificates
            )
        }
    }

    func testRejectsEmptyInput() {
        XCTAssertThrowsError(
            try ProvisioningProfileCertificateInspector.inspect(
                data: Data()
            )
        )
    }

    private func makeCMSWithoutCertificates() -> Data {
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

        let signedData = der(
            0x30,
            der(0x02, Data([0x01])) +
            der(0x31, Data()) +
            encapsulatedContent +
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
