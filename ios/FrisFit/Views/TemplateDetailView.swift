import SwiftUI

struct TemplateDetailView: View {
    let split: ProgramTemplateSplit
    @Bindable var viewModel: TrainViewModel
    let onActivate: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var previewProgram: TrainingProgram
    @State private var expandedDayId: UUID? = nil
    @State private var editingDayName: UUID? = nil
    @State private var customStartDay: Int = 0
    @State private var isActivating: Bool = false

    private let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    init(split: ProgramTemplateSplit, viewModel: TrainViewModel, onActivate: @escaping () -> Void) {
        self.split = split
        self.viewModel = viewModel
        self.onActivate = onActivate
        self._previewProgram = State(initialValue: ProgramTemplateFactory.buildProgram(for: split))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewCard
                scheduleSection
                daysSection
                activateButton
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle(split.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                statBubble(value: "\(split.daysPerWeek)", label: "Days/Week", icon: "calendar")
                statBubble(value: "\(previewProgram.days.reduce(0) { $0 + $1.exercises.count })", label: "Exercises", icon: "dumbbell.fill")
                statBubble(value: split.targetAudience, label: "Level", icon: "person.fill")
            }

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(split.focusTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(PepTheme.teal.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            Text(split.description)
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func statBubble(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.teal)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(PepTheme.teal)
                Text("Start Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }

            Text("Which day of the week do you want Day 1 to land on?")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                customStartDay = index
                            }
                        } label: {
                            Text(String(day.prefix(3)))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(customStartDay == index ? .black : PepTheme.textSecondary)
                                .frame(width: 44, height: 36)
                                .background(customStartDay == index ? PepTheme.teal : PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(PepTheme.teal)
                Text("Workout Days")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }

            ForEach(Array(previewProgram.days.enumerated()), id: \.element.id) { index, day in
                dayRow(day, dayIndex: index)
            }

            if split.daysPerWeek < 7 {
                HStack(spacing: 8) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green.opacity(0.7))
                    Text("\(7 - split.daysPerWeek) rest day\(7 - split.daysPerWeek == 1 ? "" : "s") built in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func dayRow(_ day: ProgramDay, dayIndex: Int) -> some View {
        let isExpanded = expandedDayId == day.id
        let assignedWeekday = weekdays[(customStartDay + dayIndex) % 7]

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                expandedDayId = isExpanded ? nil : day.id
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("\(dayIndex + 1)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 28, height: 28)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("\(assignedWeekday) · \(day.exercises.count) exercises")
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 10)

                if isExpanded {
                    VStack(spacing: 6) {
                        ForEach(day.exercises) { exercise in
                            HStack(spacing: 10) {
                                Image(systemName: exercise.primaryMuscle.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(PepTheme.teal.opacity(0.6))
                                    .frame(width: 24, height: 24)
                                    .background(PepTheme.teal.opacity(0.08))
                                    .clipShape(Circle())

                                Text(exercise.exerciseName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Text("\(exercise.targetSets)×\(exercise.targetRepsMin)-\(exercise.targetRepsMax)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.bottom, 8)
                    .padding(.leading, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isExpanded)
    }

    private var activateButton: some View {
        Button {
            activateProgram()
        } label: {
            HStack(spacing: 10) {
                if isActivating {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                }
                Text(isActivating ? "Setting Up..." : "Start This Program")
                    .font(.headline)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PepTheme.teal)
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.scalePrimary)
        .disabled(isActivating)
        .sensoryFeedback(.success, trigger: isActivating)
    }

    private func activateProgram() {
        isActivating = true
        var program = previewProgram
        program.isActive = true
        viewModel.activateTemplateProgram(program, startDayOffset: customStartDay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isActivating = false
            dismiss()
            onActivate()
        }
    }
}
