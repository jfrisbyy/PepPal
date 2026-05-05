import SwiftUI

/// Persists which milestone celebrations have already played so we never replay
/// them on subsequent map opens.
@Observable
@MainActor
final class JourneyMilestoneTracker {
    static let shared = JourneyMilestoneTracker()

    private let key = "peppal.journey.milestones.fired.v1"
    private(set) var fired: Set<String>

    private init() {
        let arr = (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
        self.fired = Set(arr)
    }

    func hasFired(_ id: String) -> Bool { fired.contains(id) }

    func markFired(_ id: String) {
        guard !fired.contains(id) else { return }
        fired.insert(id)
        UserDefaults.standard.set(Array(fired), forKey: key)
    }

    /// Inspect current state and return the first unfired milestone, if any.
    func nextUnfired() -> JourneyMilestone? {
        let events = JourneyEventService.shared.events
        let cal = Calendar.current
        let now = Date()

        // First cycle complete
        let completedCycles = events.filter {
            $0.lane == .compounds
                && ($0.durationDays ?? 0) > 0
                && ($0.endDate ?? now) <= now
        }
        if let first = completedCycles.sorted(by: { ($0.endDate ?? $0.timestamp) > ($1.endDate ?? $1.timestamp) }).first {
            let id = "first_cycle_complete"
            if !hasFired(id) {
                let anchor = first.endDate ?? first.timestamp
                return JourneyMilestone(
                    id: id,
                    title: "First cycle in the books.",
                    body: "You completed your first \(first.payload?.compoundName ?? "protocol") cycle. The data you logged is the foundation for everything that comes next.",
                    icon: "checkmark.seal.fill",
                    anchorDate: anchor,
                    targetLane: .compounds
                )
            }
        }

        // First 5% body fat lost
        let bf = events
            .filter { $0.lane == .body }
            .compactMap { e -> (Date, Double)? in
                guard let v = e.payload?.bodyFatPercent, v > 0 else { return nil }
                return (e.timestamp, v)
            }
            .sorted { $0.0 < $1.0 }
        if let first = bf.first, let last = bf.last, first.1 - last.1 >= 5 {
            let id = "body_fat_minus_5"
            if !hasFired(id) {
                return JourneyMilestone(
                    id: id,
                    title: "5% body fat lost.",
                    body: "From \(String(format: "%.1f", first.1))% to \(String(format: "%.1f", last.1))% — composition is moving in the right direction.",
                    icon: "figure.arms.open",
                    anchorDate: last.0,
                    targetLane: .body
                )
            }
        }

        // First 90-day streak
        let longest = StreakManager.shared.streakData.longestStreak
        if longest >= 90 {
            let id = "streak_90"
            if !hasFired(id) {
                return JourneyMilestone(
                    id: id,
                    title: "90-day streak.",
                    body: "You hit your first 90-day logging streak. Eyes on you.",
                    icon: "shield.checkered",
                    anchorDate: now,
                    targetLane: .training
                )
            }
        } else if longest >= 30 {
            let id = "streak_30"
            if !hasFired(id) {
                return JourneyMilestone(
                    id: id,
                    title: "30 days, no breaks.",
                    body: "30 straight days of showing up. The streak compounds — keep it rolling.",
                    icon: "flame.circle.fill",
                    anchorDate: now,
                    targetLane: .training
                )
            }
        } else if longest >= 7 {
            let id = "streak_7"
            if !hasFired(id) {
                return JourneyMilestone(
                    id: id,
                    title: "First week down.",
                    body: "Seven days logged in a row. Quietly the most important streak — it's where the habit forms.",
                    icon: "flame.fill",
                    anchorDate: now,
                    targetLane: .training
                )
            }
        }

        // Goal achieved (target weight reached)
        let target = InsightsDataStore.shared.targetWeight
        if target > 0,
           let latest = events
            .filter({ $0.lane == .body })
            .compactMap({ e -> (Date, Double)? in
                guard let w = e.payload?.weightLbs, w > 0 else { return nil }
                return (e.timestamp, w)
            })
            .sorted(by: { $0.0 > $1.0 })
            .first,
           abs(latest.1 - target) <= 1.5 {
            let id = "goal_weight_reached"
            if !hasFired(id) {
                _ = cal // silence unused warning
                return JourneyMilestone(
                    id: id,
                    title: "Goal weight reached.",
                    body: "You hit your target of \(Int(target)) lb. The next chapter is yours to write.",
                    icon: "flag.checkered",
                    anchorDate: latest.0,
                    targetLane: .body
                )
            }
        }

        return nil
    }
}

nonisolated struct JourneyMilestone: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let body: String
    let icon: String
    let anchorDate: Date
    let targetLane: JourneyLane
}

/// Floating top-of-screen narration card. Auto-dismisses after 4s or on tap.
struct JourneyMilestoneCard: View {
    let milestone: JourneyMilestone
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(milestone.targetLane.color.opacity(0.22))
                    .frame(width: 36, height: 36)
                Image(systemName: milestone.icon)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(milestone.targetLane.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                Text(milestone.body)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(3)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 22/255, green: 22/255, blue: 28/255).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [milestone.targetLane.color.opacity(0.55), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 14, y: 4)
        )
        .onTapGesture {
            JourneyHaptics.soft()
            onDismiss()
        }
    }
}

/// Tasteful particle burst that radiates around a milestone pin once.
struct JourneyMilestoneParticleBurst: View {
    let color: Color

    private let particleCount: Int = 14
    @State private var animated: Bool = false

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { i in
                let angle = (Double(i) / Double(particleCount)) * .pi * 2
                let dx = CGFloat(cos(angle)) * (animated ? 38 : 0)
                let dy = CGFloat(sin(angle)) * (animated ? 38 : 0)
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .shadow(color: color.opacity(0.7), radius: 3)
                    .opacity(animated ? 0 : 1)
                    .offset(x: dx, y: dy)
            }

            Circle()
                .strokeBorder(color.opacity(animated ? 0 : 0.6), lineWidth: 1.2)
                .frame(width: animated ? 80 : 14, height: animated ? 80 : 14)
        }
        .onAppear {
            withAnimation(JourneyMotion.celebratory) { animated = true }
        }
        .allowsHitTesting(false)
    }
}

/// Single-pulse soft burst used for live pin-add reactions. Smaller and faster
/// than the milestone burst so it can play on every new pin without feeling loud.
struct JourneyLivePinBurst: View {
    let color: Color
    @State private var animated: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(animated ? 0 : 0.55))
                .frame(width: animated ? 36 : 10, height: animated ? 36 : 10)
                .blur(radius: animated ? 6 : 0)
            Circle()
                .strokeBorder(color.opacity(animated ? 0 : 0.7), lineWidth: 1.0)
                .frame(width: animated ? 44 : 12, height: animated ? 44 : 12)
        }
        .onAppear {
            withAnimation(JourneyMotion.standard) { animated = true }
        }
        .allowsHitTesting(false)
    }
}
