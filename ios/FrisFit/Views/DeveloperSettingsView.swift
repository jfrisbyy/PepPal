import SwiftUI

struct DeveloperSettingsView: View {
    @State private var isGenerating: Bool = false
    @State private var isRemoving: Bool = false
    @State private var isWipingMyData: Bool = false
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false
    @State private var showRemoveConfirm: Bool = false
    @State private var showWipeMyDataConfirm: Bool = false
    @State private var showStreakDebug: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DEVELOPER")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.8)

            Text("Demo Mode is the single source of truth for screenshot-ready data. Pick one of six scenario personas to load every screen with bundled, deterministic data. No Supabase, no flakiness.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                demoModeRow
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
                    if isGenerating || isRemoving || isWipingMyData {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(statusIsError ? .red : .green)
                    }
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background((statusIsError ? Color.red : Color.green).opacity(0.1), in: .rect(cornerRadius: 10))
                .animation(.easeInOut(duration: 0.2), value: statusMessage)
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
        .alert("Wipe my seeded screenshot data?", isPresented: $showWipeMyDataConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Wipe", role: .destructive) { Task { await wipeMyData() } }
        } message: {
            Text("Removes seeded posts, workouts, weight logs, meals, protocols, vials, dose logs, biomarkers, daily tasks, and activity from your account. Real data you logged yourself is preserved.")
        }
    }

    // MARK: - Demo Mode

    private var demoModeRow: some View {
        NavigationLink {
            DemoModePickerView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "theatermasks.fill")
                    .font(.body)
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Demo Mode")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        if let s = DemoModeManager.shared.activeScenario {
                            Text(s.displayName.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(s.accent, in: .capsule)
                        }
                    }
                    Text("Six scenario personas with fully bundled data — dashboards, workouts, meals, protocols, labs, sleep, social.")
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

    // MARK: - Legacy (unused, kept compiled out)

    private var fakeAccountSwitcherRow: some View {
        NavigationLink {
            FakeAccountSwitcherView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "theatermasks.fill")
                    .font(.body)
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Fake account switcher")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        if FakeAccountService.shared.isImpersonating {
                            Text("IMPERSONATING")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange, in: .capsule)
                        }
                    }
                    Text("Sign in as any fake persona. Switching back restores your real account.")
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

    private var generatePersonasRow: some View {
        Button { Task { await generate() } } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.body)
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate fake personas")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Creates the 25-persona pool and fully populates every account in Supabase — workouts, weights, meals, doses, PRs, posts, groups, DMs. Idempotent — safe to re-run anytime.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isGenerating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isGenerating || isRemoving)
    }

    private var removeRow: some View {
        Button { showRemoveConfirm = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.body)
                    .foregroundStyle(.red)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete all fake personas")
                        .font(.body)
                        .foregroundStyle(.red)
                    Text("Wipes every fake auth user and their data from Supabase.")
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
        .disabled(isGenerating || isRemoving)
    }

    private var wipeMyDataRow: some View {
        Button { showWipeMyDataConfirm = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "eraser.fill")
                    .font(.body)
                    .foregroundStyle(.red)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wipe my seeded data")
                        .font(.body)
                        .foregroundStyle(.red)
                    Text("Removes screenshot-mode data from your own account. Use before App Store submission.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isWipingMyData {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isWipingMyData)
    }

    // MARK: - Housekeeping rows (unchanged)

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
                    Text("Re-presents the flow immediately. Supabase rows are kept; local draft + completion flag are cleared.")
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

    // MARK: - Actions

    private func generate() async {
        isGenerating = true
        statusIsError = false
        statusMessage = "Starting…"
        defer { isGenerating = false }
        do {
            let result = try await FakeAccountService.shared.generateFakePersonas { phase in
                Task { @MainActor in
                    statusMessage = phase
                }
            }
            let summary = "\(result.totalPersonas) personas · \(result.workouts) workouts · \(result.meals) meals · \(result.weights) weights · \(result.doses) doses · \(result.prs) PRs · \(result.posts) posts · \(result.groups) groups · \(result.dmThreads) DM threads."
            statusMessage = summary
            statusIsError = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
            statusIsError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func wipeMyData() async {
        isWipingMyData = true
        statusMessage = "Wiping your seeded data…"
        statusIsError = false
        defer { isWipingMyData = false }
        do {
            try await FakeAccountService.shared.wipeMyScreenshotData()
            statusMessage = "Wiped your seeded screenshot data."
            statusIsError = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
            statusIsError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func remove() async {
        isRemoving = true
        statusMessage = "Removing fake personas…"
        statusIsError = false
        defer { isRemoving = false }
        do {
            let res = try await TestFriendsService.shared.remove()
            statusMessage = "Removed \(res.deleted ?? 0) fake personas."
            statusIsError = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
            statusIsError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
