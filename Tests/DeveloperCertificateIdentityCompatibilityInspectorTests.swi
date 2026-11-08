
import XCTest
import Foundation
@testable import Zign

final class DeveloperCertificateIdentityCompatibilityInspectorTests: XCTestCase {

    private let referenceDate = Date(
        timeIntervalSince1970: 1_800_000_000
    )

    func testMatchingInstalledIdentityIsCompatible() {
        let certificate = makeCertificate(
            fingerprint: "abcdef123456",
            valid: true
        )

        let report = inspect(
            certificates: [certificate],
            installedFingerprints: ["abcdef123456"]
        )

        XCTAssertTrue(report.isCompatible)
        XCTAssertEqual(report.status, "Signing identity matched")
        XCTAssertEqual(
            report.matchedCertificateFingerprint,
            "abcdef123456"
        )
        XCTAssertTrue(report.errors.isEmpty)
    }

    func testMissingInstalledIdentityBlocksCompatibility() {
        let certificate = makeCertificate(
            fingerprint: "abcdef123456",
            valid: true
        )

        let report = inspect(
            certificates: [certificate],
            installedFingerprints: []
        )

        XCTAssertFalse(report.isCompatible)
        XCTAssertNil(report.matchedCertificateFingerprint)
        XCTAssertTrue(report.errors.contains {
            $0.contains("No installed signing identity matches")
        })
    }

    func testDifferentInstalledIdentityDoesNotMatch() {
        let certificate = makeCertificate(
            fingerprint: "abcdef123456",
            valid: true
        )

        let report = inspect(
            certificates: [certificate],
            installedFingerprints: ["different-fingerprint"]
        )

        XCTAssertFalse(report.isCompatible)
        XCTAssertNil(report.matchedCertificateFingerprint)
    }

    func testExpiredCertificateCannotMatch() {
        let certificate = makeCertificate(
            fingerprint: "abcdef123456",
            valid: false
        )

        let report = inspect(
            certificates: [certificate],
            installedFingerprints: ["abcdef123456"]
        )

        XCTAssertFalse(report.isCompatible)
        XCTAssertNil(report.matchedCertificateFingerprint)
        XCTAssertTrue(report.errors.contains {
            $0.contains("None of the developer certificates")
        })
    }

    func testFingerprintMatchingIsCaseInsensitive() {
        let certificate = makeCertificate(
            fingerprint: "ABCDEF123456",
            valid: true
        )

        let report = inspect(
            certificates: [certificate],
            installedFingerprints: ["abcdef123456"]
        )

        XCTAssertTrue(report.isCompatible)
        XCTAssertEqual(
            report.matchedCertificateFingerprint,
            "ABCDEF123456"
        )
    }

    func testMatchesAnyAvailableValidCertificate() {
        let expiredCertificate = makeCertificate(
            fingerprint: "expired-certificate",
            valid: false
        )

        let validCertificate = makeCertificate(
            fingerprint: "valid-certificate",
            valid: true
        )

        let report = inspect(
            certificates: [
                expiredCertificate,
                validCertificate
            ],
            installedFingerprints: ["valid-certificate"]
        )

        XCTAssertTrue(report.isCompatible)
        XCTAssertEqual(
            report.matchedCertificateFingerprint,
            "valid-certificate"
        )
        XCTAssertFalse(report.warnings.isEmpty)
    }

    func testCertificateWarningsArePreserved() {
        let certificate = makeCertificate(
            fingerprint: "abcdef123456",
            valid: true
        )

        let report = inspect(
            certificates: [certificate],
            installedFingerprints: ["abcdef123456"],
            warnings: ["Existing certificate warning."]
        )

        XCTAssertTrue(report.isCompatible)
        XCTAssertTrue(
            report.warnings.contains("Existing certificate warning.")
        )
    }

    func testEmptyCertificateReportIsNotCompatible() {
        let certificateReport = DeveloperCertificateInspectionReport(
            certificates: [],
            errors: [
                "The provisioning profile contains no developer certificates."
            ],
            warnings: [],
            evaluatedAt: referenceDate
        )

        let report =
            DeveloperCertificateIdentityCompatibilityInspector.inspect(
                certificateReport: certificateReport,
                installedIdentityFingerprints: ["abcdef123456"]
            )

        XCTAssertFalse(report.isCompatible)
        XCTAssertNil(report.matchedCertificateFingerprint)
        XCTAssertFalse(report.errors.isEmpty)
    }

    private func inspect(
        certificates: [DeveloperCertificateMetadata],
        installedFingerprints: Set<String>,
        warnings: [String] = []
    ) -> DeveloperCertificateIdentityCompatibilityReport {

        let validCertificates = certificates.filter {
            $0.isValid(at: referenceDate)
        }

        let errors: [String]

        if certificates.isEmpty {
            errors = [
                "The provisioning profile contains no developer certificates."
            ]
        } else if validCertificates.isEmpty {
            errors = [
                "None of the developer certificates are currently valid."
            ]
        } else {
            errors = []
        }

        let report = DeveloperCertificateInspectionReport(
            certificates: certificates,
            errors: errors,
            warnings: warnings,
            evaluatedAt: referenceDate
        )

        return DeveloperCertificateIdentityCompatibilityInspector.inspect(
            certificateReport: report,
            installedIdentityFingerprints: installedFingerprints
        )
    }

    private func makeCertificate(
        fingerprint: String,
        valid: Bool
    ) -> DeveloperCertificateMetadata {

        let startDate = valid
            ? referenceDate.addingTimeInterval(-3600)
            : referenceDate.addingTimeInterval(-7200)

        let endDate = valid
            ? referenceDate.addingTimeInterval(3600)
            : referenceDate.addingTimeInterval(-3600)

        return DeveloperCertificateMetadata(
            subjectCommonName: "Zign Test Developer",
            issuerCommonName: "Zign Test Authority",
            notValidBefore: startDate,
            notValidAfter: endDate,
            sha256Fingerprint: fingerprint
        )
    }
}
