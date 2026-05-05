import SwiftUI
import HealthKit

struct HealthStatsCardView: View {
    let healthKit: HealthKitService

    var body: some View {
        NavigationLink {
            HealthDetailView()
        } label: {
            HStack(spacing: 14) {
                recoveryRing
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                        Text("Apple Health")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 14) {
                        miniStat(icon: "figure.walk", value: formattedSteps(healthKit.steps), tint: PepTheme.teal)
                        miniStat(icon: "flame.fill", value: "\(Int(healthKit.activeCalories))", tint: .orange)
                        if healthKit.sleepHours > 0 {
                            miniStat(icon: "bed.double.fill", value: String(format: "%.1fh", healthKit.sleepHours), tint: PepTheme.violet)
                        } else if healthKit.heartRate > 0 {
                            miniStat(icon: "heart.fill", value: "\(Int(healthKit.heartRate))", tint: .red)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                PepTheme.cardSurface
                    .overlay(PepTheme.cardOverlay)
            )
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.red.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.scale)
    }

    @ViewBuilder
    private var recoveryRing: some View {
        let score = healthKit.recoveryScore ?? 0
        let hasScore = healthKit.recoveryScore != nil
        let tint: Color = !hasScore ? PepTheme.textSecondary.opacity(0.4)
            : (score >= 75 ? .green : (score >= 55 ? PepTheme.amber : .red))
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 3)
                .frame(width: 38, height: 38)
            Circle()
                .trim(from: 0, to: hasScore ? CGFloat(score) / 100 : 0)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 38, height: 38)
            if hasScore {
                Text("\(score)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            } else {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(tint)
            }
        }
    }

    private func miniStat(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
        }
    }

    private func formattedSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
}

struct HealthStatCell: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }
}

struct HealthWorkoutRow: View {
    let workout: HKWorkout

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.workoutActivityType.displayName)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 6) {
                    let durationMin = Int(workout.duration / 60)
                    Text("\(durationMin) min")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    if let stats = workout.statistics(for: HKQuantityType(.activeEnergyBurned)),
                       let sum = stats.sumQuantity() {
                        Text("\(Int(sum.doubleValue(for: .kilocalorie()))) cal")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            Spacer()
        }
    }
}
