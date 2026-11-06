
import Foundation
import Security

enum ProvisioningProfileCMSVerificationError: LocalizedError {
    case decoderCreationFailed(OSStatus)
    case decodingFailed(OSStatus)
    case finalizationFailed(OSStatus)
    case signerCountFailed(OSStatus)
    case noSigners
    case verificationFailed(OSStatus)
    case invalidSignature(CMSSignerStatus)

    var errorDescription: String? {
        switch self {
        case .decoderCreationFailed(let status):
            return "Could not create the CMS decoder. Security status: \(status)"
        case .decodingFailed(let status):
            return "Could not decode the CMS message. Security status: \(status)"
        case .finalizationFailed(let status):
            return "Could not finalize the CMS message. Security status: \(status)"
        case .signerCountFailed(let status):
            return "Could not read the CMS signer count. Security status: \(status)"
        case .noSigners:
            return "The provisioning profile has no CMS signers."
        case .verificationFailed(let status):
            return "CMS signature verification could not complete. Security status: \(status)"
        case .invalidSignature(let status):
            return "The CMS signature or signer certificate is invalid. Status: \(status.rawValue)"
        }
    }
}

enum ProvisioningProfileCMSVerifier {

    static func verify(_ data: Data) throws {
        guard !data.isEmpty else {
            throw ProvisioningProfileCMSVerificationError.noSigners
        }

        var decoder: CMSDecoder?

        var result = CMSDecoderCreate(&decoder)

        guard result == errSecSuccess, let decoder else {
            throw ProvisioningProfileCMSVerificationError
                .decoderCreationFailed(result)
        }

        result = data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }

            return CMSDecoderUpdateMessage(
                decoder,
                baseAddress,
                buffer.count
            )
        }

        guard result == errSecSuccess else {
            throw ProvisioningProfileCMSVerificationError
                .decodingFailed(result)
        }

        result = CMSDecoderFinalizeMessage(decoder)

        guard result == errSecSuccess else {
            throw ProvisioningProfileCMSVerificationError
                .finalizationFailed(result)
        }

        var signerCount = 0

        result = CMSDecoderGetNumSigners(
            decoder,
            &signerCount
        )

        guard result == errSecSuccess else {
            throw ProvisioningProfileCMSVerificationError
                .signerCountFailed(result)
        }

        guard signerCount > 0 else {
            throw ProvisioningProfileCMSVerificationError.noSigners
        }

        let policy = SecPolicyCreateBasicX509()

        for signerIndex in 0..<signerCount {
            var signerStatus = CMSSignerStatus.unsigned

            result = CMSDecoderCopySignerStatus(
                decoder,
                signerIndex,
                policy,
                true,
                &signerStatus,
                nil,
                nil
            )

            guard result == errSecSuccess else {
                throw ProvisioningProfileCMSVerificationError
                    .verificationFailed(result)
            }

            guard signerStatus == .valid else {
                throw ProvisioningProfileCMSVerificationError
                    .invalidSignature(signerStatus)
            }
        }
    }
}
