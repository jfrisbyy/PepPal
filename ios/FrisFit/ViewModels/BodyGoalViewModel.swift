import SwiftUI

@Observable
final class BodyGoalViewModel {
    var currentGoal: FitnessGoalType = .weightLoss
    var targetWeight: Double = 175.0
    var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    var weeklyRate: Double = 1.0
    var heightCm: Double = 178.0
    var isExpanded: Bool = false
    var supabaseGoalId: String?

    var weightEntries: [WeightEntry] = []
    var measurements: [BodyMeasurement] = []
    var progressPhotos: [ProgressPhoto] = []

    var showWeighInSheet: Bool = false
    var showMeasurementSheet: Bool = false
    var showGoalPicker: Bool = false
    var showFullDetail: Bool = false

    var newWeighInValue: String = ""
    var newWeighInNote: String = ""

    var newChest: String = ""
    var newWaist: String = ""
    var newHips: String = ""
    var newBicepLeft: String = ""
    var newBicepRight: String = ""
    var newThighLeft: String = ""
    var newThighRight: String = ""
    var newNeck: String = ""

    var goalTargetWeightText: String = "175.0"
    var goalWeeklyRateText: String = "1.0"

    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String?
    var hasLoaded: Bool = false

    var currentWeight: Double {
        weightEntries.last?.weight ?? 0
    }

    var startingWeight: Double {
        weightEntries.first?.weight ?? currentWeight
    }

    var totalChange: Double {
        currentWeight - startingWeight
    }

    var weeklyChange: Double {
        guard weightEntries.count >= 2 else { return 0 }
        let recent = weightEntries.suffix(2)
        return recent.last!.weight - recent.first!.weight
    }

    var progressToGoal: Double {
        let totalNeeded = abs(startingWeight - targetWeight)
        guard totalNeeded > 0 else { return 1.0 }
        let achieved = abs(startingWeight - currentWeight)
        return min(achieved / totalNeeded, 1.0)
    }

    var remainingToGoal: Double {
        abs(currentWeight - targetWeight)
    }

    var bmi: BMIData {
        BMIData(weight: currentWeight * 0.453592, heightCm: heightCm)
    }

    var weightChartData: [(date: Date, weight: Double)] {
        weightEntries.map { ($0.date, $0.weight) }
    }

    var estimatedCompletionDate: Date? {
        guard weightEntries.count >= 2 else { return nil }
        let recentEntries = weightEntries.suffix(min(7, weightEntries.count))
        guard let first = recentEntries.first, let last = recentEntries.last else { return nil }
        let daysBetween = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 0
        guard daysBetween > 0 else { return nil }
        let weightChange = last.weight - first.weight
        let dailyRate = weightChange / Double(daysBetween)
        guard dailyRate != 0 else { return nil }

        let remaining = targetWeight - currentWeight
        if (currentGoal.isLosing && dailyRate >= 0) || (currentGoal.isGaining && dailyRate <= 0) {
            return nil
        }
        let daysToGoal = Int(abs(remaining / dailyRate))
        return Calendar.current.date(byAdding: .day, value: daysToGoal, to: Date())
    }

    var daysSinceLastWeighIn: Int? {
        guard let lastDate = weightEntries.last?.date else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }

    var averageWeeklyChange: Double? {
        guard weightEntries.count >= 2 else { return nil }
        let sorted = weightEntries.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        let weeks = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day.map { Double($0) / 7.0 } ?? 0
        guard weeks > 0 else { return nil }
        return (last.weight - first.weight) / weeks
    }

    // MARK: - Data Loading

