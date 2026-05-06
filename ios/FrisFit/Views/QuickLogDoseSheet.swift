import SwiftUI

/// Lightweight wrapper around `LogDoseSheet` that resolves the active protocol
/// from the home view-model / insights store so the FAB action can present a
/// log-dose flow without needing to be opened from a specific protocol detail.
struct QuickLogDoseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var resolved: PeptideProtocol?
    @State private var detailVM: ProtocolDetailViewModel?
    @State private var isLoading: Bool = true

    var body: some View {
        Group {
            if let vm = detailVM {
                LogDoseSheet(viewModel: vm)
            } else if isLoading {
                NavigationStack {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(PepTheme.teal)
                        Text("Loading protocol…")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .appBackground()
                    .navigationTitle("Log Dose")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { dismiss() }
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            } else {
                emptyState
            }
        }
        .task { await resolveProtocol() }
    }

    private var emptyState: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "syringe")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(PepTheme.teal.opacity(0.7))
                Text("No active protocol")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Set up a protocol to start logging doses, vials, sites, and side effects.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(.body, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
            .navigationTitle("Log Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private func resolveProtocol() async {
        // Prefer cached active protocol from the insights store (already loaded
        // by HomeView). If that's empty, fetch fresh from Supabase.
        if let cached = InsightsDataStore.shared.primaryProtocol {
            resolved = cached
            detailVM = ProtocolDetailViewModel(protocolData: cached)
            isLoading = false
            return
        }

        do {
            let protocols = try await ProtocolService.shared.fetchProtocols()
            let active = protocols.first(where: { $0.isActive }) ?? protocols.first
            resolved = active
            if let active {
                detailVM = ProtocolDetailViewModel(protocolData: active)
            }
        } catch {
            // fall through — empty state will show
        }
        isLoading = false
    }
}
