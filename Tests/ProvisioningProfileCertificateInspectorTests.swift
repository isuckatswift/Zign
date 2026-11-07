
import XCTest
import Foundation
@testable import Zign

final class ProvisioningProfileCertificateInspectorTests: XCTestCase {

    func testRejectsMalformedCMS() {
        XCTAssertThrowsError(
            try ProvisioningProfileCertificateInspector.inspect(
                data: Data([0x30, 0x82, 0xFF])
            )
        )
    }

    func testRejectsCMSWithoutCertificates() {
        let data = makeCMSWithoutCertificates()

        XCTAssertThrowsError(
            try ProvisioningProfileCertificateInspector.inspect(
                data: data
            )
        ) { error in
            XCTAssertEqual(
                error as? ProvisioningProfileCertificateInspectorError,
                .missingCertificates
            )
        }
    }

    func testRejectsEmptyInput() {
        XCTAssertThrowsError(
            try ProvisioningProfileCertificateInspector.inspect(
                data: Data()
            )
        )
    }

    func testExtractsMetadataFromEmbeddedCertificate() throws {
        guard let certificateDER = Data(
            base64Encoded: appleCertificate,
            options: .ignoreUnknownCharacters
        ) else {
            XCTFail("The certificate fixture is invalid Base64.")
            return
        }

        let cms = makeCMSWithCertificate(certificateDER)

        let certificates = try ProvisioningProfileCertificateInspector.inspect(
            data: cms
        )

        XCTAssertEqual(certificates.count, 1)

        let certificate = try XCTUnwrap(certificates.first)

        XCTAssertEqual(
            certificate.subjectCommonName,
            "www.apple.com"
        )

        XCTAssertEqual(
            certificate.issuerCommonName,
            "Apple Public EV Server RSA CA 2 - G1"
        )

        XCTAssertEqual(
            certificate.notValidBefore.timeIntervalSince1970,
            1650383400,
            accuracy: 1
        )

        XCTAssertEqual(
            certificate.notValidAfter.timeIntervalSince1970,
            1684511399,
            accuracy: 1
        )

        XCTAssertEqual(
            certificate.sha256Fingerprint,
            "011b158babfc7c6a1f525822f1def13fe905aa506bb1600bea5ba86a13ed06ca"
        )
    }

    private func makeCMSWithoutCertificates() -> Data {
        let signedDataOID = Data([
            0x2A, 0x86, 0x48, 0x86, 0xF7,
            0x0D, 0x01, 0x07, 0x02
        ])

        let dataOID = Data([
            0x2A, 0x86, 0x48, 0x86, 0xF7,
            0x0D, 0x01, 0x07, 0x01
        ])

        let encapsulatedContent = der(
            0x30,
            der(0x06, dataOID)
        )

        let signedData = der(
            0x30,
            der(0x02, Data([0x01])) +
            der(0x31, Data()) +
            encapsulatedContent +
            der(0x31, Data())
        )

        return der(
            0x30,
            der(0x06, signedDataOID) +
            der(0xA0, signedData)
        )
    }

    private func makeCMSWithCertificate(
        _ certificateDER: Data
    ) -> Data {
        let signedDataOID = Data([
            0x2A, 0x86, 0x48, 0x86, 0xF7,
            0x0D, 0x01, 0x07, 0x02
        ])

        let dataOID = Data([
            0x2A, 0x86, 0x48, 0x86, 0xF7,
            0x0D, 0x01, 0x07, 0x01
        ])

        let encapsulatedContent = der(
            0x30,
            der(0x06, dataOID)
        )

        let certificateSet = der(
            0xA0,
            certificateDER
        )

        let signedData = der(
            0x30,
            der(0x02, Data([0x01])) +
            der(0x31, Data()) +
            encapsulatedContent +
            certificateSet +
            der(0x31, Data())
        )

        return der(
            0x30,
            der(0x06, signedDataOID) +
            der(0xA0, signedData)
        )
    }

    private func der(_ tag: UInt8, _ content: Data) -> Data {
        var result = Data([tag])
        let count = content.count

        if count < 128 {
            result.append(UInt8(count))
        } else {
            var value = count
            var bytes: [UInt8] = []

            while value > 0 {
                bytes.insert(UInt8(value & 0xFF), at: 0)
                value >>= 8
            }

            result.append(0x80 | UInt8(bytes.count))
            result.append(contentsOf: bytes)
        }

        result.append(content)
        return result
    }

