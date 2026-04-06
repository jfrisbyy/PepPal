import SwiftUI

struct NutritionView: View {
    @State private var viewModel = NutritionViewModel()
    @State private var showMealLogMethod: Bool = false
    @State private var selectedMealTimeForLog: MealTime = .breakfast
    @State private var animatedCalorieProgress: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                calorieRing
                macroBreakdown
                fpBonusCard
                mealLog
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Nutrition")
        
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedMealTimeForLog = suggestedMealTime
                    showMealLogMethod = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .fullScreenCover(isPresented: $showMealLogMethod) {
            MealLogView(viewModel: viewModel, mealTime: selectedMealTimeForLog)
        }
        .onAppear {
            if viewModel.loggedMeals.isEmpty {
                viewModel.loadSampleData()
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animatedCalorieProgress = viewModel.calorieProgress
            }
        }
        .onChange(of: viewModel.calorieProgress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedCalorieProgress = newValue
            }
        }
    }

    private var suggestedMealTime: MealTime {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return .breakfast }
        if hour < 15 { return .lunch }
        if hour < 20 { return .dinner }
        return .snacks
    }

    private var calorieRing: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 16)

                Circle()
                    .trim(from: 0, to: animatedCalorieProgress)
                    .stroke(
                        AngularGradient(
                            colors: [PepTheme.teal.opacity(0.5), PepTheme.teal],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * animatedCalorieProgress)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: PepTheme.teal.opacity(0.35), radius: 8)

                VStack(spacing: 2) {
                    Text("\(viewModel.totalCalories)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.teal)

                    Text("/ \(viewModel.dailyTarget.calories) cal")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)

                    Text("\(viewModel.caloriesRemaining) remaining")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        .padding(.top, 2)
                }
            }
            .frame(width: 190, height: 190)
            .padding(.top, 8)

            Text("Daily Calories")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var macroBreakdown: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Macros")
                }

                macroRow(
                    label: "Protein",
                    current: viewModel.totalProtein,
                    target: Double(viewModel.dailyTarget.protein),
                    progress: viewModel.proteinProgress,
                    color: PepTheme.teal
                )

                macroRow(
                    label: "Carbs",
                    current: viewModel.totalCarbs,
                    target: Double(viewModel.dailyTarget.carbs),
                    progress: viewModel.carbsProgress,
                    color: PepTheme.amber
                )

                macroRow(
                    label: "Fat",
                    current: viewModel.totalFat,
                    target: Double(viewModel.dailyTarget.fat),
                    progress: viewModel.fatProgress,
                    color: PepTheme.violet
                )
            }
        }
    }

    private func macroRow(label: String, current: Double, target: Double, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)

                Spacer()

                Text("\(Int(current))g")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                +
                Text(" / \(Int(target))g")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PepTheme.elevated)
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    private var fpBonusCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PepTheme.amber.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "star.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PepTheme.amber)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nutrition FP Bonus")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    if viewModel.fpBonus > 0 {
                        Text("+\(viewModel.fpBonus) FP earned from hitting targets")
                            .font(.caption)
                            .foregroundStyle(PepTheme.amber)
                    } else {
                        Text("Hit your macro targets to earn bonus FP")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                Spacer()

                Text("+\(viewModel.fpBonus)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(viewModel.fpBonus > 0 ? PepTheme.amber : PepTheme.textSecondary.opacity(0.5))
            }
        }
    }

    private var mealLog: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeadlineText(text: "Meal Log")

            ForEach(MealTime.allCases) { mealTime in
                mealTimeSection(mealTime)
            }
        }
    }

    private func mealTimeSection(_ mealTime: MealTime) -> some View {
        let meals = viewModel.mealsForTime(mealTime)
        let sectionCalories = viewModel.caloriesForMealTime(mealTime)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: mealTime.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(mealTime.color)
                    .frame(width: 28, height: 28)
                    .background(mealTime.color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 7))

                Text(mealTime.rawValue)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                Spacer()

                if viewModel.isFollowingNutritionPlan && !meals.isEmpty {
                    let status = viewModel.adherenceStatus(for: mealTime)
                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .font(.caption2)
                        Text(status.label)
                            .font(.caption2)
                    }
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(status.color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 6))
                }

                if sectionCalories > 0 {
                    Text("\(sectionCalories) cal")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if meals.isEmpty {
                Button {
                    selectedMealTimeForLog = mealTime
                    showMealLogMethod = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.subheadline)
                        Text("Add \(mealTime.rawValue)")
                            .font(.system(.subheadline, weight: .medium))
                    }
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(meals) { meal in
                        mealRow(meal)

                        if meal.id != meals.last?.id {
                            Divider()
                                .overlay(PepTheme.cardOverlay)
                                .padding(.leading, 14)
                        }
                    }
                }
            }

            if !meals.isEmpty {
                Button {
                    selectedMealTimeForLog = mealTime
                    showMealLogMethod = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Add more")
                            .font(.system(.caption, weight: .medium))
                    }
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func mealRow(_ meal: LoggedMeal) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.food.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)

                HStack(spacing: 8) {
                    if meal.servings != 1.0 {
                        Text(String(format: "%.1fx", meal.servings))
                            .foregroundStyle(PepTheme.teal)
                    }
                    Text(meal.food.servingSize)
                    Text("·")
                    Text("P: \(Int(meal.totalProtein))g")
                    Text("C: \(Int(meal.totalCarbs))g")
                    Text("F: \(Int(meal.totalFat))g")
                }
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Text("\(meal.totalCalories)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            +
            Text(" cal")
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.removeMeal(meal)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
