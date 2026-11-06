
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            InspectorView()
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
                            value: "0",
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

                        NavigationLink(destination: InspectorView()) {
                            QuickActionRow(
                                title: "Inspect IPA",
                                subtitle: "View application package information",
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

                        Text("Zign is under active development.")
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
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Inspector

struct InspectorView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "doc.zipper")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)

                Text("IPA Inspector")
                    .font(.title2.bold())

                Text("Import and inspect IPA packages.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("IPA importing and package analysis are coming soon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Inspector")
        }
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

                Text("Manage your signing certificates and provisioning profiles.")
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
