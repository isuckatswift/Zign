
import XCTest
@testable import Zign

final class ProvisioningProfileCompatibilityInspectorTests: XCTestCase {

    private let evaluationDate = Date(timeIntervalSince1970: 1_800_000_000)

    func testAcceptsMatchingBundleIdentifier() {
        let report = inspect()

        XCTAssertTrue(report.isCompatible)
        XCTAssertTrue(report.errors.isEmpty)
    }

    func testAcceptsSupportedWildcardBundleIdentifier() {
        let report = inspect(
            applicationIdentifier: "TEAM123456.com.example.*"
        )

        XCTAssertTrue(report.isCompatible)
    }

    func testRejectsMismatchedBundleIdentifier() {
        let report = inspect(
            applicationIdentifier: "TEAM123456.com.other.app"
        )

        XCTAssertFalse(report.isCompatible)
        XCTAssertTrue(
            report.errors.contains {
                $0.localizedCaseInsensitiveContains("does not match")
            }
        )
    }

    func testRejectsEmptyIPABundleIdentifier() {
        let report = inspect(
            ipaBundleIdentifier: ""
        )

        XCTAssertFalse(report.isCompatible)
    }

    func testRejectsMissingApplicationIdentifier() {
        let report = inspect(
            applicationIdentifier: nil
        )

        XCTAssertFalse(report.isCompatible)
    }

    func testRejectsMalformedApplicationIdentifier() {
        let report = inspect(
            applicationIdentifier: "com.example.app"
        )

        XCTAssertFalse(report.isCompatible)
    }

    func testRejectsMissingTeamIdentifier() {
        let report = inspect(
            teamIdentifier: nil
        )

        XCTAssertFalse(report.isCompatible)
    }

    func testRejectsMismatchedTeamIdentifier() {
        let report = inspect(
            teamIdentifier: "OTHERTEAM12"
        )

        XCTAssertFalse(report.isCompatible)
    }

    func testRejectsExpiredProfile() {
        let report = inspect(
            expirationDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertFalse(report.isCompatible)
        XCTAssertTrue(
            report.errors.contains {
                $0.localizedCaseInsensitiveContains("expired")
            }
        )
    }

    func testRejectsMissingExpirationDate() {
        let report = inspect(
            expirationDate: nil
        )

        XCTAssertFalse(report.isCompatible)
    }

    func testRejectsProfileWithoutIOSPlatform() {
        let report = inspect(
            platforms: ["macOS"]
        )

        XCTAssertFalse(report.isCompatible)
        XCTAssertTrue(
            report.errors.contains {
                $0.localizedCaseInsensitiveContains(
                    "does not declare support for iOS"
                )
            }
        )
    }

    func testAllDeviceProfileProducesWarning() {
        let report = inspect(
            isAllDevices: true
        )

        XCTAssertTrue(report.isCompatible)
        XCTAssertFalse(report.warnings.isEmpty)
    }

    func testReportWarnsThatSignatureWasNotCryptographicallyVerified() {
        let report = inspect()

        XCTAssertTrue(
            report.warnings.contains {
                $0.localizedCaseInsensitiveContains(
                    "cryptographically verified"
                )
            }
        )
    }

    // MARK: - Test Helpers

    private func inspect(
        ipaBundleIdentifier: String = "com.example.app",
        teamIdentifier: String? = "TEAM123456",
        applicationIdentifier: String? = "TEAM123456.com.example.app",
        expirationDate: Date? = Date(
            timeIntervalSince1970: 1_900_000_000
        ),
        platforms: [String] = ["iOS"],
        isAllDevices: Bool = false
    ) -> ProvisioningProfileCompatibilityReport {

        let ipa = IPAInspection(
            appName: "Zign Test App",
            bundleIdentifier: ipaBundleIdentifier,
            version: "1.0",
            buildNumber: "1",
            minimumiOSVersion: "15.0",
            iconName: nil
        )

        let profile = ImportedProvisioningProfile(
            filename: "Zign-Test.mobileprovision",
            name: "Zign Test Profile",
            uuid: "TEST-UUID-1234",
            teamIdentifier: teamIdentifier,
            applicationIdentifier: applicationIdentifier,
            creationDate: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            expirationDate: expirationDate,
            deviceCount: 1,
            isAllDevices: isAllDevices,
            getTaskAllowed: true,
            platforms: platforms,
            developerCertificateCount: 0,
            developerCertificates: [],
            certificateMetadata: [],
            provisionedDeviceIdentifiers: ["DEVICE-ONE"]
        )

        return ProvisioningProfileCompatibilityInspector.inspect(
            ipa: ipa,
            profile: profile,
            now: evaluationDate
        )
    }
}
