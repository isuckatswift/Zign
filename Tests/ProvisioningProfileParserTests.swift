
import XCTest
import Foundation
@testable import Zign

final class ProvisioningProfileParserTests: XCTestCase {

    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let directory = temporaryDirectory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    func testParsesValidProvisioningProfile() throws {
        let profile = makeProfile()
        let file = try writeFixture(makeCMSProfile(profile))

        let result = try ProvisioningProfileParser.parse(from: file)

        XCTAssertEqual(result.name, "Zign Test Profile")
        XCTAssertEqual(result.uuid, "TEST-UUID-1234")
        XCTAssertEqual(result.teamIdentifier, "TEAM123456")
        XCTAssertEqual(
            result.applicationIdentifier,
            "TEAM123456.com.example.test"
        )
        XCTAssertEqual(result.deviceCount, 2)
        XCTAssertFalse(result.isAllDevices)
        XCTAssertEqual(result.getTaskAllowed, true)
        XCTAssertEqual(result.platforms, ["iOS"])
        XCTAssertEqual(result.developerCertificateCount, 1)
    }

    func testRejectsMalformedDER() throws {
        let file = try writeFixture(Data([0x30, 0x82, 0xFF]))

        XCTAssertThrowsError(
            try ProvisioningProfileParser.parse(from: file)
        ) { error in
            XCTAssertEqual(
                error as? ProvisioningProfileError,
                .invalidDER
            )
        }
    }

    func testRejectsUnsupportedCMSContentType() throws {
        let file = try writeFixture(
            makeCMSProfile(
                Data(),
                contentTypeOID: Data([0x2A, 0x03, 0x04])
            )
        )

        XCTAssertThrowsError(
            try ProvisioningProfileParser.parse(from: file)
        ) { error in
            XCTAssertEqual(
                error as? ProvisioningProfileError,
                .invalidCMS
            )
        }
    }

    func testRejectsCMSWithoutEmbeddedContent() throws {
        let file = try writeFixture(
            makeCMSProfile(Data(), includeContent: false)
        )

        XCTAssertThrowsError(
            try ProvisioningProfileParser.parse(from: file)
        ) { error in
            XCTAssertEqual(
                error as? ProvisioningProfileError,
                .missingContent
            )
        }
    }

    func testRejectsFilesLargerThanTenMegabytes() throws {
        let oversizedData = Data(
            repeating: 0,
            count: 10 * 1024 * 1024 + 1
        )

        let file = try writeFixture(oversizedData)

        XCTAssertThrowsError(
            try ProvisioningProfileParser.parse(from: file)
        ) { error in
            XCTAssertEqual(
                error as? ProvisioningProfileError,
                .fileTooLarge
            )
        }
    }

    // MARK: - Fixtures

    private func makeProfile() -> [String: Any] {
        let certificate = Data([0x01, 0x02, 0x03])

        return [
            "Name": "Zign Test Profile",
            "UUID": "TEST-UUID-1234",
            "TeamIdentifier": ["TEAM123456"],
            "CreationDate": Date(timeIntervalSince1970: 1_700_000_000),
            "ExpirationDate": Date(timeIntervalSince1970: 1_800_000_000),
            "ProvisionedDevices": ["DEVICE-ONE", "DEVICE-TWO"],
            "ProvisionsAllDevices": false,
            "Platform": ["iOS"],
            "DeveloperCertificates": [certificate],
            "Entitlements": [
                "application-identifier": "TEAM123456.com.example.test",
                "get-task-allow": true
            ]
        ]
    }

    private func makeCMSProfile(
        _ profile: [String: Any],
        contentTypeOID: Data? = nil,
        includeContent: Bool = true
    ) throws -> Data {
        let plist = try PropertyListSerialization.data(
            fromPropertyList: profile,
            format: .xml,
            options: 0
        )

        return makeCMSProfile(
            plist,
            contentTypeOID: contentTypeOID,
            includeContent: includeContent
        )
    }

    private func makeCMSProfile(
        _ plist: Data,
        contentTypeOID: Data? = nil,
        includeContent: Bool = true
    ) -> Data {
        let signedDataOID = Data([
            0x2A, 0x86, 0x48, 0x86, 0xF7,
            0x0D, 0x01, 0x07, 0x02
        ])

        let dataOID = Data([
            0x2A, 0x86, 0x48, 0x86, 0xF7,
            0x0D, 0x01, 0x07, 0x01
        ])

        let contentOID = contentTypeOID ?? signedDataOID

        let encapsulatedContent: Data

        if includeContent {
            encapsulatedContent = der(
                0x30,
                der(0x06, dataOID) +
                der(0xA0, der(0x04, plist))
            )
        } else {
            encapsulatedContent = der(
                0x30,
                der(0x06, dataOID)
            )
        }

        let signedData = der(
            0x30,
            der(0x02, Data([0x01])) +
            der(0x31, Data()) +
            encapsulatedContent +
            der(0x31, Data())
        )

        return der(
            0x30,
            der(0x06, contentOID) +
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
            var lengthBytes: [UInt8] = []

            while value > 0 {
                lengthBytes.insert(UInt8(value & 0xFF), at: 0)
                value >>= 8
            }

            result.append(0x80 | UInt8(lengthBytes.count))
            result.append(contentsOf: lengthBytes)
        }

        result.append(content)
        return result
    }

    private func writeFixture(_ data: Data) throws -> URL {
        let file = temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mobileprovision")

        try data.write(to: file)
        return file
    }
}
