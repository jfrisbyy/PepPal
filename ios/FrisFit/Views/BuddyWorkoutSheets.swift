import SwiftUI

nonisolated enum BuddySport: String, CaseIterable, Identifiable, Sendable {
    case strength
    case run
    case cycle
    case hiit
    case walk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: return "Strength"
        case .run: return "Run"
        case .cycle: return "Cycle"
        case .hiit: return "HIIT"
        case .walk: return "Walk / Hike"
        }
    }

    var icon: String {
        switch self {
        case .strength: return "figure.strengthtraining.traditional"
        case .run: return "figure.run"
        case .cycle: return "figure.outdoor.cycle"
        case .hiit: return "figure.highintensity.intervaltraining"
        case .walk: return "figure.hiking"
        }
    }

    var verb: String {
        switch self {
        case .strength: return "lift"
        case .run: return "run"
        case .cycle: return "ride"
        case .hiit: return "crush HIIT"
        case .walk: return "walk"
        }
    }

    var defaultSetsTarget: Int {
        switch self {
        case .strength: return 18
        case .run, .cycle, .walk: return 6
        case .hiit: return 12
        }
    }
}

@MainActor
private extension BuddySport {
    var color: Color {
        switch self {
        case .strength: return PepTheme.teal
        case .run: return PepTheme.amber
        case .cycle: return PepTheme.violet
        case .hiit: return .red
        case .walk: return .green
        }
    }
}

