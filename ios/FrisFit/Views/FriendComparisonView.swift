import SwiftUI

struct FriendComparisonView: View {
    let friend: FriendStatSnapshot
    let mySnapshot: FriendStatSnapshot?

    @State private var showShareConfirm: Bool = false
    @State private var showNudgeSheet: Bool = false
    @State private var showBuddySheet: Bool = false
    @State private var showBorrowSheet: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                eyebrowTitle
                header
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(height: 0.5)
                    .padding(.horizontal)

                if friend.activeProgram != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionEyebrow("Their Program", number: "01", accent: PepTheme.violet)
                        borrowProgramCard
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionEyebrow("The Numbers", number: friend.activeProgram != nil ? "02" : "01", accent: PepTheme.teal)
                    VStack(spacing: 10) {
                        ForEach(comparisonRows(), id: \.category) { row in
                            ComparisonRow(row: row)
                        }
                    }
                }
                .padding(.horizontal)

                if friend.sharedCategories.isEmpty || StatSharingService.shared.currentUserPrefs.categories.isEmpty {
                    infoNote
                        .padding(.horizontal)
                }

                Color.clear.frame(height: 100)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("You vs \(friend.user.name)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(height: 0.5)
                HStack(spacing: 10) {
                    iconCircleButton(systemName: "hand.wave") { showNudgeSheet = true }

                    Button {
                        showBuddySheet = true
                    } label: {
                        Text("TRAIN TOGETHER")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(
                                Capsule().strokeBorder(PepTheme.textPrimary.opacity(0.85), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.scale)

                    iconCircleButton(systemName: "square.and.arrow.up") { showShareConfirm = true }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(PepTheme.background.opacity(0.95))
        }
        .sheet(isPresented: $showNudgeSheet) {
            NudgeMenuSheet(friend: friend)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBuddySheet) {
            BuddyInviteSheet(friend: friend) { _ in
                startBuddyWorkout()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBorrowSheet) {
            BorrowProgramSheet(friend: friend)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Snapshot shared", isPresented: $showShareConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A summary of your stats has been added to your chat with \(friend.user.name).")
        }
    }

    private var eyebrowTitle: some View {
        HStack {
            Text("COMPARE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal)
    }

    private func iconCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(PepTheme.separatorColor, lineWidth: 0.75))
        }
        .buttonStyle(.scale)
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerColumn(user: mySnapshot?.user, label: "You", color: PepTheme.teal)
            VStack(spacing: 4) {
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(width: 0.5, height: 22)
                Text("vs")
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundStyle(PepTheme.textSecondary)
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(width: 0.5, height: 22)
            }
            .frame(width: 44)
            headerColumn(user: friend.user, label: friend.user.name, color: PepTheme.violet)
        }
        .padding(.horizontal)
    }

    private func headerColumn(user: SocialUser?, label: String, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(PepTheme.elevated)
                    .frame(width: 68, height: 68)
                Circle()
                    .strokeBorder(color.opacity(0.45), lineWidth: 0.75)
                    .frame(width: 68, height: 68)
                if let url = user?.avatarURL, let u = URL(string: url) {
                    AsyncImage(url: u) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: {
                        Text(user?.avatarInitial ?? "?").font(.system(.title3, design: .serif, weight: .regular)).foregroundStyle(PepTheme.textPrimary)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(.circle)
                } else {
                    Text(user?.avatarInitial ?? "?")
                        .font(.system(.title3, design: .serif, weight: .regular))
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }
            Text(label)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var borrowProgramCard: some View {
        Button {
            showBorrowSheet = true
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.activeProgram ?? "")
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    Text("Try what they're running")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
            .overlay(alignment: .top) {
                Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func startBuddyWorkout() {
        let day = TrainViewModel().activeProgram?.days.first
        let exercises: [WorkoutExercise]
        let name: String
        if let day {
            name = day.name
            exercises = day.exercises.compactMap { pe in
                guard let ex = ExerciseLibrary.all.first(where: { $0.id == pe.exerciseId }) else { return nil }
                return WorkoutExercise(exercise: ex, targetSets: pe.targetSets)
            }
        } else {
            name = "Buddy Workout"
            exercises = []
        }

        let totalSets = max(exercises.reduce(0) { $0 + $1.sets.count }, 6)
        let firstExerciseName = exercises.first?.exercise.name

        WorkoutSessionManager.shared.startSession(name: name, exercises: exercises)
        BuddyWorkoutService.shared.startSession(
            workoutName: name,
            totalSetsTarget: totalSets,
            firstExerciseName: firstExerciseName,
            buddy: friend
        )
    }

    private var infoNote: some View {
        Text("Some stats aren't shown because they haven't been shared. Adjust your sharing in settings.")
            .font(.system(.caption, design: .serif).italic())
            .foregroundStyle(PepTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
    }

    private func comparisonRows() -> [ComparisonRowData] {
        let myPrefs = StatSharingService.shared.currentUserPrefs
        var rows: [ComparisonRowData] = []

        func add(_ category: StatShareCategory, mine: Double, theirs: Double, formatter: (Double) -> String, unit: String = "") {
            let iShare = myPrefs.isEnabled && myPrefs.categories.contains(category)
            let theyShare = friend.sharedCategories.contains(category)
            rows.append(ComparisonRowData(
                category: category,
                mineValue: iShare ? formatter(mine) : "—",
                theirsValue: theyShare ? formatter(theirs) : "—",
                mineRaw: iShare ? mine : 0,
                theirsRaw: theyShare ? theirs : 0,
                iShared: iShare,
                theyShared: theyShare,
                unit: unit
            ))
        }

        add(.workouts, mine: Double(mySnapshot?.weeklyWorkouts ?? 0), theirs: Double(friend.weeklyWorkouts), formatter: { "\(Int($0))" }, unit: "this week")
        add(.volume, mine: Double(mySnapshot?.weeklyVolume ?? 0), theirs: Double(friend.weeklyVolume), formatter: { formatVolume($0) })
        add(.steps, mine: Double(mySnapshot?.weeklySteps ?? 0), theirs: Double(friend.weeklySteps), formatter: { formatThousands(Int($0)) })
        add(.calories, mine: Double(mySnapshot?.weeklyCalories ?? 0), theirs: Double(friend.weeklyCalories), formatter: { "\(Int($0)) cal" })
        add(.water, mine: Double(mySnapshot?.weeklyWaterMl ?? 0), theirs: Double(friend.weeklyWaterMl), formatter: { "\(Int($0 / 1000))L" })

        return rows
    }

    private func formatVolume(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk lbs", v / 1000) }
        return "\(Int(v)) lbs"
    }

    private func formatThousands(_ v: Int) -> String {
        if v >= 1000 { return String(format: "%.1fk", Double(v) / 1000) }
        return "\(v)"
    }
}

struct ComparisonRowData {
    let category: StatShareCategory
    let mineValue: String
    let theirsValue: String
    let mineRaw: Double
    let theirsRaw: Double
    let iShared: Bool
    let theyShared: Bool
    let unit: String
}

struct ComparisonRow: View {
    let row: ComparisonRowData

    private var leader: Leader {
        if !row.iShared || !row.theyShared { return .none }
        if row.mineRaw > row.theirsRaw { return .mine }
        if row.theirsRaw > row.mineRaw { return .theirs }
        return .tie
    }

    enum Leader { case mine, theirs, tie, none }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(row.category.title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if !row.unit.isEmpty {
                    Text(row.unit)
                        .font(.system(.caption2, design: .serif).italic())
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            HStack(spacing: 14) {
                valueCell(value: row.mineValue, isLeader: leader == .mine, color: PepTheme.teal)
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(width: 0.5, height: 36)
                valueCell(value: row.theirsValue, isLeader: leader == .theirs, color: PepTheme.violet)
            }

            if leader != .none && leader != .tie {
                progressBars
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
    }

    private func valueCell(value: String, isLeader: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(isLeader ? color : PepTheme.textPrimary)
                .frame(maxWidth: .infinity)
            if isLeader {
                Text("LEADS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(color)
            } else {
                Text(" ")
                    .font(.system(size: 9))
            }
        }
    }

    private var progressBars: some View {
        let total = max(row.mineRaw + row.theirsRaw, 1)
        let mineFrac = row.mineRaw / total
        return GeometryReader { geo in
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(PepTheme.teal)
                    .frame(width: max(geo.size.width * mineFrac - 1, 0))
                RoundedRectangle(cornerRadius: 3)
                    .fill(PepTheme.violet)
            }
        }
        .frame(height: 6)
    }
}
