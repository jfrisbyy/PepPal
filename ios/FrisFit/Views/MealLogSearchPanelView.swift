import SwiftUI

struct MealLogSearchPanelView: View {
    @Bindable var viewModel: NutritionViewModel
    @Binding var selectedFood: FoodItem?
    @Binding var foodServings: Double
    var mealTime: MealTime = .breakfast

    @State private var showBarcodeScanner: Bool = false
    @State private var showRecipes: Bool = false
    @State private var showTemplates: Bool = false
    @State private var barcodeLookupError: String? = nil
    @State private var isLookingUpBarcode: Bool = false
    @State private var templates = MealTemplateStore.shared
    @State private var favorites = FoodFavoritesStore.shared

    var body: some View {
        VStack(spacing: 0) {
            quickActions
            SearchBarField(searchText: $viewModel.searchText)
            SearchCategoryFilterStrip(viewModel: viewModel)

            if viewModel.searchText.isEmpty && viewModel.selectedCategory == nil {
                quickAddChipsStrip
            }

            if isLookingUpBarcode {
                VStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Looking up barcode…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if let err = barcodeLookupError {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Button("Dismiss") { barcodeLookupError = nil }
                        .font(.caption)
                        .foregroundStyle(PepTheme.teal)
                }
                .padding()
            } else if viewModel.filteredFoods.isEmpty {
                SearchEmptyState()
            } else {
                SearchResultsList(
                    foods: viewModel.filteredFoods,
                    onSelect: { food in
                        foodServings = 1.0
                        selectedFood = food
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showBarcodeScanner) {
            BarcodeScannerView(onScan: handleBarcode)
        }
        .sheet(isPresented: $showRecipes) {
            RecipeBuilderView(nutritionVM: viewModel, mealTime: mealTime, onLogged: {})
        }
        .sheet(isPresented: $showTemplates) {
            MealTemplatesSheet(mealTime: mealTime)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            SearchQuickActionButton(icon: "barcode.viewfinder", label: "Scan") {
                showBarcodeScanner = true
            }
            SearchQuickActionButton(icon: "fork.knife", label: "Recipes") {
                showRecipes = true
            }
            SearchQuickActionButton(icon: "clock.arrow.circlepath", label: "Recent") {
                showTemplates = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var quickAddChipsStrip: some View {
        let recents: [FoodItem] = {
            var seen = Set<String>()
            var out: [FoodItem] = []
            let all = MealTime.allCases.flatMap { templates.recentMealsByTime[$0] ?? [] }
            for m in all.sorted(by: { $0.timestamp > $1.timestamp }) {
                let key = "\(m.food.name)|\(m.food.brand)"
                if !seen.contains(key) {
                    seen.insert(key)
                    out.append(m.food)
                }
                if out.count >= 12 { break }
            }
            return out
        }()
        let favs = favorites.favorites.map { $0.asFoodItem }

        if !favs.isEmpty || !recents.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if !favs.isEmpty {
                    chipsRow(title: "Favorites", icon: "star.fill", foods: favs)
                }
                if !recents.isEmpty {
                    chipsRow(title: "Recent", icon: "clock.arrow.circlepath", foods: recents)
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
    }

    private func chipsRow(title: String, icon: String, foods: [FoodItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(.caption2, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(foods) { food in
                        Button {
                            foodServings = 1.0
                            selectedFood = food
                        } label: {
                            HStack(spacing: 6) {
                                Text(food.name)
                                    .lineLimit(1)
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(food.calories)")
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .foregroundStyle(PepTheme.teal)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.08))
                            .clipShape(.capsule)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, 16)
        }
    }

    private func handleBarcode(_ code: String) {
        isLookingUpBarcode = true
        barcodeLookupError = nil
        Task {
            do {
                let food = try await FoodLookupService.shared.lookup(barcode: code)
                await MainActor.run {
                    isLookingUpBarcode = false
                    foodServings = 1.0
                    selectedFood = food
                }
            } catch {
                await MainActor.run {
                    isLookingUpBarcode = false
                    barcodeLookupError = error.localizedDescription
                }
            }
        }
    }
}

struct SearchQuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(.caption, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.white.opacity(0.1))
            .clipShape(.rect(cornerRadius: 10))
        }
    }
}

struct MealTemplatesSheet: View {
    let mealTime: MealTime
    @Environment(\.dismiss) private var dismiss
    @State private var templates = MealTemplateStore.shared

    var body: some View {
        NavigationStack {
            List {
                if let yMeals = templates.yesterdayMealsByTime[mealTime], !yMeals.isEmpty {
                    Section {
                        Button {
                            templates.relogYesterday(mealTime: mealTime)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .foregroundStyle(PepTheme.teal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Re-log yesterday's \(mealTime.rawValue)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text("\(yMeals.count) items · \(yMeals.reduce(0) { $0 + $1.totalCalories }) cal")
                                        .font(.caption)
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                    } header: { Text("Yesterday") }
                }

                Section("Recent \(mealTime.rawValue) (last 7 days)") {
                    let recents = templates.recentMealsByTime[mealTime] ?? []
                    if recents.isEmpty {
                        Text("No recent \(mealTime.rawValue.lowercased()) logged yet")
                            .foregroundStyle(PepTheme.textSecondary)
                    } else {
                        ForEach(recents) { meal in
                            Button {
                                templates.relog(meal, at: mealTime)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(meal.food.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(PepTheme.textPrimary)
                                        Text("\(meal.totalCalories) cal · P:\(Int(meal.totalProtein)) C:\(Int(meal.totalCarbs)) F:\(Int(meal.totalFat))")
                                            .font(.caption)
                                            .foregroundStyle(PepTheme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(PepTheme.teal)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Again")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { templates.rebuild() }
        }
    }
}

struct SearchBarField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            TextField("Search foods...", text: $searchText)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.white)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct SearchCategoryFilterStrip: View {
    @Bindable var viewModel: NutritionViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                SearchCategoryChipButton(label: "All", isSelected: viewModel.selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedCategory = nil }
                }
                ForEach(FoodCategory.allCases, id: \.rawValue) { category in
                    SearchCategoryChipButton(label: category.rawValue, isSelected: viewModel.selectedCategory == category) {
                        withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedCategory = category }
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .contentMargins(.horizontal, 16)
    }
}

struct SearchCategoryChipButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : .white.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
        }
    }
}

struct SearchEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.2))
            Text("No foods found")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

struct SearchResultsList: View {
    let foods: [FoodItem]
    let onSelect: (FoodItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(foods) { food in
                    Button { onSelect(food) } label: {
                        SearchFoodRowView(food: food)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }
}

struct SearchFoodRowView: View {
    let food: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if !food.brand.isEmpty {
                        Text(food.brand)
                            .foregroundStyle(PepTheme.teal.opacity(0.8))
                        Text("·")
                    }
                    Text(food.servingSize)
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(food.calories)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                +
                Text(" cal")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 5) {
                    Text("P:\(Int(food.protein))")
                        .foregroundStyle(PepTheme.teal)
                    Text("C:\(Int(food.carbs))")
                        .foregroundStyle(PepTheme.amber)
                    Text("F:\(Int(food.fat))")
                        .foregroundStyle(PepTheme.violet)
                }
                .font(.system(.caption2, design: .rounded, weight: .semibold))
            }

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(PepTheme.teal)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }
}
