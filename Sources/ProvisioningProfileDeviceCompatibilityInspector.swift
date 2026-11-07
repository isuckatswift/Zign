
import Foundation

struct ProvisioningProfileDeviceCompatibilityReport: Sendable {
    let errors: [String]
    let warnings: [String]
    let matchedDeviceIdentifier: String?

    /// True means no known device-registration conflict was found.
    /// It does not guarantee that iOS will accept or install the IPA.
    var isCompatible: Bool {
        errors.isEmpty
    }
}

enum ProvisioningProfileDeviceCompatibilityInspector {

    static func inspect(
        profile: ImportedProvisioningProfile,
        targetDeviceIdentifier: String?
    ) -> ProvisioningProfileDeviceCompatibilityReport {

        var errors: [String] = []
        var warnings: [String] = []
        var matchedDeviceIdentifier: String?

        if profile.isAllDevices {
            warnings.append(
                "The profile is marked as an all-device profile. This check does not verify the profile's signing authority or installation eligibility."
            )

            return makeReport(
                errors: errors,
                warnings: warnings,
                matchedDeviceIdentifier: nil
            )
        }

        let registeredIdentifiers = profile.provisionedDeviceIdentifiers
            .map(normalizeIdentifier)
            .filter { !$0.isEmpty }

        guard !registeredIdentifiers.isEmpty else {
            errors.append(
                "The provisioning profile is not marked for all devices and contains no registered device identifiers."
            )

            return makeReport(
                errors: errors,
                warnings: warnings,
                matchedDeviceIdentifier: nil
            )
        }

        guard let targetDeviceIdentifier else {
            warnings.append(
                "A target device identifier was not supplied, so device registration could not be checked."
            )

            return makeReport(
                errors: errors,
                warnings: warnings,
                matchedDeviceIdentifier: nil
            )
        }

        let normalizedTarget = normalizeIdentifier(targetDeviceIdentifier)

        guard !normalizedTarget.isEmpty else {
            warnings.append(
                "The supplied target device identifier is empty, so device registration could not be checked."
            )

            return makeReport(
                errors: errors,
                warnings: warnings,
                matchedDeviceIdentifier: nil
            )
        }

        guard registeredIdentifiers.contains(normalizedTarget) else {
            errors.append(
                "The target device is not registered in this provisioning profile."
            )

            return makeReport(
                errors: errors,
                warnings: warnings,
                matchedDeviceIdentifier: nil
            )
        }

        matchedDeviceIdentifier = targetDeviceIdentifier.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return makeReport(
            errors: errors,
            warnings: warnings,
            matchedDeviceIdentifier: matchedDeviceIdentifier
        )
    }

    private static func normalizeIdentifier(_ identifier: String) -> String {
        identifier.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
    }

    private static func makeReport(
        errors: [String],
        warnings: [String],
        matchedDeviceIdentifier: String?
    ) -> ProvisioningProfileDeviceCompatibilityReport {

        ProvisioningProfileDeviceCompatibilityReport(
            errors: errors,
            warnings: warnings,
            matchedDeviceIdentifier: matchedDeviceIdentifier
        )
    }
}
