import SwiftUI

@Observable
final class ExerciseLibraryViewModel {
    var searchText: String = ""
    var selectedMuscleGroup: MuscleGroup? = nil
    var selectedEquipment: Equipment? = nil

    private let allExercises: [Exercise] = ExerciseLibrary.all

    var filteredExercises: [Exercise] {
        var results = allExercises

        if let muscle = selectedMuscleGroup {
            results = results.filter { $0.primaryMuscle == muscle }
        }

        if let equip = selectedEquipment {
            results = results.filter { $0.equipment == equip }
        }

        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.primaryMuscle.rawValue.localizedStandardContains(searchText) ||
                $0.equipment.rawValue.localizedStandardContains(searchText)
            }
        }

        return results
    }

    var exerciseCount: Int {
        allExercises.count
    }

    func alternatives(for exercise: Exercise) -> [Exercise] {
        allExercises.filter {
            $0.id != exercise.id &&
            $0.primaryMuscle == exercise.primaryMuscle &&
            $0.movementPattern == exercise.movementPattern
        }
        .prefix(5)
        .map { $0 }
    }

    func similarExercises(for exercise: Exercise) -> [Exercise] {
        allExercises.filter {
            $0.id != exercise.id &&
            $0.primaryMuscle == exercise.primaryMuscle
        }
        .prefix(6)
        .map { $0 }
    }

    func selectMuscleGroup(_ group: MuscleGroup?) {
        if selectedMuscleGroup == group {
            selectedMuscleGroup = nil
        } else {
            selectedMuscleGroup = group
        }
    }

    func clearFilters() {
        searchText = ""
        selectedMuscleGroup = nil
        selectedEquipment = nil
    }
}
