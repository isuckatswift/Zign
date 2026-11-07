
import XCTest
import Foundation
@testable import Zign

final class ProvisioningProfileDeviceCompatibilityInspectorTests: XCTestCase {

    func testAcceptsRegisteredDevice() {
        let profile = makeProfile(
            deviceIdentifiers: ["DEVICE-ONE", "DEVICE-TWO"]
        )

        let result = inspect(
            profile: profile,
            target: "DEVICE-ONE"
        )

        XCTAssertTrue(result.isCompatible)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.matchedDeviceIdentifier, "DEVICE-ONE")
    }

    func testRejectsUnregisteredDevice() {
        let profile = makeProfile(
            deviceIdentifiers: ["DEVICE-ONE", "DEVICE-TWO"]
        )

        let result = inspect(
            profile: profile,
            target: "DEVICE-THREE"
        )

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("not registered")
            }
        )
        XCTAssertNil(result.matchedDeviceIdentifier)
    }

    func testDeviceIdentifierMatchingIsCaseInsensitive() {
        let profile = makeProfile(
            deviceIdentifiers: ["abcdef123456"]
        )

        let result = inspect(
            profile: profile,
            target: "ABCDEF123456"
        )

        XCTAssertTrue(result.isCompatible)
        XCTAssertEqual(
            result.matchedDeviceIdentifier,
            "ABCDEF123456"
        )
    }

    func testDeviceIdentifierMatchingTrimsWhitespace() {
        let profile = makeProfile(
            deviceIdentifiers: [" DEVICE-ONE "]
        )

        let result = inspect(
            profile: profile,
            target: "DEVICE-ONE"
        )

        XCTAssertTrue(result.isCompatible)
    }

    func testMissingTargetProducesWarningInsteadOfClaimingMatch() {
        let profile = makeProfile(
            deviceIdentifiers: ["DEVICE-ONE"]
        )

        let result = inspect(
            profile: profile,
            target: nil
        )

        XCTAssertTrue(result.isCompatible)
        XCTAssertNil(result.matchedDeviceIdentifier)
        XCTAssertTrue(
            result.warnings.contains {
                $0.contains("target device identifier was not supplied")
            }
        )
    }

    func testEmptyTargetProducesWarning() {
        let profile = makeProfile(
            deviceIdentifiers: ["DEVICE-ONE"]
        )

        let result = inspect(
            profile: profile,
            target: "   "
        )

        XCTAssertTrue(result.isCompatible)
        XCTAssertNil(result.matchedDeviceIdentifier)
        XCTAssertTrue(
            result.warnings.contains {
                $0.contains("identifier is empty")
            }
        )
    }

    func testRejectsLimitedProfileWithoutRegisteredDevices() {
        let profile = makeProfile(deviceIdentifiers: [])

        let result = inspect(
            profile: profile,
            target: "DEVICE-ONE"
        )

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("contains no registered device identifiers")
            }
        )
    }

    func testAllDeviceProfileDoesNotRequireTargetIdentifier() {
        let profile = makeProfile(
            deviceIdentifiers: [],
            isAllDevices: true
        )

        let result = inspect(
            profile: profile,
            target: nil
        )

        XCTAssertTrue(result.isCompatible)
        XCTAssertNil(result.matchedDeviceIdentifier)
        XCTAssertTrue(
            result.warnings.contains {
                $0.contains("all-device profile")
            }
        )
    }

    func testAllDeviceProfileDoesNotRequireDeviceList() {
        let profile = makeProfile(
            deviceIdentifiers: ["DEVICE-ONE"],
            isAllDevices: true
        )

        let result = inspect(
            profile: profile,
            target: "DEVICE-TWO"
        )

        XCTAssertTrue(result.isCompatible)
        XCTAssertNil(result.matchedDeviceIdentifier)
    }

    // MARK: - Helpers

    private func inspect(
        profile: ImportedProvisioningProfile,
        target: String?
    ) -> ProvisioningProfileDeviceCompatibilityReport {

        ProvisioningProfileDeviceCompatibilityInspector.inspect(
            profile: profile,
            targetDeviceIdentifier: target
        )
    }

    private func makeProfile(
        deviceIdentifiers: [String],
        isAllDevices: Bool = false
    ) -> ImportedProvisioningProfile {

        ImportedProvisioningProfile(
            filename: "Zign-Test.mobileprovision",
            name: "Zign Test Profile",
            uuid: "TEST-UUID-1234",
            teamIdentifier: "TEAM123456",
            applicationIdentifier: "TEAM123456.com.example.app",
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            expirationDate: Date(timeIntervalSince1970: 1_900_000_000),
            deviceCount: deviceIdentifiers.count,
            isAllDevices: isAllDevices,
            getTaskAllowed: true,
            platforms: ["iOS"],
            developerCertificateCount: 1,
            certificateMetadata: [],
            provisionedDeviceIdentifiers: deviceIdentifiers
        )
    }
}
