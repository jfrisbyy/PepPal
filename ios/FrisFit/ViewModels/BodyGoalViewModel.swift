import SwiftUI

@Observable
final class BodyGoalViewModel {
    var currentGoal: FitnessGoalType = .weightLoss
    var targetWeight: Double = 175.0
    var heightCm: Double = 178.0
    var isExpanded: Bool = false

    var weightEntries: [WeightEntry] = [
        WeightEntry(weight: 192.0, date: Calendar.current.date(byAdding: .day, value: -42, to: Date())!),
        WeightEntry(weight: 190.5, date: Calendar.current.date(byAdding: .day, value: -35, to: Date())!),
        WeightEntry(weight: 189.2, date: Calendar.current.date(byAdding: .day, value: -28, to: Date())!),
        WeightEntry(weight: 188.0, date: Calendar.current.date(byAdding: .day, value: -21, to: Date())!),
        WeightEntry(weight: 186.8, date: Calendar.current.date(byAdding: .day, value: -14, to: Date())!),
        WeightEntry(weight: 185.5, date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!),
        WeightEntry(weight: 184.3, date: Date()),
    ]

    var measurements: [BodyMeasurement] = [
        BodyMeasurement(date: Calendar.current.date(byAdding: .day, value: -28, to: Date())!, chest: 42.0, waist: 34.5, hips: 40.0, bicepLeft: 14.5, bicepRight: 15.0, thighLeft: 24.0, thighRight: 24.5, neck: 16.0),
        BodyMeasurement(date: Date(), chest: 42.5, waist: 33.5, hips: 39.5, bicepLeft: 14.8, bicepRight: 15.2, thighLeft: 24.2, thighRight: 24.7, neck: 16.0),
    ]

    var progressPhotos: [ProgressPhoto] = [
        ProgressPhoto(date: Calendar.current.date(byAdding: .day, value: -28, to: Date())!, label: "Week 1"),
        ProgressPhoto(date: Calendar.current.date(byAdding: .day, value: -14, to: Date())!, label: "Week 3"),
        ProgressPhoto(date: Date(), label: "Current"),
    ]

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

    func logWeighIn() {
        guard let weight = Double(newWeighInValue), weight > 0 else { return }
        let entry = WeightEntry(weight: weight, date: Date(), note: newWeighInNote)
        weightEntries.append(entry)
        newWeighInValue = ""
        newWeighInNote = ""
        showWeighInSheet = false
    }

    func logMeasurement() {
        let measurement = BodyMeasurement(
            date: Date(),
            chest: Double(newChest),
            waist: Double(newWaist),
            hips: Double(newHips),
            bicepLeft: Double(newBicepLeft),
            bicepRight: Double(newBicepRight),
            thighLeft: Double(newThighLeft),
            thighRight: Double(newThighRight),
            neck: Double(newNeck)
        )
        measurements.append(measurement)
        clearMeasurementFields()
        showMeasurementSheet = false
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
