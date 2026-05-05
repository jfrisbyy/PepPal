import SwiftUI

@Observable
final class RecipeLibrary {
    @MainActor static let shared = RecipeLibrary()

    var recipes: [Recipe] = []
    var isLoading: Bool = false

    private let localKey = "com.frisfit.recipes.local"
    private var loaded = false

    private init() {
        loadLocal()
    }

    func add(_ recipe: Recipe) {
        recipes.insert(recipe, at: 0)
        saveLocal()
        guard AuthService.shared.authState == .signedIn,
              let uid = try? AuthService.shared.currentUserId() else { return }
        Task { @MainActor in
            do {
                let created = try await RecipeService.shared.create(userId: uid, recipe: recipe)
                if let idx = recipes.firstIndex(where: { $0.id == recipe.id }) {
                    recipes[idx] = created
                    saveLocal()
                }
            } catch {
                print("[RecipeLibrary] create error: \(error)")
            }
        }
    }

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        saveLocal()
        guard AuthService.shared.authState == .signedIn else { return }
        Task {
            try? await RecipeService.shared.delete(id: recipe.id.uuidString)
        }
    }

    func loadFromSupabase() async {
        guard !loaded, AuthService.shared.authState == .signedIn,
              let uid = try? AuthService.shared.currentUserId() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let remote = try await RecipeService.shared.fetch(userId: uid)
            var merged = remote
            for local in recipes where !remote.contains(where: { $0.id == local.id }) {
                merged.append(local)
            }
            recipes = merged
            loaded = true
            saveLocal()
        } catch {
            print("[RecipeLibrary] fetch error: \(error)")
        }
    }

    private func saveLocal() {
        guard let data = try? JSONEncoder().encode(recipes) else { return }
        UserDefaults.standard.set(data, forKey: localKey)
    }

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let decoded = try? JSONDecoder().decode([Recipe].self, from: data) else { return }
        recipes = decoded
    }
}

struct RecipeBuilderView: View {
    @Bindable var nutritionVM: NutritionViewModel
    let mealTime: MealTime
    let onLogged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var library = RecipeLibrary.shared
    @State private var showCreate: Bool = false
    @State private var selectedRecipe: Recipe? = nil
    @State private var portionsToLog: Double = 1.0

