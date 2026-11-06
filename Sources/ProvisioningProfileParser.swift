
import Foundation

struct ImportedProvisioningProfile: Identifiable {
    let id = UUID()
    let filename: String
    let name: String
    let uuid: String
    let teamIdentifier: String?
    let applicationIdentifier: String?
    let creationDate: Date?
    let expirationDate: Date?
    let deviceCount: Int
    let isAllDevices: Bool
    let getTaskAllowed: Bool?
    let platforms: [String]
    let developerCertificateCount: Int
}

enum ProvisioningProfileError: LocalizedError, Equatable {
    case fileTooLarge
    case invalidCMS
    case missingContent
    case invalidPropertyList
    case invalidDER

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "The provisioning profile exceeds the 10 MB size limit."
        case .invalidCMS:
            return "The file is not a supported CMS provisioning profile."
        case .missingContent:
            return "No embedded profile content was found."
        case .invalidPropertyList:
            return "The profile contents could not be read."
        case .invalidDER:
            return "The profile contains malformed DER data."
        }
    }
}

private struct DERTLV {
    let tag: UInt8
    let content: Range<Int>
    let nextOffset: Int
}

enum ProvisioningProfileParser {

    private static let maximumFileSize = 10 * 1024 * 1024
    private static let readChunkSize = 64 * 1024

    private static let signedDataOID = Data([
        0x2A, 0x86, 0x48, 0x86, 0xF7,
        0x0D, 0x01, 0x07, 0x02
    ])

    static func parse(from url: URL) throws -> ImportedProvisioningProfile {
        let hasAccess = url.startAccessingSecurityScopedResource()

        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey])

        if let size = values.fileSize, size > maximumFileSize {
            throw ProvisioningProfileError.fileTooLarge
        }

        let data = try readBoundedFile(from: url)

        guard !data.isEmpty else {
            throw ProvisioningProfileError.invalidCMS
        }

        let plistData = try extractCMSContent(from: data)

        guard let profile = try PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw ProvisioningProfileError.invalidPropertyList
        }

        let entitlements = profile["Entitlements"] as? [String: Any] ?? [:]
        let teams = profile["TeamIdentifier"] as? [String] ?? []
        let devices = profile["ProvisionedDevices"] as? [String] ?? []
        let platforms = profile["Platform"] as? [String] ?? []
        let certificates = profile["DeveloperCertificates"] as? [Data] ?? []

        return ImportedProvisioningProfile(
            filename: url.lastPathComponent,
            name: profile["Name"] as? String ?? url.deletingPathExtension().lastPathComponent,
            uuid: profile["UUID"] as? String ?? "Unknown UUID",
            teamIdentifier: teams.first,
            applicationIdentifier: entitlements["application-identifier"] as? String,
            creationDate: profile["CreationDate"] as? Date,
            expirationDate: profile["ExpirationDate"] as? Date,
            deviceCount: devices.count,
            isAllDevices: profile["ProvisionsAllDevices"] as? Bool ?? false,
            getTaskAllowed: entitlements["get-task-allow"] as? Bool,
            platforms: platforms,
            developerCertificateCount: certificates.count
        )
    }

    private static func readBoundedFile(from url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var result = Data()

        while true {
            let remainingCapacity = maximumFileSize - result.count

            let requestedCount = min(
                readChunkSize,
                remainingCapacity + 1
            )

            guard let chunk = try handle.read(upToCount: requestedCount),
                  !chunk.isEmpty else {
                break
            }

            guard chunk.count <= remainingCapacity else {
                throw ProvisioningProfileError.fileTooLarge
            }

            result.append(chunk)
        }

        return result
    }

    private static func extractCMSContent(from data: Data) throws -> Data {
        var offset = 0

        let root = try readElement(
            in: data,
            at: &offset,
            limit: data.count
        )

        guard root.tag == 0x30, root.nextOffset == data.count else {
            throw ProvisioningProfileError.invalidCMS
        }

        let rootChildren = try children(of: root, in: data)

        guard
            rootChildren.count >= 2,
            rootChildren[0].tag == 0x06,
            Data(data[rootChildren[0].content]) == signedDataOID,
            rootChildren[1].tag == 0xA0
        else {
            throw ProvisioningProfileError.invalidCMS
        }

        let explicitChildren = try children(
            of: rootChildren[1],
            in: data
        )

        guard
            let signedData = explicitChildren.first,
            signedData.tag == 0x30
        else {
            throw ProvisioningProfileError.invalidCMS
        }

        let signedDataChildren = try children(
            of: signedData,
            in: data
        )

        guard signedDataChildren.count >= 3 else {
            throw ProvisioningProfileError.invalidCMS
        }

        let encapsulatedContentInfo = signedDataChildren[2]

        guard encapsulatedContentInfo.tag == 0x30 else {
            throw ProvisioningProfileError.invalidCMS
        }

        let contentInfoChildren = try children(
            of: encapsulatedContentInfo,
            in: data
        )

        guard
            contentInfoChildren.count >= 2,
            contentInfoChildren[1].tag == 0xA0
        else {
            throw ProvisioningProfileError.missingContent
        }

        let contentWrapperChildren = try children(
            of: contentInfoChildren[1],
            in: data
        )

        guard let octetElement = contentWrapperChildren.first else {
            throw ProvisioningProfileError.missingContent
        }

        return try extractOctets(
            from: octetElement,
            in: data
        )
    }

    private static func extractOctets(
        from element: DERTLV,
        in data: Data
    ) throws -> Data {
        if element.tag == 0x04 {
            return Data(data[element.content])
        }

        if element.tag == 0x24 {
            let nested = try children(of: element, in: data)
            var result = Data()

            for item in nested {
                result.append(
                    try extractOctets(from: item, in: data)
                )
            }

            return result
        }

        throw ProvisioningProfileError.missingContent
    }

    private static func children(
        of element: DERTLV,
        in data: Data
    ) throws -> [DERTLV] {
        var result: [DERTLV] = []
        var offset = element.content.lowerBound
        let limit = element.content.upperBound

        while offset < limit {
            let child = try readElement(
                in: data,
                at: &offset,
                limit: limit
            )

            result.append(child)
        }

        guard offset == limit else {
            throw ProvisioningProfileError.invalidDER
        }

        return result
    }

    private static func readElement(
        in data: Data,
        at offset: inout Int,
        limit: Int
    ) throws -> DERTLV {
        guard offset < limit, limit <= data.count else {
            throw ProvisioningProfileError.invalidDER
        }

        let tag = data[offset]
        offset += 1

        guard offset < limit else {
            throw ProvisioningProfileError.invalidDER
        }

        let firstLength = data[offset]
        offset += 1

        let length: Int

        if firstLength & 0x80 == 0 {
            length = Int(firstLength)
        } else {
            let byteCount = Int(firstLength & 0x7F)

            guard
                byteCount > 0,
                byteCount <= 4,
                offset + byteCount <= limit
            else {
                throw ProvisioningProfileError.invalidDER
            }

            var decodedLength = 0

            for _ in 0..<byteCount {
                guard decodedLength <= Int.max / 256 else {
                    throw ProvisioningProfileError.invalidDER
                }

                decodedLength = decodedLength * 256 + Int(data[offset])
                offset += 1
            }

            length = decodedLength
        }

        guard length <= limit - offset else {
            throw ProvisioningProfileError.invalidDER
        }

        let contentStart = offset
        let contentEnd = contentStart + length
        offset = contentEnd

        return DERTLV(
            tag: tag,
            content: contentStart..<contentEnd,
            nextOffset: contentEnd
        )
    }
}
