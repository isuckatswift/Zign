import Foundation
import ZIPFoundation

struct IPASignatureInspection: Sendable {
    let appBundlePath: String
    let hasCodeResources: Bool
    let hasEmbeddedProvisioningProfile: Bool

    /// This inspector checks for signature artifacts only.
    /// It does not verify code hashes, CMS signatures, or certificate trust.
    let cryptographicVerificationPerformed = false

    var missingArtifacts: [String] {
        var missing: [String] = []

        if !hasCodeResources {
            missing.append("_CodeSignature/CodeResources")
        }

        if !hasEmbeddedProvisioningProfile {
            missing.append("embedded.mobileprovision")
        }

        return missing
    }
}

enum IPASignatureInspectionError: LocalizedError {
    case invalidArchive
    case missingAppBundle
    case ambiguousAppBundle

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The selected file is not a valid IPA archive."

        case .missingAppBundle:
            return "Could not find the application's bundle in the IPA."

        case .ambiguousAppBundle:
            return "The IPA contains multiple root application bundles."
        }
    }
}

enum IPASignatureInspector {

    static func inspect(
        at url: URL
    ) throws -> IPASignatureInspection {
        let archive: Archive

        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw IPASignatureInspectionError.invalidArchive
        }

        let appInfoEntries = archive.filter { entry in
            let components = entry.path.components(
                separatedBy: "/"
            )

            return entry.type == .file &&
                components.count == 3 &&
                components[0] == "Payload" &&
                components[1].hasSuffix(".app") &&
                components[1] != ".app" &&
                components[2] == "Info.plist"
        }

        guard !appInfoEntries.isEmpty else {
            throw IPASignatureInspectionError.missingAppBundle
        }

        guard appInfoEntries.count == 1,
              let appInfoEntry = appInfoEntries.first else {
            throw IPASignatureInspectionError.ambiguousAppBundle
        }

        let appBundlePath = String(
            appInfoEntry.path.dropLast("Info.plist".count)
        )

        let codeResourcesPath =
            appBundlePath + "_CodeSignature/CodeResources"

        let provisioningProfilePath =
            appBundlePath + "embedded.mobileprovision"

        let hasCodeResources = archive.contains { entry in
            entry.type == .file &&
                entry.path == codeResourcesPath
        }

        let hasEmbeddedProvisioningProfile = archive.contains { entry in
            entry.type == .file &&
                entry.path == provisioningProfilePath
        }

        return IPASignatureInspection(
            appBundlePath: appBundlePath,
            hasCodeResources: hasCodeResources,
            hasEmbeddedProvisioningProfile:
                hasEmbeddedProvisioningProfile
        )
    }
}