    var body: some View {
        NavigationStack {
            Group {
                if library.recipes.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(library.recipes) { recipe in
                            Button {
                                portionsToLog = 1.0
                                selectedRecipe = recipe
                            } label: {
                                recipeRow(recipe)
                            }
                            .listRowBackground(PepTheme.cardSurface)
                        }
                        .onDelete { offsets in
                            for i in offsets { library.delete(library.recipes[i]) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .appBackground()
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(PepTheme.teal)
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                RecipeEditorView(onSave: { library.add($0) })
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeLogSheet(
                    recipe: recipe,
                    portions: $portionsToLog,
                    onLog: {
                        nutritionVM.logMeal(
                            food: recipe.asFoodItem(portions: portionsToLog),
                            servings: portionsToLog,
                            mealTime: mealTime
                        )
                        selectedRecipe = nil
                        onLogged()
                        dismiss()
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .task { await library.loadFromSupabase() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife")
                .font(.system(size: 40))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
            Text("No recipes yet")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Combine ingredients into reusable meals")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

            Button {
                showCreate = true
            } label: {
                Label("Create Recipe", systemImage: "plus.circle.fill")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(PepTheme.teal, in: .rect(cornerRadius: 10))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func recipeRow(_ recipe: Recipe) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 8) {
                    Text("\(recipe.portions) portion\(recipe.portions > 1 ? "s" : "")")
                    Text("·")
                    Text("\(recipe.ingredients.count) item\(recipe.ingredients.count != 1 ? "s" : "")")
                }
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(recipe.caloriesPerPortion) cal")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("per portion")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecipeLogSheet: View {
    let recipe: Recipe
    @Binding var portions: Double
    let onLog: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(recipe.name)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)

                HStack(spacing: 14) {
                    macroPill("Cal", "\(Int(Double(recipe.caloriesPerPortion) * portions))", PepTheme.teal)
                    macroPill("P", "\(Int(recipe.proteinPerPortion * portions))g", PepTheme.teal)
                    macroPill("C", "\(Int(recipe.carbsPerPortion * portions))g", PepTheme.amber)
                    macroPill("F", "\(Int(recipe.fatPerPortion * portions))g", PepTheme.violet)
                }

                VStack(spacing: 8) {
                    Text("Portions to log")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    HStack(spacing: 18) {
                        Button {
                            if portions > 0.5 { portions -= 0.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text(String(format: "%.1f", portions))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 60)
                        Button {
                            portions += 0.5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(PepTheme.teal)
                        }
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(recipe.ingredients) { ing in
                            HStack {
                                Text(ing.name)
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textPrimary)
                                Spacer()
                                Text(String(format: "%.1fx · %d cal", ing.servings, ing.totalCalories))
                                    .font(.caption2)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 160)

                Button(action: onLog) {
                    Text("Log Recipe")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                }
            }
            .padding(20)
            .appBackground()
        }
    }

    private func macroPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 10))
    }
}

struct RecipeEditorView: View {
    let onSave: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var portions: Int = 1
    @State private var ingredients: [RecipeIngredient] = []
    @State private var showIngredientPicker: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name (e.g. Protein Pancakes)", text: $name)
                    Stepper("Makes \(portions) portion\(portions > 1 ? "s" : "")", value: $portions, in: 1...20)
                }

                Section {
                    if ingredients.isEmpty {
                        Text("No ingredients")
                            .foregroundStyle(PepTheme.textSecondary)
                    } else {
                        ForEach(ingredients) { ing in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.name)
                                    .font(.subheadline)
                                HStack(spacing: 8) {
                                    Text(String(format: "%.1fx", ing.servings))
                                    Text("·")
                                    Text("\(ing.totalCalories) cal")
                                    Text("·")
                                    Text("P:\(Int(ing.totalProtein))")
                                    Text("C:\(Int(ing.totalCarbs))")
                                    Text("F:\(Int(ing.totalFat))")
                                }
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                        .onDelete { ingredients.remove(atOffsets: $0) }
                    }

                    Button {
                        showIngredientPicker = true
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Ingredients (\(ingredients.count))")
                } footer: {
                    if !ingredients.isEmpty {
                        let total = ingredients.reduce(0) { $0 + $1.totalCalories }
                        Text("Total: \(total) cal · \(total / max(portions, 1)) per portion")
                    }
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let recipe = Recipe(name: name, portions: portions, ingredients: ingredients)
                        onSave(recipe)
                        dismiss()
                    }
                    .disabled(name.isEmpty || ingredients.isEmpty)
                }
            }
            .sheet(isPresented: $showIngredientPicker) {
                IngredientPickerSheet { ing in
                    ingredients.append(ing)
                }
            }
        }
    }
}

struct IngredientPickerSheet: View {
    let onPick: (RecipeIngredient) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    @State private var selectedFood: FoodItem? = nil
    @State private var servings: Double = 1.0

    private var filtered: [FoodItem] {
        guard !search.isEmpty else { return Array(FoodDatabase.allFoods.prefix(40)) }
        return FoodDatabase.allFoods.filter { $0.name.localizedStandardContains(search) || $0.brand.localizedStandardContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { food in
                    Button {
                        selectedFood = food
                        servings = 1.0
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(food.name).font(.subheadline)
                                Text("\(food.calories) cal · \(food.servingSize)")
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedFood) { food in
                FoodDetailSheet(
                    food: food,
                    servings: $servings,
                    onAdd: {
                        onPick(RecipeIngredient.from(food, servings: servings))
                        selectedFood = nil
                        dismiss()
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }
}