struct BuddyInviteSheet: View {
    let friend: FriendStatSnapshot
    var sport: BuddySport = .strength
    var onStart: ((BuddySport) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var inviteSent: Bool = false
    @State private var showStartCountdown: Bool = false
    @State private var countdown: Int = 3

    private let trainVM = TrainViewModel()

    private var todayDay: ProgramDay? {
        sport == .strength ? trainVM.activeProgram?.days.first : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        SectionEyebrow("How It Works", number: "01", accent: sport.color)
                        syncExplainer
                    }

                    if let day = todayDay {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionEyebrow("Today's Workout", number: "02", accent: PepTheme.teal)
                            workoutPreview(day: day)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionEyebrow("Today's Session", number: "02", accent: sport.color)
                            cardioPreview
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .safeAreaInset(edge: .bottom) {
                Button {
                    startInvite()
                } label: {
                    Group {
                        if showStartCountdown {
                            Text("STARTING IN \(countdown)…")
                        } else if inviteSent {
                            Text("WAITING ON \((friend.user.name.components(separatedBy: " ").first ?? friend.user.name).uppercased())…")
                        } else {
                            let first = friend.user.name.components(separatedBy: " ").first ?? friend.user.name
                            Text("INVITE \(first.uppercased()) TO \(sport.verb.uppercased())")
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Capsule().strokeBorder(PepTheme.textPrimary.opacity(0.85), lineWidth: 1)
                    )
                }
                .buttonStyle(.scale)
                .disabled(showStartCountdown)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Workout Buddy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Text("WORKOUT BUDDY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 14) {
                participantAvatar(initial: "Y", color: PepTheme.teal)
                VStack(spacing: 4) {
                    Rectangle().fill(PepTheme.separatorColor).frame(width: 0.5, height: 14)
                    Text("· · ·")
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(sport.color)
                    Rectangle().fill(PepTheme.separatorColor).frame(width: 0.5, height: 14)
                }
                .frame(width: 28)
                participantAvatar(initial: friend.user.avatarInitial, color: friend.user.avatarColor, url: friend.user.avatarURL)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Text(sport.title)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    private func participantAvatar(initial: String, color: Color, url: String? = nil) -> some View {
        ZStack {
            Circle()
                .fill(PepTheme.elevated)
                .frame(width: 68, height: 68)
            Circle()
                .strokeBorder(color.opacity(0.45), lineWidth: 0.75)
                .frame(width: 68, height: 68)
            if let s = url, let u = URL(string: s) {
                AsyncImage(url: u) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: {
                    Text(initial).font(.system(.title3, design: .serif)).foregroundStyle(PepTheme.textPrimary)
                }
                .frame(width: 64, height: 64)
                .clipShape(.circle)
            } else {
                Text(initial).font(.system(.title3, design: .serif)).foregroundStyle(PepTheme.textPrimary)
            }
        }
    }

    private var syncExplainer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Synced \(sport.title.lowercased())")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            bullet("You both start at the same time, synced timer.")
            bullet(syncBulletTwo)
            bullet("Feel a haptic tap when they hit a milestone.")
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("—")
                .font(.system(.caption, design: .serif))
                .foregroundStyle(PepTheme.textSecondary)
            Text(text)
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func workoutPreview(day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.name)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(day.exercises.count) EX")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(day.exercises.prefix(5).enumerated()), id: \.element.id) { idx, ex in
                    HStack {
                        Text(ex.exerciseName)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text("\(ex.targetSets)×\(ex.targetRepsMin)-\(ex.targetRepsMax)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 9)
                    if idx < min(day.exercises.count, 5) - 1 {
                        Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                    }
                }
                if day.exercises.count > 5 {
                    Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                    Text("+\(day.exercises.count - 5) more")
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 9)
                }
            }
            .overlay(alignment: .top) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
            .overlay(alignment: .bottom) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardioPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(cardioTitle)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text(cardioDescription)
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
    }

    private var syncBulletTwo: String {
        switch sport {
        case .strength: return "See each other's live set-by-set progress."
        case .run: return "See each other's live distance and pace."
        case .cycle: return "See each other's live distance and speed."
        case .hiit: return "See each other's live round count."
        case .walk: return "See each other's live distance and time."
        }
    }

    private var cardioTitle: String {
        switch sport {
        case .run: return "Synced Run"
        case .cycle: return "Synced Ride"
        case .hiit: return "Synced HIIT Session"
        case .walk: return "Synced Walk"
        case .strength: return "Freestyle Lift"
        }
    }

    private var cardioDescription: String {
        switch sport {
        case .run: return "Open-format run. Distance, pace, and time sync between both of you in real time."
        case .cycle: return "Open-format ride. Distance, speed, and elapsed time sync between both of you."
        case .hiit: return "Freestyle HIIT — pick your own intervals. Round milestones sync between both of you."
        case .walk: return "Easy synced walk or hike. Distance and time stay in sync."
        case .strength: return "No active program — you'll sync a freestyle lift. Add exercises as you go."
        }
    }

    private func startInvite() {
        guard !inviteSent else { return }
        inviteSent = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            await MainActor.run {
                showStartCountdown = true
                countdown = 3
            }
            for i in (1...3).reversed() {
                await MainActor.run {
                    countdown = i
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run {
                startSession()
                let cb = onStart
                let s = sport
                dismiss()
                cb?(s)
            }
        }
    }

    private func startSession() {
        let workoutName: String
        var totalSets = sport.defaultSetsTarget
        var firstExerciseName: String?

        switch sport {
        case .strength:
            let day = trainVM.activeProgram?.days.first
            let exercises: [WorkoutExercise]
            if let day {
                workoutName = day.name
                exercises = day.exercises.compactMap { pe in
                    guard let ex = ExerciseLibrary.all.first(where: { $0.id == pe.exerciseId }) else { return nil }
                    return WorkoutExercise(exercise: ex, targetSets: pe.targetSets)
                }
            } else {
                workoutName = "Buddy Lift"
                exercises = []
            }
            totalSets = max(exercises.reduce(0) { $0 + $1.sets.count }, 6)
            firstExerciseName = exercises.first?.exercise.name
            WorkoutSessionManager.shared.startSession(name: workoutName, exercises: exercises)

        case .run:
            workoutName = "Run with \(friend.user.name.components(separatedBy: " ").first ?? friend.user.name)"
            firstExerciseName = "Mile 1"
            if !RunningViewModel.shared.isRunning {
                RunningViewModel.shared.startRun()
            }

        case .cycle:
            workoutName = "Ride with \(friend.user.name.components(separatedBy: " ").first ?? friend.user.name)"
            firstExerciseName = "Mile 1"
            if !CyclingViewModel.shared.isRiding {
                CyclingViewModel.shared.startRide()
            }

        case .hiit:
            workoutName = "HIIT with \(friend.user.name.components(separatedBy: " ").first ?? friend.user.name)"
            firstExerciseName = "Round 1"

        case .walk:
            workoutName = "Walk with \(friend.user.name.components(separatedBy: " ").first ?? friend.user.name)"
            firstExerciseName = "Mile 1"
        }

        BuddyWorkoutService.shared.startSession(
            workoutName: workoutName,
            totalSetsTarget: totalSets,
            firstExerciseName: firstExerciseName,
            buddy: friend
        )
    }
}

struct BuddyProgressOverlay: View {
    @State private var service = BuddyWorkoutService.shared
    @State private var pulseId: UUID = UUID()

    var body: some View {
        if let session = service.session {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    participantColumn(participant: session.me, tint: PepTheme.teal, label: "You")
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PepTheme.amber)
                    participantColumn(participant: session.buddy, tint: PepTheme.violet, label: session.buddy.name.components(separatedBy: " ").first ?? session.buddy.name)
                }
                if let last = latestBuddyEvent(session: session) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.violet)
                        Text("\(session.buddy.name.components(separatedBy: " ").first ?? "They") finished \(last.exerciseName)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text(last.timestamp, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    }
                    .transition(.opacity)
                }
            }
            .padding(12)
            .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.violet.opacity(0.35), lineWidth: 1)
            )
            .onChange(of: session.buddy.setsCompleted) { oldValue, newValue in
                if newValue > oldValue {
                    pulseId = UUID()
                }
            }
        }
    }

    private func latestBuddyEvent(session: BuddySession) -> BuddySetEvent? {
        service.recentEvents.last(where: { $0.participantId == session.buddy.id })
    }

    private func participantColumn(participant: BuddyParticipant, tint: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [tint.opacity(0.85), tint.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 22, height: 22)
                    if let s = participant.avatarURL, let u = URL(string: s) {
                        AsyncImage(url: u) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: {
                            Text(participant.avatarInitial).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        }
                        .frame(width: 22, height: 22)
                        .clipShape(.circle)
                    } else {
                        Text(participant.avatarInitial).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    }
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if participant.isFinished {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(tint)
                }
            }
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(PepTheme.elevated)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(tint)
                            .frame(width: geo.size.width * progressFrac(participant))
                    }
                }
                .frame(height: 5)
                Text("\(participant.setsCompleted)/\(participant.totalSetsTarget)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressFrac(_ p: BuddyParticipant) -> Double {
        guard p.totalSetsTarget > 0 else { return 0 }
        return min(1, Double(p.setsCompleted) / Double(p.totalSetsTarget))
    }
}
