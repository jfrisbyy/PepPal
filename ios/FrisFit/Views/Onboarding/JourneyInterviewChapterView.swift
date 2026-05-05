import SwiftUI
import UIKit

// MARK: - Draft model

/// Disk-backed scratchpad for the Chapter 4 interview. Lives on its own so a
/// user who backs out mid-flow doesn't lose entries. Only flushed to
/// `journey_events` when the user taps "Show my map".
nonisolated struct JourneyInterviewDraft: Codable, Sendable, Equatable {
    var startingWeightLbs: Double?
    var startingDate: Date?
    var startingBodyFatPercent: Double?
    var currentWeightLbs: Double?
    var bodyMilestones: [BodyMilestoneDraft] = []

    var trainingBlockStart: Date?
    var prs: [PRDraft] = []

    var pastCycles: [PastCycleDraft] = []
    var recentPins: [RecentPinDraft] = []

    var lifeEvents: [LifeEventDraft] = []

    var bloodworkDate: Date?
    var bloodworkNote: String?

    nonisolated struct BodyMilestoneDraft: Codable, Sendable, Identifiable, Equatable {
        var id: UUID = UUID()
        var date: Date
        var weightLbs: Double
        var note: String?
    }
    nonisolated struct PRDraft: Codable, Sendable, Identifiable, Equatable {
        var id: UUID = UUID()
        var lift: String
        var weightLbs: Double
        var date: Date
    }
    nonisolated struct PastCycleDraft: Codable, Sendable, Identifiable, Equatable {
        var id: UUID = UUID()
        var compoundName: String
        var doseAmount: Double?
        var doseUnit: String
        var startDate: Date
        var durationWeeks: Int
        var feel: String?
    }
    nonisolated struct RecentPinDraft: Codable, Sendable, Identifiable, Equatable {
        var id: UUID = UUID()
        var compoundName: String
        var doseAmount: Double?
        var doseUnit: String
        var date: Date
    }
    nonisolated struct LifeEventDraft: Codable, Sendable, Identifiable, Equatable {
        var id: UUID = UUID()
        var kind: String
        var date: Date
        var note: String?
    }
}

@MainActor
enum JourneyInterviewDraftStore {
    private static let key = "peppal.onboarding.journeyInterview.v1"

    static func load() -> JourneyInterviewDraft {
        guard let data = UserDefaults.standard.data(forKey: key) else { return JourneyInterviewDraft() }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode(JourneyInterviewDraft.self, from: data)) ?? JourneyInterviewDraft()
    }

    static func save(_ draft: JourneyInterviewDraft) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Wrapper view

/// Runs the guided interview, then hands off to the cinematic
/// `JourneyChapterView` so the reveal lands on a populated map.
struct JourneyChapterContainerView: View {
    let firstName: String
    let primaryGoal: PrimaryGoal?
    let personaTrack: PersonaTrack?
    let unitSystem: UnitSystem
    let prefillWeightKg: Double?
    let onContinue: () -> Void

    @State private var phase: Phase = .interview

    enum Phase { case interview, cinematic }

