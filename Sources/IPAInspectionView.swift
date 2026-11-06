
import SwiftUI

struct IPAInspectionView: View {
    let file: ImportedIPA

    @State private var inspection: IPAInspection?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                appHeader

                if isLoading {
                    ProgressView("Inspecting IPA...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let inspection {
                    metadataSection(inspection)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Inspection Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("IPA Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await inspectIPA()
        }
    }

    private var appHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.dashed")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(inspection?.appName ?? file.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(file.formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func metadataSection(_ info: IPAInspection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Application Information")
                .font(.title2.bold())

            metadataRow("App Name", value: info.appName)
            metadataRow("Bundle Identifier", value: info.bundleIdentifier)
            metadataRow("Version", value: info.version)
            metadataRow("Build Number", value: info.buildNumber)
            metadataRow("Minimum iOS", value: info.minimumiOSVersion)

            if let iconName = info.iconName {
                metadataRow("Icon Filename", value: iconName)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metadataRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @MainActor
    private func inspectIPA() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try IPAInspection.inspect(at: file.url)
            }.value

            inspection = result
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
