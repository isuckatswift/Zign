
import Foundation
import SwiftUI

struct ImportedIPA: Identifiable {
    let url: URL
    let fileSize: Int64

    var id: String {
        url.path
    }

    var name: String {
        url.lastPathComponent
    }

    var formattedSize: String {
        ByteCountFormatter.string(
            fromByteCount: fileSize,
            countStyle: .file
        )
    }
}

@MainActor
final class IPAFileStore: ObservableObject {
    @Published private(set) var files: [ImportedIPA] = []

    private let fileManager = FileManager.default

    private var storageDirectory: URL {
        let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        return documents.appendingPathComponent(
            "Imported IPAs",
            isDirectory: true
        )
    }

    init() {
        reload()
    }

    func reload() {
        do {
            try fileManager.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true
            )

            let urls = try fileManager.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            files = urls
                .filter { $0.pathExtension.lowercased() == "ipa" }
                .map { url in
                    let values = try? url.resourceValues(
                        forKeys: [.fileSizeKey]
                    )

                    return ImportedIPA(
                        url: url,
                        fileSize: Int64(values?.fileSize ?? 0)
                    )
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name)
                        == .orderedAscending
                }
        } catch {
            files = []
        }
    }

    func importFiles(_ urls: [URL]) throws {
        try fileManager.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )

        for source in urls {
            guard source.pathExtension.lowercased() == "ipa" else {
                continue
            }

            let hasAccess = source.startAccessingSecurityScopedResource()

            defer {
                if hasAccess {
                    source.stopAccessingSecurityScopedResource()
                }
            }

            guard hasAccess else {
                throw IPAStoreError.accessDenied
            }

            let destination = uniqueDestination(
                for: source.lastPathComponent
            )

            try fileManager.copyItem(
                at: source,
                to: destination
            )
        }

        reload()
    }

    func delete(_ file: ImportedIPA) throws {
        try fileManager.removeItem(at: file.url)
        reload()
    }

    private func uniqueDestination(for filename: String) -> URL {
        var destination = storageDirectory.appendingPathComponent(filename)
        var counter = 2

        let fileExtension = destination.pathExtension
        let baseName = destination.deletingPathExtension().lastPathComponent

        while fileManager.fileExists(atPath: destination.path) {
            let newName = "\(baseName) (\(counter)).\(fileExtension)"
            destination = storageDirectory.appendingPathComponent(newName)
            counter += 1
        }

        return destination
    }
}

enum IPAStoreError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Zign could not access the selected file."
        }
    }
}
