import SwiftUI

struct FoodSearchView: View {
    @Bindable var viewModel: NutritionViewModel
    let selectedMealTime: MealTime
    @Environment(\.dismiss) private var dismiss
    @State private var showQuickAdd: Bool = false
    @State private var selectedFood: FoodItem? = nil
    @State private var servings: Double = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilter

                if viewModel.filteredFoods.isEmpty {
                    emptyState
                } else {
                    foodList
                }
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showQuickAdd = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                            Text("Quick Add")
                                .font(.system(.subheadline, weight: .medium))
                        }
                        .foregroundStyle(PepTheme.teal)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search foods...")
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(viewModel: viewModel, mealTime: selectedMealTime)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedFood) { food in
                FoodDetailSheet(food: food, servings: $servings, onAdd: {
                    viewModel.logMeal(food: food, servings: servings, mealTime: selectedMealTime)
                    selectedFood = nil
                    servings = 1.0
                    dismiss()
                })
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .onDisappear {
                viewModel.searchText = ""
                viewModel.selectedCategory = nil
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(label: "All", category: nil)
                ForEach(FoodCategory.allCases, id: \.rawValue) { category in
                    categoryChip(label: category.rawValue, category: category)
                }
            }
            .padding(.vertical, 10)
        }
        .contentMargins(.horizontal, 16)
    }

    private func categoryChip(label: String, category: FoodCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedCategory = category
            }
        } label: {
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(isSelected ? PepTheme.background : PepTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var foodList: some View {
        List {
            ForEach(viewModel.filteredFoods) { food in
                Button {
                    servings = 1.0
                    selectedFood = food
                } label: {
                    foodRow(food)
                }
                .listRowBackground(PepTheme.cardSurface)
                .listRowSeparatorTint(PepTheme.separatorColor)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func foodRow(_ food: FoodItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !food.brand.isEmpty {
                        Text(food.brand)
                            .foregroundStyle(PepTheme.teal.opacity(0.8))
                        Text("·")
                    }
                    Text(food.servingSize)
                }
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(food.calories)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                +
                Text(" cal")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)

                HStack(spacing: 6) {
                    macroTag("P", value: food.protein, color: PepTheme.teal)
                    macroTag("C", value: food.carbs, color: PepTheme.amber)
                    macroTag("F", value: food.fat, color: PepTheme.violet)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func macroTag(_ letter: String, value: Double, color: Color) -> some View {
        Text("\(letter):\(Int(value))")
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(color.opacity(0.9))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
            Text("No foods found")
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Text("Try a different search or use Quick Add")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FoodDetailSheet: View {
    let food: FoodItem
    @Binding var servings: Double
    let onAdd: () -> Void

    private var adjustedCalories: Int { Int(Double(food.calories) * servings) }
    private var adjustedProtein: Double { food.protein * servings }
    private var adjustedCarbs: Double { food.carbs * servings }
    private var adjustedFat: Double { food.fat * servings }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(food.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if !food.brand.isEmpty {
                        Text(food.brand)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                HStack(spacing: 20) {
                    macroCircle(label: "Calories", value: "\(adjustedCalories)", unit: "cal", color: PepTheme.teal)
                    macroCircle(label: "Protein", value: "\(Int(adjustedProtein))", unit: "g", color: PepTheme.teal)
                    macroCircle(label: "Carbs", value: "\(Int(adjustedCarbs))", unit: "g", color: PepTheme.amber)
                    macroCircle(label: "Fat", value: "\(Int(adjustedFat))", unit: "g", color: PepTheme.violet)
                }

                VStack(spacing: 10) {
                    Text("Servings")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)

                    HStack(spacing: 16) {
                        Button {
                            if servings > 0.5 { servings -= 0.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(PepTheme.textSecondary)
                        }

                        Text(String(format: "%.1f", servings))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 60)

                        Button {
                            servings += 0.5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(PepTheme.teal)
                        }
                    }

                    Text(food.servingSize)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }

                Button(action: onAdd) {
                    Text("Add to Meal")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: servings)
            }
            .padding(20)
            .background(PepTheme.background.ignoresSafeArea())
        }
    }

    private func macroCircle(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 56, height: 56)
                VStack(spacing: 0) {
                    Text(value)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(color.opacity(0.7))
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }
}

struct QuickAddSheet: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(PepTheme.teal)
                    Text("Quick Add")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Add calories and optionally macros")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                VStack(spacing: 14) {
                    quickField(label: "Name (optional)", text: $name, placeholder: "e.g. Lunch out")
                    quickField(label: "Calories *", text: $caloriesText, placeholder: "e.g. 500")
                    HStack(spacing: 12) {
                        quickField(label: "Protein (g)", text: $proteinText, placeholder: "0")
                        quickField(label: "Carbs (g)", text: $carbsText, placeholder: "0")
                        quickField(label: "Fat (g)", text: $fatText, placeholder: "0")
                    }
                }

                Button {
                    let cal = Int(caloriesText) ?? 0
                    guard cal > 0 else { return }
                    viewModel.quickAddMeal(
                        name: name,
                        calories: cal,
                        protein: Double(proteinText) ?? 0,
                        carbs: Double(carbsText) ?? 0,
                        fat: Double(fatText) ?? 0,
                        mealTime: mealTime
                    )
                    dismiss()
                } label: {
                    Text("Add Entry")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            (caloriesText.isEmpty ? PepTheme.elevated : PepTheme.teal),
                            in: .rect(cornerRadius: 12)
                        )
                }
                .disabled(caloriesText.isEmpty)

                Spacer()
            }
            .padding(20)
            .background(PepTheme.background.ignoresSafeArea())
        }
    }

    private func quickField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

            TextField(placeholder, text: text)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
                .keyboardType(label.contains("Name") ? .default : .decimalPad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}
