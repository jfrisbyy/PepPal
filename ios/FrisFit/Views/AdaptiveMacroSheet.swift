import SwiftUI

struct AdaptiveMacroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = AdaptiveMacroStore.shared

    @State private var weightKg: Double = 75
    @State private var heightCm: Double = 175
    @State private var age: Double = 30
    @State private var sex: String = "male"
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: FitnessGoalType = .maintain
    @State private var weeklyWorkoutMinutes: Double = 180

    private var trainingBoost: Double {
        AdaptiveMacroService.trainingLoadBoost(weeklyWorkoutMinutes: Int(weeklyWorkoutMinutes))
    }

    private var preview: MacroTarget {
        AdaptiveMacroService.compute(
            MacroGoalInputs(
                weightKg: weightKg,
                heightCm: heightCm,
                ageYears: Int(age),
                biologicalSex: sex,
                activity: activity,
                goal: goal,
                trainingLoadBoost: trainingBoost
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    Picker("Goal", selection: $goal) {
                        ForEach(FitnessGoalType.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    Text(goal.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Body") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        Text("\(Int(weightKg)) kg").foregroundStyle(.secondary)
                    }
                    Slider(value: $weightKg, in: 40...160, step: 1)

                    HStack {
                        Text("Height")
                        Spacer()
                        Text("\(Int(heightCm)) cm").foregroundStyle(.secondary)
                    }
                    Slider(value: $heightCm, in: 140...210, step: 1)

                    HStack {
                        Text("Age")
                        Spacer()
                        Text("\(Int(age))").foregroundStyle(.secondary)
                    }
                    Slider(value: $age, in: 16...80, step: 1)

                    Picker("Biological Sex", selection: $sex) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }
                }

                Section("Training Load") {
                    Picker("Activity", selection: $activity) {
                        ForEach(ActivityLevel.allCases, id: \.self) { a in
                            Text(a.label).tag(a)
                        }
                    }

                    HStack {
                        Text("Workout min/week")
                        Spacer()
                        Text("\(Int(weeklyWorkoutMinutes))").foregroundStyle(.secondary)
                    }
                    Slider(value: $weeklyWorkoutMinutes, in: 0...900, step: 15)

                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(PepTheme.amber)
                        Text("Training boost: +\(Int(trainingBoost)) cal/day")
                            .font(.caption)
                    }
                }

                Section("Your Daily Targets") {
                    macroPreviewRow("Calories", value: "\(preview.calories)", unit: "cal", color: PepTheme.teal)
                    macroPreviewRow("Protein", value: "\(preview.protein)", unit: "g", color: PepTheme.teal)
                    macroPreviewRow("Carbs", value: "\(preview.carbs)", unit: "g", color: PepTheme.amber)
                    macroPreviewRow("Fat", value: "\(preview.fat)", unit: "g", color: PepTheme.violet)
                }

                if store.isEnabled {
                    Section {
                        Button(role: .destructive) {
                            store.disable()
                            dismiss()
                        } label: {
                            Label("Revert to default goals", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
            .navigationTitle("Macro Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        let inputs = MacroGoalInputs(
                            weightKg: weightKg,
                            heightCm: heightCm,
                            ageYears: Int(age),
                            biologicalSex: sex,
                            activity: activity,
                            goal: goal,
                            trainingLoadBoost: trainingBoost
                        )
                        store.save(inputs: inputs)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let i = store.inputs {
                    weightKg = i.weightKg
                    heightCm = i.heightCm
                    age = Double(i.ageYears)
                    sex = i.biologicalSex
                    activity = i.activity
                    goal = i.goal
                }
            }
        }
    }

    private func macroPreviewRow(_ label: String, value: String, unit: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
