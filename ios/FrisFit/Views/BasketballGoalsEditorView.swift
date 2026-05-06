import SwiftUI

struct BasketballGoalsEditorView: View {
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pickerType: BasketballGoalType = .sessionsPerWeek
    @State private var pickerTarget: Int = 3
    @State private var showPicker: Bool = false

    private let accentColor = BasketballPalette.courtOrange

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard

                    if bbVM.goals.isEmpty {
                        emptyState
                    } else {
                        goalsList
                    }

                    addGoalButton

                    if showPicker {
                        pickerCard
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var introCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 8) {
                Text("PERSONAL TARGETS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(accentColor)
                Text("Pick goals that match your life.")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Small targets you can actually hit beat unrealistic ones every time. We'll celebrate when you cross the line.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.title2)
                .foregroundStyle(accentColor.opacity(0.5))
            Text("No goals set yet.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var goalsList: some View {
        VStack(spacing: 10) {
            ForEach(bbVM.goals) { goal in
                goalRow(goal)
            }
        }
    }

    private func goalRow(_ goal: BasketballGoal) -> some View {
        let progress = bbVM.progress(for: goal)
        let value = bbVM.currentValue(for: goal.type)
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(PepTheme.elevated, lineWidth: 4).frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(goal.type.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Image(systemName: goal.type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(goal.type.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.type.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("\(value) / \(goal.target) \(goal.type.unit)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()

            HStack(spacing: 6) {
                Button {
                    var g = goal
                    g.target = max(1, g.target - 1)
                    bbVM.updateGoal(g)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Text("\(goal.target)")
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 32)
                    .contentTransition(.numericText())
                Button {
                    var g = goal
                    g.target += 1
                    bbVM.updateGoal(g)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 28)
                        .background(goal.type.color)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: goal.target)
            }

            Button {
                bbVM.removeGoal(goal)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(goal.type.color.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var addGoalButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                showPicker.toggle()
                if showPicker {
                    pickerType = .sessionsPerWeek
                    pickerTarget = pickerType.defaultTarget
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showPicker ? "minus.circle.fill" : "plus.circle.fill")
                Text(showPicker ? "Cancel" : "Add Goal")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(accentColor.opacity(0.12))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accentColor.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PICK A GOAL TYPE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(spacing: 6) {
                ForEach(BasketballGoalType.allCases) { type in
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            pickerType = type
                            pickerTarget = type.defaultTarget
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: type.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(type.color)
                                .frame(width: 30, height: 30)
                                .background(type.color.opacity(0.12))
                                .clipShape(Circle())
                            Text(type.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Image(systemName: pickerType == type ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(pickerType == type ? type.color : PepTheme.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(pickerType == type ? type.color.opacity(0.08) : PepTheme.cardSurface.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Target")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Stepper(value: $pickerTarget, in: 1...500, step: pickerType == .minutesPerWeek ? 15 : 1) {
                    Text("\(pickerTarget) \(pickerType.unit)")
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(pickerType.color)
                        .contentTransition(.numericText())
                }
                .labelsHidden()
            }

            EditorialPrimaryButton("Add Goal", icon: "plus.circle.fill", accent: accentColor) {
                bbVM.addGoal(BasketballGoal(type: pickerType, target: pickerTarget))
                withAnimation(.spring(duration: 0.3)) { showPicker = false }
                let haptic = UINotificationFeedbackGenerator()
                haptic.notificationOccurred(.success)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 0.5)
        )
    }
}
