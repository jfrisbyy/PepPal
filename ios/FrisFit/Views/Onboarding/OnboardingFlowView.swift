import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    let onSignIn: () -> Void
    let onComplete: () -> Void

    @State private var state: OnboardingState = OnboardingFlowView.makeRestoredState()
    @State private var showCompletionPreview: Bool = false
    @State private var showTrackBCuriosity: Bool = false

    @State private var sessionStartedAt: Date = Date()
    @State private var chapterStartedAt: Date = Date()
    @State private var lastTrackedChapter: OnboardingChapter? = nil
    @State private var perChapterSeconds: [String: Int] = [:]

    private static func makeRestoredState() -> OnboardingState {
        let s = OnboardingState()
        guard let draft = OnboardingManager.loadDraft() else { return s }
        if let step = OnboardingStep(rawValue: draft.step) { s.step = step }
        if let raw = draft.personaTrack, let track = PersonaTrack(rawValue: raw) { s.personaTrack = track }
        s.disclaimerAcceptedAt = draft.disclaimerAcceptedAt
        if let v = draft.disclaimerVersion { s.disclaimerVersion = v }
        s.firstName = draft.firstName
        s.dateOfBirth = draft.dateOfBirth
        if let raw = draft.biologicalSex { s.biologicalSex = BiologicalSex(rawValue: raw) }
        s.isPregnantOrNursing = draft.isPregnantOrNursing
        if let u = UnitSystem(rawValue: draft.unitSystem) { s.unitSystem = u }
        s.heightCm = draft.heightCm
        s.weightKg = draft.weightKg
        s.bodyFatPercent = draft.bodyFatPercent
        s.neckCm = draft.neckCm
        s.waistCm = draft.waistCm
        s.hipCm = draft.hipCm
        if let raw = draft.activityLevel { s.activityLevel = ActivityLevel(rawValue: raw) }
        s.bmrKcal = draft.bmrKcal
        s.tdeeKcal = draft.tdeeKcal
        s.dailyWaterMl = draft.dailyWaterMl
        s.dailyStepFloor = draft.dailyStepFloor
        if let c = draft.starterCalories, let p = draft.starterProtein, let cb = draft.starterCarbs, let f = draft.starterFat {
            s.starterMacros = MacroTarget(calories: c, protein: p, carbs: cb, fat: f)
        }
        if let raw = draft.primaryGoal { s.primaryGoal = PrimaryGoal(rawValue: raw) }
        if let raw = draft.secondaryGoal { s.secondaryGoal = PrimaryGoal(rawValue: raw) }
        s.targetWeightKg = draft.targetWeightKg
        s.targetBodyFatPercent = draft.targetBodyFatPercent
        s.targetPerformanceMetric = draft.targetPerformanceMetric
        s.targetDate = draft.targetDate
        s.sessionsPerWeek = draft.sessionsPerWeek
        s.trainingModalities = Set(draft.trainingModalities.compactMap { TrainingModality(rawValue: $0) })
        if let raw = draft.experienceLevel { s.experienceLevel = TrainingExperience(rawValue: raw) }
        s.currentProgramName = draft.currentProgramName
        s.injuries = Set(draft.injuries.compactMap { InjuryArea(rawValue: $0) })
        s.otherInjuryNote = draft.otherInjuryNote
        if let raw = draft.dietStyle { s.dietStyle = DietStyle(rawValue: raw) }
        if let raw = draft.priorTracker { s.priorTracker = PriorTracker(rawValue: raw) }
        s.proteinPerKgOverride = draft.proteinPerKgOverride
        s.allergies = Set(draft.allergies)
        s.allergiesOther = draft.allergiesOther
        s.restrictions = Set(draft.restrictions)
        s.restrictionsOther = draft.restrictionsOther
        s.goalDefaults = draft.goalDefaults
        if let u = draft.socialUsername { s.username = u }
        s.avatarColorHex = draft.avatarColorHex
        s.avatarImageURL = draft.avatarImageURL
        return s
    }

    private func snapshotDraft() -> OnboardingDraft {
        OnboardingDraft(
            step: state.step.rawValue,
            personaTrack: state.personaTrack?.rawValue,
            disclaimerAcceptedAt: state.disclaimerAcceptedAt,
            disclaimerVersion: state.disclaimerVersion,
            firstName: state.firstName,
            dateOfBirth: state.dateOfBirth,
            biologicalSex: state.biologicalSex?.rawValue,
            isPregnantOrNursing: state.isPregnantOrNursing,
            unitSystem: state.unitSystem.rawValue,
            heightCm: state.heightCm,
            weightKg: state.weightKg,
            bodyFatPercent: state.bodyFatPercent,
            neckCm: state.neckCm,
            waistCm: state.waistCm,
            hipCm: state.hipCm,
            activityLevel: state.activityLevel?.rawValue,
            bmrKcal: state.bmrKcal,
            tdeeKcal: state.tdeeKcal,
            dailyWaterMl: state.dailyWaterMl,
            dailyStepFloor: state.dailyStepFloor,
            starterCalories: state.starterMacros?.calories,
            starterProtein: state.starterMacros?.protein,
            starterCarbs: state.starterMacros?.carbs,
            starterFat: state.starterMacros?.fat,
            primaryGoal: state.primaryGoal?.rawValue,
            secondaryGoal: state.secondaryGoal?.rawValue,
            targetWeightKg: state.targetWeightKg,
            targetBodyFatPercent: state.targetBodyFatPercent,
            targetPerformanceMetric: state.targetPerformanceMetric,
            targetDate: state.targetDate,
            sessionsPerWeek: state.sessionsPerWeek,
            trainingModalities: state.trainingModalities.map { $0.rawValue }.sorted(),
            experienceLevel: state.experienceLevel?.rawValue,
            currentProgramName: state.currentProgramName,
            injuries: state.injuries.map { $0.rawValue }.sorted(),
            otherInjuryNote: state.otherInjuryNote,
            dietStyle: state.dietStyle?.rawValue,
            priorTracker: state.priorTracker?.rawValue,
            proteinPerKgOverride: state.proteinPerKgOverride,
            allergies: Array(state.allergies).sorted(),
            allergiesOther: state.allergiesOther,
            restrictions: Array(state.restrictions).sorted(),
            restrictionsOther: state.restrictionsOther,
            goalDefaults: state.goalDefaults,
            socialUsername: state.username.isEmpty ? nil : state.username,
            avatarColorHex: state.avatarColorHex,
            avatarImageURL: state.avatarImageURL
        )
    }

    var body: some View {
        ZStack {
            PepTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                topBar

                stepContainer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 8)
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(true)
        .onChange(of: state.step) { _, newStep in
            OnboardingManager.saveDraft(snapshotDraft())
            handleChapterChange(to: newStep.chapter)
        }
        .onAppear {
            OnboardingManager.saveDraft(snapshotDraft())
            if lastTrackedChapter == nil {
                PeptideAnalytics.onboardingStarted()
            }
            handleChapterChange(to: state.step.chapter)
        }
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                if state.previousStep(from: state.step) != nil && state.step != .welcome {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(PepTheme.elevated.opacity(0.6))
                            .clipShape(Circle())
                    }
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }

                Spacer()

                Text(state.step.chapter.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                Spacer()

                if state.step.canSkip && state.step != .welcome {
                    Button("Skip") {
                        skip()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 52, height: 36)
                } else {
                    Color.clear.frame(width: 52, height: 36)
                }
            }
            .padding(.horizontal, 20)

            OnboardingProgressBar(
                activeChapter: state.step.chapter,
                progressInChapter: progressInChapter
            )
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var stepContainer: some View {
        Group {
            switch state.step {
            case .welcome:
                WelcomeStepView(onContinue: advance, onSignIn: onSignIn)
            case .disclaimer:
                DisclaimerStepView(state: state, onAccept: advance)
            case .persona:
                PersonaForkStepView(state: state, onContinue: {
                    if let persona = state.personaTrack {
                        PeptideAccessManager.shared.personaTrack = persona
                        Task { await OnboardingManager.persistPersona(persona) }
                    }
                    advance()
                })
            case .account:
                AccountStepView(state: state, onCreated: advance, onSignIn: onSignIn)
            case .socialIdentity:
                SocialIdentityStepView(state: state, onContinue: {
                    let username = state.username.trimmingCharacters(in: .whitespacesAndNewlines)
                    let color = state.avatarColorHex
                    let imageData = state.avatarImageData
                    Task {
                        let uploaded = await OnboardingManager.persistSocialIdentity(
                            username: username,
                            avatarColorHex: color,
                            avatarImageData: imageData
                        )
                        await MainActor.run {
                            if let uploaded { state.avatarImageURL = uploaded }
                            state.avatarImageData = nil
                        }
                    }
                    advance()
                })
            case .aboutYou:
                AboutYouStepView(state: state, onContinue: {
                    if let dob = state.dateOfBirth,
                       let sex = state.biologicalSex,
                       let h = state.heightCm,
                       let w = state.weightKg,
                       let activity = state.activityLevel {
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
                    }
                    advance()
                })
            case .ageBlocked:
                AgeBlockedView(
                    onSupport: openSupport,
                    onBack: { goBack() }
                )
            case .pregnancyGate:
                PregnancyGateStepView(state: state, onContinue: {
                    if let answer = state.isPregnantOrNursing {
                        PeptideAccessManager.shared.isPregnantOrNursing = answer
                        Task { await OnboardingManager.persistPregnancyAnswer(answer) }
                    }
                    advance()
                })
            case .connect:
                ConnectStepView(onContinue: {
                    Task { await OnboardingMemorySeeder.seedHealthKitSummary() }
                    advance()
                })
            case .journey:
                journeyChapter
            case .goals:
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
                    advance()
                })
            case .finish:
                finishChapter
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: state.step)
    }

    private var journeyChapter: some View {
        JourneyChapterContainerView(
            firstName: state.firstName,
            primaryGoal: state.primaryGoal,
            personaTrack: state.personaTrack,
            unitSystem: state.unitSystem,
            prefillWeightKg: state.weightKg,
            onContinue: {
                OnboardingMemorySeeder.seedJourneyEvents(
                    firstName: state.firstName,
                    primaryGoal: state.primaryGoal
                )
                advance()
            }
        )
    }

    @ViewBuilder
    private var finishChapter: some View {
        if showCompletionPreview {
            OnboardingCompletionPreviewView(
                firstName: state.firstName,
                onGo: { finish() }
            )
        } else if state.personaTrack == .C && state.canAccessCompoundSurfaces {
            OnboardingProtocolChapterView(
                state: state,
                onComplete: { presentCompletionPreview() }
            )
        } else if state.personaTrack == .B && !showTrackBCuriosity {
            OnboardingTrackBCuriosityView(
                firstName: state.firstName,
                onComplete: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        showTrackBCuriosity = true
                    }
                    presentCompletionPreview()
                }
            )
        } else {
            OnboardingCompletionPreviewView(
                firstName: state.firstName,
                onGo: { finish() }
            )
            .onAppear {
                stageSuccessCardCounts()
            }
        }
    }

    // MARK: - Funnel + time analytics (Prompt 19)

    private func handleChapterChange(to next: OnboardingChapter) {
        if let prev = lastTrackedChapter, prev != next {
            let elapsed = Int(Date().timeIntervalSince(chapterStartedAt))
            perChapterSeconds[prev.analyticsKey, default: 0] += elapsed
            PeptideAnalytics.onboardingChapterCompleted(
                chapter: prev.analyticsKey,
                persona: state.personaTrack?.rawValue,
                secondsInChapter: elapsed
            )
        }
        if lastTrackedChapter != next {
            chapterStartedAt = Date()
            PeptideAnalytics.onboardingChapterStarted(
                chapter: next.analyticsKey,
                persona: state.personaTrack?.rawValue
            )
            lastTrackedChapter = next
        }
    }

    private func presentCompletionPreview() {
        stageSuccessCardCounts()
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            showCompletionPreview = true
        }
    }

    private func stageSuccessCardCounts() {
        let factCount = AIMemoryStore.shared.allFacts().count
        let hkDays = JourneyMapStagingStore.load()?.days.count ?? 0
        let pinCount = JourneyEventService.shared.events.count
        var protoLine: String? = nil
        if let proto = InsightsDataStore.shared.primaryProtocol, let c = proto.compounds.first {
            let dose = CompoundUnitHelper.displayDoseShort(c.doseMcg, for: c.compoundName)
            protoLine = "\(c.compoundName) \(dose) \(c.frequency)"
        }
        OnboardingManager.stageSuccessCardCounts(
            firstName: state.firstName,
            factCount: factCount,
            hkDays: hkDays,
            pinCount: pinCount,
            protocolDescription: protoLine
        )
    }

    private func placeholderStep(icon: String, title: String, body: String, primary: String = "Continue") -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
            }
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer()
            Button {
                if state.step == .finish {
                    finish()
                } else {
                    advance()
                }
            } label: {
                Text(primary)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PepTheme.teal)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var progressInChapter: Double {
        let chapter = state.step.chapter
        let stepsInChapter = OnboardingStep.allCases.filter { $0.chapter == chapter }
        guard let idx = stepsInChapter.firstIndex(of: state.step), !stepsInChapter.isEmpty else {
            return 1
        }
        return Double(idx + 1) / Double(stepsInChapter.count)
    }

    private func advance() {
        UISelectionFeedbackGenerator().selectionChanged()
        guard let next = state.nextStep(from: state.step) else {
            finish()
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            state.step = next
        }
    }

    private func goBack() {
        guard let prev = state.previousStep(from: state.step) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            state.step = prev
        }
    }

    private func skip() {
        guard state.step.canSkip else { return }
        advance()
    }

    private func openSupport() {
        if let url = URL(string: "https://peppalapp.com/support") {
            UIApplication.shared.open(url)
        }
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let prev = lastTrackedChapter {
            let elapsed = Int(Date().timeIntervalSince(chapterStartedAt))
            perChapterSeconds[prev.analyticsKey, default: 0] += elapsed
            PeptideAnalytics.onboardingChapterCompleted(
                chapter: prev.analyticsKey,
                persona: state.personaTrack?.rawValue,
                secondsInChapter: elapsed
            )
        }
        let totalSeconds = Int(Date().timeIntervalSince(sessionStartedAt))
        PeptideAnalytics.onboardingCompleted(
            persona: state.personaTrack?.rawValue,
            totalSeconds: totalSeconds,
            perChapterSeconds: perChapterSeconds
        )
        OnboardingManager.markCompleted()
        Task { await OnboardingMemorySeeder.runCorrelationWarmUp() }
        onComplete()
    }
}
