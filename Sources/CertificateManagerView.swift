
import SwiftUI
import UniformTypeIdentifiers

struct CertificateManagerView: View {
    @StateObject private var store = CertificateStore()

    @State private var isImporting = false
    @State private var showPasswordPrompt = false
    @State private var selectedFile: URL?
    @State private var password = ""
    @State private var errorMessage: String?

    private var p12Type: UTType {
        UTType(filenameExtension: "p12", conformingTo: .data) ?? .data
    }

    private var pfxType: UTType {
        UTType(filenameExtension: "pfx", conformingTo: .data) ?? .data
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Certificates")
                            .font(.largeTitle.bold())

                        Text("Manage your signing identities.")
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
                                description: Text(
                                    "Import a .p12 or .pfx file to get started."
                                )
                            )
                            .padding(.vertical, 20)
                        } else {
                            ForEach(store.certificates) { certificate in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Color(uiColor: .tertiarySystemBackground)
                                        )
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 12)
                                        )

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
                                    .accessibilityLabel(
                                        "Remove \(certificate.displayName)"
                                    )
                                }
                                .padding()
                                .background(
                                    Color(uiColor: .secondarySystemBackground)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }

                    Text(
                        "Certificate identities are currently stored in memory and will not survive an app restart."
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
                allowedContentTypes: [p12Type, pfxType],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        return
                    }

                    selectedFile = url
                    password = ""
                    showPasswordPrompt = true

                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showPasswordPrompt) {
                NavigationStack {
                    Form {
                        Section("Selected Certificate") {
                            Text(
                                selectedFile?.lastPathComponent ?? "No file selected"
                            )
                            .font(.subheadline)
                        }

                        Section("Certificate Password") {
                            SecureField(
                                "Enter password",
                                text: $password
                            )
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
                }
                .presentationDetents([.medium, .large])
            }
            .alert(
                "Certificate Import",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
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
            errorMessage = error.localizedDescription
        }
    }

    private func closePasswordPrompt() {
        showPasswordPrompt = false
        password = ""
        selectedFile = nil
    }
}