    var body: some View {
        Group {
            switch phase {
            case .interview:
                JourneyInterviewChapterView(
                    firstName: firstName,
                    primaryGoal: primaryGoal,
                    personaTrack: personaTrack,
                    unitSystem: unitSystem,
                    prefillWeightKg: prefillWeightKg,
                    onFinishedInterview: {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                            phase = .cinematic
                        }
                    }
                )
            case .cinematic:
                JourneyChapterView(firstName: firstName, onContinue: onContinue)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Interview view

struct JourneyInterviewChapterView: View {
    let firstName: String
    let primaryGoal: PrimaryGoal?
    let personaTrack: PersonaTrack?
    let unitSystem: UnitSystem
    let prefillWeightKg: Double?
    let onFinishedInterview: () -> Void

    @State private var draft: JourneyInterviewDraft = JourneyInterviewDraftStore.load()
    @State private var subStep: Int = 0
    @State private var isCommitting: Bool = false

    private var steps: [Step] {
        var s: [Step] = [.intro]
        if showsBody { s.append(.body) }
        if showsTraining { s.append(.training) }
        if showsPeptides {
            s.append(.pastCycles)
            s.append(.recentPins)
        }
        s.append(.life)
        s.append(.bloodwork)
        return s
    }

    enum Step: Hashable {
        case intro, body, training, pastCycles, recentPins, life, bloodwork
    }

    private var showsBody: Bool {
        switch primaryGoal {
        case .fatLoss, .muscleGain, .recomposition, .longevity, .recoveryInjury, .performance:
            return true
        case .none:
            return true
        }
    }
    private var showsTraining: Bool {
        primaryGoal == .muscleGain || primaryGoal == .performance || primaryGoal == .recomposition
    }
    private var showsPeptides: Bool {
        personaTrack == .C
    }

    private var current: Step { steps[min(subStep, steps.count - 1)] }
    private var isLast: Bool { subStep >= steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 12)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .onChange(of: draft) { _, newValue in
            JourneyInterviewDraftStore.save(newValue)
        }
        .onAppear { hydrateInitialDraft() }
    }

    // MARK: Indicator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { idx in
                Capsule()
                    .fill(idx <= subStep ? PepTheme.teal : PepTheme.elevated)
                    .frame(height: 4)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: subStep)
            }
        }
    }

    // MARK: Content router

    @ViewBuilder
    private var content: some View {
        switch current {
        case .intro: introCard
        case .body: bodyCard
        case .training: trainingCard
        case .pastCycles: pastCyclesCard
        case .recentPins: recentPinsCard
        case .life: lifeCard
        case .bloodwork: bloodworkCard
        }
    }

    // MARK: Intro

    private var introCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle().fill(PepTheme.teal.opacity(0.14)).frame(width: 84, height: 84)
                    Image(systemName: "map.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Text(introTitle)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("A few quick questions to sketch the story so far. Skip anything you'd rather not share — we'll fill it in over time.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private var introTitle: String {
        let n = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Let's sketch your journey" : "Let's sketch your journey, \(n)"
    }

    // MARK: Body

    private var bodyCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    title: bodyTitle,
                    subtitle: "Where did this chapter begin? You can skip anything."
                )

                // Starting point
                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        cardLabel("Starting point", icon: "flag.checkered")
                        weightField(
                            placeholder: "Starting weight",
                            value: $draft.startingWeightLbs
                        )
                        DatePicker(
                            "About when?",
                            selection: Binding(
                                get: { draft.startingDate ?? defaultStartDate },
                                set: { draft.startingDate = $0 }
                            ),
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .tint(PepTheme.teal)

                        if primaryGoal == .muscleGain || primaryGoal == .recomposition {
                            HStack(spacing: 10) {
                                Image(systemName: "percent")
                                    .foregroundStyle(PepTheme.textSecondary)
                                TextField(
                                    "Body fat % (optional)",
                                    value: $draft.startingBodyFatPercent,
                                    format: .number
                                )
                                .keyboardType(.decimalPad)
                            }
                        }
                    }
                }

                // Current
                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        cardLabel("Where you are today", icon: "scalemass")
                        weightField(
                            placeholder: "Current weight",
                            value: $draft.currentWeightLbs
                        )
                        Text("Pre-filled from earlier — adjust if it's stale.")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                // Milestones
                milestonesSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private var bodyTitle: String {
        switch primaryGoal {
        case .fatLoss: return "Your weight story"
        case .muscleGain: return "Your build story"
        case .recomposition: return "Your recomp story"
        default: return "Your body baseline"
        }
    }

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Milestones already hit")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(draft.bodyMilestones.count)/5")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            ForEach(draft.bodyMilestones) { entry in
                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(PepTheme.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(formattedWeight(entry.weightLbs)) • \(formattedDate(entry.date))")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        if let note = entry.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                    Spacer()
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            draft.bodyMilestones.removeAll { $0.id == entry.id }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(PepTheme.cardSurface.opacity(0.85))
                .clipShape(.rect(cornerRadius: 12))
            }

            if draft.bodyMilestones.count < 5 {
                inlineMilestoneAdder
            }
        }
    }

    @State private var milestoneDraftWeight: String = ""
    @State private var milestoneDraftDate: Date = Date()
    @State private var milestoneDraftNote: String = ""

    private var inlineMilestoneAdder: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField(unitSystem == .metric ? "kg" : "lb", text: $milestoneDraftWeight)
                    .keyboardType(.decimalPad)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(PepTheme.elevated.opacity(0.7))
                    .clipShape(.rect(cornerRadius: 10))
                    .frame(width: 90)
                DatePicker("", selection: $milestoneDraftDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .tint(PepTheme.teal)
                Spacer()
            }
            TextField("Note (optional) — \"post-vacation\"", text: $milestoneDraftNote)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(PepTheme.elevated.opacity(0.7))
                .clipShape(.rect(cornerRadius: 10))

            Button {
                addMilestone()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add milestone")
                }
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(milestoneAdderEnabled ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background((milestoneAdderEnabled ? PepTheme.teal : PepTheme.textSecondary).opacity(0.10))
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!milestoneAdderEnabled)
        }
        .padding(12)
        .background(PepTheme.cardSurface.opacity(0.5))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.teal.opacity(0.18), lineWidth: 0.6)
        )
    }

    private var milestoneAdderEnabled: Bool {
        Double(milestoneDraftWeight) ?? 0 > 0
    }

    private func addMilestone() {
        guard let raw = Double(milestoneDraftWeight), raw > 0 else { return }
        let lbs = unitSystem == .metric ? UnitConversion.kgToPounds(raw) : raw
        let entry = JourneyInterviewDraft.BodyMilestoneDraft(
            date: milestoneDraftDate,
            weightLbs: lbs,
            note: milestoneDraftNote.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil : milestoneDraftNote
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            draft.bodyMilestones.append(entry)
            milestoneDraftWeight = ""
            milestoneDraftNote = ""
            milestoneDraftDate = Date()
        }
    }

    // MARK: Training

    private var trainingCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    title: "Training baseline",
                    subtitle: "Where's the current block at?"
                )

                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        cardLabel("Current block start", icon: "figure.strengthtraining.traditional")
                        DatePicker(
                            "Started",
                            selection: Binding(
                                get: { draft.trainingBlockStart ?? defaultBlockStart },
                                set: { draft.trainingBlockStart = $0 }
                            ),
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .tint(PepTheme.teal)
                    }
                }

                prSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    @State private var prDraftLift: String = ""
    @State private var prDraftWeight: String = ""
    @State private var prDraftDate: Date = Date()

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PRs to mark")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(draft.prs.count)/3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            ForEach(draft.prs) { pr in
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PepTheme.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(pr.lift) — \(formattedWeight(pr.weightLbs))")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(formattedDate(pr.date))
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            draft.prs.removeAll { $0.id == pr.id }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(PepTheme.cardSurface.opacity(0.85))
                .clipShape(.rect(cornerRadius: 12))
            }

            if draft.prs.count < 3 {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Lift (e.g. Squat)", text: $prDraftLift)
                        .padding(.vertical, 10).padding(.horizontal, 12)
                        .background(PepTheme.elevated.opacity(0.7))
                        .clipShape(.rect(cornerRadius: 10))
                    HStack(spacing: 10) {
                        TextField(unitSystem == .metric ? "kg" : "lb", text: $prDraftWeight)
                            .keyboardType(.decimalPad)
                            .padding(.vertical, 10).padding(.horizontal, 12)
                            .background(PepTheme.elevated.opacity(0.7))
                            .clipShape(.rect(cornerRadius: 10))
                            .frame(width: 100)
                        DatePicker("", selection: $prDraftDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .tint(PepTheme.teal)
                        Spacer()
                    }
                    Button {
                        addPR()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add PR")
                        }
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(prAdderEnabled ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background((prAdderEnabled ? PepTheme.teal : PepTheme.textSecondary).opacity(0.10))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!prAdderEnabled)
                }
                .padding(12)
                .background(PepTheme.cardSurface.opacity(0.5))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private var prAdderEnabled: Bool {
        !prDraftLift.trimmingCharacters(in: .whitespaces).isEmpty
            && (Double(prDraftWeight) ?? 0) > 0
    }

    private func addPR() {
        guard let raw = Double(prDraftWeight), raw > 0 else { return }
        let lbs = unitSystem == .metric ? UnitConversion.kgToPounds(raw) : raw
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            draft.prs.append(.init(
                lift: prDraftLift.trimmingCharacters(in: .whitespaces),
                weightLbs: lbs,
                date: prDraftDate
            ))
            prDraftLift = ""
            prDraftWeight = ""
            prDraftDate = Date()
        }
    }

    // MARK: Past cycles

    @State private var showAddPastCycle: Bool = false

    private var pastCyclesCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(
                    title: "Anything you've run before?",
                    subtitle: "Add past cycles so your timeline reflects your full story."
                )

                ForEach(draft.pastCycles) { c in
                    pastCycleRow(c)
                }

                if draft.pastCycles.count < 5 {
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        showAddPastCycle = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text(draft.pastCycles.isEmpty ? "Add a past cycle" : "Add another")
                                .font(.system(.headline, weight: .semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                Text("Skip if this is your first run.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showAddPastCycle) {
            AddPastCycleSheet { c in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    draft.pastCycles.append(c)
                }
            }
        }
    }

    private func pastCycleRow(_ c: JourneyInterviewDraft.PastCycleDraft) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(PepTheme.teal.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(c.compoundName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(pastCycleSummary(c))
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    draft.pastCycles.removeAll { $0.id == c.id }
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(PepTheme.cardSurface.opacity(0.85))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func pastCycleSummary(_ c: JourneyInterviewDraft.PastCycleDraft) -> String {
        var parts: [String] = []
        if let dose = c.doseAmount { parts.append("\(formatNumber(dose)) \(c.doseUnit)") }
        parts.append("\(c.durationWeeks) wk")
        parts.append(formattedDate(c.startDate))
        if let feel = c.feel, !feel.isEmpty { parts.append(feel) }
        return parts.joined(separator: " • ")
    }

    // MARK: Recent pins

    @State private var showAddRecentPin: Bool = false

    private var recentPinsCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(
                    title: "Recent pins (last 30 days)",
                    subtitle: "Mark anything you've already injected so today picks up where you left off."
                )

                ForEach(draft.recentPins) { p in
                    recentPinRow(p)
                }

                if draft.recentPins.count < 10 {
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        showAddRecentPin = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text(draft.recentPins.isEmpty ? "Add a recent pin" : "Add another")
                                .font(.system(.headline, weight: .semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showAddRecentPin) {
            AddRecentPinSheet { p in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    draft.recentPins.append(p)
                }
            }
        }
    }

    private func recentPinRow(_ p: JourneyInterviewDraft.RecentPinDraft) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "syringe.fill")
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 32, height: 32)
                .background(PepTheme.teal.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(p.compoundName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("\(p.doseAmount.map { "\(formatNumber($0)) \(p.doseUnit)" } ?? "") • \(formattedDate(p.date))")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    draft.recentPins.removeAll { $0.id == p.id }
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(PepTheme.cardSurface.opacity(0.85))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: Life

    @State private var showAddLifeEvent: Bool = false
    @State private var lifeKindForSheet: String = "vacation"

    private let lifeChips: [(kind: String, label: String, icon: String)] = [
        ("vacation", "Vacation", "airplane"),
        ("surgery", "Surgery", "cross.case.fill"),
        ("injury", "Injury", "bandage.fill"),
        ("schedule_change", "Big change", "calendar.badge.clock"),
        ("family", "Family", "house.fill")
    ]

    private var lifeCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(
                    title: "Life context",
                    subtitle: "Anything that shaped this stretch — vacations, life events, an injury?"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                    ForEach(lifeChips, id: \.kind) { chip in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            lifeKindForSheet = chip.kind
                            showAddLifeEvent = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: chip.icon)
                                Text(chip.label)
                                    .lineLimit(1)
                            }
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(PepTheme.cardSurface.opacity(0.85))
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(PepTheme.teal.opacity(0.18), lineWidth: 0.6)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !draft.lifeEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Added")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        ForEach(draft.lifeEvents) { e in
                            HStack(spacing: 10) {
                                Image(systemName: lifeChips.first(where: { $0.kind == e.kind })?.icon ?? "calendar")
                                    .foregroundStyle(PepTheme.violet)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lifeChips.first(where: { $0.kind == e.kind })?.label ?? e.kind.capitalized)
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text("\(formattedDate(e.date))\(e.note.map { " • \($0)" } ?? "")")
                                        .font(.caption)
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                Spacer()
                                Button {
                                    withAnimation {
                                        draft.lifeEvents.removeAll { $0.id == e.id }
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(PepTheme.cardSurface.opacity(0.7))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showAddLifeEvent) {
            AddLifeEventSheet(kind: lifeKindForSheet) { e in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    draft.lifeEvents.append(e)
                }
            }
        }
    }

    // MARK: Bloodwork

    @State private var bloodworkPicked: Bool = false

    private var bloodworkCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(
                    title: "Recent bloodwork?",
                    subtitle: "If you've had labs drawn lately, mark the date so we can line up biomarkers later."
                )

                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: Binding(
                            get: { draft.bloodworkDate != nil || bloodworkPicked },
                            set: { on in
                                if on {
                                    bloodworkPicked = true
                                    if draft.bloodworkDate == nil { draft.bloodworkDate = Date() }
                                } else {
                                    bloodworkPicked = false
                                    draft.bloodworkDate = nil
                                    draft.bloodworkNote = nil
                                }
                            }
                        )) {
                            Text("Yes — I have a recent draw")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        .tint(PepTheme.teal)

                        if draft.bloodworkDate != nil || bloodworkPicked {
                            DatePicker(
                                "Draw date",
                                selection: Binding(
                                    get: { draft.bloodworkDate ?? Date() },
                                    set: { draft.bloodworkDate = $0 }
                                ),
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .tint(PepTheme.teal)

                            TextField(
                                "Note (optional)",
                                text: Binding(
                                    get: { draft.bloodworkNote ?? "" },
                                    set: { draft.bloodworkNote = $0.isEmpty ? nil : $0 }
                                )
                            )
                            .padding(.vertical, 10).padding(.horizontal, 12)
                            .background(PepTheme.elevated.opacity(0.7))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if subStep > 0 {
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        subStep -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 56, height: 54)
                        .background(PepTheme.elevated.opacity(0.7))
                        .clipShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            Button {
                advance()
            } label: {
                HStack(spacing: 8) {
                    if isCommitting {
                        ProgressView().tint(.white)
                    }
                    Text(primaryCTA)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(isCommitting)
        }
    }

    private var primaryCTA: String {
        if isLast { return "Show my map" }
        if current == .intro { return "Continue" }
        return entriesForCurrentStep == 0 ? "Skip" : "Continue"
    }

    private var entriesForCurrentStep: Int {
        switch current {
        case .body:
            var c = 0
            if draft.startingWeightLbs != nil { c += 1 }
            if draft.currentWeightLbs != nil { c += 1 }
            c += draft.bodyMilestones.count
            return c
        case .training:
            return (draft.trainingBlockStart != nil ? 1 : 0) + draft.prs.count
        case .pastCycles: return draft.pastCycles.count
        case .recentPins: return draft.recentPins.count
        case .life: return draft.lifeEvents.count
        case .bloodwork: return draft.bloodworkDate != nil ? 1 : 0
        case .intro: return 0
        }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if isLast {
            commit()
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                subStep += 1
            }
        }
    }

    // MARK: - Commit

    private func commit() {
        guard !isCommitting else { return }
        isCommitting = true
        let snapshot = draft
        Task {
            await JourneyInterviewCommitter.commit(snapshot)
            await MainActor.run {
                JourneyInterviewDraftStore.clear()
                isCommitting = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onFinishedInterview()
            }
        }
    }

    // MARK: - Helpers

    private func hydrateInitialDraft() {
        if draft.currentWeightLbs == nil, let kg = prefillWeightKg {
            draft.currentWeightLbs = UnitConversion.kgToPounds(kg)
        }
    }

    private var defaultStartDate: Date {
        Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    }

    private var defaultBlockStart: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    }

    private func formattedWeight(_ lbs: Double) -> String {
        if unitSystem == .metric {
            let kg = UnitConversion.poundsToKg(lbs)
            return String(format: "%.1f kg", kg)
        }
        return String(format: "%.1f lb", lbs)
    }

    private func formattedDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    private func formatNumber(_ x: Double) -> String {
        if x.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(x))
        }
        return String(format: "%.1f", x)
    }

    @ViewBuilder
    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PepTheme.cardSurface.opacity(0.85))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
            )
    }

    private func cardLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(PepTheme.teal)
            Text(text)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private func weightField(placeholder: String, value: Binding<Double?>) -> some View {
        let displayBinding = Binding<String>(
            get: {
                guard let lbs = value.wrappedValue else { return "" }
                let display = unitSystem == .metric ? UnitConversion.poundsToKg(lbs) : lbs
                return formatNumber(display)
            },
            set: { newText in
                guard let raw = Double(newText), raw > 0 else {
                    value.wrappedValue = nil
                    return
                }
                value.wrappedValue = unitSystem == .metric ? UnitConversion.kgToPounds(raw) : raw
            }
        )
        return HStack(spacing: 10) {
            Image(systemName: "scalemass")
                .foregroundStyle(PepTheme.textSecondary)
            TextField(placeholder, text: displayBinding)
                .keyboardType(.decimalPad)
            Text(unitSystem.weightUnitLabel)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(PepTheme.elevated.opacity(0.7))
        .clipShape(.rect(cornerRadius: 10))
    }
}