    func loadData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        Task {
            await fetchAllData()
            isLoading = false
        }
    }

    func refresh() async {
        await fetchAllData()
    }

    private func fetchAllData() async {
        do {
            async let goalResult = BodyGoalsService.shared.fetchGoal()
            async let weightResult = BodyGoalsService.shared.fetchWeightLogs()
            async let measurementResult = BodyGoalsService.shared.fetchMeasurements()

            let goal = try await goalResult
            let weights = try await weightResult
            let meas = try await measurementResult

            if let goal {
                supabaseGoalId = goal.id
                currentGoal = FitnessGoalType.allCases.first { $0.rawValue == goal.goal_type } ?? .weightLoss
                targetWeight = goal.target_weight ?? 175.0
                goalTargetWeightText = String(format: "%.1f", targetWeight)
                weeklyRate = goal.weekly_rate ?? 1.0
                goalWeeklyRateText = String(format: "%.1f", weeklyRate)
                if let heightVal = goal.height_cm {
                    heightCm = heightVal
                }
                if let targetDateStr = goal.target_date {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let fBasic = ISO8601DateFormatter()
                    fBasic.formatOptions = [.withInternetDateTime]
                    targetDate = f.date(from: targetDateStr) ?? fBasic.date(from: targetDateStr) ?? targetDate
                }
            }

            weightEntries = weights
            measurements = meas
            errorMessage = nil
            if let latestWeight = weights.last?.weight, latestWeight > 0 {
                UserDefaults.standard.set(latestWeight, forKey: "cachedWeightLbs")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Goal Management

    func saveGoal() {
        guard let tw = Double(goalTargetWeightText), tw > 0 else { return }
        targetWeight = tw
        weeklyRate = Double(goalWeeklyRateText) ?? 1.0
        isSaving = true

        Task {
            do {
                let result = try await BodyGoalsService.shared.upsertGoal(
                    goalType: currentGoal,
                    targetWeight: targetWeight,
                    targetDate: targetDate,
                    startingWeight: startingWeight > 0 ? startingWeight : nil,
                    currentWeight: currentWeight > 0 ? currentWeight : nil,
                    heightCm: heightCm,
                    weeklyRate: weeklyRate
                )
                supabaseGoalId = result.id
                isSaving = false
                showGoalPicker = false
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    // MARK: - Weight Logging

    func logWeighIn() {
        guard let weight = Double(newWeighInValue), weight > 0 else { return }
        isSaving = true

        Task {
            do {
                let entry = try await BodyGoalsService.shared.logWeight(weight: weight, note: newWeighInNote)
                weightEntries.append(entry)
                StreakManager.shared.logActivity(type: .weight)
                await HealthKitService.shared.saveBodyMass(pounds: weight, date: entry.date)
                weightEntries.sort { $0.date < $1.date }
                UserDefaults.standard.set(weight, forKey: "cachedWeightLbs")

                if supabaseGoalId != nil {
                    _ = try? await BodyGoalsService.shared.upsertGoal(
                        goalType: currentGoal,
                        targetWeight: targetWeight,
                        targetDate: targetDate,
                        startingWeight: startingWeight > 0 ? startingWeight : nil,
                        currentWeight: weight,
                        heightCm: heightCm,
                        weeklyRate: weeklyRate
                    )
                }

                newWeighInValue = ""
                newWeighInNote = ""
                showWeighInSheet = false
                isSaving = false
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    func deleteWeightEntry(_ entry: WeightEntry) {
        guard let sid = entry.supabaseId else { return }
        Task {
            do {
                try await BodyGoalsService.shared.deleteWeightLog(id: sid)
                weightEntries.removeAll { $0.id == entry.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Measurement Logging

    func logMeasurement() {
        isSaving = true

        Task {
            do {
                let measurement = try await BodyGoalsService.shared.logMeasurement(
                    chest: Double(newChest),
                    waist: Double(newWaist),
                    hips: Double(newHips),
                    neck: Double(newNeck),
                    bicepLeft: Double(newBicepLeft),
                    bicepRight: Double(newBicepRight),
                    thighLeft: Double(newThighLeft),
                    thighRight: Double(newThighRight)
                )
                measurements.append(measurement)
                measurements.sort { $0.date < $1.date }
                clearMeasurementFields()
                showMeasurementSheet = false
                isSaving = false
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    func deleteMeasurement(_ measurement: BodyMeasurement) {
        guard let sid = measurement.supabaseId else { return }
        Task {
            do {
                try await BodyGoalsService.shared.deleteMeasurement(id: sid)
                measurements.removeAll { $0.id == measurement.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func clearMeasurementFields() {
        newChest = ""
        newWaist = ""
        newHips = ""
        newBicepLeft = ""
        newBicepRight = ""
        newThighLeft = ""
        newThighRight = ""
        newNeck = ""
    }
}
