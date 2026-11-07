import Foundation

struct SigningReadinessReport: Sendable {
    let errors: [String]
    let warnings: [String]

    let profileCompatibility:
        ProvisioningProfileCompatibilityReport

    let deviceCompatibility:
        ProvisioningProfileDeviceCompatibilityReport

    /// True means no known metadata or device-registration
    /// conflicts were found.
    ///
    /// This does not guarantee that signing or installation
    /// will succeed.
    var isReadyForSigning: Bool {
        errors.isEmpty
    }

    var status: String {
        isReadyForSigning
            ? "Ready for signing"
            : "Not ready for signing"
    }
}

enum SigningReadinessInspector {

    static func inspect(
        ipa: IPAInspection,
        profile: ImportedProvisioningProfile,
        targetDeviceIdentifier: String? = nil,
        now: Date = Date()
    ) -> SigningReadinessReport {

        let profileReport =
            ProvisioningProfileCompatibilityInspector.inspect(
                ipa: ipa,
                profile: profile,
                now: now
            )

        let deviceReport =
            ProvisioningProfileDeviceCompatibilityInspector.inspect(
                profile: profile,
                targetDeviceIdentifier: targetDeviceIdentifier
            )

        let errors = deduplicated(
            profileReport.errors + deviceReport.errors
        )

        let warnings = deduplicated(
            profileReport.warnings + deviceReport.warnings
        )

        return SigningReadinessReport(
            errors: errors,
            warnings: warnings,
            profileCompatibility: profileReport,
            deviceCompatibility: deviceReport
        )
    }

    private static func deduplicated(
        _ messages: [String]
    ) -> [String] {

        var seen = Set<String>()

        return messages.filter { message in
            seen.insert(message).inserted
        }
    }
}
