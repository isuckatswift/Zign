import XCTest
import Foundation
import ZIPFoundation
@testable import Zign

final class IPAInspectorTests: XCTestCase {

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

    func testInspectsValidIPA() throws {
        let plist: [String: Any] = [
            "CFBundleDisplayName": "Zign Test",
            "CFBundleIdentifier": "com.example.zign",
            "CFBundleShortVersionString": "1.2.0",
            "CFBundleVersion": "12",
            "MinimumOSVersion": "17.0",
            "CFBundleIcons": [
                "CFBundlePrimaryIcon": [
                    "CFBundleIconFiles": ["AppIcon"]
                ]
            ]
        ]

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        let ipa = try makeIPA(entries: [
            ("Payload/Zign.app/Info.plist", plistData)
        ])

        let result = try IPAInspection.inspect(at: ipa)

        XCTAssertEqual(result.appName, "Zign Test")
        XCTAssertEqual(result.bundleIdentifier, "com.example.zign")
        XCTAssertEqual(result.version, "1.2.0")
        XCTAssertEqual(result.buildNumber, "12")
        XCTAssertEqual(result.minimumiOSVersion, "17.0")
        XCTAssertEqual(result.iconName, "AppIcon")
    }

    func testRejectsInvalidArchive() throws {
        let ipa = temporaryDirectory
            .appendingPathComponent("invalid.ipa")

        try Data([0x01, 0x02, 0x03, 0x04]).write(to: ipa)

        XCTAssertThrowsError(
            try IPAInspection.inspect(at: ipa)
        )
    }

    func testRejectsArchiveWithoutInfoPlist() throws {
        let ipa = try makeIPA(entries: [])

        XCTAssertThrowsError(
            try IPAInspection.inspect(at: ipa)
        )
    }

    func testRejectsMultipleApplicationInfoPlists() throws {
        let plistData = try makeInfoPlist()

        let ipa = try makeIPA(entries: [
            ("Payload/First.app/Info.plist", plistData),
            ("Payload/Second.app/Info.plist", plistData)
        ])

        XCTAssertThrowsError(
            try IPAInspection.inspect(at: ipa)
        ) { error in
            XCTAssertEqual(
                error as? IPAInspectionError,
                .ambiguousInfoPlist
            )
        }
    }

    func testRejectsOversizedInfoPlist() throws {
        let oversizedData = Data(
            repeating: 0x41,
            count: 16 * 1024 * 1024 + 1
        )

        let ipa = try makeIPA(entries: [
            ("Payload/Zign.app/Info.plist", oversizedData)
        ])

        XCTAssertThrowsError(
            try IPAInspection.inspect(at: ipa)
        ) { error in
            XCTAssertEqual(
                error as? IPAInspectionError,
                .infoPlistTooLarge
            )
        }
    }

    func testRejectsInfoPlistWithoutBundleIdentifier() throws {
        let plist: [String: Any] = [
            "CFBundleDisplayName": "Incomplete App",
            "CFBundleVersion": "1"
        ]

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        let ipa = try makeIPA(entries: [
            ("Payload/Zign.app/Info.plist", plistData)
        ])

        XCTAssertThrowsError(
            try IPAInspection.inspect(at: ipa)
        ) { error in
            XCTAssertEqual(
                error as? IPAInspectionError,
                .missingBundleIdentifier
            )
        }
    }

    // MARK: - Fixtures

    private func makeInfoPlist() throws -> Data {
        let plist: [String: Any] = [
            "CFBundleDisplayName": "Test App",
            "CFBundleIdentifier": "com.example.test"
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
