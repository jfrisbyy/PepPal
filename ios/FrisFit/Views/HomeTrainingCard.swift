import SwiftUI

struct HomeTrainingCard: View {
    @Bindable var viewModel: HomeViewModel
    @Bindable var trainViewModel: TrainViewModel
    @Binding var showProgramCreation: Bool
    var onStartWorkout: () -> Void

    @State private var showEditProgram: Bool = false
    @State private var editProgramTrainVM: TrainViewModel? = nil
    @State private var showPreSession: Bool = false

    var body: some View {
        let hasProgram = viewModel.activeProgram != nil
        let hasRec = viewModel.trainingRecommendation != nil
        let showSection = hasProgram || hasRec

        Group {
            if showSection {
                VStack(spacing: 8) {
                    summaryCard(hasProgram: hasProgram)
                }
            }
        }
        .navigationDestination(isPresented: $showPreSession) {
            PreSessionBriefView(
                homeVM: viewModel,
                trainVM: trainViewModel,
                onStartWorkout: onStartWorkout
            )
        }
        .sheet(isPresented: $showEditProgram, onDismiss: {
            viewModel.reloadActiveProgram()
            editProgramTrainVM = nil
        }) {
            if let program = viewModel.activeProgram, let trainVM = editProgramTrainVM {
                NavigationStack {
                    ProgramDetailView(program: program, viewModel: trainVM, isActive: true)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") { showEditProgram = false }
                                    .foregroundStyle(PepTheme.teal)
                                    .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func summaryCard(hasProgram: Bool) -> some View {
        Button {
            if hasProgram, !viewModel.todaysPlan.isRestDay {
                showPreSession = true
            } else if hasProgram, viewModel.todaysPlan.isRestDay {
                viewModel.showEditSplit = true
            }
        } label: {
            GlassCard(accent: PepTheme.blue) {
                VStack(alignment: .leading, spacing: 14) {
                    editorialHeader(hasProgram: hasProgram)

                    if hasProgram {
                        if viewModel.allActivePrograms.count > 1 {
                            programSwitcherStrip
                        }

                        if viewModel.multiActiveEnabled,
                           viewModel.showAllActiveOnToday,
                           viewModel.allActivePrograms.count > 1 {
                            multiProgramList
                        } else if viewModel.todaysPlan.isRestDay {
                            restDayContent
                        } else {
                            programOverview
                            statsRow
                        }

                        startWorkoutButton(isRestDay: viewModel.todaysPlan.isRestDay)
                    } else if let rec = viewModel.trainingRecommendation {
                        recommendationContent(rec)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: showPreSession)
    }

    // MARK: - Editorial Header

    private func editorialHeader(hasProgram: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("TRAIN")
                        .font(.system(.caption2, weight: .heavy))
                        .tracking(3.5)
                        .foregroundStyle(PepTheme.blue)
                    Rectangle()
                        .fill(PepTheme.shimmerHighlight)
                        .frame(width: 16, height: 1)
                }
                Text("Training")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            if hasProgram {
                Button {
                    let vm = TrainViewModel()
                    vm.loadAllData()
                    editProgramTrainVM = vm
                    showEditProgram = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.blue)
                        .frame(width: 28, height: 28)
                        .background(PepTheme.blue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            ZStack {
                Circle()
                    .fill(PepTheme.blue.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.blue)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(hasProgram && !viewModel.todaysPlan.isRestDay ? 0.55 : 0.35))
        }
    }

    // MARK: - Program Overview

    private var programOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let program = viewModel.activeProgram {
                HStack(spacing: 6) {
                    Text("W\(program.currentWeek)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.blue)
                    Rectangle()
                        .fill(PepTheme.blue.opacity(0.4))
                        .frame(width: 8, height: 1)
                    Text(dayPositionLabel(program: program))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.blue.opacity(0.85))
                    Text("·")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    Text(program.name)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                        .lineLimit(1)
                }
            }
            Text(viewModel.todaysPlan.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statTile(icon: "dumbbell.fill", value: "\(viewModel.todaysPlan.exercises)", label: "exercises")
            divider
            statTile(icon: "clock.fill", value: "\(viewModel.todaysPlan.estimatedMinutes)", label: "min")
            if let sets = totalSetsCount() {
                divider
                statTile(icon: "square.stack.3d.up.fill", value: "\(sets)", label: "sets")
            }
            if let muscle = primaryMuscles().first {
                divider
                statTile(icon: "figure.arms.open", value: muscle, label: muscleSubLabel())
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.textSecondary.opacity(0.15))
            .frame(width: 1, height: 22)
    }

    private func statTile(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.blue.opacity(0.8))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.65))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Rest Day

    private var restDayContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PepTheme.amber.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PepTheme.amber)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Rest Day")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                if let tip = viewModel.todaysPlan.recoveryTip {
                    Text(tip)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                } else {
                    Text("Recover hard. Hydrate, sleep, mobilize.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Multi-program list

    private var multiProgramList: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.todaysPlans, id: \.program.id) { entry in
                multiProgramRow(program: entry.program, plan: entry.plan)
            }
        }
    }

    private func multiProgramRow(program: TrainingProgram, plan: WorkoutPlan) -> some View {
        let isFocused = viewModel.activeProgram?.id == program.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                viewModel.selectDisplayedProgram(program.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: program.type.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isFocused ? PepTheme.blue : PepTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background((isFocused ? PepTheme.blue : PepTheme.textSecondary).opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    if plan.isRestDay {
                        Text("Rest day")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    } else {
                        Text("\(plan.name) · \(plan.exercises) ex · \(plan.estimatedMinutes)m")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if isFocused {
                    Text("FOCUS")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(PepTheme.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(PepTheme.blue.opacity(0.14))
                        .clipShape(.capsule)
                }
            }
            .padding(10)
            .background(PepTheme.elevated.opacity(isFocused ? 0.7 : 0.4))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isFocused ? PepTheme.blue.opacity(0.35) : PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Program switcher

    private var programSwitcherStrip: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.allActivePrograms) { program in
                        programChip(program)
                    }
                }
            }
            if viewModel.multiActiveEnabled {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        viewModel.showAllActiveOnToday.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.showAllActiveOnToday ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(viewModel.showAllActiveOnToday ? PepTheme.blue : PepTheme.textSecondary)
                        .frame(width: 28, height: 24)
                        .background((viewModel.showAllActiveOnToday ? PepTheme.blue : PepTheme.textSecondary).opacity(0.12))
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func programChip(_ program: TrainingProgram) -> some View {
        let isSelected = viewModel.activeProgram?.id == program.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                viewModel.selectDisplayedProgram(program.id)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: program.type.icon)
                    .font(.system(size: 9, weight: .bold))
                Text(program.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isSelected ? PepTheme.blue : PepTheme.elevated.opacity(0.7))
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Start workout button

    private func startWorkoutButton(isRestDay: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PepTheme.textSecondary.opacity(0.12))
                .frame(height: 0.5)
                .padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: isRestDay ? "slider.horizontal.3" : "sparkles")
                    .font(.system(size: 10, weight: .bold))
                Text(isRestDay ? "EDIT SPLIT" : "OPEN PRE-SESSION BRIEF")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.5)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.6)
            }
            .foregroundStyle(PepTheme.blue)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Recommendation (no program)