// MARK: - Add sheets

private struct AddPastCycleSheet: View {
    let onAdd: (JourneyInterviewDraft.PastCycleDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var doseText: String = ""
    @State private var doseUnit: String = "mg"
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var weeks: Int = 12
    @State private var feel: String?

    private let units = ["mcg", "mg", "iu"]
    private let feelOptions = ["Great", "Okay", "Not for me", "Unsure"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Compound") {
                    TextField("e.g. Semaglutide", text: $name)
                        .textInputAutocapitalization(.words)
                    if !name.isEmpty {
                        let q = name.lowercased()
                        let matches = CompoundDatabase.all.filter { $0.name.lowercased().contains(q) }.prefix(4)
                        ForEach(Array(matches), id: \.id) { p in
                            Button {
                                name = p.name
                            } label: {
                                HStack {
                                    Image(systemName: p.iconName).foregroundStyle(PepTheme.teal)
                                    Text(p.name).foregroundStyle(PepTheme.textPrimary)
                                    Spacer()
                                    Text(p.peptideType).font(.caption).foregroundStyle(PepTheme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Approximate dose") {
                    HStack {
                        TextField("Amount", text: $doseText)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $doseUnit) {
                            ForEach(units, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }
                Section("Window") {
                    DatePicker("Start", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    Stepper(value: $weeks, in: 1...52) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text("\(weeks) wk").foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                Section("How'd it feel?") {
                    Picker("Feel", selection: Binding(
                        get: { feel ?? "" },
                        set: { feel = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("—").tag("")
                        ForEach(feelOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Past cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(.init(
                            compoundName: name.trimmingCharacters(in: .whitespaces),
                            doseAmount: Double(doseText),
                            doseUnit: doseUnit,
                            startDate: startDate,
                            durationWeeks: weeks,
                            feel: feel
                        ))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct AddRecentPinSheet: View {
    let onAdd: (JourneyInterviewDraft.RecentPinDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var doseText: String = ""
    @State private var doseUnit: String = "mcg"
    @State private var date: Date = Date()

    private let units = ["mcg", "mg", "iu"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Compound") {
                    TextField("e.g. Semaglutide", text: $name)
                        .textInputAutocapitalization(.words)
                    if !name.isEmpty {
                        let q = name.lowercased()
                        let matches = CompoundDatabase.all.filter { $0.name.lowercased().contains(q) }.prefix(4)
                        ForEach(Array(matches), id: \.id) { p in
                            Button {
                                name = p.name
                            } label: {
                                HStack {
                                    Image(systemName: p.iconName).foregroundStyle(PepTheme.teal)
                                    Text(p.name).foregroundStyle(PepTheme.textPrimary)
                                    Spacer()
                                    Text(p.peptideType).font(.caption).foregroundStyle(PepTheme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Dose") {
                    HStack {
                        TextField("Amount", text: $doseText)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $doseUnit) {
                            ForEach(units, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }
                Section("When") {
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: (Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())...Date(),
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle("Recent pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(.init(
                            compoundName: name.trimmingCharacters(in: .whitespaces),
                            doseAmount: Double(doseText),
                            doseUnit: doseUnit,
                            date: date
                        ))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct AddLifeEventSheet: View {
    let kind: String
    let onAdd: (JourneyInterviewDraft.LifeEventDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = Date()
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("One-line note") {
                    TextField("Optional", text: $note)
                }
            }
            .navigationTitle(kind.replacingOccurrences(of: "_", with: " ").capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(.init(
                            kind: kind,
                            date: date,
                            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Commit (drafts → JourneyEvents)

@MainActor
enum JourneyInterviewCommitter {
    static func commit(_ draft: JourneyInterviewDraft) async {
        guard let uidStr = try? AuthService.shared.currentUserId(),
              let uid = UUID(uuidString: uidStr) else {
            return
        }
        let svc = JourneyEventService.shared

        // Body — starting point
        if let lbs = draft.startingWeightLbs {
            var payload = JourneyEventPayload()
            payload.weightLbs = lbs
            payload.bodyFatPercent = draft.startingBodyFatPercent
            payload.note = "Starting point"
            let event = JourneyEvent(
                userId: uid,
                lane: .body,
                timestamp: draft.startingDate ?? (Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()),
                title: String(format: "Starting %.1f lbs", lbs),
                description: "Where the journey began",
                sourceType: .manual,
                payload: payload
            )
            await svc.add(event)
        }

        // Body — current
        if let lbs = draft.currentWeightLbs {
            var payload = JourneyEventPayload()
            payload.weightLbs = lbs
            payload.note = "Current"
            let event = JourneyEvent(
                userId: uid,
                lane: .body,
                timestamp: Date(),
                title: String(format: "%.1f lbs today", lbs),
                sourceType: .manual,
                payload: payload
            )
            await svc.add(event)
        }

        // Body — milestones
        for m in draft.bodyMilestones {
            var payload = JourneyEventPayload()
            payload.weightLbs = m.weightLbs
            payload.note = m.note
            let event = JourneyEvent(
                userId: uid,
                lane: .body,
                timestamp: m.date,
                title: String(format: "%.1f lbs", m.weightLbs),
                description: m.note,
                sourceType: .manual,
                payload: payload
            )
            await svc.add(event)
        }

        // Training — block start
        if let start = draft.trainingBlockStart {
            var payload = JourneyEventPayload()
            payload.phaseType = JourneyTrainingPhase.maintenance.rawValue
            payload.startDate = start
            let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
            let event = JourneyEvent(
                userId: uid,
                lane: .training,
                timestamp: start,
                durationDays: max(0, days),
                title: "Current block",
                sourceType: .manual,
                payload: payload
            )
            await svc.add(event)
        }

        // Training — PRs
        for pr in draft.prs {
            var payload = JourneyEventPayload()
            payload.note = "PR"
            let event = JourneyEvent(
                userId: uid,
                lane: .training,
                timestamp: pr.date,
                title: "\(pr.lift) PR — \(Int(pr.weightLbs.rounded())) lbs",
                description: nil,
                sourceType: .manual,
                payload: payload
            )
            await svc.add(event)
        }

        // Compounds — past cycles
        for c in draft.pastCycles {
            var payload = JourneyEventPayload()
            payload.compoundName = c.compoundName
            payload.doseAmount = c.doseAmount
            payload.doseUnit = c.doseUnit
            payload.frequency = "Weekly"
            payload.startDate = c.startDate
            let endDate = Calendar.current.date(byAdding: .day, value: c.durationWeeks * 7, to: c.startDate)
            payload.endDate = endDate
            payload.perceivedResults = c.feel
            let event = JourneyEvent(
                userId: uid,
                lane: .compounds,
                timestamp: c.startDate,
                durationDays: c.durationWeeks * 7,
                title: c.compoundName,
                description: c.feel,
                sourceType: .manual,
                payload: payload
            )
            await svc.add(event)
        }

        // Compounds — recent pins
        for p in draft.recentPins {
            var payload = JourneyEventPayload()
            payload.compoundName = p.compoundName
            payload.doseAmount = p.doseAmount
            payload.doseUnit = p.doseUnit
            let titleDose = p.doseAmount.map { "\(Int($0.rounded())) \(p.doseUnit)" } ?? p.doseUnit
            let event = JourneyEvent(
                userId: uid,
                lane: .compounds,
                timestamp: p.date,
                title: "\(p.compoundName) • \(titleDose)",
                sourceType: .manual,
                payload: payload
            )
            await svc.add(event)
        }

        // Life events
        for e in draft.lifeEvents {
            var payload = JourneyEventPayload()
            payload.lifeEventType = mappedLifeEventType(e.kind)
            payload.shortDescription = e.note
            let label = (JourneyLifeEventType(rawValue: payload.lifeEventType ?? "")?.label) ?? e.kind.capitalized
            let event = JourneyEvent(
                userId: uid,
                lane: .life,
                timestamp: e.date,
                title: label,
                description: e.note,
                sourceType: .manual,
                payload: payload
            )
            await svc.add(event)
        }

        // Bloodwork
        if let date = draft.bloodworkDate {
            let event = JourneyEvent(
                userId: uid,
                lane: .bloodwork,
                timestamp: date,
                title: "Bloodwork draw",
                description: draft.bloodworkNote,
                sourceType: .manual
            )
            await svc.add(event)
        }
    }

    private static func mappedLifeEventType(_ raw: String) -> String {
        switch raw {
        case "vacation": return JourneyLifeEventType.vacation.rawValue
        case "surgery", "injury": return JourneyLifeEventType.surgery.rawValue
        case "schedule_change": return JourneyLifeEventType.scheduleChange.rawValue
        case "family": return JourneyLifeEventType.family.rawValue
        default: return JourneyLifeEventType.other.rawValue
        }
    }
}
