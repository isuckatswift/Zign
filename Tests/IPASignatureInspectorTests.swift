import XCTest
import Foundation
import ZIPFoundation
@testable import Zign

final class IPASignatureInspectorTests: XCTestCase {

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

    func testDetectsPresentSignatureArtifacts() throws {
        let ipa = try makeIPA(entries: [
            ("Payload/Zign.app/Info.plist", makeInfoPlist()),
            (
                "Payload/Zign.app/_CodeSignature/CodeResources",
                Data([0x01, 0x02, 0x03])
            ),
            (
                "Payload/Zign.app/embedded.mobileprovision",
                Data([0x04, 0x05, 0x06])
            )
        ])

        let result = try IPASignatureInspector.inspect(at: ipa)

        XCTAssertEqual(result.appBundlePath, "Payload/Zign.app/")
        XCTAssertTrue(result.hasCodeResources)
        XCTAssertTrue(result.hasEmbeddedProvisioningProfile)
        XCTAssertTrue(result.missingArtifacts.isEmpty)
        XCTAssertFalse(result.cryptographicVerificationPerformed)
    }

    func testDetectsMissingSignatureArtifacts() throws {
        let ipa = try makeIPA(entries: [
            ("Payload/Zign.app/Info.plist", makeInfoPlist())
        ])

        let result = try IPASignatureInspector.inspect(at: ipa)

        XCTAssertFalse(result.hasCodeResources)
        XCTAssertFalse(result.hasEmbeddedProvisioningProfile)

        XCTAssertEqual(
            result.missingArtifacts,
            [
                "_CodeSignature/CodeResources",
                "embedded.mobileprovision"
            ]
        )
    }

    func testDetectsMissingProvisioningProfile() throws {
        let ipa = try makeIPA(entries: [
            ("Payload/Zign.app/Info.plist", makeInfoPlist()),
            (
                "Payload/Zign.app/_CodeSignature/CodeResources",
                Data([0x01])
            )
        ])

        let result = try IPASignatureInspector.inspect(at: ipa)

        XCTAssertTrue(result.hasCodeResources)
        XCTAssertFalse(result.hasEmbeddedProvisioningProfile)
        XCTAssertEqual(
            result.missingArtifacts,
            ["embedded.mobileprovision"]
        )
    }

    func testDetectsMissingCodeResources() throws {
        let ipa = try makeIPA(entries: [
            ("Payload/Zign.app/Info.plist", makeInfoPlist()),
            (
                "Payload/Zign.app/embedded.mobileprovision",
                Data([0x01])
            )
        ])

        let result = try IPASignatureInspector.inspect(at: ipa)

        XCTAssertFalse(result.hasCodeResources)
        XCTAssertTrue(result.hasEmbeddedProvisioningProfile)
        XCTAssertEqual(
            result.missingArtifacts,
            ["_CodeSignature/CodeResources"]
        )
    }

    func testRejectsInvalidArchive() throws {
        let ipa = temporaryDirectory
            .appendingPathComponent("invalid.ipa")

        try Data([0x01, 0x02, 0x03]).write(to: ipa)

        XCTAssertThrowsError(
            try IPASignatureInspector.inspect(at: ipa)
        ) { error in
            XCTAssertEqual(
                error as? IPASignatureInspectionError,
                .invalidArchive
            )
        }
    }

    func testRejectsArchiveWithoutAppBundle() throws {
        let ipa = try makeIPA(entries: [])

        XCTAssertThrowsError(
            try IPASignatureInspector.inspect(at: ipa)
        ) { error in
            XCTAssertEqual(
                error as? IPASignatureInspectionError,
                .missingAppBundle
            )
        }
    }

    func testRejectsMultipleAppBundles() throws {
        let plist = try makeInfoPlist()

        let ipa = try makeIPA(entries: [
            ("Payload/First.app/Info.plist", plist),
            ("Payload/Second.app/Info.plist", plist)
        ])

        XCTAssertThrowsError(
            try IPASignatureInspector.inspect(at: ipa)
        ) { error in
            XCTAssertEqual(
                error as? IPASignatureInspectionError,
                .ambiguousAppBundle
            )
        }
    }

    // MARK: - Fixtures

    private func makeInfoPlist() throws -> Data {
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.example.zign",
            "CFBundleName": "Zign"
        ]

        return try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
    }

    private func makeIPA(
        entries: [(path: String, data: Data)]
    ) throws -> URL {
        let archiveURL = temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("ipa")

        let archive = try Archive(
            url: archiveURL,
            accessMode: .create
        )

        for entry in entries {
            let sourceURL = temporaryDirectory
                .appendingPathComponent(UUID().uuidString)

            try entry.data.write(to: sourceURL)

            try archive.addEntry(
                with: entry.path,
                fileURL: sourceURL
            )
        }

        return archiveURL
    }
}
