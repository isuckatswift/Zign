
import X509

struct ProvisioningProfileCertificatePolicy: VerifierPolicy {

    let expectedChainLength: Int
    let expectedLeafCommonName: String
    let expectedIntermediateCommonName: String

    var verifyingCriticalExtensions: [ASN1ObjectIdentifier] {
        []
    }

    mutating func chainMeetsPolicyRequirements(
        chain: UnverifiedCertificateChain
    ) async -> PolicyEvaluationResult {

        guard chain.count == expectedChainLength else {
            return .failsToMeetPolicy(
                reason: "Unexpected certificate chain length."
            )
        }

        guard commonName(chain.leaf.subject)
            == expectedLeafCommonName else {
            return .failsToMeetPolicy(
                reason: "Unexpected provisioning profile signer."
            )
        }

        guard chain.count >= 2,
              commonName(chain[1].subject)
                == expectedIntermediateCommonName else {
            return .failsToMeetPolicy(
                reason: "Unexpected certificate authority."
            )
        }

        return .meetsPolicy
    }

    private func commonName(
        _ distinguishedName: DistinguishedName
    ) -> String? {

        for relativeName in distinguishedName {
            for attribute in relativeName {
                if attribute.type == .RDNAttributeType.commonName {
                    return String(attribute.value)
                }
            }
        }

        return nil
    }
}
