import SwiftUI

struct NutritionView: View {
    @State private var viewModel = NutritionViewModel.shared
    @State private var todaysPlanVM = TodaysPlanViewModel.shared
    @State private var showMealLogMethod: Bool = false
    @State private var selectedMealTimeForLog: MealTime = .breakfast
    @State private var animatedCalorieProgress: Double = 0
    @State private var showMacroGoalSheet: Bool = false
    @State private var showAdaptiveReason: Bool = false
    @State private var mealToCopy: LoggedMeal? = nil
    @State private var showCopyDatePicker: Bool = false
    @State private var copyTargetDate: Date = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                editorialHero
                EditorialInsightSection(
                    eyebrow: "FUEL · INSIGHT",
                    title: "Today's Read",
                    content: todaysPlanVM.moduleContent(for: "nutrition"),
                    accent: PepTheme.amber,
                    isRefreshing: todaysPlanVM.isBackgroundRefreshing || (todaysPlanVM.isLoading && todaysPlanVM.moduleContent(for: "nutrition") == nil),
                    lastUpdated: todaysPlanVM.lastFetchDate
                )
                WaterIntakeCard()
                mealLog
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Nutrition")
        
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SyncStatusBadge()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        selectedMealTimeForLog = suggestedMealTime
                        showMealLogMethod = true
                    } label: {
                        Label("Log Meal", systemImage: "fork.knife")
                    }
                    Button {
                        showMacroGoalSheet = true
                    } label: {
                        Label("Macro Goals", systemImage: "target")
                    }
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
        .sheet(isPresented: $showMacroGoalSheet) {
            AdaptiveMacroSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCopyDatePicker) {
            NavigationStack {
                VStack(spacing: 16) {
                    DatePicker("Copy to", selection: $copyTargetDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                    Spacer()
                    Button {
                        if let meal = mealToCopy {
                            viewModel.copyMeal(meal, to: copyTargetDate)
                        }
                        mealToCopy = nil
                        showCopyDatePicker = false
                    } label: {
                        Text("Copy")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .navigationTitle("Copy Meal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            mealToCopy = nil
                            showCopyDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .onAppear {
            if AuthService.shared.authState != .signedIn {
                viewModel.loadSampleData()
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animatedCalorieProgress = viewModel.calorieProgress
            }
        }
        .task {
            if AuthService.shared.authState == .signedIn {
                await viewModel.loadFromSupabaseAsync()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animatedCalorieProgress = viewModel.calorieProgress
                }
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

    private var editorialHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            heroHeader

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [PepTheme.teal.opacity(0.55), PepTheme.teal.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.75)

            HStack(alignment: .center, spacing: 22) {
                heroRing
                heroMacroColumn
            }

            Rectangle()
                .fill(PepTheme.cardOverlay)
                .frame(height: 0.5)

            heroFootnote
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            ZStack {
                PepTheme.cardSurface
                LinearGradient(
                    colors: [PepTheme.teal.opacity(0.06), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.teal.opacity(0.22), PepTheme.teal.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
        )
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(PepTheme.teal)
                .frame(width: 2, height: 36)
                .padding(.top, 20)
        }
    }

    private var heroHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("FUEL · TODAY")
                        .font(.system(.caption2, weight: .heavy))
                        .tracking(3.2)
                        .foregroundStyle(PepTheme.teal)
                    Rectangle()
                        .fill(PepTheme.shimmerHighlight)
                        .frame(width: 18, height: 1)
                }
                Text("Daily Intake")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            if viewModel.adaptiveTargetReason != nil {
                Button { showAdaptiveReason.toggle() } label: {
                    Text("ADAPTIVE")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            Capsule().strokeBorder(PepTheme.teal.opacity(0.45), lineWidth: 0.6)
                        )
                }
                .popover(isPresented: $showAdaptiveReason, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recalculated from")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(viewModel.adaptiveTargetReason ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Recomputes weekly from your weight & training.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(12)
                    .frame(width: 220)
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
    }

    private var heroRing: some View {
        ZStack {
            Circle()
                .stroke(PepTheme.elevated, lineWidth: 12)

            Circle()
                .trim(from: 0, to: animatedCalorieProgress)
                .stroke(
                    AngularGradient(
                        colors: [PepTheme.teal.opacity(0.5), PepTheme.teal],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedCalorieProgress)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: PepTheme.teal.opacity(0.3), radius: 6)

            VStack(spacing: 1) {
                Text("\(viewModel.totalCalories)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("of \(viewModel.dailyTarget.calories)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("KCAL")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.teal)
                    .padding(.top, 2)
            }
        }
        .frame(width: 132, height: 132)
    }

    private var heroMacroColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroMacroRow(
                label: "Protein",
                current: viewModel.totalProtein,
                target: Double(viewModel.dailyTarget.protein),
                progress: viewModel.proteinProgress,
                color: PepTheme.teal
            )
            heroMacroRow(
                label: "Carbs",
                current: viewModel.totalCarbs,
                target: Double(viewModel.dailyTarget.carbs),
                progress: viewModel.carbsProgress,
                color: PepTheme.amber
            )
            heroMacroRow(
                label: "Fat",
                current: viewModel.totalFat,
                target: Double(viewModel.dailyTarget.fat),
                progress: viewModel.fatProgress,
                color: PepTheme.violet
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroMacroRow(label: String, current: Double, target: Double, progress: Double, color: Color) -> some View {
        let remaining = max(Int(target) - Int(current), 0)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: 10)
                Text(label.uppercased())
                    .font(.system(.caption2, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(Int(current))")
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
                        .fill(color.opacity(0.14))
                        .frame(height: 3)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.6), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(progress, 1.0), height: 3)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
                }
            }
            .frame(height: 3)

            Text(remaining > 0 ? "\(remaining)g remaining" : "target met")
                .font(.system(.caption2, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
        }
    }

    private var heroFootnote: some View {
        HStack(spacing: 18) {
            footnoteStat(label: "Remaining", value: "\(viewModel.caloriesRemaining)", unit: "kcal")
            Rectangle()
                .fill(PepTheme.cardOverlay)
                .frame(width: 0.5, height: 24)
            footnoteStat(
                label: "Consumed",
                value: "\(Int(animatedCalorieProgress * 100))",
                unit: "%"
            )
            Rectangle()
                .fill(PepTheme.cardOverlay)
                .frame(width: 0.5, height: 24)
            footnoteStat(
                label: "Macro Split",
                value: macroSplitString,
                unit: "P · C · F"
            )
            Spacer(minLength: 0)
        }
    }

    private func footnoteStat(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private var macroSplitString: String {
        let p = viewModel.totalProtein * 4
        let c = viewModel.totalCarbs * 4
        let f = viewModel.totalFat * 9
        let total = max(p + c + f, 1)
        let pp = Int((p / total * 100).rounded())
        let cp = Int((c / total * 100).rounded())
        let fp = max(100 - pp - cp, 0)
        return "\(pp)·\(cp)·\(fp)"
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

                    if viewModel.adaptiveTargetReason != nil {
                        Button { showAdaptiveReason.toggle() } label: {
                            Text("Adaptive")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PepTheme.teal.opacity(0.15))
                            .clipShape(.capsule)
                        }
                        .padding(.top, 3)
                        .popover(isPresented: $showAdaptiveReason, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Recalculated from")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(viewModel.adaptiveTargetReason ?? "")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Recomputes weekly from your weight & training.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                            .padding(12)
                            .frame(width: 220)
                            .presentationCompactAdaptation(.popover)
                        }
                    }
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

        let sectionProtein = viewModel.mealsForTime(mealTime).reduce(0) { $0 + $1.totalProtein }
        let sectionCarbs = viewModel.mealsForTime(mealTime).reduce(0) { $0 + $1.totalCarbs }
        let sectionFat = viewModel.mealsForTime(mealTime).reduce(0) { $0 + $1.totalFat }
        let perMealCal = max(viewModel.dailyTarget.calories / 4, 1)
        let perMealProtein = max(viewModel.dailyTarget.protein / 4, 1)
        let perMealCarbs = max(viewModel.dailyTarget.carbs / 4, 1)
        let perMealFat = max(viewModel.dailyTarget.fat / 4, 1)

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

                if sectionCalories > 0 {
                    HStack(spacing: 3) {
                        miniRing(value: Double(sectionCalories), target: Double(perMealCal), color: mealTime.color)
                        miniRing(value: sectionProtein, target: Double(perMealProtein), color: PepTheme.teal)
                        miniRing(value: sectionCarbs, target: Double(perMealCarbs), color: PepTheme.amber)
                        miniRing(value: sectionFat, target: Double(perMealFat), color: PepTheme.violet)
                    }
                    .padding(.trailing, 4)
                }

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

    private func miniRing(value: Double, target: Double, color: Color) -> some View {
        let progress = target > 0 ? min(value / target, 1.0) : 0
        return ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 2)
                .frame(width: 14, height: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(-90))
        }
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
            Button {
                viewModel.copyMeal(meal, to: Date())
            } label: {
                Label("Copy to Today", systemImage: "doc.on.doc")
            }
            .tint(PepTheme.teal)
        }
        .contextMenu {
            Button {
                viewModel.copyMeal(meal, to: Date())
            } label: {
                Label("Copy to Today", systemImage: "doc.on.doc")
            }
            Button {
                mealToCopy = meal
                copyTargetDate = Date()
                showCopyDatePicker = true
            } label: {
                Label("Copy to date…", systemImage: "calendar.badge.plus")
            }
            Button(role: .destructive) {
                viewModel.removeMeal(meal)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

extension NutritionView {
    fileprivate func _copyPickerBinding() -> Binding<Bool> { $showCopyDatePicker }
}
