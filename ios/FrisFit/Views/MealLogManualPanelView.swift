import SwiftUI

struct MealLogManualPanelView: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    let onDismiss: () -> Void

    @State private var quickName: String = ""
    @State private var quickCalories: String = ""
    @State private var quickProtein: String = ""
    @State private var quickCarbs: String = ""
    @State private var quickFat: String = ""
    @State private var showSaveMealSheet: Bool = false
    @State private var saveMealName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !viewModel.savedMeals.isEmpty {
                    ManualSavedMealsSection(
                        savedMeals: viewModel.savedMeals,
                        onSelect: { meal in
                            quickName = meal.name
                            quickCalories = "\(meal.calories)"
                            quickProtein = String(format: "%.0f", meal.protein)
                            quickCarbs = String(format: "%.0f", meal.carbs)
                            quickFat = String(format: "%.0f", meal.fat)
                        },
                        onDelete: { viewModel.deleteSavedMeal($0) }
                    )
                }

                ManualInputFields(
                    quickName: $quickName,
                    quickCalories: $quickCalories,
                    quickProtein: $quickProtein,
                    quickCarbs: $quickCarbs,
                    quickFat: $quickFat,
                    onAdd: { addEntry() },
                    onSave: { prepareSave() }
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showSaveMealSheet) {
            SaveMealSheetView(
                mealName: $saveMealName,
                calories: quickCalories,
                protein: quickProtein,
                carbs: quickCarbs,
                fat: quickFat,
                onSave: {
                    let meal = SavedMeal(
                        name: saveMealName.isEmpty ? "My Meal" : saveMealName,
                        calories: Int(quickCalories) ?? 0,
                        protein: Double(quickProtein) ?? 0,
                        carbs: Double(quickCarbs) ?? 0,
                        fat: Double(quickFat) ?? 0
                    )
                    viewModel.saveMeal(meal)
                    showSaveMealSheet = false
                },
                onClose: { showSaveMealSheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func addEntry() {
        let cal = Int(quickCalories) ?? 0
        guard cal > 0 else { return }
        viewModel.quickAddMeal(
            name: quickName,
            calories: cal,
            protein: Double(quickProtein) ?? 0,
            carbs: Double(quickCarbs) ?? 0,
            fat: Double(quickFat) ?? 0,
            mealTime: mealTime
        )
        onDismiss()
    }

    private func prepareSave() {
        let cal = Int(quickCalories) ?? 0
        guard cal > 0 else { return }
        saveMealName = quickName.isEmpty ? "My Meal" : quickName
        showSaveMealSheet = true
    }
}

struct ManualSavedMealsSection: View {
    let savedMeals: [SavedMeal]
    let onSelect: (SavedMeal) -> Void
    let onDelete: (SavedMeal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(PepTheme.amber)
                Text("Saved Meals")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(savedMeals) { saved in
                        ManualSavedMealChip(meal: saved, onSelect: onSelect, onDelete: onDelete)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }
}

struct ManualSavedMealChip: View {
    let meal: SavedMeal
    let onSelect: (SavedMeal) -> Void
    let onDelete: (SavedMeal) -> Void

    var body: some View {
        Button { onSelect(meal) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(meal.calories)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                    Text("cal")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }

                HStack(spacing: 4) {
                    Text("P:\(Int(meal.protein))")
                        .foregroundStyle(PepTheme.teal)
                    Text("C:\(Int(meal.carbs))")
                        .foregroundStyle(PepTheme.amber)
                    Text("F:\(Int(meal.fat))")
                        .foregroundStyle(PepTheme.violet)
                }
                .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minWidth: 100)
            .background(.white.opacity(0.08))
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(PepTheme.amber.opacity(0.2), lineWidth: 0.5)
            )
        }
        .contextMenu {
            Button(role: .destructive) { onDelete(meal) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct ManualInputFields: View {
    @Binding var quickName: String
    @Binding var quickCalories: String
    @Binding var quickProtein: String
    @Binding var quickCarbs: String
    @Binding var quickFat: String
    let onAdd: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ManualTextField(label: "Name", text: $quickName, placeholder: "e.g. Lunch out", isNumeric: false)
            ManualTextField(label: "Calories", text: $quickCalories, placeholder: "500", isNumeric: true)

            HStack(spacing: 10) {
                ManualTextField(label: "Protein (g)", text: $quickProtein, placeholder: "0", isNumeric: true)
                ManualTextField(label: "Carbs (g)", text: $quickCarbs, placeholder: "0", isNumeric: true)
                ManualTextField(label: "Fat (g)", text: $quickFat, placeholder: "0", isNumeric: true)
            }

            HStack(spacing: 10) {
                Button(action: onAdd) {
                    Text("Add Entry")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            quickCalories.isEmpty ? Color.white.opacity(0.2) : Color.white,
                            in: .rect(cornerRadius: 12)
                        )
                }
                .disabled(quickCalories.isEmpty)
                .sensoryFeedback(.impact(weight: .light), trigger: quickCalories)

                Button(action: onSave) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PepTheme.amber)
                        .frame(width: 50, height: 46)
                        .background(PepTheme.amber.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(PepTheme.amber.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .disabled((Int(quickCalories) ?? 0) <= 0)
            }
        }
    }
}

struct ManualTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let isNumeric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            TextField(placeholder, text: $text)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.white)
                .keyboardType(isNumeric ? .decimalPad : .default)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}
