import Foundation
import HealthKit
import SwiftUI

/// Central store that holds snapshots of the user's multi-domain data for the
/// insights agent to query. Populated from HomeView on data changes.
@Observable
final class InsightsDataStore {
    static let shared = InsightsDataStore()

    var firstName: String = ""
    var activeProtocols: [PeptideProtocol] = []
    var workoutHistory: [WorkoutHistoryDetail] = []
    var recentMealsByDay: [Date: [LoggedMeal]] = [:]
    var todayMeals: [LoggedMeal] = []
    var macroTarget: MacroTarget = MacroTarget(calories: 2200, protein: 150, carbs: 220, fat: 70)
    var weightEntries: [WeightEntry] = []
    var bodyMeasurements: [BodyMeasurement] = []
    var startingWeight: Double = 0
    var targetWeight: Double = 0
    var bloodwork: [BloodworkEntry] = []
    var muscleRecovery: [MuscleRecoveryItem] = []
    var weeklyVolumes: [WeeklyMuscleVolume] = []
    var personalRecords: [TrainPersonalRecord] = []
    var activeProgram: TrainingProgram?
    var lastUpdated: Date = Date()

    // Expanded correlation data
    var vialInventory: [Vial] = []
    var lowStockForecasts: [SupplyForecast] = []
    var sleepCorrelation: TrainingSleepCorrelation?
    var bloodworkInterpretation: BloodworkInterpretation?
    var adaptiveMacroReason: String?
    var goalType: String = ""

    private init() {}

    func update(
        firstName: String,
        activeProtocols: [PeptideProtocol],
        workoutHistory: [WorkoutHistoryDetail],
        todayMeals: [LoggedMeal],
        macroTarget: MacroTarget,
        weightEntries: [WeightEntry],
        bodyMeasurements: [BodyMeasurement],
        startingWeight: Double,
        targetWeight: Double,
        bloodwork: [BloodworkEntry],
        muscleRecovery: [MuscleRecoveryItem],
        weeklyVolumes: [WeeklyMuscleVolume],
        personalRecords: [TrainPersonalRecord],
        activeProgram: TrainingProgram?
    ) {
        self.firstName = firstName
        self.activeProtocols = activeProtocols
        self.workoutHistory = workoutHistory
        self.todayMeals = todayMeals
        self.macroTarget = macroTarget
        self.weightEntries = weightEntries
        self.bodyMeasurements = bodyMeasurements
        self.startingWeight = startingWeight
        self.targetWeight = targetWeight
        self.bloodwork = bloodwork
        self.muscleRecovery = muscleRecovery
        self.weeklyVolumes = weeklyVolumes
        self.personalRecords = personalRecords
        self.activeProgram = activeProgram
        self.lastUpdated = Date()
    }

    func updateInventory(vials: [Vial], lowStock: [SupplyForecast]) {
        self.vialInventory = vials
        self.lowStockForecasts = lowStock
    }

    func updateSleep(_ correlation: TrainingSleepCorrelation?) {
        self.sleepCorrelation = correlation
    }

    func updateBloodworkInterpretation(_ interp: BloodworkInterpretation?) {
        self.bloodworkInterpretation = interp
    }

    func updateGoal(goalType: String, adaptiveReason: String?) {
        self.goalType = goalType
        self.adaptiveMacroReason = adaptiveReason
    }

    func ingestDailyMeals(date: Date, meals: [LoggedMeal]) {
        let key = Calendar.current.startOfDay(for: date)
        recentMealsByDay[key] = meals
    }

    var primaryProtocol: PeptideProtocol? {
        activeProtocols.first(where: { $0.isActive }) ?? activeProtocols.first
    }

    /// Hash of the data relevant for insight generation. If this doesn't change,
    /// we can reuse the cached investigation result.
    var dataHash: String {
        var parts: [String] = []
        for p in activeProtocols {
            parts.append("\(p.name):\(Int(p.startDate.timeIntervalSince1970 / 86400)):\(p.doseLog.count):\(p.sideEffectLog.count):\(p.compounds.map(\.compoundName).joined(separator: ","))")
        }
        parts.append("wh:\(workoutHistory.count):\(workoutHistory.first?.id.uuidString ?? "")")
        parts.append("meals:\(todayMeals.count):\(Int(todayMeals.reduce(0) { $0 + $1.totalCalories }))")
        parts.append("w:\(weightEntries.count):\(weightEntries.last.map { Int($0.weight * 10) } ?? 0)")
        parts.append("bm:\(bodyMeasurements.count)")
        parts.append("bw:\(bloodwork.count)")
        parts.append("prs:\(personalRecords.count)")
        let combined = parts.joined(separator: "|")
        var hasher = Hasher()
        hasher.combine(combined)
        return "ds-\(hasher.finalize())"
    }
}
