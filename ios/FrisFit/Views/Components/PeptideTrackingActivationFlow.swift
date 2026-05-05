import SwiftUI
import UIKit

/// Modal flow that walks a Track A user through the gating sequence required
/// to unlock peptide-related surfaces:
///
/// 1. Medical disclaimer (if not yet acknowledged)
/// 2. Date-of-birth / age gate (if missing)
/// 3. Pregnancy gate (if female and not yet answered)
/// 4. Activation question — "currently or previously on a protocol?"
///    Yes → `personaTrack = .C`, No → `personaTrack = .B`
///
/// Logs `activated_peptide_tracking` via `PeptideAnalytics` with the originating
/// surface, then dismisses and lets the caller refresh.
struct PeptideTrackingActivationFlow: View {
    let surface: PeptideAnalytics.Surface
    let onActivated: (PersonaTrack) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var access = PeptideAccessManager.shared

    @State private var stage: Stage = .intro
    @State private var disclaimerPresented: Bool = false
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var sex: BiologicalSex = .male
    @State private var pregnancyAnswer: Bool? = nil
    @State private var isFinalizing: Bool = false

    private enum Stage {
        case intro
        case disclaimer
        case ageBlocked
        case ageEntry
        case pregnancyEntry
        case activationQuestion
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PepTheme.background.ignoresSafeArea()
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
            .navigationTitle("Peptide tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .sheet(isPresented: $disclaimerPresented, onDismiss: {
                advanceFromDisclaimer()
            }) {
                MedicalDisclaimerGateView(isPresented: $disclaimerPresented)
                    .interactiveDismissDisabled(true)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            PeptideAnalytics.tappedActivationCTA(surface: surface)
            primeStage()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .intro: introStage
        case .disclaimer: disclaimerLoader
        case .ageBlocked: ageBlockedStage
        case .ageEntry: ageEntryStage
        case .pregnancyEntry: pregnancyEntryStage
        case .activationQuestion: activationStage
        }
    }

    // MARK: - Intro

    private var introStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroHeader(
                    icon: "syringe.fill",
                    title: "Activate peptide tracking",
                    subtitle: "Just a few quick checks, then EPTI unlocks vial scanning, protocols, dose logging, and reconstitution math."
                )

                checklistRow(symbol: "doc.text.fill", title: "Acknowledge the medical disclaimer", done: MedicalDisclaimerManager.hasAccepted)
                checklistRow(symbol: "person.fill", title: "Confirm you're 18+", done: access.isAdult)
                if access.biologicalSex == .female {
                    checklistRow(symbol: "heart.fill", title: "Confirm pregnancy/nursing status", done: pregnancyResolved)
                }
                checklistRow(symbol: "checkmark.seal.fill", title: "Tell us how you'll use it", done: false)

                Spacer(minLength: 24)

                primaryButton(title: "Continue") {
                    advanceFromIntro()
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var pregnancyResolved: Bool {
        // Pregnant/nursing locks compound surfaces, but for the gate to be considered
        // answered we just need the user to have submitted an answer.
        UserDefaults.standard.object(forKey: "peppal.compoundSurfaces.isPregnantOrNursing.v1") != nil
    }

    // MARK: - Disclaimer

    private var disclaimerLoader: some View {
        VStack {
            ProgressView()
                .controlSize(.large)
                .tint(PepTheme.teal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { disclaimerPresented = true }
    }

    private func advanceFromDisclaimer() {
        if MedicalDisclaimerManager.hasAccepted {
            advance()
        } else {
            // User dismissed without accepting — close the flow.
            dismiss()
        }
    }

    // MARK: - Age blocked (terminal)

    private var ageBlockedStage: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(PepTheme.amber.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(PepTheme.amber)
            }
            VStack(spacing: 10) {
                Text("18+ only")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Peptide tracking is restricted to users 18 or older. The rest of EPTI stays available.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            primaryButton(title: "Close") { dismiss() }
        }
    }

    // MARK: - Age entry

    private var ageEntryStage: some View {
        VStack(alignment: .leading, spacing: 20) {
            heroHeader(
                icon: "person.fill",
                title: "Quick check",
                subtitle: "Peptide tracking is for adults only. Confirm your date of birth and biological sex so we can calibrate safety guidance."
            )

            VStack(spacing: 14) {
                DatePicker("Date of birth", selection: $dob, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(PepTheme.cardSurface.opacity(0.6))
                    .clipShape(.rect(cornerRadius: 12))

                Picker("Biological sex", selection: $sex) {
                    ForEach(BiologicalSex.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            Spacer()

            primaryButton(title: "Continue") {
                access.dateOfBirth = dob
                access.biologicalSex = sex
                advance()
            }
        }
    }

    // MARK: - Pregnancy entry

    private var pregnancyEntryStage: some View {
        VStack(alignment: .leading, spacing: 20) {
            heroHeader(
                icon: "heart.fill",
                title: "One more thing",
                subtitle: "Are you currently pregnant or nursing? Compound tracking stays locked while pregnant or nursing — you can flip this in Settings any time."
            )

            VStack(spacing: 12) {
                pregnancyOption(label: "No", value: false)
                pregnancyOption(label: "Yes", value: true)
            }

            Spacer()

            primaryButton(title: "Continue", disabled: pregnancyAnswer == nil) {
                guard let answer = pregnancyAnswer else { return }
                access.setPregnancyState(answer)
                advance()
            }
        }
    }

    private func pregnancyOption(label: String, value: Bool) -> some View {
        let isSelected = pregnancyAnswer == value
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                pregnancyAnswer = value
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack {
                Text(label)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary.opacity(0.6))
            }
            .padding(16)
            .background(isSelected ? PepTheme.teal.opacity(0.12) : PepTheme.cardSurface.opacity(0.6))
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Activation question

    private var activationStage: some View {
        VStack(alignment: .leading, spacing: 20) {
            heroHeader(
                icon: "syringe.fill",
                title: "How will you use it?",
                subtitle: "This shapes the rest of your experience — we can always adjust later."
            )

            VStack(spacing: 12) {
                activationOption(
                    icon: "syringe.fill",
                    title: "I'm currently or have been on a protocol",
                    subtitle: "Full peptide capture, cycles, dosing, vials.",
                    track: .C
                )
                activationOption(
                    icon: "book.fill",
                    title: "Just curious — researching for now",
                    subtitle: "Education-first surfaces, no active dosing required.",
                    track: .B
                )
            }

            Spacer()

            if isFinalizing {
                ProgressView().tint(PepTheme.teal)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }
        }
    }

    private func activationOption(icon: String, title: String, subtitle: String, track: PersonaTrack) -> some View {
        Button {
            finalizeActivation(track: track)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PepTheme.teal.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }
            .padding(16)
            .background(PepTheme.cardSurface.opacity(0.6))
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isFinalizing)
    }

    private func finalizeActivation(track: PersonaTrack) {
        guard !isFinalizing else { return }
        isFinalizing = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        access.setPersonaTrack(track)
        PeptideAnalytics.activatedPeptideTracking(from: surface, resolvedTrack: track)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onActivated(track)
            dismiss()
        }
    }

    // MARK: - Stage flow

    private func primeStage() {
        if access.personaTrack == nil {
            access.personaTrack = .A
        }
        if access.biologicalSex == nil, let stored = UserDefaults.standard.string(forKey: "peppal.compoundSurfaces.biologicalSex.v1") {
            access.biologicalSex = BiologicalSex(rawValue: stored)
        }
        if access.biologicalSex == .female { sex = .female }
        if let storedDob = access.dateOfBirth { dob = storedDob }
    }

    private func advanceFromIntro() {
        if !MedicalDisclaimerManager.hasAccepted {
            stage = .disclaimer
            return
        }
        advance()
    }

    private func advance() {
        if !MedicalDisclaimerManager.hasAccepted {
            stage = .disclaimer
            return
        }
        if access.dateOfBirth == nil || access.biologicalSex == nil {
            stage = .ageEntry
            return
        }
        if !access.isAdult {
            stage = .ageBlocked
            return
        }
        if access.biologicalSex == .female, !pregnancyResolved {
            stage = .pregnancyEntry
            return
        }
        if access.biologicalSex == .female, access.isPregnantOrNursing {
            stage = .ageBlocked
            return
        }
        stage = .activationQuestion
    }

    // MARK: - Shared chrome

    private func heroHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
            }
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func checklistRow(symbol: String, title: String, done: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(done ? .green : PepTheme.teal)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(PepTheme.cardSurface.opacity(0.45))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func primaryButton(title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(disabled ? PepTheme.elevated : PepTheme.teal)
                .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
