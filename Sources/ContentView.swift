
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var ipaStore = IPAFileStore()

    var body: some View {
        TabView {
            HomeView(store: ipaStore)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            InspectorView(store: ipaStore)
                .tabItem {
                    Label("Inspect", systemImage: "doc.text.magnifyingglass")
                }

            CertificatesView()
                .tabItem {
                    Label("Certificates", systemImage: "checkmark.seal")
                }

            RepositoriesView()
                .tabItem {
                    Label("Repos", systemImage: "globe")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Home

struct HomeView: View {
    @ObservedObject var store: IPAFileStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Zign")
                            .font(.system(size: 38, weight: .bold))

                        Text("IPA signing and management")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        DashboardCard(
                            title: "IPA Files",
                            value: "\(store.files.count)",
                            symbol: "doc.zipper"
                        )

                        DashboardCard(
                            title: "Certificates",
                            value: "0",
                            symbol: "checkmark.seal"
                        )
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Quick Actions")
                            .font(.title2.bold())

                        NavigationLink {
                            InspectorView(store: store)
                        } label: {
                            QuickActionRow(
                                title: "Inspect IPA",
                                subtitle: "Import and manage application packages",
                                symbol: "doc.text.magnifyingglass"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: CertificatesView()) {
                            QuickActionRow(
                                title: "Manage Certificates",
                                subtitle: "Manage signing credentials",
                                symbol: "checkmark.seal"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: RepositoriesView()) {
                            QuickActionRow(
                                title: "Repositories",
                                subtitle: "Manage IPA sources",
                                symbol: "globe"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Development Status")
                            .font(.title2.bold())

                        Text("IPA importing is now being implemented.")
                            .foregroundStyle(.secondary)

                        Text("Signing functionality is not yet available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding()
            }
            .background(Color(uiColor: .systemBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Inspector

struct InspectorView: View {
    @ObservedObject var store: IPAFileStore

    @State private var isImporting = false
    @State private var importError: String?

    private var ipaType: UTType {
        UTType(filenameExtension: "ipa", conformingTo: .zip) ?? .zip
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("IPA Inspector")
                            .font(.largeTitle.bold())

                        Text("Import and manage your IPA packages.")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isImporting = true
                    } label: {
                        Label(
                            "Import IPA",
                            systemImage: "square.and.arrow.down"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Imported Files")
                                .font(.title2.bold())

                            Spacer()

                            Text("\(store.files.count)")
                                .foregroundStyle(.secondary)
                        }

                        if store.files.isEmpty {
                            ContentUnavailableView(
                                "No IPA Files",
                                systemImage: "doc.zipper",
                                description: Text(
                                    "Import an IPA file to get started."
                                )
                            )
                            .padding(.vertical, 20)
                        } else {
                            ForEach(store.files) { file in
                                IPAFileRow(
                                    file: file,
                                    onDelete: {
                                        do {
                                            try store.delete(file)
                                        } catch {
                                            importError = error.localizedDescription
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Inspector")
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [ipaType],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    do {
                        try store.importFiles(urls)
                    } catch {
                        importError = error.localizedDescription
                    }

                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert(
                "Import Error",
                isPresented: Binding(
                    get: { importError != nil },
                    set: { if !$0 { importError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    importError = nil
                }
            } message: {
                Text(importError ?? "An unknown error occurred.")
            }
        }
    }
}

// MARK: - IPA File Row

struct IPAFileRow: View {
    let file: ImportedIPA
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            NavigationLink {
                IPAInspectionView(file: file)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.zipper")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.headline)
                            .lineLimit(1)

                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .padding(8)
            }
            .accessibilityLabel("Delete \(file.name)")
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Certificates

struct CertificatesView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)

                Text("Certificates")
                    .font(.title2.bold())

                Text(
                    "Manage your signing certificates and provisioning profiles."
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Text("No certificates imported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Certificates")
        }
    }
}

// MARK: - Repositories

struct RepositoriesView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "globe")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)

                Text("Repositories")
                    .font(.title2.bold())

                Text("Manage sources for IPA packages.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("No repositories added.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Repositories")
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Label("Dark Appearance", systemImage: "moon")
                }

                Section("Application") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text("Zign")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Developer") {
                    DeveloperRow(
                        platform: "Discord",
                        username: "zenithhh_.",
                        symbol: "bubble.left.and.bubble.right"
                    )

                    DeveloperRow(
                        platform: "TikTok",
                        username: "whatzenithhh",
                        symbol: "music.note"
                    )

                    DeveloperRow(
                        platform: "X",
                        username: "sheloveszennnn",
                        symbol: "at"
                    )

                    DeveloperRow(
                        platform: "GitHub",
                        username: "isuckatswift",
                        symbol: "chevron.left.forwardslash.chevron.right"
                    )
                }

                Section {
                    Text("Zign — Zenith Sign")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("An independent iOS application signing project.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Reusable Components

struct DashboardCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)

            Text(value)
                .font(.system(size: 30, weight: .bold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct QuickActionRow: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct DeveloperRow: View {
    let platform: String
    let username: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(platform)

                Text(username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
