import SwiftUI
import Charts

struct FriendStatDetailSheet: View {
    let friend: FriendStatSnapshot
    let mySnapshot: FriendStatSnapshot?
    let category: StatShareCategory
    @Environment(\.dismiss) private var dismiss

    private var theirValue: Double {
        rawValue(snapshot: friend, category: category)
    }

    private var myValue: Double {
        guard let mySnapshot else { return 0 }
        return rawValue(snapshot: mySnapshot, category: category)
    }

    private var theirSeries: [WeekPoint] {
        weeklySeries(seed: friend.id.uuidString.hashValue, total: theirValue)
    }

    private var mySeries: [WeekPoint] {
        guard let mySnapshot else { return [] }
        return weeklySeries(seed: mySnapshot.id.uuidString.hashValue, total: myValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    bigValue
                    chartCard
                    if mySnapshot != nil {
                        comparisonCard
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    private var bigValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(category.color)
                .frame(width: 38, height: 38)
                .background(category.color.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(formatted(theirValue, category: category))
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(friend.user.name + " · this week")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 7 days")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .textCase(.uppercase)

            Chart(theirSeries) { pt in
                BarMark(
                    x: .value("Day", pt.label),
                    y: .value("Value", pt.value)
                )
                .foregroundStyle(category.color.gradient)
                .cornerRadius(4)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(PepTheme.separatorColor.opacity(0.4))
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You vs them")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                comparisonCell(label: "You", value: myValue, color: PepTheme.teal, isLeader: myValue >= theirValue)
                comparisonCell(label: friend.user.name.components(separatedBy: " ").first ?? "Them", value: theirValue, color: PepTheme.violet, isLeader: theirValue > myValue)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
    }

    private func comparisonCell(label: String, value: Double, color: Color, isLeader: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
            HStack(spacing: 4) {
                Text(formatted(value, category: category))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(isLeader ? color : PepTheme.textPrimary)
                if isLeader {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isLeader ? color.opacity(0.12) : PepTheme.elevated, in: .rect(cornerRadius: 12))
    }

    // MARK: - Helpers

    private struct WeekPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    private func rawValue(snapshot: FriendStatSnapshot, category: StatShareCategory) -> Double {
        switch category {
        case .streak: return Double(snapshot.streak)
        case .workouts: return Double(snapshot.weeklyWorkouts)
        case .volume: return Double(snapshot.weeklyVolume)
        case .steps: return Double(snapshot.weeklySteps)
        case .calories: return Double(snapshot.weeklyCalories)
        case .water: return Double(snapshot.weeklyWaterMl)
        case .prs, .nutrition, .protocols, .programs, .sets: return 0
        }
    }

    private func formatted(_ value: Double, category: StatShareCategory) -> String {
        switch category {
        case .streak: return "\(Int(value)) days"
        case .workouts: return "\(Int(value))"
        case .volume:
            if value >= 1000 { return String(format: "%.1fk kg", value / 1000) }
            return "\(Int(value)) kg"
        case .steps:
            if value >= 1000 { return String(format: "%.1fk", value / 1000) }
            return "\(Int(value))"
        case .calories: return "\(Int(value)) cal"
        case .water: return String(format: "%.1fL", value / 1000)
        case .prs, .nutrition, .protocols, .programs, .sets: return "\(Int(value))"
        }
    }

    private func weeklySeries(seed: Int, total: Double) -> [WeekPoint] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        var generator = SeededRandom(seed: UInt64(bitPattern: Int64(seed)))
        var weights: [Double] = (0..<7).map { _ in Double.random(in: 0.4...1.4, using: &generator) }
        let sum = weights.reduce(0, +)
        if sum > 0 {
            weights = weights.map { $0 / sum }
        }
        let now = Date()
        return (0..<7).map { i in
            let day = cal.date(byAdding: .day, value: -(6 - i), to: now) ?? now
            let value = total * weights[i]
            return WeekPoint(label: formatter.string(from: day), value: value)
        }
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xdeadbeef : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
