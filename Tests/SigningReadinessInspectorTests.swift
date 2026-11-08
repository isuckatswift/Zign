
import XCTest
import Foundation
@testable import Zign

final class SigningReadinessInspectorTests: XCTestCase {

    private let referenceDate = Date(
        timeIntervalSince1970: 1_800_000_000
    )

    func testRegisteredDeviceAndCompatibleProfileAreReady() {
        let ipa = makeIPA()
        let profile = makeProfile(
            deviceIdentifiers: ["DEVICE-UDID-1"]
        )

        let result = inspect(
            ipa: ipa,
            profile: profile,
            target: "DEVICE-UDID-1"
        )

        XCTAssertTrue(result.isReadyForSigning)
        XCTAssertEqual(result.status, "Ready for signing")
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(
            result.deviceCompatibility.matchedDeviceIdentifier,
            "DEVICE-UDID-1"
        )
    }

    func testBundleIdentifierMismatchBlocksReadiness() {
        let ipa = makeIPA(bundleIdentifier: "com.example.other")
        let profile = makeProfile()

        let result = inspect(
            ipa: ipa,
            profile: profile,
            target: "DEVICE-UDID-1"
        )

        XCTAssertFalse(result.isReadyForSigning)
        XCTAssertEqual(result.status, "Not ready for signing")
        XCTAssertTrue(result.errors.contains {
            $0.contains("bundle identifier does not match")
        })
    }

    func testUnregisteredDeviceBlocksReadiness() {
        let ipa = makeIPA()
        let profile = makeProfile(
            deviceIdentifiers: ["DEVICE-UDID-1"]
        )

        let result = inspect(
            ipa: ipa,
            profile: profile,
            target: "DEVICE-UDID-2"
        )

        XCTAssertFalse(result.isReadyForSigning)
        XCTAssertTrue(result.errors.contains {
            $0.contains("target device is not registered")
        })
    }

    func testMissingTargetDeviceProducesWarningsButRemainsReady() {
        let ipa = makeIPA()
        let profile = makeProfile(
            deviceIdentifiers: ["DEVICE-UDID-1"]
        )

        let result = inspect(
            ipa: ipa,
            profile: profile,
            target: nil
        )

        XCTAssertTrue(result.isReadyForSigning)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertNil(result.deviceCompatibility.matchedDeviceIdentifier)
    }

    func testExpiredProfileBlocksReadiness() {
        let ipa = makeIPA()
        let profile = makeProfile(
            expirationDate: referenceDate.addingTimeInterval(-60),
            deviceIdentifiers: ["DEVICE-UDID-1"]
        )

        let result = inspect(
            ipa: ipa,
            profile: profile,
            target: "DEVICE-UDID-1"
        )

        XCTAssertFalse(result.isReadyForSigning)
        XCTAssertTrue(result.errors.contains {
            $0.contains("provisioning profile has expired")
        })
    }

    func testNonIOSProfileBlocksReadiness() {
        let ipa = makeIPA()
        let profile = makeProfile(
            platforms: ["tvOS"],
            deviceIdentifiers: ["DEVICE-UDID-1"]
        )

        let result = inspect(
            ipa: ipa,
            profile: profile,
            target: "DEVICE-UDID-1"
        )

        XCTAssertFalse(result.isReadyForSigning)
        XCTAssertTrue(result.errors.contains {
            $0.contains("does not declare support for iOS")
        })
    }

    func testAllDeviceProfileCanBeReadyWithWarning() {
        let ipa = makeIPA()
        let profile = makeProfile(
            isAllDevices: true,
            deviceIdentifiers: []
        )

        let result = inspect(
            ipa: ipa,
            profile: profile,
            target: nil
        )

        XCTAssertTrue(result.isReadyForSigning)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.warnings.contains {
            $0.contains("all-device profile")
        })
    }

    func testCombinedWarningsContainNoExactDuplicates() {
        let ipa = makeIPA()
        let profile = makeProfile(
            deviceIdentifiers: ["DEVICE-UDID-1"]
        )

        let result = inspect(
            ipa: ipa,
            profile: profile,
            target: nil
        )

        XCTAssertEqual(
            result.warnings.count,
            Set(result.warnings).count
        )
    }

    private func inspect(
        ipa: IPAInspection,
        profile: ImportedProvisioningProfile,
        target: String?
    ) -> SigningReadinessReport {
        SigningReadinessInspector.inspect(
            ipa: ipa,
            profile: profile,
            targetDeviceIdentifier: target,
            now: referenceDate
        )
    }

    private func makeIPA(
        bundleIdentifier: String = "com.example.app"
    ) -> IPAInspection {
        IPAInspection(
            appName: "Zign Test App",
            bundleIdentifier: bundleIdentifier,
            version: "1.0",
            buildNumber: "1",
            minimumiOSVersion: "15.0",
            iconName: nil
        )
    }

    private func makeProfile(
        expirationDate: Date? = Date(
            timeIntervalSince1970: 1_900_000_000
        ),
        platforms: [String] = ["iOS"],
        isAllDevices: Bool = false,
        deviceIdentifiers: [String] = ["DEVICE-UDID-1"]
    ) -> ImportedProvisioningProfile {
        ImportedProvisioningProfile(
            filename: "Zign-Test.mobileprovision",
            name: "Zign Test Profile",
            uuid: "TEST-UUID-1234",
            teamIdentifier: "TEAM123456",
            applicationIdentifier: "TEAM123456.com.example.app",
            creationDate: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            expirationDate: expirationDate,
            deviceCount: deviceIdentifiers.count,
            isAllDevices: isAllDevices,
            getTaskAllowed: true,
            platforms: platforms,
            developerCertificateCount: 0,
            developerCertificates: [],
            certificateMetadata: [],
            provisionedDeviceIdentifiers: deviceIdentifiers
        )
    }
}
