
import SwiftUI
import UniformTypeIdentifiers

struct CertificateManagerView: View {
    @StateObject private var store = CertificateStore()
    @StateObject private var profileStore = ProvisioningProfileStore()

    @State private var isImporting = false
    @State private var importKind: ImportKind = .certificate
    @State private var showPasswordPrompt = false
    @State private var selectedFile: URL?
    @State private var password = ""

    @State private var alertTitle = "Import"
    @State private var alertMessage: String?

    private enum ImportKind {
        case certificate
        case profile
    }

    private var p12Type: UTType {
        UTType(filenameExtension: "p12", conformingTo: .data) ?? .data
    }

    private var pfxType: UTType {
        UTType(filenameExtension: "pfx", conformingTo: .data) ?? .data
    }

    private var profileType: UTType {
        UTType(filenameExtension: "mobileprovision", conformingTo: .data) ?? .data
    }

    private var allowedTypes: [UTType] {
        switch importKind {
        case .certificate:
            return [p12Type, pfxType]
        case .profile:
            return [profileType]
        }
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
                        importKind = .certificate
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
                        importKind = .profile
                        isImporting = true
                    } label: {
                        Label("Import Provisioning Profile", systemImage: "doc.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    certificateSection
                    profileSection
                    failedProfileSection

                    Text("Signing identities are stored in the device Keychain. Provisioning profile files are stored locally in the app's Application Support directory. CMS signatures are not yet verified.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Certificates")
            .task {
                await loadCertificates()
                loadProfiles()
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: allowedTypes,
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

    // MARK: - Failed Profile Loading

    private var failedProfileSection: some View {
        Group {
            if !profileStore.failedProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        "Profiles Could Not Be Loaded",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.orange)

                    Text(
                        "\(profileStore.failedProfiles.count) saved profile(s) could not be loaded. Other valid profiles remain available."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    ForEach(
                        Array(profileStore.failedProfiles.enumerated()),
                        id: \.offset
                    ) { _, failure in
                        Text(failure)
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(10)
                            .background(
                                Color(uiColor: .tertiarySystemBackground)
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 10)
                            )
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Certificates

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Imported Certificates")
                    .font(.title2.bold())

                Spacer()

                Text("\(store.certificates.count)")
                    .foregroundStyle(.secondary)
            }

            if store.isLoading {
                ProgressView("Loading certificates...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if store.certificates.isEmpty {
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
                            Task {
                                await removeCertificate(certificate)
                            }
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

    // MARK: - Provisioning Profiles

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Provisioning Profiles")
                    .font(.title2.bold())

                Spacer()

                Text("\(profileStore.profiles.count)")
                    .foregroundStyle(.secondary)
            }

            if profileStore.profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "doc.text",
                    description: Text("Import a .mobileprovision file.")
                )
                .padding(.vertical, 12)
            } else {
                ForEach(profileStore.profiles) { profile in
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
                    removeProfile(profile)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Remove profile")
            }

            Divider()

            profileDetail("Team", value: profile.teamIdentifier ?? "Unavailable")
            profileDetail("Application ID", value: profile.applicationIdentifier ?? "Unavailable")
            profileDetail("Created", value: formattedDate(profile.creationDate))
            profileDetail("Expires", value: formattedDate(profile.expirationDate))

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
                value: profile.getTaskAllowed.map {
                    $0 ? "Enabled" : "Disabled"
                } ?? "Unavailable"
            )

            Divider()

            Text("Embedded Certificates")
                .font(.headline)

            if profile.certificateMetadata.isEmpty {
                Text("No embedded certificates found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(profile.certificateMetadata.enumerated()),
                    id: \.offset
                ) { index, certificate in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Certificate \(index + 1)")
                            .font(.subheadline.bold())

                        profileDetail(
                            "Subject",
                            value: certificate.subjectCommonName ?? "Unavailable"
                        )

                        profileDetail(
                            "Issuer",
                            value: certificate.issuerCommonName ?? "Unavailable"
                        )

                        profileDetail(
                            "Valid from",
                            value: formattedDate(certificate.notValidBefore)
                        )

                        profileDetail(
                            "Valid until",
                            value: formattedDate(certificate.notValidAfter)
                        )

                        profileDetail(
                            "SHA-256 fingerprint",
                            value: certificate.sha256Fingerprint
                        )
                    }
                    .padding()
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Text("Certificate metadata extracted only. CMS signature and certificate trust have not been verified.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func profileDetail(_ title: String, value: String) -> some View {
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

    // MARK: - Password Sheet

    private var passwordSheet: some View {
        NavigationStack {
            Form {
                Section("Selected Certificate") {
                    Text(selectedFile?.lastPathComponent ?? "No file selected")
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

    // MARK: - Loading

    private func loadCertificates() async {
        do {
            try await store.loadCertificates()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func loadProfiles() {
        do {
            try profileStore.loadProfiles()
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Removal

    private func removeCertificate(
        _ certificate: StoredSigningIdentity
    ) async {
        do {
            try await store.remove(certificate)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func removeProfile(
        _ profile: ImportedProvisioningProfile
    ) {
        do {
            try profileStore.removeProfile(profile)
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }

            switch importKind {
            case .certificate:
                selectedFile = url
                password = ""
                showPasswordPrompt = true

            case .profile:
                importProfile(from: url)
            }

        case .failure(let error):
            showError(error.localizedDescription)
        }
    }

    private func importProfile(from url: URL) {
        do {
            try profileStore.importProfile(from: url)

            alertTitle = "Profile Imported"
            alertMessage = "The provisioning profile was saved locally. Its CMS signature has not been verified."
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func importCertificate() {
        guard let selectedFile else {
            return
        }

        let file = selectedFile
        let enteredPassword = password

        Task {
            do {
                try await store.importPKCS12(
                    from: file,
                    password: enteredPassword
                )

                closePasswordPrompt()
                alertTitle = "Certificate Imported"
                alertMessage = "The signing identity was saved to the device Keychain."
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

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
