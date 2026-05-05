import SwiftUI

struct WeeklyNutritionSummaryCard: View {
    @State private var avgKcal: Int = 0
    @State private var proteinAdherence: Double = 0
    @State private var daysHitGoal: Int = 0
    @State private var totalDays: Int = 7
    @State private var isLoading: Bool = true
    @State private var nutritionVM = NutritionViewModel.shared

    var body: some View {
        GlassCard(accent: PepTheme.teal) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    Text("Weekly Nutrition")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text("Last 7 days")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                if isLoading {
                    HStack { Spacer(); ProgressView().tint(PepTheme.teal); Spacer() }
                        .frame(height: 60)
                } else {
                    HStack(spacing: 10) {
                        statTile(
                            icon: "flame.fill",
                            value: "\(avgKcal)",
                            unit: "cal",
                            label: "Avg / day",
                            color: PepTheme.amber
                        )
                        statTile(
                            icon: "bolt.heart.fill",
                            value: "\(Int(proteinAdherence * 100))",
                            unit: "%",
                            label: "Protein hit",
                            color: PepTheme.teal
                        )
                        statTile(
                            icon: "checkmark.seal.fill",
                            value: "\(daysHitGoal)",
                            unit: "/ \(totalDays)",
                            label: "On-goal days",
                            color: PepTheme.violet
                        )
                    }
                }
            }
        }
        .task {
            await reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mealPersistedToSupabase)) { _ in
            Task { await reload() }
        }
    }

    private func statTile(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(color)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func reload() async {
        guard AuthService.shared.authState == .signedIn else {
            isLoading = false
            return
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -6, to: today),
              let end = cal.date(byAdding: .day, value: 1, to: today) else { return }

        do {
            let userId = try AuthService.shared.currentUserId()
            let meals = try await NutritionService.shared.fetchLoggedMealsInRange(userId: userId, from: start, to: end)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.locale = Locale(identifier: "en_US_POSIX")

            var dayCals: [String: Int] = [:]
            var dayProtein: [String: Double] = [:]
            for m in meals {
                guard let loggedStr = m.logged_at, let d = iso.date(from: loggedStr) else { continue }
                let key = df.string(from: d)
                dayCals[key, default: 0] += m.calories ?? 0
                dayProtein[key, default: 0] += m.protein_g ?? 0
            }

            let target = nutritionVM.dailyTarget
            let calTarget = target.calories
            let proteinTarget = Double(target.protein)

            var countedDays = 0
            var totalCals = 0
            var proteinHit = 0
            var goalDays = 0
            for i in 0..<7 {
                guard let d = cal.date(byAdding: .day, value: -i, to: today) else { continue }
                let key = df.string(from: d)
                let kc = dayCals[key] ?? 0
                let pr = dayProtein[key] ?? 0
                if kc > 0 || pr > 0 {
                    countedDays += 1
                    totalCals += kc
                    if proteinTarget > 0, pr >= proteinTarget * 0.9 { proteinHit += 1 }
                    if calTarget > 0, abs(kc - calTarget) <= Int(Double(calTarget) * 0.1) { goalDays += 1 }
                }
            }

            await MainActor.run {
                self.avgKcal = countedDays > 0 ? totalCals / countedDays : 0
                self.proteinAdherence = countedDays > 0 ? Double(proteinHit) / Double(countedDays) : 0
                self.daysHitGoal = goalDays
                self.totalDays = 7
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
}
