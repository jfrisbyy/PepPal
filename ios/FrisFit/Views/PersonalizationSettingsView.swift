import SwiftUI
import UIKit

/// Settings → Personalization. The "I made a mistake" path:
/// - Switch persona track (downgrade direct, upgrade via activation flow).
/// - Re-run About You / Goals if stats or goals change materially.
struct PersonalizationSettingsView: View {
    @State private var access = PeptideAccessManager.shared
    @State private var showActivationFlow: Bool = false
    @State private var showAboutYouSheet: Bool = false
    @State private var showGoalsSheet: Bool = false
    @State private var showDowngradeConfirm: Bool = false
    @State private var pendingDowngradeTarget: PersonaTrack?
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                trackSection
                rerunSection
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .appBackground()
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showActivationFlow) {
            PeptideTrackingActivationFlow(surface: .settingsToggle) { resolved in
                statusMessage = "Switched to Track \(resolved.rawValue)."
            }
        }
        .sheet(isPresented: $showAboutYouSheet) {
            RerunAboutYouSheet(isPresented: $showAboutYouSheet) {
                statusMessage = "Saved updated body stats."
            }
        }
        .sheet(isPresented: $showGoalsSheet) {
            RerunGoalsSheet(isPresented: $showGoalsSheet) {
                statusMessage = "Saved updated goals."
            }
        }
        .alert("Switch persona track?", isPresented: $showDowngradeConfirm, presenting: pendingDowngradeTarget) { target in
            Button("Cancel", role: .cancel) { pendingDowngradeTarget = nil }
            Button("Switch") { performDowngrade(to: target) }
        } message: { target in
            Text("This switches you to Track \(target.rawValue). Compound surfaces will render the empty state until you reactivate peptide tracking.")
        }
    }

    private var trackSection: some View {
        SectionCard(title: "Persona Track") {
            VStack(spacing: 10) {
                ForEach(PersonaTrack.allCases, id: \.self) { track in
                    trackRow(track)
                }
                Text("Switching to Track A locks compound surfaces immediately. Switching to B or C runs the disclaimer + age + pregnancy gates again.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
    }

    private func trackRow(_ track: PersonaTrack) -> some View {
        let isCurrent = access.personaTrack == track
        return Button {
            handleTrackSelection(track)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PepTheme.teal.opacity(isCurrent ? 0.22 : 0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: track.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(track.subtitle)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isCurrent ? .green : PepTheme.textSecondary.opacity(0.5))
            }
            .padding(12)
            .background(isCurrent ? PepTheme.teal.opacity(0.08) : PepTheme.elevated.opacity(0.4))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
    }

    private func handleTrackSelection(_ target: PersonaTrack) {
        guard target != access.personaTrack else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        if target == .A {
            pendingDowngradeTarget = .A
            showDowngradeConfirm = true
        } else {
            // Upgrade path — run the full gating flow so disclaimer + age + pregnancy are
            // re-checked. The activation flow ends with the user choosing B or C, so we
            // don't pre-commit `target` here.
            showActivationFlow = true
        }
    }

    private func performDowngrade(to target: PersonaTrack) {
        access.setPersonaTrack(target)
        pendingDowngradeTarget = nil
        statusMessage = "Switched to Track \(target.rawValue)."
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var rerunSection: some View {
        SectionCard(title: "Update Profile") {
            VStack(spacing: 0) {
                rerunRow(
                    icon: "person.text.rectangle.fill",
                    title: "Re-run About You",
                    subtitle: "Update height, weight, body fat, activity. Recomputes BMR / TDEE."
                ) { showAboutYouSheet = true }
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                rerunRow(
                    icon: "target",
                    title: "Re-run Goals",
                    subtitle: "Change primary goal, training context, nutrition. Recomputes starter macros."
                ) { showGoalsSheet = true }
            }
        }
    }

    private func rerunRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section card

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.8)
            content()
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
    }
}

// MARK: - Re-run sheets

private struct RerunAboutYouSheet: View {
    @Binding var isPresented: Bool
    let onSaved: () -> Void

    @State private var state: OnboardingState = RerunAboutYouSheet.makeState()

    private static func makeState() -> OnboardingState {
        let s = OnboardingState()
        let access = PeptideAccessManager.shared
        s.dateOfBirth = access.dateOfBirth
        s.biologicalSex = access.biologicalSex
        s.isPregnantOrNursing = access.isPregnantOrNursing
        // Pre-fill cached weight if available
        let cachedLbs = UserDefaults.standard.double(forKey: PrefKey.cachedWeightLbs.rawValue)
        if cachedLbs > 0 {
            s.weightKg = UnitConversion.poundsToKg(cachedLbs)
        }
        return s
    }

    var body: some View {
        NavigationStack {
            AboutYouStepView(state: state, onContinue: {
                guard let dob = state.dateOfBirth,
                      let sex = state.biologicalSex,
                      let h = state.heightCm,
                      let w = state.weightKg,
                      let activity = state.activityLevel else { return }
                let firstName = state.firstName
                let bf = state.bodyFatPercent
                Task {
                    await OnboardingManager.persistAboutYou(
                        firstName: firstName,
                        dateOfBirth: dob,
                        biologicalSex: sex,
                        heightCm: h,
                        weightKg: w,
                        bodyFatPercent: bf,
                        activityLevel: activity
                    )
                }
                OnboardingMemorySeeder.seedAboutYou(state: state)
                PeptideAccessManager.shared.updateFromOnboarding(
                    dateOfBirth: dob,
                    biologicalSex: sex,
                    isPregnantOrNursing: nil
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSaved()
                isPresented = false
            })
            .appBackground()
            .navigationTitle("About You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct RerunGoalsSheet: View {
    @Binding var isPresented: Bool
    let onSaved: () -> Void

    @State private var state: OnboardingState = RerunGoalsSheet.makeState()

    private static func makeState() -> OnboardingState {
        let s = OnboardingState()
        // Pre-fill what's needed for goals to compute defaults: weight + activity + sex.
        let access = PeptideAccessManager.shared
        s.dateOfBirth = access.dateOfBirth
        s.biologicalSex = access.biologicalSex
        let cachedLbs = UserDefaults.standard.double(forKey: PrefKey.cachedWeightLbs.rawValue)
        if cachedLbs > 0 {
            s.weightKg = UnitConversion.poundsToKg(cachedLbs)
        }
        s.activityLevel = .moderate
        return s
    }

    var body: some View {
        NavigationStack {
            GoalsStepView(state: state, onContinue: {
                let snapshot = OnboardingManager.GoalsSnapshot(
                    primary: state.primaryGoal,
                    secondary: state.secondaryGoal,
                    targetWeightKg: state.targetWeightKg,
                    targetBodyFat: state.targetBodyFatPercent,
                    targetPerformance: state.targetPerformanceMetric,
                    targetDate: state.targetDate,
                    sessionsPerWeek: state.sessionsPerWeek,
                    modalities: state.trainingModalities,
                    experience: state.experienceLevel,
                    currentProgram: state.currentProgramName,
                    injuries: state.injuries,
                    otherInjury: state.otherInjuryNote,
                    dietStyle: state.dietStyle,
                    priorTracker: state.priorTracker,
                    proteinPerKg: state.proteinPerKgOverride,
                    allergies: state.allergies,
                    restrictions: state.restrictions,
                    defaults: state.goalDefaults
                )
                Task { await OnboardingManager.persistGoals(snapshot) }
                OnboardingMemorySeeder.seedGoals(state: state)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSaved()
                isPresented = false
            })
            .appBackground()
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
