import SwiftUI

struct DeveloperSettingsView: View {
    @State private var isSeeding: Bool = false
    @State private var isRemoving: Bool = false
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false
    @State private var showRemoveConfirm: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DEVELOPER")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.8)

            Text("Tools for testing. Manages the shared pool of 25 realistic fake personas everyone follows.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                seedRow
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                refreshRow
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                removeRow
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                resetOnboardingRow
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                rerunOnboardingRow
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                aiMemoryDebugRow
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                onboardingQARow
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                streakDebugRow
            }

            if let msg = statusMessage {
                HStack(spacing: 8) {
                    Image(systemName: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(statusIsError ? .red : .green)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background((statusIsError ? Color.red : Color.green).opacity(0.1), in: .rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
        .alert("Remove fake personas?", isPresented: $showRemoveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { Task { await remove() } }
        } message: {
            Text("Deletes every fake persona globally — their auth users, profiles, posts, and follow rows. Affects all users.")
        }
    }

    private var seedRow: some View {
        Button { Task { await seed(refresh: false) } } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.body)
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Seed 25 fake personas")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Curated profiles with avatars, banners, posts, streaks, and a follow graph")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isSeeding {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isSeeding || isRemoving)
    }

    private var refreshRow: some View {
        Button { Task { await seed(refresh: true) } } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.body)
                    .foregroundStyle(PepTheme.violet)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Refresh fake personas")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Re-runs the seed idempotently — syncs profiles, posts, and follows")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isSeeding {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isSeeding || isRemoving)
    }

    private var removeRow: some View {
        Button { showRemoveConfirm = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.body)
                    .foregroundStyle(.red)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove fake personas")
                        .font(.body)
                        .foregroundStyle(.red)
                    Text("Deletes every seeded profile, their auth user, and their data")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isRemoving {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isSeeding || isRemoving)
    }

    @State private var showStreakDebug: Bool = false

    private var streakDebugRow: some View {
        Button { showStreakDebug = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "flame.circle.fill")
                    .font(.body)
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak debug")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Simulate missed day, force freeze/pause, seed N-day streak, reset")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showStreakDebug) {
            StreakDebugSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var onboardingQARow: some View {
        NavigationLink {
            OnboardingQAView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.body)
                    .foregroundStyle(.green)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Onboarding QA")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Verify the Day-1 home experience meets every Prompt 17 requirement")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var aiMemoryDebugRow: some View {
        NavigationLink {
            AIMemoryDebugView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "brain")
                    .font(.body)
                    .foregroundStyle(PepTheme.violet)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Memory Debug")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Inspect every fact persisted in AIMemoryStore for the active user")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var rerunOnboardingRow: some View {
        Button {
            OnboardingManager.rerunNow()
            statusMessage = "Re-running onboarding now on this account."
            statusIsError = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.body)
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Re-run onboarding now")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Re-presents the flow immediately on this account — useful for QA on partially-complete users. Supabase rows are kept; local draft + completion flag are cleared.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var resetOnboardingRow: some View {
        Button {
            OnboardingManager.reset()
            statusMessage = "Onboarding will show on next launch."
            statusIsError = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.body)
                    .foregroundStyle(PepTheme.amber)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset onboarding")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Show the welcome flow again on next app launch")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func seed(refresh: Bool) async {
        isSeeding = true
        statusMessage = nil
        defer { isSeeding = false }
        do {
            let res = try await TestFriendsService.shared.seed()
            let created = res.created ?? 0
            let existed = res.existed ?? 0
            let total = res.total_test_profiles ?? (created + existed)
            if refresh {
                statusMessage = "Refreshed \(total) fake personas."
            } else {
                statusMessage = "\(total) fake personas ready — \(created) new, \(existed) existing."
            }
            statusIsError = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func remove() async {
        isRemoving = true
        statusMessage = nil
        defer { isRemoving = false }
        do {
            let res = try await TestFriendsService.shared.remove()
            statusMessage = "Removed \(res.deleted ?? 0) fake personas."
            statusIsError = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
