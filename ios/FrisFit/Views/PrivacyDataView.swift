import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Supabase
import Functions
import PostgREST

struct PrivacyDataView: View {
    @State private var isExporting: Bool = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    @State private var showDeleteConfirm: Bool = false
    @State private var isDeleting: Bool = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                introCard

                exportCard
                deleteCard
                linksCard
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .appBackground()
        .navigationTitle("Privacy & Your Data")
        .navigationBarTitleDisplayMode(.large)
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This permanently deletes your account, profile, journey events, dose logs, vials, and AI memory. This action cannot be undone.")
        }
        .sheet(item: $exportFile) { file in
            PrivacyExportShareSheet(url: file.url)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.title3)
                    .foregroundStyle(PepTheme.teal)
                Text("Your data, your control")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Text("Export everything EPTI stores about you, delete your account at any time, or review our policies below.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var exportCard: some View {
        privacyCard(
            icon: "square.and.arrow.up",
            iconColor: PepTheme.teal,
            title: "Export my data",
            subtitle: "Bundles your profile, journey events, dose logs, vials, AI memory, and disclaimer acknowledgements into a single JSON file you can save or share."
        ) {
            VStack(spacing: 8) {
                Button {
                    Task { await exportData() }
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export to JSON")
                                .font(.system(.body, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.teal)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isExporting)

                if let exportError {
                    Text(exportError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var deleteCard: some View {
        privacyCard(
            icon: "trash.fill",
            iconColor: .red,
            title: "Delete my account",
            subtitle: "Removes your account and every row of your personal data from our servers. You will be signed out immediately."
        ) {
            VStack(spacing: 8) {
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                            Text("Delete account")
                                .font(.system(.body, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)

                if let deleteError {
                    Text(deleteError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("POLICIES")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                Link(destination: URL(string: "https://peppalapp.com/privacy")!) {
                    linkRow(icon: "hand.raised.fill", title: "Privacy Policy")
                }
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                Link(destination: URL(string: "https://peppalapp.com/terms")!) {
                    linkRow(icon: "doc.text.fill", title: "Terms of Service")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func linkRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(PepTheme.textPrimary)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func privacyCard<Body: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Body
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func exportData() async {
        exportError = nil
        isExporting = true
        defer { isExporting = false }

        do {
            let userId = try AuthService.shared.currentUserId()
            let bundle = await PrivacyDataExporter.buildExport(userId: userId)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let stamp = formatter.string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let filename = "peppal-export-\(stamp).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try bundle.write(to: url, options: .atomic)
            exportFile = ExportFile(url: url)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            exportError = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func deleteAccount() async {
        deleteError = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await AccountDeletionService.deleteAccountAndSignOut()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            ErrorLogger.shared.log(error, screen: "PrivacyDataView.delete")
            deleteError = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

private struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct PrivacyExportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum PrivacyDataExporter {
    static func buildExport(userId: String) async -> Data {
        let supabase = SupabaseService.shared.client

        async let profile = fetchJSON {
            try await supabase.from("profiles").select().eq("id", value: userId).execute().data
        }
        async let journeyEvents = fetchJSON {
            try await supabase.from("journey_events").select().eq("user_id", value: userId).execute().data
        }
        async let doseLogs = fetchJSON {
            try await supabase.from("dose_logs").select().eq("user_id", value: userId).execute().data
        }
        async let vialInventory = fetchJSON {
            try await supabase.from("vial_inventory").select().eq("user_id", value: userId).execute().data
        }
        async let aiMemory = fetchJSON {
            try await supabase.from("ai_memory_facts").select().eq("user_id", value: userId).execute().data
        }
        async let disclaimerAcks = fetchJSON {
            try await supabase.from("disclaimer_acknowledgements").select().eq("user_id", value: userId).execute().data
        }

        let bundle: [String: Any] = [
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "user_id": userId,
            "schema_version": 1,
            "profile": await profile,
            "journey_events": await journeyEvents,
            "dose_logs": await doseLogs,
            "vial_inventory": await vialInventory,
            "ai_memory_facts": await aiMemory,
            "disclaimer_acknowledgements": await disclaimerAcks
        ]

        if let data = try? JSONSerialization.data(
            withJSONObject: bundle,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            return data
        }
        return Data("{}".utf8)
    }

    private static func fetchJSON(_ load: () async throws -> Data) async -> Any {
        do {
            let data = try await load()
            return (try? JSONSerialization.jsonObject(with: data, options: [])) ?? []
        } catch {
            return ["error": error.localizedDescription]
        }
    }
}
