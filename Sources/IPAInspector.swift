
import Foundation
import ZIPFoundation

struct IPAInspection: Sendable {
    let appName: String
    let bundleIdentifier: String
    let version: String
    let buildNumber: String
    let minimumiOSVersion: String
    let iconName: String?

    private static let maximumInfoPlistSize: UInt64 = 16 * 1024 * 1024

    static func inspect(at url: URL) throws -> IPAInspection {
        let archive: Archive

        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw IPAInspectionError.invalidArchive
        }

        let matchingEntries = archive.filter { entry in
            let components = entry.path.components(separatedBy: "/")

            return entry.type == .file &&
                components.count == 3 &&
                components[0] == "Payload" &&
                components[1].hasSuffix(".app") &&
                components[1] != ".app" &&
                components[2] == "Info.plist"
        }

        guard !matchingEntries.isEmpty else {
            throw IPAInspectionError.missingInfoPlist
        }

        guard matchingEntries.count == 1,
              let entry = matchingEntries.first else {
            throw IPAInspectionError.ambiguousInfoPlist
        }

        guard entry.uncompressedSize > 0,
              entry.uncompressedSize <= maximumInfoPlistSize else {
            throw IPAInspectionError.infoPlistTooLarge
        }

        var plistData = Data()
        plistData.reserveCapacity(Int(entry.uncompressedSize))

        do {
            _ = try archive.extract(entry) { chunk in
                guard UInt64(plistData.count) + UInt64(chunk.count)
                        <= maximumInfoPlistSize else {
                    throw IPAInspectionError.infoPlistTooLarge
                }

                plistData.append(chunk)
            }
        } catch let error as IPAInspectionError {
            throw error
        } catch {
            throw IPAInspectionError.unableToReadInfoPlist
        }

        guard let plist = try? PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw IPAInspectionError.invalidInfoPlist
        }

        let displayName =
            nonEmptyString(plist["CFBundleDisplayName"]) ??
            nonEmptyString(plist["CFBundleName"]) ??
            "Unknown App"

        guard let bundleIdentifier =
                nonEmptyString(plist["CFBundleIdentifier"]) else {
            throw IPAInspectionError.missingBundleIdentifier
        }

        return IPAInspection(
            appName: displayName,
            bundleIdentifier: bundleIdentifier,
            version: nonEmptyString(
                plist["CFBundleShortVersionString"]
            ) ?? "Unknown",
            buildNumber: nonEmptyString(
                plist["CFBundleVersion"]
            ) ?? "Unknown",
            minimumiOSVersion: nonEmptyString(
                plist["MinimumOSVersion"]
            ) ?? "Unknown",
            iconName: primaryIconName(from: plist)
        )
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }

        let trimmed = string.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }

    private static func primaryIconName(
        from plist: [String: Any]
    ) -> String? {
        let icons = plist["CFBundleIcons"] as? [String: Any]
        let primaryIcon = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let iconFiles = primaryIcon?["CFBundleIconFiles"] as? [String]

        return iconFiles?.last
    }
}

enum IPAInspectionError: LocalizedError {
    case invalidArchive
    case missingInfoPlist
    case ambiguousInfoPlist
    case infoPlistTooLarge
    case unableToReadInfoPlist
    case invalidInfoPlist
    case missingBundleIdentifier

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The selected file is not a valid IPA archive."

        case .missingInfoPlist:
            return "Could not find the application's Info.plist."

        case .ambiguousInfoPlist:
            return "The IPA contains multiple application Info.plist entries."

        case .infoPlistTooLarge:
            return "The application's Info.plist exceeds the inspection size limit."

        case .unableToReadInfoPlist:
            return "Could not safely read the application's Info.plist."

        case .invalidInfoPlist:
            return "The application's Info.plist is invalid."

        case .missingBundleIdentifier:
            return "The application's bundle identifier is missing or invalid."
        }
    }
}
