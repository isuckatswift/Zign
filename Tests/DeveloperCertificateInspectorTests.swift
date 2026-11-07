import XCTest
import Foundation
@testable import Zign

final class DeveloperCertificateInspectorTests: XCTestCase {

    func testEmptyCertificateListReportsError() throws {
        let report = try DeveloperCertificateInspector.inspect(
            certificates: []
        )

        XCTAssertTrue(report.certificates.isEmpty)
        XCTAssertFalse(report.hasUsableCertificate)
        XCTAssertTrue(
            report.errors.contains(
                "The provisioning profile contains no developer certificates."
            )
        )
    }

    func testRejectsMalformedCertificate() {
        XCTAssertThrowsError(
            try DeveloperCertificateInspector.inspect(
                certificates: [Data([0x01, 0x02, 0x03])]
            )
        ) { error in
            guard case DeveloperCertificateInspectorError.invalidCertificate = error else {
                XCTFail("Expected invalidCertificate, got \(error)")
                return
            }
        }
    }

    func testRejectsMoreThanSixteenCertificates() {
        let certificates = Array(
            repeating: Data([0x01]),
            count: 17
        )

        XCTAssertThrowsError(
            try DeveloperCertificateInspector.inspect(
                certificates: certificates
            )
        ) { error in
            guard case DeveloperCertificateInspectorError.tooManyCertificates = error else {
                XCTFail("Expected tooManyCertificates, got \(error)")
                return
            }
        }
    }

    func testRejectsCertificateLargerThanOneMegabyte() {
        let oversizedCertificate = Data(
            repeating: 0x01,
            count: 1_048_577
        )

        XCTAssertThrowsError(
            try DeveloperCertificateInspector.inspect(
                certificates: [oversizedCertificate]
            )
        ) { error in
            guard case DeveloperCertificateInspectorError.certificateTooLarge = error else {
                XCTFail("Expected certificateTooLarge, got \(error)")
                return
            }
        }
    }

    func testReportUsesProvidedEvaluationDate() throws {
        let evaluationDate = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let report = try DeveloperCertificateInspector.inspect(
            certificates: [],
            now: evaluationDate
        )

        XCTAssertEqual(
            report.evaluatedAt,
            evaluationDate
        )
    }
}
