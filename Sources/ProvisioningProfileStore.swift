
import Foundation
import Combine

@MainActor
final class ProvisioningProfileStore: ObservableObject {

    @Published private(set) var profiles: [ImportedProvisioningProfile] = []
    @Published private(set) var failedProfiles: [String] = []

    private let directoryName = "ProvisioningProfiles"

    private var storageDirectory: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return applicationSupport.appendingPathComponent(
            directoryName,
            isDirectory: true
        )
    }

    // MARK: - Loading

    func loadProfiles() throws {
        try createStorageDirectory()

        let files = try FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var loadedProfiles: [ImportedProvisioningProfile] = []
        var failedFiles: [String] = []

        for file in files where file.pathExtension == "mobileprovision" {
            do {
                let values = try file.resourceValues(
                    forKeys: [.isRegularFileKey]
                )

                guard values.isRegularFile == true else {
                    failedFiles.append(
                        "\(file.lastPathComponent): Not a regular file."
                    )
                    continue
                }

                let profile = try ProvisioningProfileParser.parse(from: file)
                loadedProfiles.append(profile)
            } catch {
                failedFiles.append(
                    "\(file.lastPathComponent): \(error.localizedDescription)"
                )
            }
        }

        profiles = loadedProfiles.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name)
                == .orderedAscending
        }

        failedProfiles = failedFiles
    }

    // MARK: - Importing

    func importProfile(from sourceURL: URL) throws {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()

        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try createStorageDirectory()

        let storedFilename = UUID().uuidString + ".mobileprovision"
        let destinationURL = storageDirectory.appendingPathComponent(
            storedFilename
        )

        try FileManager.default.copyItem(
            at: sourceURL,
            to: destinationURL
        )

        do {
            let profile = try ProvisioningProfileParser.parse(
                from: destinationURL
            )

            profiles.append(profile)
            failedProfiles.removeAll {
                $0.hasPrefix("\(storedFilename):")
            }
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }

    // MARK: - Removal

    func removeProfile(_ profile: ImportedProvisioningProfile) throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        guard let file = files.first(where: {
            $0.lastPathComponent == profile.filename &&
            $0.pathExtension == "mobileprovision"
        }) else {
            throw ProvisioningProfileStoreError.profileNotFound
        }

        try FileManager.default.removeItem(at: file)

        profiles.removeAll {
            $0.filename == profile.filename
        }
    }

    // MARK: - Storage

    private func createStorageDirectory() throws {
        try FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )
    }
}

// MARK: - Errors

enum ProvisioningProfileStoreError: LocalizedError {
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "The saved provisioning profile could not be found."
        }
    }
}
