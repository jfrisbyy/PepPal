import Foundation
import SwiftUI

nonisolated enum SportCoachSport: String, Sendable {
    case main = "lifting"
    case running = "running"
    case cycling = "cycling"
    case basketball = "basketball"
}

nonisolated struct SportCoachTip: Identifiable, Sendable {
    let id: UUID
    let icon: String
    let text: String

    init(icon: String, text: String) {
        self.id = UUID()
        self.icon = icon
        self.text = text
    }
}

nonisolated struct SportCoachBrief: Sendable {
    let headline: String
    let recovery: RecoverySignalRaw
    let tips: [SportCoachTip]

    nonisolated enum RecoverySignalRaw: String, Sendable {
        case green, amber, red, unknown
    }
}

/// Lightweight on-device coach that produces instant, sport-aware tips using
/// the user's recent sessions and Apple Health recovery signals. No network
/// call required — tapping "Ask coach" opens the full PepChatView for chat.
@MainActor
enum SportCoachService {
    static func brief(for sport: SportCoachSport) -> SportCoachBrief {
        let hk = HealthKitService.shared
        let recovery = recoverySignal(hk: hk)

        switch sport {
        case .running:
            return runningBrief(recovery: recovery)
        case .cycling:
            return cyclingBrief(recovery: recovery)
        case .basketball:
            return basketballBrief(recovery: recovery)
        case .main:
            return mainBrief(recovery: recovery)
        }
    }

    private static func recoverySignal(hk: HealthKitService) -> SportCoachBrief.RecoverySignalRaw {
        guard hk.isAvailable, hk.isAuthorized else { return .unknown }
        if let score = hk.recoveryScore {
            if score >= 70 { return .green }
            if score >= 50 { return .amber }
            return .red
        }
        return .unknown
    }

    // MARK: - Running

    private static func runningBrief(recovery: SportCoachBrief.RecoverySignalRaw) -> SportCoachBrief {
        let vm = RunningViewModel.shared
        let thisWeek = vm.thisWeekMiles
        let runs = vm.thisWeekRuns.count
        let avgPace = vm.averagePaceAllTime
        let longest = vm.longestRunEver
        var tips: [SportCoachTip] = []

        let headline: String
        switch recovery {
        case .red:
            headline = "Ease up today — recovery is low"
            tips.append(SportCoachTip(icon: "figure.walk", text: "Keep it Z1–Z2 or take a full rest day"))
        case .amber:
            headline = "Moderate day — keep it conversational"
            tips.append(SportCoachTip(icon: "speedometer", text: "Target ~30s/mi slower than your average pace"))
        case .green:
            headline = "Good day for a quality session"
            if avgPace > 0 {
                let target = max(avgPace - 0.5, 5.5)
                let m = Int(target)
                let s = Int((target - Double(m)) * 60)
                tips.append(SportCoachTip(icon: "bolt.fill", text: "Tempo target: \(m):\(String(format: "%02d", s))/mi for 20–25 min"))
            } else {
                tips.append(SportCoachTip(icon: "bolt.fill", text: "Great day for a tempo or intervals"))
            }
        case .unknown:
            headline = "Pick a session and go"
        }

        if thisWeek > 0 {
            if runs >= 4 {
                tips.append(SportCoachTip(icon: "exclamationmark.shield.fill", text: "4+ runs already this week — watch for cumulative fatigue"))
            } else {
                tips.append(SportCoachTip(icon: "chart.line.uptrend.xyaxis", text: String(format: "%.1f mi logged this week — aim for a long run soon", thisWeek)))
            }
        }

        if longest < 6, vm.completedRuns.count >= 4 {
            tips.append(SportCoachTip(icon: "road.lanes", text: "Try extending your longest run by 10% next week"))
        }

        if tips.isEmpty {
            tips.append(SportCoachTip(icon: "figure.run", text: "Start an easy run to build your baseline"))
        }

        return SportCoachBrief(headline: headline, recovery: recovery, tips: Array(tips.prefix(3)))
    }

    // MARK: - Cycling

