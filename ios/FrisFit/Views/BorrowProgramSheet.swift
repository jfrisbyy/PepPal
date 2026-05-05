import SwiftUI

struct BorrowProgramSheet: View {
    let friend: FriendStatSnapshot
    @Environment(\.dismiss) private var dismiss

    @State private var trainVM = TrainViewModel()
    @State private var isCloning: Bool = false
    @State private var didClone: Bool = false

    private var matchedSplit: ProgramTemplateSplit? {
        guard let name = friend.activeProgram?.lowercased() else { return nil }
        return ProgramTemplateSplit.allCases.first { split in
            let shortMatch = name.contains(split.shortName.lowercased())
            let fullMatch = name.contains(split.rawValue.lowercased())
            return shortMatch || fullMatch
        }
    }

    private var previewProgram: TrainingProgram? {
        if let split = matchedSplit {
            return ProgramTemplateFactory.buildProgram(for: split)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    socialProofPill

                    if let program = previewProgram {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionEyebrow("At a Glance", number: "01", accent: PepTheme.violet)
                            programSummary(program: program)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            SectionEyebrow("What You'll Do", number: "02", accent: PepTheme.teal)
                            daysList(program: program)
                        }
                    } else {
                        unknownProgramNote
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .safeAreaInset(edge: .bottom) {
                bottomBar
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Borrow Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .task {
                trainVM.loadAllData()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PepTheme.elevated)
                    .frame(width: 52, height: 52)
                Circle()
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.75)
                    .frame(width: 52, height: 52)
                if let s = friend.user.avatarURL, let u = URL(string: s) {
                    AsyncImage(url: u) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: {
                        Text(friend.user.avatarInitial).font(.system(.headline, design: .serif)).foregroundStyle(PepTheme.textPrimary)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(.circle)
                } else {
                    Text(friend.user.avatarInitial).font(.system(.headline, design: .serif)).foregroundStyle(PepTheme.textPrimary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(friend.user.name.uppercased()) IS RUNNING")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary)
                Text(friend.activeProgram ?? "—")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private var socialProofPill: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(PepTheme.amber)
                .frame(width: 2, height: 28)
            Text("\(friend.streak)-day streak · \(friend.weeklyWorkouts) workouts this week")
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(PepTheme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func programSummary(program: TrainingProgram) -> some View {
        HStack(spacing: 10) {
            statPill(icon: "calendar", value: "\(program.daysPerWeek)", label: "days/wk")
            statPill(icon: "list.bullet", value: "\(program.days.count)", label: "sessions")
            statPill(icon: "dumbbell.fill", value: "\(totalExercises(program))", label: "exercises")
        }
    }

    private func totalExercises(_ program: TrainingProgram) -> Int {
        program.days.reduce(0) { $0 + $1.exercises.count }
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
    }

    private func daysList(program: TrainingProgram) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(program.days.enumerated()), id: \.element.id) { idx, day in
                dayRow(day)
                if idx < program.days.count - 1 {
                    Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                }
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
    }

    private func dayRow(_ day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.name)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(day.exercises.count) EX")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Text(day.exercises.prefix(4).map(\.exerciseName).joined(separator: " · "))
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unknownProgramNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CUSTOM PROGRAM")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary)
            Text("This is a custom program we can't clone directly. Ask \(friend.user.name) to share the details — in the meantime, start with a similar template from the Train tab.")
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5) }
    }

    private var bottomBar: some View {
        let active = previewProgram != nil
        return Button {
            cloneProgram()
        } label: {
            Group {
                if didClone {
                    Text("ADDED TO YOUR PLAN")
                } else if isCloning {
                    ProgressView().tint(PepTheme.textPrimary)
                } else {
                    Text("TRY WHAT THEY'RE DOING")
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(active ? PepTheme.textPrimary : PepTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                Capsule().strokeBorder(active ? PepTheme.textPrimary.opacity(0.85) : PepTheme.separatorColor, lineWidth: 1)
            )
        }
        .buttonStyle(.scale)
        .disabled(previewProgram == nil || isCloning || didClone)
    }

    private func cloneProgram() {
        guard let template = previewProgram, !isCloning else { return }
        isCloning = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let friendFirstName = friend.user.name.components(separatedBy: " ").first ?? friend.user.name
        let cloned = TrainingProgram(
            name: "\(template.name) (from \(friendFirstName))",
            type: template.type,
            daysPerWeek: template.daysPerWeek,
            days: template.days,
            isActive: true
        )

        trainVM.activateTemplateProgram(cloned, startDayOffset: 0)
        if !trainVM.savedPrograms.contains(where: { $0.id == cloned.id }) {
            trainVM.savedPrograms.insert(cloned, at: 0)
        }

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                isCloning = false
                didClone = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run { dismiss() }
        }
    }
}
