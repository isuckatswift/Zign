
import SwiftUI
import UniformTypeIdentifiers

struct CertificateManagerView: View {
    @StateObject private var store = CertificateStore()

    @State private var profiles: [ImportedProvisioningProfile] = []

    @State private var isImporting = false
    @State private var showPasswordPrompt = false
    @State private var selectedFile: URL?
    @State private var password = ""

    @State private var alertTitle = "Import"
    @State private var alertMessage: String?

    private var p12Type: UTType {
        UTType(filenameExtension: "p12", conformingTo: .data) ?? .data
    }

    private var pfxType: UTType {
        UTType(filenameExtension: "pfx", conformingTo: .data) ?? .data
    }

    private var profileType: UTType {
        UTType(filenameExtension: "mobileprovision", conformingTo: .data) ?? .data
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Certificates")
                            .font(.largeTitle.bold())

                        Text("Manage signing identities and provisioning profiles.")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isImporting = true
                    } label: {
                        Label("Import Certificate", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        isImporting = true
                    } label: {
                        Label("Import Provisioning Profile", systemImage: "doc.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    certificateSection

                    profileSection

                    Text(
                        "Signing identities are currently stored in memory. Provisioning profile metadata is also temporary and will not survive an app restart."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Certificates")
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [p12Type, pfxType, profileType],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showPasswordPrompt) {
                passwordSheet
            }
            .alert(
                alertTitle,
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { if !$0 { alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Imported Certificates")
                    .font(.title2.bold())

                Spacer()

                Text("\(store.certificates.count)")
                    .foregroundStyle(.secondary)
            }

            if store.certificates.isEmpty {
                ContentUnavailableView(
                    "No Certificates",
                    systemImage: "checkmark.seal",
                    description: Text("Import a .p12 or .pfx file.")
                )
                .padding(.vertical, 12)
            } else {
                ForEach(store.certificates) { certificate in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 44, height: 44)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(certificate.displayName)
                                .font(.headline)
                                .lineLimit(2)

                            Text("Signing identity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            store.remove(certificate)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .padding(8)
                        }
                        .accessibilityLabel("Remove certificate")
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Provisioning Profiles")
                    .font(.title2.bold())

                Spacer()

                Text("\(profiles.count)")
                    .foregroundStyle(.secondary)
            }

            if profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "doc.text",
                    description: Text("Import a .mobileprovision file.")
                )
                .padding(.vertical, 12)
            } else {
                ForEach(profiles) { profile in
                    profileCard(profile)
                }
            }
        }
    }

    private func profileCard(
        _ profile: ImportedProvisioningProfile
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.headline)

                    Text(profile.uuid)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Button(role: .destructive) {
                    profiles.removeAll { $0.id == profile.id }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Remove profile")
            }

            Divider()

            profileDetail(
                "Team",
                value: profile.teamIdentifier ?? "Unavailable"
            )

            profileDetail(
                "Application ID",
                value: profile.applicationIdentifier ?? "Unavailable"
            )

            profileDetail(
                "Created",
                value: formattedDate(profile.creationDate)
            )

            profileDetail(
                "Expires",
                value: formattedDate(profile.expirationDate)
            )

            profileDetail(
                "Devices",
                value: profile.isAllDevices
                    ? "All devices"
                    : "\(profile.deviceCount) registered devices"
            )

            profileDetail(
                "Developer certificates",
                value: "\(profile.developerCertificateCount)"
            )

            profileDetail(
                "Platforms",
                value: profile.platforms.isEmpty
                    ? "Unavailable"
                    : profile.platforms.joined(separator: ", ")
            )

            profileDetail(
                "Get-task-allow",
                value: profile.getTaskAllowed.map { $0 ? "Enabled" : "Disabled" }
                    ?? "Unavailable"
            )

            Text("Metadata extracted only — CMS signature not verified.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func profileDetail(
        _ title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "Unavailable"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var passwordSheet: some View {
        NavigationStack {
            Form {
                Section("Selected Certificate") {
                    Text(
                        selectedFile?.lastPathComponent ?? "No file selected"
                    )
                    .font(.subheadline)
                }

                Section("Certificate Password") {
                    SecureField("Enter password", text: $password)
                }

                Section {
                    Button {
                        importCertificate()
                    } label: {
                        Text("Import Certificate")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(password.isEmpty)
                }
            }
            .navigationTitle("Import Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        closePasswordPrompt()
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func handleFileImport(
        _ result: Result<[URL], Error>
    ) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }

            if url.pathExtension.lowercased() == "mobileprovision" {
                importProfile(from: url)
            } else {
                selectedFile = url
                password = ""
                showPasswordPrompt = true
            }

        case .failure(let error):
            showError(error.localizedDescription)
        }
    }

    private func importProfile(from url: URL) {
        do {
            let profile = try ProvisioningProfileParser.parse(from: url)
            profiles.append(profile)

            alertTitle = "Profile Imported"
            alertMessage = """
            Profile metadata was extracted successfully.

            The CMS signature has not been verified.
            """
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func importCertificate() {
        guard let selectedFile else {
            return
        }

        do {
            try store.importPKCS12(
                from: selectedFile,
                password: password
            )

            closePasswordPrompt()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func closePasswordPrompt() {
        showPasswordPrompt = false
        password = ""
        selectedFile = nil
    }

    private func showError(_ message: String) {
        alertTitle = "Import Failed"
        alertMessage = message
    }
}
