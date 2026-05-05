import SwiftUI

struct TitrationScheduleCard: View {
    let schedule: TitrationSchedule
    let onEdit: () -> Void
    let onRemove: () -> Void

    private var current: TitrationScheduleStep? { schedule.currentStep() }
    private var next: TitrationScheduleStep? { schedule.nextStep() }

    private var nextDate: Date? {
        guard let next else { return nil }
        return schedule.startDate(for: next)
    }

    private var daysUntilNext: Int? {
        guard let d = nextDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: d)).day
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(PepTheme.amber)
                Text("Titration")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if schedule.remindersEnabled {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.teal)
                }
                Menu {
                    Button { onEdit() } label: { Label("Edit Schedule", systemImage: "slider.horizontal.3") }
                    Button(role: .destructive) { onRemove() } label: { Label("Remove Schedule", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                }
            }

            if let next, let days = daysUntilNext {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundStyle(PepTheme.amber)
                    Text(daysText(days: days, next: next))
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                }
                .padding(10)
                .background(PepTheme.amber.opacity(0.1), in: .rect(cornerRadius: 10))
            } else if current != nil {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("You're at your target dose.")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                }
                .padding(10)
                .background(Color.green.opacity(0.1), in: .rect(cornerRadius: 10))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(schedule.sortedSteps) { step in
                        stepPill(step)
                    }
                }
                .padding(.vertical, 2)
            }

            Button(action: onEdit) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Edit Schedule")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(PepTheme.teal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(PepTheme.teal.opacity(0.12), in: .rect(cornerRadius: 9))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.45), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.amber.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func daysText(days: Int, next: TitrationScheduleStep) -> String {
        let doseStr = CompoundUnitHelper.displayDoseShort(next.doseMcg, for: schedule.compoundName)
        if days <= 0 {
            return "Step up today → \(doseStr)"
        } else if days == 1 {
            return "Next step-up tomorrow → \(doseStr)"
        }
        return "Next step-up in \(days) days → \(doseStr)"
    }

    @ViewBuilder
    private func stepPill(_ step: TitrationScheduleStep) -> some View {
        let isCurrent = current?.id == step.id
        let isPast = (current.map { $0.week > step.week }) ?? false
        let bg: Color = isCurrent ? PepTheme.amber.opacity(0.22) : (isPast ? Color.green.opacity(0.15) : PepTheme.elevated.opacity(0.6))
        let fg: Color = isCurrent ? PepTheme.amber : (isPast ? .green : PepTheme.textSecondary)

        VStack(spacing: 3) {
            Text("W\(step.week)")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(fg.opacity(0.9))
            Text(CompoundUnitHelper.displayDoseShort(step.doseMcg, for: schedule.compoundName))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(isCurrent ? PepTheme.textPrimary : (isPast ? PepTheme.textPrimary : PepTheme.textSecondary))
            if !step.label.isEmpty {
                Text(step.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(bg, in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isCurrent ? PepTheme.amber.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }
}
