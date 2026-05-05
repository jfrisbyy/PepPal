import SwiftUI

struct MealLogNutritionSummaryCard: View {
    let items: [EstimatedFoodItem]

    var body: some View {
        let totalCal = items.reduce(0) { $0 + $1.calories }
        let totalP = items.reduce(0) { $0 + $1.protein }
        let totalC = items.reduce(0) { $0 + $1.carbs }
        let totalF = items.reduce(0) { $0 + $1.fat }

        HStack(spacing: 0) {
            MealLogMacroColumn(label: "", value: "\(totalCal)", unit: "cal", color: PepTheme.teal, isBig: true)
                .frame(maxWidth: .infinity)

            MealLogDividerLine()

            MealLogMacroColumn(label: "Protein", value: "\(Int(totalP))g", unit: "", color: PepTheme.teal, isBig: false)
                .frame(maxWidth: .infinity)

            MealLogDividerLine()

            MealLogMacroColumn(label: "Carbs", value: "\(Int(totalC))g", unit: "", color: PepTheme.amber, isBig: false)
                .frame(maxWidth: .infinity)

            MealLogDividerLine()

            MealLogMacroColumn(label: "Fat", value: "\(Int(totalF))g", unit: "", color: PepTheme.violet, isBig: false)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
    }
}

struct MealLogMacroColumn: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    let isBig: Bool

    var body: some View {
        VStack(spacing: 2) {
            if isBig {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

struct MealLogDividerLine: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(width: 0.5, height: 30)
    }
}

struct MealLogEstimatedItemRow: View {
    let item: EstimatedFoodItem
    let index: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(item.amount)
                    Text("·")
                    Text("P:\(Int(item.protein))g")
                    Text("C:\(Int(item.carbs))g")
                    Text("F:\(Int(item.fat))g")
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(item.calories)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("cal")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(10)
        .background(.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct MealLogAddAllButton: View {
    let items: [EstimatedFoodItem]
    let mealTime: MealTime
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Add to \(mealTime.rawValue)")
                    .font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(PepTheme.teal, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.scale)
        .sensoryFeedback(.success, trigger: items.count)
    }
}

struct SaveMealSheetView: View {
    @Binding var mealName: String
    let calories: String
    let protein: String
    let carbs: String
    let fat: String
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                SaveMealHeader()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Meal Name")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)

                    TextField("e.g. Morning Smoothie", text: $mealName)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }

                SaveMealMacroRow(calories: calories, protein: protein, carbs: carbs, fat: fat)

                Button(action: onSave) {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                        Text("Save Meal")
                            .font(.system(.body, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.amber, in: .rect(cornerRadius: 12))
                }

                Spacer()
            }
            .padding(20)
            .appBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                }
            }
        }
    }
}

struct SaveMealHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(PepTheme.amber.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(PepTheme.amber)
            }

            Text("Save This Meal")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Save for quick access next time")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }
}

struct SaveMealMacroRow: View {
    let calories: String
    let protein: String
    let carbs: String
    let fat: String

    var body: some View {
        HStack(spacing: 16) {
            SaveMealMacroPreview(label: "Calories", value: calories, color: PepTheme.teal)
            SaveMealMacroPreview(label: "Protein", value: protein + "g", color: PepTheme.teal)
            SaveMealMacroPreview(label: "Carbs", value: carbs + "g", color: PepTheme.amber)
            SaveMealMacroPreview(label: "Fat", value: fat + "g", color: PepTheme.violet)
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
    }
}

struct SaveMealMacroPreview: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