    private static func cyclingBrief(recovery: SportCoachBrief.RecoverySignalRaw) -> SportCoachBrief {
        let vm = CyclingViewModel.shared
        let thisWeek = vm.thisWeekMiles
        let rides = vm.thisWeekRides.count
        var tips: [SportCoachTip] = []

        let headline: String
        switch recovery {
        case .red:
            headline = "Recovery spin day"
            tips.append(SportCoachTip(icon: "figure.outdoor.cycle", text: "Keep power in Z1–Z2, 30–45 min max"))
        case .amber:
            headline = "Steady endurance today"
            tips.append(SportCoachTip(icon: "speedometer", text: "Hold Z2 heart rate, avoid hard efforts"))
        case .green:
            headline = "Good day to push the legs"
            tips.append(SportCoachTip(icon: "bolt.fill", text: "2×20 min sweet spot (88–94% FTP) is on the table"))
        case .unknown:
            headline = "Pick a ride type and roll out"
        }

        if rides == 0 && vm.completedRides.count > 0 {
            tips.append(SportCoachTip(icon: "calendar", text: "No rides this week yet — start easy to build back"))
        } else if thisWeek > 0 {
            tips.append(SportCoachTip(icon: "chart.bar.fill", text: String(format: "%.1f mi this week · %d ride%@", thisWeek, rides, rides == 1 ? "" : "s")))
        }

        if let fastestMax = vm.completedRides.map(\.maxSpeed).max(), fastestMax > 0 {
            tips.append(SportCoachTip(icon: "trophy.fill", text: String(format: "Top speed PR: %.1f mph — still yours to beat", fastestMax)))
        }

        if tips.isEmpty {
            tips.append(SportCoachTip(icon: "bicycle", text: "Start an outdoor or indoor ride to get a baseline"))
        }

        return SportCoachBrief(headline: headline, recovery: recovery, tips: Array(tips.prefix(3)))
    }

    // MARK: - Basketball

    private static func basketballBrief(recovery: SportCoachBrief.RecoverySignalRaw) -> SportCoachBrief {
        let vm = BasketballViewModel.shared
        var tips: [SportCoachTip] = []

        let headline: String
        switch recovery {
        case .red:
            headline = "Light shooting day"
            tips.append(SportCoachTip(icon: "scope", text: "Focus on form shooting, skip live play"))
        case .amber:
            headline = "Skill work over scrimmage"
            tips.append(SportCoachTip(icon: "target", text: "Drill catch-and-shoot reps, avoid long games"))
        case .green:
            headline = "Green light — scrimmage or play live"
            tips.append(SportCoachTip(icon: "sportscourt.fill", text: "Great day to log a full game"))
        case .unknown:
            headline = "Get shots up"
        }

        if vm.totalGamesPlayed >= 3 {
            tips.append(SportCoachTip(icon: "chart.xyaxis.line", text: String(format: "Averaging %.1f ppg across %d games", vm.averagePoints, vm.totalGamesPlayed)))
        }

        if vm.thisWeekSessions == 0 {
            tips.append(SportCoachTip(icon: "calendar.badge.exclamationmark", text: "No sessions logged this week — stay sharp"))
        } else if vm.thisWeekSessions >= 3 {
            tips.append(SportCoachTip(icon: "flame.fill", text: "\(vm.thisWeekSessions) sessions this week — stay hydrated"))
        }

        if tips.isEmpty {
            tips.append(SportCoachTip(icon: "basketball.fill", text: "Log a session to build your stats"))
        }

        return SportCoachBrief(headline: headline, recovery: recovery, tips: Array(tips.prefix(3)))
    }

    // MARK: - Main / lifting

    private static func mainBrief(recovery: SportCoachBrief.RecoverySignalRaw) -> SportCoachBrief {
        let store = InsightsDataStore.shared
        var tips: [SportCoachTip] = []

        let headline: String
        switch recovery {
        case .red:
            headline = "Body says deload"
            tips.append(SportCoachTip(icon: "arrow.down.circle.fill", text: "Drop working sets by ~30% or swap in mobility"))
        case .amber:
            headline = "Hit your lift — stay sub-max"
            tips.append(SportCoachTip(icon: "figure.strengthtraining.traditional", text: "Hold RPE 7 or lower across top sets"))
        case .green:
            headline = "Primed for a strong session"
            tips.append(SportCoachTip(icon: "bolt.fill", text: "Go for a PR attempt on your main lift"))
        case .unknown:
            headline = "Ready to lift"
        }

        let stillRecovering = store.muscleRecovery.filter { $0.status != .recovered }
        if !stillRecovering.isEmpty {
            let names = stillRecovering.prefix(2).map(\.muscle.rawValue).joined(separator: ", ")
            tips.append(SportCoachTip(icon: "heart.text.clipboard", text: "Still recovering: \(names)"))
        }

        let newPRs = store.personalRecords.filter(\.isNew).count
        if newPRs > 0 {
            tips.append(SportCoachTip(icon: "trophy.fill", text: "\(newPRs) new PR\(newPRs == 1 ? "" : "s") this week — nice work"))
        }

        if tips.isEmpty {
            tips.append(SportCoachTip(icon: "figure.strengthtraining.traditional", text: "Start today's program workout to progress"))
        }

        return SportCoachBrief(headline: headline, recovery: recovery, tips: Array(tips.prefix(3)))
    }
}