    private let appleCertificate = """
    MIIIUTCCBzmgAwIBAgIQCxya6sqWO6dnzw4XR5O0UzANBgkqhkiG9w0BAQsF
    ADBRMQswCQYDVQQGEwJVUzETMBEGA1UEChMKQXBwbGUgSW5jLjEtMCsGA1UE
    AxMkQXBwbGUgUHVibGljIEVWIFNlcnZlciBSU0EgQ0EgMiAtIEcxMB4XDTIy
    MDQxOTE1NTAwMFoXDTIzMDUxOTE1NDk1OVowge8xHTAbBgNVBA8TFFByaXZh
    dGUgT3JnYW5pemF0aW9uMRMwEQYLKwYBBAGCNzwCAQMTAlVTMRswGQYLKwYB
    BAGCNzwCAQITCkNhbGlmb3JuaWExETAPBgNVBAUTCEMwODA2NTkyMQswCQYD
    VQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTESMBAGA1UEBxMJQ3VwZXJ0
    aW5vMRMwEQYDVQQKEwpBcHBsZSBJbmMuMSYwJAYDVQQLEx1tYW5hZ2VtZW50
    OmlkbXMuZ3JvdXAuMTIwODkyMDEWMBQGA1UEAxMNd3d3LmFwcGxlLmNvbTCC
    ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK01MvC1a1/N6YX4+b/X
    62eSXqdK0rJD+wZRPWmJl4JQZVgJi+uafl2teFw8Tu2OQ17fBDDVQ1UwyvW8
    +zPPcnCQA/6p/+TbLszE0diZDFx8YwhtA/q4hDOI8RwiKDtZgyi0Gm7sV/yy
    bsd/sW1zRInbMhmgEhuQBqt912aLSopx5+bXsA9xTpfdNUIOzkOwXWXu6WD3
    IDG0rVoA14XD3waErzrJ5z4w2MEQgJz5QUXjObA1SLprmTBPN7wAHgB5u9GE
    VwE9mxzrriewcnpOVcZUgtIVbXymP7tsPRftLWQ/436XkjrFoVfn1YnRenAz
    WMKO8pFzeVYptFO9uozVbH8CAwEAAaOCBIQwggSAMAwGA1UdEwEB/wQCMAAw
    HwYDVR0jBBgwFoAUUFWrQ6GvqUgrWsGih4kE5HoOytowegYIKwYBBQUHAQEE
    bjBsMDIGCCsGAQUFBzAChiZodHRwOi8vY2VydHMuYXBwbGUuY29tL2FwZXZz
    cnNhMmcxLmRlcjA2BggrBgEFBQcwAYYqaHR0cDovL29jc3AuYXBwbGUuY29t
    L29jc3AwMy1hcGV2c3JzYTJnMTAxMDwGA1UdEQQ1MDOCEHd3dy5hcHBsZS5j
    b20uY26CDXd3dy5hcHBsZS5jb22CEGltYWdlcy5hcHBsZS5jb20wggESBgNV
    HSAEggEJMIIBBTAHBgVngQwBATCB+QYJYIZIAYb9bAIBMIHrMD4GCCsGAQUF
    BwIBFjJodHRwczovL3d3dy5hcHBsZS5jb20vY2VydGlmaWNhdGVhdXRob3Jp
    dHkvcHVibGljLzCBqAYIKwYBBQUHAgIwgZsMgZhSZWxpYW5jZSBvbiB0aGlz
    IGNlcnRpZmljYXRlIGJ5IGFueSBwYXJ0eSBhc3N1bWVzIGFjY2VwdGFuY2Ug
    b2YgdGhlIFJlbHlpbmcgUGFydHkgQWdyZWVtZW50IGZvdW5kIGF0IGh0dHBz
    Oi8vd3d3LmFwcGxlLmNvbS9jZXJ0aWZpY2F0ZWF1dGhvcml0eS9wdWJsaWMv
    LjAdBgNVHSUEFjAUBggrBgEFBQcDAgYIKwYBBQUHAwEwNQYDVR0fBC4wLDAq
    oCigJoYkaHR0cDovL2NybC5hcHBsZS5jb20vYXBldnNyc2EyZzEuY3JsMB0G
    A1UdDgQWBBRYak9RD/EOFiubhYxEpzYzZfhcVTAOBgNVHQ8BAf8EBAMCBaAw
    ggH4BgorBgEEAdZ5AgQCBIIB6ASCAeQB4gB2ALvZ37wfinG1k5Qjl6qSe0c4
    V5UKq1LoGpCWZDaOHtGFAAABgEKNVzMAAAQDAEcwRQIhAOBG34lbqnnGrEu1
    h1idGvy5/5Fj6Jf/auwly5XrC7++AiBiw5eapGODx6ui1C3hE14gvwb8KMOs
    Mps1sUeqAGgOIgB2AO5Lvbd1zmC64UJpH6vhnmajD35fsHLYgwDEe4l6qP3L
    AAABgEKNV2AAAAQDAEcwRQIgQB+Avl96nQv3RiRgNIUfGKxL1cTS5ztt2XTn
    kXv5uJ4CIQCaEP+u9nnNjfp2JT3a1kkNG3eGKxUpAESvLFuzB9ECFgB3AHoy
    jFTYty22IOo44FIe6YQWcDIThU070ivBOlejUutSAAABgEKNV4gAAAQDAEgw
    RgIhANK5cwVNfzNIAeI8nOHBfKNyiV7zgibBNhLpzSHRlAxUAiEA/kd3hoVQ
    YjPzvkd5Ehy+UNeYnLvFt8ahzofFpWVLOk4AdwCt9776fP8QyIudPZwePhhq
    tGcpXc+xDCTKhYY069yCigAAAYBCjVdgAAAEAwBIMEYCIQCc+n8x/OfqR/k1
    6PrnmjVDZujiwe1FUd9CZ/nh5BMnbAIhAMVgATv6OVmfyQudllzbd5YtmX+L
    R7yiN5owaE5+H6kbMA0GCSqGSIb3DQEBCwUAA4IBAQAAHxWsefNp29IRd6ad
    awvBZ5lelhSH3mrX2o6w3qPXtfBhg+Vl1pkQnBaL7rUoXKbCZ9RK68jEUnks
    TCWbAoNLSGLd84uVxqJD8AFG+6tSCd3zdilrBMgfQc1OO5Dmfd6/g1as+hD9
    DR9OwOOVnBkyGYPpwHTTt0koLZxaHBTRjuUvzFpvnNr5263gRXN2a60xLhwG
    p0z29i0/IZytr1I2T/utzir8exLY8q+bfvpyBJhWHrufcfnbZCF4rfAw2xtX
    cIsTcUoOLMdq7VDMDSfeOP9ptncQwY7DELmN2zEkgsZ1QiiEhx1GT1fyOIQb
    nJPbKvMCpGetDKh7bbBiZAaG
    """
}
