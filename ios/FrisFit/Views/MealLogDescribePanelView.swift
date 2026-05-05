import SwiftUI

struct MealLogDescribePanelView: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    let onDismiss: () -> Void

    @State private var descriptionText: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var estimatedItems: [EstimatedFoodItem] = []
    @State private var hasResult: Bool = false
    @State private var error: String? = nil
    @State private var mealSaved: Bool = false
    @State private var showSaveMealSheet: Bool = false
    @State private var saveMealName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !hasResult {
                    DescribeInputSection(
                        descriptionText: $descriptionText,
                        isAnalyzing: $isAnalyzing,
                        error: error,
                        onAnalyze: { analyzeDescription() }
                    )
                } else {
                    DescribeResultSection(
                        estimatedItems: estimatedItems,
                        mealTime: mealTime,
                        mealSaved: mealSaved,
                        onAddAll: { addAllItems() },
                        onSave: { prepareSave() },
                        onReDescribe: { resetState() }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showSaveMealSheet) {
            SaveMealSheetView(
                mealName: $saveMealName,
                calories: "\(estimatedItems.reduce(0) { $0 + $1.calories })",
                protein: "\(Int(estimatedItems.reduce(0) { $0 + $1.protein }))",
                carbs: "\(Int(estimatedItems.reduce(0) { $0 + $1.carbs }))",
                fat: "\(Int(estimatedItems.reduce(0) { $0 + $1.fat }))",
                onSave: {
                    let totalCal = estimatedItems.reduce(0) { $0 + $1.calories }
                    let totalP = estimatedItems.reduce(0) { $0 + $1.protein }
                    let totalC = estimatedItems.reduce(0) { $0 + $1.carbs }
                    let totalF = estimatedItems.reduce(0) { $0 + $1.fat }
                    let meal = SavedMeal(
                        name: saveMealName.isEmpty ? "My Meal" : saveMealName,
                        calories: totalCal,
                        protein: totalP,
                        carbs: totalC,
                        fat: totalF
                    )
                    viewModel.saveMeal(meal)
                    mealSaved = true
                    showSaveMealSheet = false
                },
                onClose: { showSaveMealSheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func analyzeDescription() {
        isAnalyzing = true
        error = nil

        Task {
            do {
                let result = try await NutritionAIService.shared.estimateFromDescription(descriptionText)
                estimatedItems = result.items
                hasResult = true
            } catch {
                self.error = "Could not estimate nutrition. Please try again."
            }
            isAnalyzing = false
        }
    }

    private func addAllItems() {
        for item in estimatedItems {
            viewModel.quickAddMeal(
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                mealTime: mealTime
            )
        }
        onDismiss()
    }

    private func prepareSave() {
        let names = estimatedItems.map { $0.name }
        saveMealName = names.count <= 2 ? names.joined(separator: " & ") : "\(names[0]) + \(names.count - 1) more"
        showSaveMealSheet = true
    }

    private func resetState() {
        hasResult = false
        estimatedItems = []
        mealSaved = false
    }
}

struct DescribeInputSection: View {
    @Binding var descriptionText: String
    @Binding var isAnalyzing: Bool
    let error: String?
    let onAnalyze: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            TextEditor(text: $descriptionText)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 110)
                .padding(12)
                .background(.white.opacity(0.08))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    Group {
                        if descriptionText.isEmpty {
                            Text("Describe what you ate...\ne.g. \"Grilled chicken, rice, and a side salad\"")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.3))
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )

            if let error {
                DescribeErrorBanner(message: error)
            }

            DescribeAnalyzeButton(
                descriptionText: descriptionText,
                isAnalyzing: isAnalyzing,
                onAnalyze: onAnalyze
            )

            DescribeSuggestionChips(onSelect: { descriptionText = $0 })
        }
    }
}

struct DescribeErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(10)
        .background(.orange.opacity(0.15))
        .clipShape(.rect(cornerRadius: 8))
    }
}

struct DescribeAnalyzeButton: View {
    let descriptionText: String
    let isAnalyzing: Bool
    let onAnalyze: () -> Void

    private var isDisabled: Bool {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing
    }

    var body: some View {
        Button(action: onAnalyze) {
            HStack(spacing: 10) {
                if isAnalyzing {
                    ProgressView().tint(.black)
                }
                Text(isAnalyzing ? "Analyzing…" : "Estimate Nutrition")
                    .font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                isDisabled ? Color.white.opacity(0.2) : Color.white,
                in: .rect(cornerRadius: 12)
            )
        }
        .disabled(isDisabled)
        .sensoryFeedback(.impact(weight: .medium), trigger: isAnalyzing)
    }
}

struct DescribeSuggestionChips: View {
    let onSelect: (String) -> Void

    private let suggestions = [
        "Chicken breast with rice and broccoli",
        "Two slices of pepperoni pizza",
        "Greek yogurt with granola",
        "Protein shake with banana"
    ]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button { onSelect(suggestion) } label: {
                    Text(suggestion)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 6))
                }
            }
        }
    }
}

struct DescribeResultSection: View {
    let estimatedItems: [EstimatedFoodItem]
    let mealTime: MealTime
    let mealSaved: Bool
    let onAddAll: () -> Void
    let onSave: () -> Void
    let onReDescribe: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            MealLogNutritionSummaryCard(items: estimatedItems)

            ForEach(Array(estimatedItems.enumerated()), id: \.element.id) { index, item in
                MealLogEstimatedItemRow(item: item, index: index, accent: PepTheme.violet)
            }

            HStack(spacing: 10) {
                MealLogAddAllButton(items: estimatedItems, mealTime: mealTime, onAdd: onAddAll)

                Button(action: onSave) {
                    Image(systemName: mealSaved ? "bookmark.fill" : "bookmark")
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
            }

            Button(action: onReDescribe) {
                Text("Re-describe")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 10))
            }
        }
    }
}
