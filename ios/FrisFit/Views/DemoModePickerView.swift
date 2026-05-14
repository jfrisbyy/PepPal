import SwiftUI

struct DemoModePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var demo = DemoModeManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if demo.isActive, let s = demo.activeScenario {
                    activeBanner(for: s)
                }

                VStack(spacing: 14) {
                    ForEach(DemoScenario.allCases, id: \.self) { scenario in
                        personaCard(for: scenario)
                    }
                }

                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Demo Mode")
        .navigationBarTitleDisplayMode(.large)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Six scenario personas. Tap one to load every screen with realistic, screenshot-ready data — no Supabase, no flakiness.")
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func activeBanner(for s: DemoScenario) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(s.accent)
                .frame(width: 10, height: 10)
                .shadow(color: s.accent.opacity(0.6), radius: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("Demo: \(s.displayName) active")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(s.headline)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Button {
                withAnimation { demo.deactivate() }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Text("Exit")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PepTheme.elevated, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(s.accent.opacity(0.08)))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(s.accent.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func personaCard(for scenario: DemoScenario) -> some View {
        let isActive = demo.activeScenario == scenario
        let persona = DemoPersonaLibrary.persona(for: scenario)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                demo.activate(scenario)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Pop back to app so the user can see the populated screens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                dismiss()
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    avatar(for: scenario)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scenario.headline.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(scenario.accent)
                        Text(scenario.fullName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(scenario.archetype)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(scenario.accent)
                    }
                }

                Text(scenario.teaser)
                    .font(.system(size: 13))
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let p = persona {
                    HStack(spacing: 18) {
                        statChip(value: "\(p.currentStreak)d", label: "Streak")
                        statChip(value: "\(p.totalWorkouts)", label: "Workouts")
                        statChip(value: "\(p.followers)", label: "Followers")
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        PepTheme.cardSurface,
                        scenario.accent.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isActive ? scenario.accent.opacity(0.55) : PepTheme.glassBorderTop,
                        lineWidth: isActive ? 1.5 : 0.5
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func avatar(for scenario: DemoScenario) -> some View {
        ZStack {
            Circle()
                .fill(scenario.accent.opacity(0.18))
                .overlay(Circle().strokeBorder(scenario.accent.opacity(0.4), lineWidth: 1))
            Text(scenario.avatarInitial)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(scenario.accent)
        }
        .frame(width: 52, height: 52)
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOW IT WORKS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(PepTheme.textSecondary)
            Text("Tapping a persona loads bundled data into every shared store in the app. No network, no Supabase writes. Exit anytime to return to your real account.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
    }
}

// MARK: - Persistent pill overlay

struct DemoModePill: View {
    @State private var demo = DemoModeManager.shared

    var body: some View {
        if let s = demo.activeScenario {
            HStack(spacing: 8) {
                Circle()
                    .fill(s.accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: s.accent.opacity(0.7), radius: 3)
                Text("Demo: \(s.displayName)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Button {
                    withAnimation { demo.deactivate() }
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: .capsule)
            .overlay(
                Capsule().strokeBorder(s.accent.opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
