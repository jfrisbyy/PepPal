import SwiftUI

struct PreSessionBriefView: View {
    @Bindable var homeVM: HomeViewModel
    @Bindable var trainVM: TrainViewModel
    var onStartWorkout: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var appeared: Bool = false
    @State private var showReview: Bool = false
    @State private var expandedWarmupId: UUID? = nil

    private let healthKit = HealthKitService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 22) {
                    headerSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    readinessSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.05), value: appeared)

                    coachingCueSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.1), value: appeared)

                    timelineSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.15), value: appeared)

                    warmupSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.2), value: appeared)

                    lastSessionSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.25), value: appeared)

                    exercisesSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.3), value: appeared)

                    fuelingSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.35), value: appeared)

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)

            stickyBottomBar
        }
        .appBackground(accent: PepTheme.blue)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("PRE-SESSION")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2.6)
                        .foregroundStyle(PepTheme.blue)
                    Text(homeVM.todaysPlan.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                appeared = true
            }
            Task { await healthKit.fetchAllData(for: Date()) }
        }
        .sheet(isPresented: $showReview) {
            ReviewAndStartSheet(
                planName: homeVM.todaysPlan.name,
                exercises: todaysProgramExercises,
                lastByExercise: lastPerformanceMap(),
                onStart: {
                    showReview = false
                    onStartWorkout()
                    dismiss()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
        }
    }

    // MARK: - 1. Editorial Header

    private var headerSection: some View {
        GlassCard(accent: PepTheme.blue) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Text("TRAIN · TODAY")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(3.0)
                        .foregroundStyle(PepTheme.blue)
                    Rectangle()
                        .fill(PepTheme.blue.opacity(0.4))
                        .frame(width: 18, height: 1)
                    Spacer()
                    if let program = homeVM.activeProgram {
                        Text(program.name.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                if let program = homeVM.activeProgram {
                    HStack(spacing: 8) {
                        chip("W\(program.currentWeek)")
                        chip(dayPositionLabel(program: program))
                        if let tag = focusTag {
                            chip(tag.uppercased(), tinted: true)
                        }
                    }
                }

                Text(homeVM.todaysPlan.name)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                mesocycleProgressBar
            }
        }
    }

    private func chip(_ text: String, tinted: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(tinted ? PepTheme.blue : PepTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((tinted ? PepTheme.blue : PepTheme.textSecondary).opacity(0.12))
            .clipShape(.capsule)
    }

    private var mesocycleProgressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MESOCYCLE")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.55))
                Spacer()
                Text("\(Int(mesocycleProgress * 100))%")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(PepTheme.blue)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PepTheme.elevated)
                        .frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [PepTheme.blue.opacity(0.6), PepTheme.blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * mesocycleProgress, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private var mesocycleProgress: Double {
        guard let program = homeVM.activeProgram else { return 0 }
        let totalWeeks: Double = 4
        let week = max(1, min(Int(totalWeeks), program.currentWeek))
        let dayPart: Double
        if let idx = homeVM.todaysPlan.splitDays.firstIndex(where: { $0.isToday }) {
            dayPart = Double(idx + 1) / Double(max(program.days.count, 1))
        } else {
            dayPart = 0
        }
        return min(1.0, (Double(week - 1) + dayPart) / totalWeeks)
    }

    private var focusTag: String? {
        let name = homeVM.todaysPlan.name.lowercased()
        if name.contains("push") { return "Push" }
        if name.contains("pull") { return "Pull" }
        if name.contains("leg") { return "Legs" }
        if name.contains("upper") { return "Upper" }
        if name.contains("lower") { return "Lower" }
        if name.contains("full") { return "Full Body" }
        if name.contains("chest") { return "Chest" }
        if name.contains("back") { return "Back" }
        if name.contains("shoulder") { return "Shoulders" }
        if name.contains("arm") { return "Arms" }
        let muscles = todaysProgramExercises.map(\.primaryMuscle.rawValue)
        return muscles.first
    }

    private func dayPositionLabel(program: TrainingProgram) -> String {
        guard let idx = homeVM.todaysPlan.splitDays.firstIndex(where: { $0.isToday }) else {
            return "DAY \(program.currentWeek)"
        }
        return "DAY \(idx + 1)/\(program.days.count)"
    }

    // MARK: - 2. Readiness

    private var readinessSection: some View {
        sectionCard(eyebrow: "01 — Readiness", accent: PepTheme.blue) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    readinessTile(
                        icon: "moon.fill",
                        label: "Sleep",
                        value: sleepValueText,
                        progress: sleepProgress,
                        color: PepTheme.violet,
                        missing: healthKit.sleepHours <= 0
                    )
                    readinessTile(
                        icon: "figure.cooldown",
                        label: "Soreness",
                        value: sorenessValueText,
                        progress: sorenessProgress,
                        color: PepTheme.amber,
                        missing: false
                    )
                }
                HStack(spacing: 10) {
                    readinessTile(
                        icon: "bolt.fill",
                        label: "Energy",
                        value: energyValueText,
                        progress: energyProgress,
                        color: PepTheme.coral,
                        missing: false
                    )
                    readinessTile(
                        icon: "drop.fill",
                        label: "In Body",
                        value: peptideLevelText,
                        progress: peptideLevelProgress,
                        color: PepTheme.teal,
                        missing: peptideLevelText == "—"
                    )
                }

                Divider().overlay(PepTheme.glassBorderTop)

                HStack(spacing: 10) {
                    Image(systemName: readinessVerdict.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(readinessVerdict.color)
                        .frame(width: 26, height: 26)
                        .background(readinessVerdict.color.opacity(0.14))
                        .clipShape(Circle())
                    Text(readinessVerdict.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func readinessTile(
        icon: String,
        label: String,
        value: String,
        progress: Double,
        color: Color,
        missing: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }
            Text(missing ? "Log" : value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(missing ? PepTheme.textSecondary : PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PepTheme.elevated).frame(height: 3)
                    Capsule()
                        .fill(missing ? PepTheme.textSecondary.opacity(0.25) : color)
                        .frame(width: geo.size.width * max(0.05, min(1, progress)), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var sleepValueText: String {
        let h = healthKit.sleepHours
        if h <= 0 { return "—" }
        return String(format: "%.1fh", h)
    }
    private var sleepProgress: Double {
        let h = healthKit.sleepHours
        return min(1, h / 8.0)
    }

    private var sorenessFatigued: Int {
        trainVM.muscleRecoveryItems.filter { $0.status == .fatigued }.count
    }
    private var sorenessValueText: String {
        let f = sorenessFatigued
        if f == 0 { return "Fresh" }
        if f <= 2 { return "Mild" }
        return "High"
    }
    private var sorenessProgress: Double {
        let total = max(trainVM.muscleRecoveryItems.count, 1)
        return 1.0 - Double(sorenessFatigued) / Double(total)
    }

    private var energyScore: Double {
        var score = 0.5
        score += (sleepProgress - 0.5) * 0.6
        score += (sorenessProgress - 0.5) * 0.4
        return max(0.05, min(1, score))
    }
    private var energyValueText: String {
        let s = energyScore
        if s > 0.75 { return "High" }
        if s > 0.45 { return "Solid" }
        return "Low"
    }
    private var energyProgress: Double { energyScore }

    private var peptideLevelText: String {
        guard let proto = homeVM.activeProtocol,
              let compound = proto.compounds.first else { return "—" }
        let reading = ProtocolBodyLevelCalculator.currentLevel(for: compound, in: proto)
        return reading.displayValue
    }
    private var peptideLevelProgress: Double {
        guard let proto = homeVM.activeProtocol,
              let compound = proto.compounds.first else { return 0 }
        let reading = ProtocolBodyLevelCalculator.currentLevel(for: compound, in: proto)
        if let pct = reading.percentOfLastDose {
            return Double(pct) / 100.0
        }
        return 0.5
    }

    private var readinessVerdict: (text: String, icon: String, color: Color) {
        let avg = (sleepProgress + sorenessProgress + energyScore) / 3
        if avg > 0.72 {
            return ("Recovery looking strong — push intensity today.", "flame.fill", PepTheme.coral)
        }
        if avg > 0.45 {
            return ("Solid baseline — hit your prescribed loads, leave 1 in reserve.", "checkmark.circle.fill", PepTheme.teal)
        }
        return ("Underrecovered — autoregulate down 5–10% on top sets.", "exclamationmark.triangle.fill", PepTheme.amber)
    }

    // MARK: - 3. Coaching Cue

    private var coachingCueSection: some View {
        sectionCard(eyebrow: "02 — Today's Cue", accent: PepTheme.blue) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PepTheme.blue.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PepTheme.blue)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pep says")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.blue.opacity(0.85))
                    Text(coachingCue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var coachingCue: String {
        let n = todaysProgramExercises.count
        let mainLift = todaysProgramExercises.first?.exerciseName ?? "your main lift"
        let style: String
        if n >= 7 { style = "high-volume hypertrophy block" }
        else if n >= 5 { style = "balanced volume session" }
        else { style = "focused strength block" }
        return "\(style.capitalized) — open with \(mainLift), accessories at RPE 7. Quality reps over chasing PRs today."
    }

    // MARK: - 4. Timeline

    private var timelineSection: some View {
        sectionCard(eyebrow: "03 — Timeline", accent: PepTheme.blue) {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 0) {
                    timelineBlock(label: "Warmup", minutes: warmupMinutes, color: PepTheme.amber, ratio: warmupRatio)
                    timelineBlock(label: "Main", minutes: mainMinutes, color: PepTheme.blue, ratio: mainRatio)
                    timelineBlock(label: "Cooldown", minutes: cooldownMinutes, color: PepTheme.teal, ratio: cooldownRatio)
                }
                HStack {
                    Text("Total")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    Spacer()
                    Text("\(totalMinutes) min")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }
        }
    }

    private func timelineBlock(label: String, minutes: Int, color: Color, ratio: Double) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                .frame(height: 8)
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer(minLength: 0)
                Text("\(minutes)m")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .frame(width: nil)
        .layoutPriority(ratio)
    }

    private var warmupMinutes: Int { max(5, min(12, trainVM.warmupExercises.count * 2)) }
    private var mainMinutes: Int {
        let perEx = 8
        return max(20, todaysProgramExercises.count * perEx)
    }
    private var cooldownMinutes: Int { 5 }
    private var totalMinutes: Int { warmupMinutes + mainMinutes + cooldownMinutes }
    private var warmupRatio: Double { Double(warmupMinutes) / Double(max(totalMinutes, 1)) }
    private var mainRatio: Double { Double(mainMinutes) / Double(max(totalMinutes, 1)) }
    private var cooldownRatio: Double { Double(cooldownMinutes) / Double(max(totalMinutes, 1)) }

    // MARK: - 5. Warmup

    private var warmupSection: some View {
        sectionCard(eyebrow: "04 — Warmup Flow", accent: PepTheme.blue) {
            VStack(spacing: 8) {
                ForEach(trainVM.warmupExercises) { warmup in
                    warmupRow(warmup)
                }
                if trainVM.warmupExercises.isEmpty {
                    emptyInline("No specific warmup yet — 5 min light cardio + dynamic stretching.")
                }
            }
        }
    }

    private func warmupRow(_ warmup: WarmupExercise) -> some View {
        let isExpanded = expandedWarmupId == warmup.id
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                expandedWarmupId = isExpanded ? nil : warmup.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PepTheme.blue.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: warmup.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(warmup.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("\(warmup.type.rawValue) · \(warmup.durationOrReps)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        .contentTransition(.symbolEffect(.replace))
                }
                if isExpanded {
                    Text(warmupNote(for: warmup))
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 44)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.elevated.opacity(0.4))
            .clipShape(.rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func warmupNote(for w: WarmupExercise) -> String {
        switch w.type {
        case .mobility: return "Slow, controlled — feel the tissue lengthen, breathe through it. Don't rush."
        case .activation: return "Light load, full ROM. Goal is to wake up the prime movers, not pre-fatigue them."
        case .dynamic: return "Build heart rate gradually. Each rep slightly more aggressive than the last."
        }
    }

    // MARK: - 6. Last Time

    private var lastSessionSection: some View {
        sectionCard(eyebrow: "05 — Last Time You Trained This", accent: PepTheme.blue) {
            if let last = lastMatchingSession {
                lastSessionContent(last)
            } else {
                emptyInline("First time running this split — set your starting weights and we'll track from here.")
            }
        }
    }

    private var lastMatchingSession: WorkoutHistoryDetail? {
        let target = homeVM.todaysPlan.name.lowercased()
        return trainVM.workoutHistory.first { $0.name.lowercased() == target }
    }

    private func lastSessionContent(_ last: WorkoutHistoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                statBlock(label: "DATE", value: relativeDate(last.date))
                divider
                statBlock(label: "VOLUME", value: formatVolume(last.totalVolume))
                divider
                statBlock(label: "DURATION", value: "\(last.durationMinutes)m")
            }
            if let trend = volumeTrendText {
                HStack(spacing: 8) {
                    Image(systemName: trend.up ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(trend.up ? PepTheme.teal : PepTheme.amber)
                    Text(trend.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((trend.up ? PepTheme.teal : PepTheme.amber).opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }
            if !recentPRs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RECENT PRS")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    ForEach(recentPRs.prefix(2)) { pr in
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(PepTheme.amber)
                            Text(pr.exerciseName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(Int(pr.weight)) × \(pr.reps)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(PepTheme.amber)
                        }
                    }
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(PepTheme.glassBorderTop).frame(width: 1, height: 26)
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var volumeTrendText: (text: String, up: Bool)? {
        let target = homeVM.todaysPlan.name.lowercased()
        let matching = trainVM.workoutHistory.filter { $0.name.lowercased() == target }
        guard matching.count >= 2 else { return nil }
        let latest = matching[0].totalVolume
        let prior = matching[1].totalVolume
        guard prior > 0 else { return nil }
        let delta = Double(latest - prior) / Double(prior) * 100
        let sign = delta >= 0 ? "+" : ""
        return ("\(sign)\(Int(delta.rounded()))% volume vs previous session", delta >= 0)
    }

    private var recentPRs: [TrainPersonalRecord] {
        trainVM.personalRecords.filter { $0.isNew }
    }

    // MARK: - 7. Today's Exercises

    private var exercisesSection: some View {
        sectionCard(eyebrow: "06 — Today's Exercises", accent: PepTheme.blue) {
            VStack(spacing: 8) {
                if todaysProgramExercises.isEmpty {
                    emptyInline("No exercises scheduled for today.")
                } else {
                    ForEach(Array(todaysProgramExercises.enumerated()), id: \.element.id) { idx, ex in
                        exerciseRow(ex, index: idx + 1)
                    }
                }
            }
        }
    }

    private var todaysProgramExercises: [ProgramExercise] {
        guard let program = homeVM.activeProgram else { return [] }
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let mondayBased = (dayOfWeek + 5) % 7
        if program.days.contains(where: { $0.scheduledWeekday != nil }) {
            if let match = program.days.first(where: { $0.scheduledWeekday == mondayBased }) {
                return match.exercises
            }
        }
        let startOffset = UserDefaults.standard.integer(forKey: "programStartDayOffset")
        let adjusted = (mondayBased - startOffset + 7) % 7
        guard adjusted < program.days.count else { return [] }
        return program.days[adjusted].exercises
    }

    private func lastPerformanceMap() -> [String: String] {
        var map: [String: String] = [:]
        for entry in trainVM.workoutHistory {
            for ex in entry.exercises where map[ex.exerciseName] == nil {
                let setsStr = ex.sets.prefix(3).map { "\(Int($0.weight))×\($0.reps)" }.joined(separator: ", ")
                if !setsStr.isEmpty {
                    map[ex.exerciseName] = setsStr
                }
            }
        }
        return map
    }

    private func exerciseRow(_ ex: ProgramExercise, index: Int) -> some View {
        let last = lastPerformanceMap()[ex.exerciseName]
        return HStack(alignment: .center, spacing: 12) {
            Text(String(format: "%02d", index))
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(PepTheme.blue.opacity(0.7))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(ex.exerciseName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(ex.targetSets) × \(ex.targetRepsMin)–\(ex.targetRepsMax)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                    if let weight = ex.prescribedWeight, weight > 0 {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("\(Int(weight)) lbs")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(PepTheme.blue)
                    }
                }
                if let last {
                    Text("Last: \(last)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
                        .lineLimit(1)
                } else {
                    Text("First time — set your starting load.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
            Text(ex.primaryMuscle.rawValue.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.capsule)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - 8. Fueling

    private var fuelingSection: some View {
        sectionCard(eyebrow: "07 — Fuel & Hydration", accent: PepTheme.blue) {
            VStack(spacing: 10) {
                fuelingRow(icon: "leaf.fill", color: PepTheme.teal, title: "Carbs", detail: "30–50g fast carbs 45–60m before — banana + rice cakes is plug-and-play.")
                fuelingRow(icon: "drop.fill", color: PepTheme.blue, title: "Hydration", detail: "16–20oz water in the next 30m. Add a pinch of salt if you sweat heavy.")
                fuelingRow(icon: "cup.and.saucer.fill", color: PepTheme.amber, title: "Caffeine", detail: "200mg ~30m before lifts — skip if it's after 3pm.")
                if homeVM.activeProtocol != nil {
                    fuelingRow(icon: "syringe.fill", color: PepTheme.violet, title: "Peptide Note", detail: peptideAwareNote)
                }
            }
        }
    }

    private var peptideAwareNote: String {
        let level = peptideLevelText
        if level == "—" { return "Train normally — no compound timing concerns today." }
        return "\(level) circulating now. If on a GLP, eat slow and small to avoid GI distress mid-session."
    }

    private func fuelingRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.14)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Bottom Bar

    private var stickyBottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [PepTheme.background.opacity(0), PepTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)
            .allowsHitTesting(false)

            Button {
                showReview = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("REVIEW & START")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(2.5)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.7)
                }
                .padding(.horizontal, 18)
                .frame(height: 56)
                .foregroundStyle(PepTheme.invertedText)
                .background(
                    LinearGradient(colors: [PepTheme.blue, PepTheme.blue.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: PepTheme.blue.opacity(0.35), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: showReview)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .background(PepTheme.background)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard<Content: View>(
        eyebrow: String,
        accent: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2.5)
                        .foregroundStyle(accent)
                    Rectangle()
                        .fill(accent.opacity(0.35))
                        .frame(height: 1)
                }
                content()
            }
        }
    }

    private func emptyInline(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yest." }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 { return "\(days)d ago" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func formatVolume(_ v: Int) -> String {
        if v >= 1000 { return String(format: "%.1fk", Double(v) / 1000.0) }
        return "\(v)"
    }
}

// MARK: - Review & Start Sheet

private struct ReviewAndStartSheet: View {
    let planName: String
    let exercises: [ProgramExercise]
    let lastByExercise: [String: String]
    var onStart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weights: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONFIRM TODAY")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(2.5)
                            .foregroundStyle(PepTheme.blue)
                        Text(planName)
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    VStack(spacing: 8) {
                        ForEach(exercises) { ex in
                            reviewRow(ex)
                        }
                    }
                    .padding(.horizontal, 16)

                    Color.clear.frame(height: 80)
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("START WORKOUT")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(2.5)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(PepTheme.invertedText)
                    .background(LinearGradient(colors: [PepTheme.blue, PepTheme.blue.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: PepTheme.blue.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: false)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private func reviewRow(_ ex: ProgramExercise) -> some View {
        let last = lastByExercise[ex.exerciseName]
        let binding = Binding<String>(
            get: { weights[ex.id] ?? (ex.prescribedWeight.map { String(Int($0)) } ?? "") },
            set: { weights[ex.id] = $0 }
        )
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ex.exerciseName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text("\(ex.targetSets) × \(ex.targetRepsMin)–\(ex.targetRepsMax)\(last.map { " · last \($0)" } ?? "")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                TextField("0", text: binding)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 50)
                Text("lbs")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 10))
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}
