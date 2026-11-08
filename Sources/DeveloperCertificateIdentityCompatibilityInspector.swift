
import Foundation

struct DeveloperCertificateIdentityCompatibilityReport: Sendable {
    let errors: [String]
    let warnings: [String]
    let matchedCertificateFingerprint: String?

    var isCompatible: Bool {
        errors.isEmpty && matchedCertificateFingerprint != nil
    }

    var status: String {
        isCompatible
            ? "Signing identity matched"
            : "No compatible signing identity"
    }
}

enum DeveloperCertificateIdentityCompatibilityInspector {

    static func inspect(
        certificateReport: DeveloperCertificateInspectionReport,
        installedIdentityFingerprints: Set<String>
    ) -> DeveloperCertificateIdentityCompatibilityReport {

        var errors = certificateReport.errors
        let warnings = certificateReport.warnings

        let installedFingerprints = Set(
            installedIdentityFingerprints.map {
                $0.lowercased()
            }
        )

        let usableCertificates = certificateReport.usableCertificates

        var matchedFingerprint: String?

        if let match = usableCertificates.first(where: {
            installedFingerprints.contains(
                $0.sha256Fingerprint.lowercased()
            )
        }) {
            matchedFingerprint = match.sha256Fingerprint
        } else if !usableCertificates.isEmpty {
            errors.append(
                "No installed signing identity matches the valid developer certificates in this provisioning profile."
            )
        }

        return DeveloperCertificateIdentityCompatibilityReport(
            errors: errors,
            warnings: warnings,
            matchedCertificateFingerprint: matchedFingerprint
        )
    }
}
