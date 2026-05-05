import SwiftUI
import Charts

/// Editorial-style Apple Health section for HomeView. Surfaces every metric
/// the user has data for as its own card; auto-hides cards whose underlying
/// HealthKit value is empty so the section never shows a hollow skeleton.
struct HomeAppleHealthSection: View {
    let healthKit: HealthKitService

    var body: some View {
        VStack(spacing: 14) {
            // Steps + recovery summary live up top — these are the
            // headline rings most users open the home screen to see.
            if healthKit.steps > 0 || healthKit.activeCalories > 0 {
                stepsActivityCard
            }
            if hasRecoveryData {
                recoveryCard
            }
            if healthKit.sleepHours > 0 {
                sleepCard
            }
            if healthKit.heartRate > 0 || healthKit.hrv != nil || healthKit.restingHeartRate != nil {
                heartCard
            }
            if let weight = healthKit.bodyWeight, weight > 0 {
                bodyCompositionCard(weight: weight)
            }
            if let vo2 = healthKit.vo2Max, vo2 > 0 {
                vo2Card(value: vo2)
            }
            if hasVitalsData {
                vitalsCard
            }
            if hasNutritionData {
                nutritionCard
            }
            if !hasAnyData {
                emptyState
            }

            NavigationLink {
                HealthDetailView()
            } label: {
                HStack(spacing: 8) {
                    Text("VIEW FULL APPLE HEALTH")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(2.0)
                        .foregroundStyle(PepTheme.textPrimary)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Has-data flags

    private var hasRecoveryData: Bool {
        healthKit.recoveryScore != nil
    }

    private var hasVitalsData: Bool {
        healthKit.respiratoryRate != nil
            || healthKit.oxygenSaturation != nil
            || healthKit.bloodGlucose != nil
            || healthKit.bloodPressureSystolic != nil
    }

    private var hasNutritionData: Bool {
        healthKit.dietaryWater > 0
            || healthKit.dietaryEnergyConsumed > 0
            || healthKit.mindfulMinutesToday > 0
    }

    private var hasAnyData: Bool {
        healthKit.steps > 0
            || healthKit.activeCalories > 0
            || hasRecoveryData
            || healthKit.sleepHours > 0
            || healthKit.heartRate > 0
            || healthKit.hrv != nil
            || (healthKit.bodyWeight ?? 0) > 0
            || (healthKit.vo2Max ?? 0) > 0
            || hasVitalsData
            || hasNutritionData
    }

    // MARK: - Card chrome

    private func cardShell<Content: View>(
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.08), accent.opacity(0.015)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(PepTheme.cardSurface)
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.22), accent.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func eyebrow(_ label: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(accent)
                .frame(width: 14, height: 1.5)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.8)
                .foregroundStyle(accent)
            Spacer(minLength: 0)
        }
    }

    private func bigNumber(_ value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func metricRow(_ items: [(String, String)]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textTertiary)
                    Text(item.1)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if idx < items.count - 1 {
                    Rectangle()
                        .fill(PepTheme.textPrimary.opacity(0.08))
                        .frame(width: 0.5, height: 28)
                }
            }
        }
    }

    // MARK: - Cards

    private var stepsActivityCard: some View {
        cardShell(accent: PepTheme.teal) {
            eyebrow("Activity", accent: PepTheme.teal)
            bigNumber(formattedSteps, unit: "STEPS")
            metricRow([
                ("Active", "\(Int(healthKit.activeCalories)) cal"),
                ("Distance", String(format: "%.1f mi", healthKit.distanceMiles)),
                ("Floors", "\(healthKit.flightsClimbed)")
            ])
            if healthKit.exerciseMinutes > 0 {
                Text("\(Int(healthKit.exerciseMinutes)) exercise minutes today")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private var recoveryCard: some View {
        let score = healthKit.recoveryScore ?? 0
        let tint: Color = score >= 75 ? .green : (score >= 55 ? PepTheme.amber : .red)
        return cardShell(accent: tint) {
            eyebrow("Recovery", accent: tint)
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.18), lineWidth: 5)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 64, height: 64)
                    Text("\(score)")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(recoveryCaption(score: score))
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Composite of HRV, RHR, sleep & respiration")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func recoveryCaption(score: Int) -> String {
        if score >= 75 { return "Primed — push training." }
        if score >= 55 { return "Moderate — train at maintenance." }
        return "Low — prioritize rest."
    }

    private var sleepCard: some View {
        cardShell(accent: PepTheme.violet) {
            eyebrow("Sleep", accent: PepTheme.violet)
            bigNumber(String(format: "%.1f", healthKit.sleepHours), unit: "HOURS")
            Text(sleepCaption)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var sleepCaption: String {
        let hours = healthKit.sleepHours
        if hours >= 7.5 { return "Quality rest — your nervous system is restored." }
        if hours >= 6.5 { return "Decent sleep — aim for an earlier wind-down tonight." }
        return "Short sleep — consider a recovery-focused day."
    }

    private var heartPairs: [(String, String)] {
        var pairs: [(String, String)] = []
        if let rhr = healthKit.restingHeartRate {
            pairs.append(("Resting", "\(Int(rhr)) bpm"))
        }
        if let hrv = healthKit.hrv {
            pairs.append(("HRV", "\(Int(hrv)) ms"))
        }
        if let walking = healthKit.walkingHeartRateAverage {
            pairs.append(("Walking", "\(Int(walking)) bpm"))
        }
        return pairs
    }

    private var heartCard: some View {
        cardShell(accent: .red) {
            eyebrow("Heart", accent: .red)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if healthKit.heartRate > 0 {
                    Text("\(Int(healthKit.heartRate))")
                        .font(.system(size: 32, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("BPM")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            if !heartPairs.isEmpty {
                metricRow(heartPairs)
            }
        }
    }

    private func bodyPairs() -> [(String, String)] {
        var pairs: [(String, String)] = []
        if let bf = healthKit.bodyFatPercentage {
            pairs.append(("Body Fat", String(format: "%.1f%%", bf)))
        }
        if let lean = healthKit.leanBodyMass {
            pairs.append(("Lean", String(format: "%.1f lb", lean)))
        }
        if let bmi = healthKit.bmi {
            pairs.append(("BMI", String(format: "%.1f", bmi)))
        }
        return pairs
    }

    private func bodyCompositionCard(weight: Double) -> some View {
        let pairs = bodyPairs()
        return cardShell(accent: .orange) {
            eyebrow("Body", accent: .orange)
            bigNumber(String(format: "%.1f", weight), unit: "LB")
            if !pairs.isEmpty {
                metricRow(pairs)
            }
        }
    }

    private func vo2Card(value: Double) -> some View {
        cardShell(accent: PepTheme.blue) {
            eyebrow("VO₂ Max", accent: PepTheme.blue)
            bigNumber(String(format: "%.1f", value), unit: "ML/KG·MIN")
            Text(vo2Caption(value: value))
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func vo2Caption(value: Double) -> String {
        if value >= 50 { return "Excellent cardiorespiratory fitness." }
        if value >= 40 { return "Above average — keep building Zone 2." }
        if value >= 30 { return "Average — easy aerobic work raises this fast." }
        return "Below average — consistent cardio compounds quickly."
    }

    private var vitalsPairs: [(String, String)] {
        var pairs: [(String, String)] = []
        if let rr = healthKit.respiratoryRate {
            pairs.append(("Respiration", String(format: "%.0f br/min", rr)))
        }
        if let o2 = healthKit.oxygenSaturation {
            pairs.append(("Blood O₂", String(format: "%.0f%%", o2)))
        }
        if let glu = healthKit.bloodGlucose {
            pairs.append(("Glucose", String(format: "%.0f mg/dL", glu)))
        }
        if let sys = healthKit.bloodPressureSystolic, let dia = healthKit.bloodPressureDiastolic {
            pairs.append(("Pressure", String(format: "%.0f/%.0f", sys, dia)))
        }
        return pairs
    }

    private var vitalsCard: some View {
        let pairs = vitalsPairs
        return cardShell(accent: PepTheme.blue) {
            eyebrow("Vitals", accent: PepTheme.blue)
            if !pairs.isEmpty {
                metricRow(Array(pairs.prefix(3)))
                if pairs.count > 3 {
                    metricRow(Array(pairs.suffix(from: 3)))
                }
            }
        }
    }

    private var nutritionPairs: [(String, String)] {
        var pairs: [(String, String)] = []
        if healthKit.dietaryWater > 0 {
            pairs.append(("Water", "\(Int(healthKit.dietaryWater)) ml"))
        }
        if healthKit.dietaryEnergyConsumed > 0 {
            pairs.append(("Energy", "\(Int(healthKit.dietaryEnergyConsumed)) cal"))
        }
        if healthKit.mindfulMinutesToday > 0 {
            pairs.append(("Mindful", "\(Int(healthKit.mindfulMinutesToday)) min"))
        }
        return pairs
    }

    private var nutritionCard: some View {
        let pairs = nutritionPairs
        return cardShell(accent: .green) {
            eyebrow("Nutrition & Mindfulness", accent: .green)
            if !pairs.isEmpty {
                metricRow(pairs)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No Apple Health data yet today")
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Pull to refresh, or open the Health app to sync new readings.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var formattedSteps: String {
        let steps = healthKit.steps
        if steps >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
        }
        return "\(steps)"
    }
}
