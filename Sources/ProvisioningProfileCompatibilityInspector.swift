
import Foundation

struct ProvisioningProfileCompatibilityReport: Sendable {
    let errors: [String]
    let warnings: [String]

    /// True means the inspected metadata has no known blocking conflicts.
    /// It does not guarantee that iOS will accept or install the IPA.
    var isCompatible: Bool {
        errors.isEmpty
    }
}

enum ProvisioningProfileCompatibilityInspector {

    /// Checks whether an IPA's bundle identifier and the supplied
    /// provisioning profile are compatible based on the metadata
    /// currently available to Zign.
    ///
    /// The check does not verify the IPA's code signature, signing
    /// certificate, target device, or target iOS version.
    static func inspect(
        ipa: IPAInspection,
        profile: ImportedProvisioningProfile,
        now: Date = Date()
    ) -> ProvisioningProfileCompatibilityReport {

        var errors: [String] = []
        var warnings: [String] = []

        let bundleIdentifier = ipa.bundleIdentifier.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !bundleIdentifier.isEmpty else {
            errors.append("The IPA bundle identifier is missing.")
            return makeReport(errors: errors, warnings: warnings)
        }

        // MARK: - Profile application identifier

        guard let rawApplicationIdentifier = profile.applicationIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawApplicationIdentifier.isEmpty else {
            errors.append(
                "The provisioning profile does not contain an application identifier."
            )

            return makeReport(errors: errors, warnings: warnings)
        }

        guard let separator = rawApplicationIdentifier.firstIndex(of: ".") else {
            errors.append(
                "The profile application identifier has an invalid format."
            )

            return makeReport(errors: errors, warnings: warnings)
        }

        let applicationTeamIdentifier = String(
            rawApplicationIdentifier[..<separator]
        )

        let applicationBundlePattern = String(
            rawApplicationIdentifier[
                rawApplicationIdentifier.index(after: separator)...
            ]
        )

        guard !applicationTeamIdentifier.isEmpty,
              !applicationBundlePattern.isEmpty else {
            errors.append(
                "The profile application identifier is incomplete."
            )

            return makeReport(errors: errors, warnings: warnings)
        }

        // MARK: - Team identifier consistency

        guard let profileTeamIdentifier = profile.teamIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !profileTeamIdentifier.isEmpty else {
            errors.append(
                "The provisioning profile does not contain a team identifier."
            )

            return makeReport(errors: errors, warnings: warnings)
        }

        guard profileTeamIdentifier == applicationTeamIdentifier else {
            errors.append(
                "The profile team identifier does not match the team prefix in its application identifier."
            )

            return makeReport(errors: errors, warnings: warnings)
        }

        // MARK: - Bundle identifier compatibility

        if !matches(
            bundleIdentifier: bundleIdentifier,
            applicationIdentifierPattern: applicationBundlePattern
        ) {
            errors.append(
                "The IPA bundle identifier does not match the provisioning profile application identifier."
            )
        }

        // MARK: - Expiration

        guard let expirationDate = profile.expirationDate else {
            errors.append(
                "The provisioning profile does not contain an expiration date."
            )

            return makeReport(errors: errors, warnings: warnings)
        }

        if expirationDate <= now {
            errors.append("The provisioning profile has expired.")
        }

        // MARK: - Platform

        let supportsIOS = profile.platforms.contains { platform in
            platform.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare("iOS") == .orderedSame
        }

        if !supportsIOS {
            errors.append(
                "The provisioning profile does not declare support for iOS."
            )
        }

        // MARK: - Device information

        if profile.isAllDevices {
            warnings.append(
                "This profile is marked as an all-device profile."
            )
        } else if profile.deviceCount == 0 {
            warnings.append(
                "The profile contains no registered device entries."
            )
        } else {
            warnings.append(
                "A target device identifier was not supplied, so registration of a specific device was not checked."
            )
        }

        // MARK: - Minimum iOS version

        if ipa.minimumiOSVersion.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).caseInsensitiveCompare("Unknown") == .orderedSame {
            warnings.append(
                "The IPA's minimum iOS version could not be determined."
            )
        }

        warnings.append(
            "A target device iOS version was not supplied, so operating-system compatibility was not checked."
        )

        // MARK: - Signature verification boundary

        warnings.append(
            "The IPA's signing identity and code signature were not cryptographically verified by this inspection."
        )

        return makeReport(errors: errors, warnings: warnings)
    }

    // MARK: - Application identifier matching

    private static func matches(
        bundleIdentifier: String,
        applicationIdentifierPattern: String
    ) -> Bool {

        let pattern = applicationIdentifierPattern

        guard !pattern.isEmpty else {
            return false
        }

        let wildcardCount = pattern.filter { $0 == "*" }.count

        // Exact application identifiers must match exactly.
        if wildcardCount == 0 {
            return bundleIdentifier == pattern
        }

        // Apple wildcard application identifiers use a single
        // asterisk at the end of the identifier.
        guard wildcardCount == 1,
              pattern.hasSuffix("*") else {
            return false
        }

        let prefix = String(pattern.dropLast())

        // A wildcard must represent at least one character.
        // For example, com.example.* matches com.example.app,
        // but does not match com.example.
        if prefix.isEmpty {
            return !bundleIdentifier.isEmpty
        }

        guard bundleIdentifier.hasPrefix(prefix) else {
            return false
        }

        let suffix = bundleIdentifier.dropFirst(prefix.count)
        return !suffix.isEmpty
    }

    private static func makeReport(
        errors: [String],
        warnings: [String]
    ) -> ProvisioningProfileCompatibilityReport {

        ProvisioningProfileCompatibilityReport(
            errors: errors,
            warnings: warnings
        )
    }
}
