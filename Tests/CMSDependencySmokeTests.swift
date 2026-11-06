import Foundation
import XCTest
@_spi(CMS) import X509

final class CMSDependencySmokeTests: XCTestCase {

    func testX509ModuleIsAvailable() {
        XCTAssertTrue(true)
    }

    private func compileCMSVerifier(
        signature: Data,
        trustRoots: CertificateStore
    ) async {
        _ = await CMS.isValidAttachedSignature(
            signatureBytes: signature,
            trustRoots: trustRoots
        ) {}
    }
}
