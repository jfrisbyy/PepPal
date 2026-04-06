import SwiftUI

@Observable
final class SportSessionViewModel {
    var selectedSport: Sport = .basketball
    var sessionType: SportSessionType = .practice
    var durationMinutes: Int = 60
    var intensity: Int = 5
    var customSportName: String = ""

    var basketballStats = BasketballStats()
    var runningStats = RunningStats()
    var swimmingStats = SwimmingStats()

    var estimatedFP: Int {
        SportSession.calculateFP(durationMinutes: durationMinutes, intensity: intensity)
    }

    func reset() {
        sessionType = .practice
        durationMinutes = 60
        intensity = 5
        customSportName = ""
        basketballStats = BasketballStats()
        runningStats = RunningStats()
        swimmingStats = SwimmingStats()
    }

    func createSession() -> SportSession {
        let stats: SportSpecificStats
        switch selectedSport {
        case .basketball:
            stats = .basketball(basketballStats)
        case .running:
            stats = .running(runningStats)
        case .swimming:
            stats = .swimming(swimmingStats)
        default:
            stats = .none
        }

        return SportSession(
            sport: selectedSport,
            sessionType: sessionType,
            durationMinutes: durationMinutes,
            intensity: intensity,
            specificStats: stats,
            customSportName: selectedSport == .custom ? customSportName : nil
        )
    }
}
