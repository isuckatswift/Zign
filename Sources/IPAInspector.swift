
import Foundation
import ZIPFoundation

struct IPAInspection {
    let appName: String
    let bundleIdentifier: String
    let version: String
    let buildNumber: String
    let minimumiOSVersion: String
    let iconName: String?

    static func inspect(at url: URL) throws -> IPAInspection {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw IPAInspectionError.invalidArchive
        }

        guard let entry = archive.first(where: {
            $0.path.hasPrefix("Payload/") &&
            $0.path.hasSuffix(".app/Info.plist") &&
            $0.path.components(separatedBy: "/").count == 3
        }) else {
            throw IPAInspectionError.missingInfoPlist
        }

        var plistData = Data()

        _ = try archive.extract(entry) { data in
            plistData.append(data)
        }

        guard let plist = try PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw IPAInspectionError.invalidInfoPlist
        }

        let displayName =
            plist["CFBundleDisplayName"] as? String ??
            plist["CFBundleName"] as? String ??
            "Unknown App"

        let icons = plist["CFBundleIcons"] as? [String: Any]
        let primaryIcon = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let iconFiles = primaryIcon?["CFBundleIconFiles"] as? [String]

        return IPAInspection(
            appName: displayName,
            bundleIdentifier: plist["CFBundleIdentifier"] as? String ?? "Unknown",
            version: plist["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: plist["CFBundleVersion"] as? String ?? "Unknown",
            minimumiOSVersion: plist["MinimumOSVersion"] as? String ?? "Unknown",
            iconName: iconFiles?.last
        )
    }
}

enum IPAInspectionError: LocalizedError {
    case invalidArchive
    case missingInfoPlist
    case invalidInfoPlist

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The selected file is not a valid IPA archive."
        case .missingInfoPlist:
            return "Could not find the application's Info.plist."
        case .invalidInfoPlist:
            return "The application's Info.plist is invalid."
        }
    }
}
