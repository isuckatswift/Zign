import XCTest
import Foundation
@testable import Zign

final class ProvisioningProfileCompatibilityInspectorTests: XCTestCase {

    private let referenceDate = Date(
        timeIntervalSince1970: 1_800_000_000
    )

    // MARK: - Exact bundle identifier

    func testAcceptsExactBundleIdentifierMatch() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            applicationIdentifier: "TEAM123456.com.example.app"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testRejectsExactBundleIdentifierMismatch() {
        let ipa = makeIPA(bundleIdentifier: "com.example.other")
        let profile = makeProfile(
            applicationIdentifier: "TEAM123456.com.example.app"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("bundle identifier does not match")
            }
        )
    }

    // MARK: - Wildcard bundle identifiers

    func testAcceptsWildcardBundleIdentifierMatch() {
        let ipa = makeIPA(bundleIdentifier: "com.example.testapp")
        let profile = makeProfile(
            applicationIdentifier: "TEAM123456.com.example.*"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testRejectsWildcardWhenBundleIdentifierDoesNotMatch() {
        let ipa = makeIPA(bundleIdentifier: "com.other.app")
        let profile = makeProfile(
            applicationIdentifier: "TEAM123456.com.example.*"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("bundle identifier does not match")
            }
        )
    }

    func testWildcardRequiresAtLeastOneCharacterAfterPrefix() {
        let ipa = makeIPA(bundleIdentifier: "com.example")
        let profile = makeProfile(
            applicationIdentifier: "TEAM123456.com.example.*"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
    }

    func testRejectsWildcardInInvalidPosition() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            applicationIdentifier: "TEAM123456.com.*.app"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
    }

    func testRejectsMultipleWildcards() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            applicationIdentifier: "TEAM123456.com.*.*"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
    }

    func testAcceptsGlobalWildcard() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            applicationIdentifier: "TEAM123456.*"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
    }

    // MARK: - Team identifier

    func testAcceptsMatchingTeamIdentifier() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            teamIdentifier: "TEAM123456",
            applicationIdentifier: "TEAM123456.com.example.app"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
    }

    func testRejectsMismatchedTeamIdentifier() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            teamIdentifier: "OTHERTEAM12",
            applicationIdentifier: "TEAM123456.com.example.app"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("team identifier does not match")
            }
        )
    }

    func testRejectsMissingTeamIdentifier() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(teamIdentifier: nil)

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("does not contain a team identifier")
            }
        )
    }

    // MARK: - Expiration

    func testAcceptsProfileThatHasNotExpired() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            expirationDate: referenceDate.addingTimeInterval(60)
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
    }

    func testRejectsExpiredProfile() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            expirationDate: referenceDate.addingTimeInterval(-60)
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("has expired")
            }
        )
    }

    func testRejectsProfileExpiringAtInspectionTime() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            expirationDate: referenceDate
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
    }

    func testRejectsMissingExpirationDate() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(expirationDate: nil)

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("does not contain an expiration date")
            }
        )
    }

    // MARK: - Platform

    func testAcceptsIOSPlatform() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(platforms: ["iOS"])

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
    }

    func testAcceptsIOSAmongMultiplePlatforms() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            platforms: ["tvOS", "iOS"]
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
    }

    func testRejectsNonIOSPlatform() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(platforms: ["tvOS"])

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("does not declare support for iOS")
            }
        )
    }

    func testRejectsMissingPlatformInformation() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(platforms: [])

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
    }

    // MARK: - Missing application identifier

    func testRejectsMissingApplicationIdentifier() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(applicationIdentifier: nil)

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(
            result.errors.contains {
                $0.contains("does not contain an application identifier")
            }
        )
    }

    func testRejectsMalformedApplicationIdentifier() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            applicationIdentifier: "INVALID"
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertFalse(result.isCompatible)
    }

    // MARK: - Device information and warnings

    func testAllDeviceProfileProducesWarningWithoutBlockingCompatibility() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            isAllDevices: true,
            deviceCount: 0
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
        XCTAssertTrue(
            result.warnings.contains {
                $0.contains("all-device profile")
            }
        )
    }

    func testEmptyLimitedDeviceListProducesWarning() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(
            isAllDevices: false,
            deviceCount: 0
        )

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
        XCTAssertTrue(
            result.warnings.contains {
                $0.contains("no registered device entries")
            }
        )
    }

    func testRegisteredDevicesDoNotClaimSpecificDeviceWasChecked() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile(deviceCount: 3)

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
        XCTAssertTrue(
            result.warnings.contains {
                $0.contains("specific device was not checked")
            }
        )
    }

    // MARK: - IPA metadata warnings

    func testUnknownMinimumIOSVersionProducesWarning() {
        let ipa = makeIPA(
            bundleIdentifier: "com.example.app",
            minimumiOSVersion: "Unknown"
        )
        let profile = makeProfile()

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(result.isCompatible)
        XCTAssertTrue(
            result.warnings.contains {
                $0.contains("minimum iOS version could not be determined")
            }
        )
    }

    func testReportExplainsCryptographicVerificationWasNotPerformed() {
        let ipa = makeIPA(bundleIdentifier: "com.example.app")
        let profile = makeProfile()

        let result = inspect(ipa: ipa, profile: profile)

        XCTAssertTrue(
            result.warnings.contains {
                $0.contains("not cryptographically verified")
            }
        )
    }

    // MARK: - Helpers

    private func inspect(
        ipa: IPAInspection,
        profile: ImportedProvisioningProfile
    ) -> ProvisioningProfileCompatibilityReport {

        ProvisioningProfileCompatibilityInspector.inspect(
            ipa: ipa,
            profile: profile,
            now: referenceDate
        )
    }

    private func makeIPA(
        bundleIdentifier: String,
        minimumiOSVersion: String = "15.0"
    ) -> IPAInspection {

        IPAInspection(
            appName: "Zign Test App",
            bundleIdentifier: bundleIdentifier,
            version: "1.0",
            buildNumber: "1",
            minimumiOSVersion: minimumiOSVersion,
            iconName: nil
        )
    }

    private func makeProfile(
        teamIdentifier: String? = "TEAM123456",
        applicationIdentifier: String? = "TEAM123456.com.example.app",
        expirationDate: Date? = Date(
            timeIntervalSince1970: 1_900_000_000
        ),
        platforms: [String] = ["iOS"],
        deviceCount: Int = 2,
        isAllDevices: Bool = false
    ) -> ImportedProvisioningProfile {

        ImportedProvisioningProfile(
            filename: "Zign-Test.mobileprovision",
            name: "Zign Test Profile",
            uuid: "TEST-UUID-1234",
            teamIdentifier: teamIdentifier,
            applicationIdentifier: applicationIdentifier,
            creationDate: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            expirationDate: expirationDate,
            deviceCount: deviceCount,
            isAllDevices: isAllDevices,
            getTaskAllowed: true,
            platforms: platforms,
            developerCertificateCount: 1,
            certificateMetadata: []
        )
    }
}
