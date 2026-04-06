import SwiftUI

struct DescribeMealView: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    @Environment(\.dismiss) private var dismiss
    @State private var description: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var estimatedItems: [EstimatedFoodItem] = []
    @State private var hasResult: Bool = false
    @State private var errorMessage: String? = nil
    @State private var pulseAnimation: Bool = false

    private var totalCalories: Int { estimatedItems.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { estimatedItems.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { estimatedItems.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { estimatedItems.reduce(0) { $0 + $1.fat } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !hasResult {
                        inputSection
                    } else {
                        resultSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Describe Meal")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var inputSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(PepTheme.violet.opacity(0.12))
                        .frame(width: 64, height: 64)
                        .scaleEffect(pulseAnimation ? 1.08 : 1.0)

                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(PepTheme.violet)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseAnimation = true
                    }
                }

                Text("Describe What You Ate")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text("AI will estimate the calories and macros")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $description)
                    .font(.body)
                    .foregroundStyle(PepTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(14)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                    )

                Text("e.g. \"Two scrambled eggs, one slice of whole wheat toast with butter, and a glass of orange juice\"")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    .padding(.horizontal, 4)
            }

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))
            }

            Button {
                analyzeDescription()
            } label: {
                HStack(spacing: 10) {
                    if isAnalyzing {
                        ProgressView()
                            .tint(PepTheme.invertedText)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isAnalyzing ? "Analyzing..." : "Estimate Nutrition")
                        .font(.system(.body, weight: .semibold))
                }
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing
                        ? PepTheme.elevated : PepTheme.violet,
                    in: .rect(cornerRadius: 12)
                )
            }
            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
            .sensoryFeedback(.impact(weight: .medium), trigger: isAnalyzing)

            quickSuggestions
        }
    }

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick suggestions")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)

            let suggestions = [
                "Chicken breast with rice and broccoli",
                "Two slices of pepperoni pizza",
                "Greek yogurt with granola and berries",
                "Protein shake with banana and peanut butter"
            ]

            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    description = suggestion
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.violet.opacity(0.6))
                        Text(suggestion)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
    }

    private var resultSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(totalCalories)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.teal)
                    Text("calories")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 16) {
                    miniMacro(label: "Protein", value: Int(totalProtein), unit: "g", color: PepTheme.teal)
                    miniMacro(label: "Carbs", value: Int(totalCarbs), unit: "g", color: PepTheme.amber)
                    miniMacro(label: "Fat", value: Int(totalFat), unit: "g", color: PepTheme.violet)
                }
            }
            .padding(16)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.teal.opacity(0.15), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Estimated Items")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text("Tap to adjust")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                }

                ForEach($estimatedItems) { $item in
                    estimatedItemRow(item: $item)
                }
            }

            VStack(spacing: 10) {
                Button {
                    addAllToMealLog()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Add All to \(mealTime.rawValue)")
                            .font(.system(.body, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                }
                .sensoryFeedback(.success, trigger: hasResult)

                HStack(spacing: 12) {
                    Button {
                        hasResult = false
                        estimatedItems = []
                    } label: {
                        Text("Re-describe")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.violet)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PepTheme.violet.opacity(0.12), in: .rect(cornerRadius: 10))
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PepTheme.elevated, in: .rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func estimatedItemRow(item: Binding<EstimatedFoodItem>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.wrappedValue.name)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text(item.wrappedValue.amount)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    VStack(spacing: 1) {
                        TextField("", value: item.calories, format: .number)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 54)
                        Text("cal")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            HStack(spacing: 8) {
                editableMacroTag("P", value: item.protein, color: PepTheme.teal)
                editableMacroTag("C", value: item.carbs, color: PepTheme.amber)
                editableMacroTag("F", value: item.fat, color: PepTheme.violet)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func editableMacroTag(_ letter: String, value: Binding<Double>, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(letter)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            TextField("", value: value, format: .number)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .keyboardType(.decimalPad)
                .frame(width: 28)
            Text("g")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 6))
    }

    private func miniMacro(label: String, value: Int, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)\(unit)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func analyzeDescription() {
        isAnalyzing = true
        errorMessage = nil

        Task {
            do {
                let result = try await NutritionAIService.shared.estimateFromDescription(description)
                estimatedItems = result.items
                hasResult = true
            } catch {
                errorMessage = "Could not estimate nutrition. Please try again."
            }
            isAnalyzing = false
        }
    }

    private func addAllToMealLog() {
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
        dismiss()
    }
}