    private func recommendationContent(_ rec: (title: String, message: String, icon: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: rec.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PepTheme.blue)
                    .frame(width: 32, height: 32)
                    .background(PepTheme.blue.opacity(0.12))
                    .clipShape(Circle())
                Text(rec.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer(minLength: 0)
            }

            Text(rec.message)
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(PepTheme.textSecondary.opacity(0.12))
                    .frame(height: 0.5)
                    .padding(.bottom, 10)

                Button {
                    showProgramCreation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("BROWSE ROUTINES")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(2.5)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.6)
                    }
                    .foregroundStyle(PepTheme.blue)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func dayPositionLabel(program: TrainingProgram) -> String {
        guard let todayIndex = viewModel.todaysPlan.splitDays.firstIndex(where: { $0.isToday }) else {
            return ""
        }
        let trainingDays = program.days.count
        return "DAY \(todayIndex + 1)/\(trainingDays)"
    }

    private func totalSetsCount() -> Int? {
        let sets = viewModel.todaysPlan.planExercises.reduce(0) { $0 + $1.sets }
        return sets > 0 ? sets : nil
    }

    private func primaryMuscles() -> [String] {
        let names = viewModel.todaysPlan.planExercises.map(\.muscle)
        var seen: Set<String> = []
        var ordered: [String] = []
        for n in names where !n.isEmpty {
            if seen.insert(n).inserted { ordered.append(n) }
        }
        return ordered
    }

    private func muscleSubLabel() -> String {
        let count = primaryMuscles().count
        return count > 1 ? "+\(count - 1) more" : "focus"
    }
}
