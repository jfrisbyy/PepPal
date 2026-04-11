import SwiftUI
import PhotosUI
import AVFoundation

enum MealLogMode: Int, CaseIterable {
    case photo = 0
    case describe = 1
    case search = 2
    case quickAdd = 3

    var label: String {
        switch self {
        case .photo: return "Scan"
        case .describe: return "Describe"
        case .search: return "Search"
        case .quickAdd: return "Manual"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "camera.fill"
        case .describe: return "text.bubble.fill"
        case .search: return "magnifyingglass"
        case .quickAdd: return "square.and.pencil"
        }
    }
}

struct MealLogView: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: MealLogMode = .photo

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var isPhotoAnalyzing: Bool = false
    @State private var photoEstimatedItems: [EstimatedFoodItem] = []
    @State private var photoOverlays: [PhotoFoodOverlay] = []
    @State private var photoHasResult: Bool = false
    @State private var showCamera: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showClarifySheet: Bool = false
    @State private var selectedOverlayIndex: Int? = nil
    @State private var scanLineOffset: CGFloat = 0

    @State private var descriptionText: String = ""
    @State private var isDescribeAnalyzing: Bool = false
    @State private var describeEstimatedItems: [EstimatedFoodItem] = []
    @State private var describeHasResult: Bool = false
    @State private var describeError: String? = nil

    @State private var selectedFood: FoodItem? = nil
    @State private var foodServings: Double = 1.0

    @State private var quickName: String = ""
    @State private var quickCalories: String = ""
    @State private var quickProtein: String = ""
    @State private var quickCarbs: String = ""
    @State private var quickFat: String = ""

    var body: some View {
        ZStack(alignment: .top) {
            PepTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                modeSelector
                    .padding(.top, 4)
                tabPages
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            loadPhoto(from: newValue)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                capturedImage = image
                if let data = image.jpegData(compressionQuality: 0.7) {
                    analyzePhoto(data: data)
                }
            }
        }
        .sheet(isPresented: $showClarifySheet) {
            if let idx = selectedOverlayIndex, idx < photoEstimatedItems.count {
                ClarifyItemSheet(item: $photoEstimatedItems[idx])
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $selectedFood) { food in
            FoodDetailSheet(food: food, servings: $foodServings, onAdd: {
                viewModel.logMeal(food: food, servings: foodServings, mealTime: mealTime)
                selectedFood = nil
                foodServings = 1.0
                dismiss()
            })
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            #if !targetEnvironment(simulator)
            if capturedImage == nil && !photoHasResult {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showCamera = true
                }
            }
            #endif
        }
        .onChange(of: selectedMode) { _, _ in
            viewModel.searchText = ""
            viewModel.selectedCategory = nil
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(PepTheme.elevated)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 1) {
                Text("Log Meal")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(mealTime.rawValue)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(MealLogMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedMode = mode
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(mode.label)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selectedMode == mode ? PepTheme.teal : PepTheme.textSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedMode == mode
                            ? PepTheme.teal.opacity(0.12)
                            : Color.clear,
                        in: .rect(cornerRadius: 12)
                    )
                }
                .sensoryFeedback(.selection, trigger: selectedMode)
            }
        }
        .padding(.horizontal, 4)
        .padding(4)
        .background(PepTheme.elevated.opacity(0.6))
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Tab Pages

    private var tabPages: some View {
        TabView(selection: $selectedMode) {
            photoTab
                .tag(MealLogMode.photo)
            describeTab
                .tag(MealLogMode.describe)
            searchTab
                .tag(MealLogMode.search)
            quickAddTab
                .tag(MealLogMode.quickAdd)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: selectedMode)
    }

    // MARK: - Photo Tab

    private var photoTab: some View {
        Group {
            if capturedImage == nil {
                photoCaptureState
            } else if isPhotoAnalyzing {
                photoAnalyzingState
            } else if photoHasResult {
                photoResultState
            }
        }
    }

    private var photoCaptureState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                #if targetEnvironment(simulator)
                VStack(spacing: 14) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(PepTheme.teal.opacity(0.5))

                    Text("Camera Preview")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("Install this app on your device\nvia the Rork App to use the camera.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
                .padding(.horizontal, 24)
                #endif

                VStack(spacing: 10) {
                    Button {
                        #if !targetEnvironment(simulator)
                        showCamera = true
                        #endif
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Take Photo")
                                .font(.system(.body, weight: .semibold))
                        }
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(PepTheme.teal, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.scale)

                    Button {
                        showPhotoPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Choose from Library")
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(PepTheme.teal.opacity(0.1), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.scale)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    private var photoAnalyzingState: some View {
        VStack(spacing: 0) {
            if let image = capturedImage {
                ZStack {
                    Color(.secondarySystemBackground)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 16))

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [PepTheme.teal.opacity(0), PepTheme.teal.opacity(0.6), PepTheme.teal.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 3)
                        .offset(y: scanLineOffset)
                        .onAppear {
                            scanLineOffset = -120
                            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: true)) {
                                scanLineOffset = 120
                            }
                        }
                }
                .frame(height: 260)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(PepTheme.teal)
                    .scaleEffect(1.1)

                Text("Analyzing your meal...")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text("Identifying items & estimating nutrition")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()
        }
    }

    private var photoResultState: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let image = capturedImage {
                    photoWithOverlays(image: image)
                }

                nutritionSummaryCard(items: photoEstimatedItems)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Detected Items")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text("Tap to adjust")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                    .padding(.horizontal, 4)

                    ForEach(Array(photoEstimatedItems.enumerated()), id: \.element.id) { index, item in
                        Button {
                            selectedOverlayIndex = index
                            showClarifySheet = true
                        } label: {
                            estimatedItemRow(item: item, index: index, accent: PepTheme.teal)
                        }
                        .buttonStyle(.scale)
                    }
                }

                addAllButton(items: photoEstimatedItems)

                Button {
                    resetPhotoState()
                } label: {
                    Text("Retake Photo")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(PepTheme.elevated, in: .rect(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func photoWithOverlays(image: UIImage) -> some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)

                ForEach(Array(photoOverlays.enumerated()), id: \.element.id) { _, overlay in
                    let x = overlay.relativeX * geo.size.width
                    let y = overlay.relativeY * geo.size.height

                    overlayTag(item: overlay.item)
                        .position(
                            x: min(max(x, 60), geo.size.width - 60),
                            y: min(max(y, 20), geo.size.height - 20)
                        )
                }
            }
        }
        .frame(height: 240)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.teal.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func overlayTag(item: EstimatedFoodItem) -> some View {
        VStack(spacing: 2) {
            Text(item.name)
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(item.amount) · \(item.calories) cal")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(PepTheme.teal.opacity(0.85).background(.ultraThinMaterial))
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
    }

    // MARK: - Describe Tab

    private var describeTab: some View {
        ScrollView {
            VStack(spacing: 18) {
                if !describeHasResult {
                    describeInputSection
                } else {
                    describeResultSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private var describeInputSection: some View {
        VStack(spacing: 18) {
            TextEditor(text: $descriptionText)
                .font(.body)
                .foregroundStyle(PepTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100, maxHeight: 140)
                .padding(14)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    Group {
                        if descriptionText.isEmpty {
                            Text("Describe what you ate...\ne.g. \"Grilled chicken, rice, and a side salad\"")
                                .font(.body)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                                .padding(18)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )

            if let error = describeError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }

            Button {
                analyzeDescription()
            } label: {
                HStack(spacing: 10) {
                    if isDescribeAnalyzing {
                        ProgressView()
                            .tint(PepTheme.invertedText)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isDescribeAnalyzing ? "Analyzing..." : "Estimate Nutrition")
                        .font(.system(.body, weight: .semibold))
                }
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDescribeAnalyzing
                        ? PepTheme.elevated : PepTheme.violet,
                    in: .rect(cornerRadius: 12)
                )
            }
            .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDescribeAnalyzing)
            .sensoryFeedback(.impact(weight: .medium), trigger: isDescribeAnalyzing)

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick suggestions")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)

                let suggestions = [
                    "Chicken breast with rice and broccoli",
                    "Two slices of pepperoni pizza",
                    "Greek yogurt with granola and berries",
                    "Protein shake with banana and peanut butter"
                ]

                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            descriptionText = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(PepTheme.cardSurface)
                                .clipShape(.rect(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var describeResultSection: some View {
        VStack(spacing: 14) {
            nutritionSummaryCard(items: describeEstimatedItems)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Estimated Items")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                }

                ForEach(Array(describeEstimatedItems.enumerated()), id: \.element.id) { index, item in
                    estimatedItemRow(item: item, index: index, accent: PepTheme.violet)
                }
            }

            addAllButton(items: describeEstimatedItems)

            Button {
                describeHasResult = false
                describeEstimatedItems = []
            } label: {
                Text("Re-describe")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(PepTheme.elevated, in: .rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Search Tab

    private var searchTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)

                TextField("Search foods...", text: $viewModel.searchText)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .autocorrectionDisabled()

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            searchCategoryFilter

            if viewModel.filteredFoods.isEmpty {
                searchEmptyState
            } else {
                searchFoodList
            }
        }
    }

    private var searchCategoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                searchCategoryChip(label: "All", category: nil)
                ForEach(FoodCategory.allCases, id: \.rawValue) { category in
                    searchCategoryChip(label: category.rawValue, category: category)
                }
            }
            .padding(.vertical, 6)
        }
        .contentMargins(.horizontal, 16)
    }

    private func searchCategoryChip(label: String, category: FoodCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedCategory = category
            }
        } label: {
            Text(label)
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? PepTheme.teal : PepTheme.elevated.opacity(0.8))
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var searchFoodList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.filteredFoods) { food in
                    Button {
                        foodServings = 1.0
                        selectedFood = food
                    } label: {
                        searchFoodRow(food)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func searchFoodRow(_ food: FoodItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
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
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(food.calories)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                +
                Text(" cal")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)

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
        .padding(.vertical, 11)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var searchEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 40))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.3))
            Text("No foods found")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Text("Try a different search term")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Add Tab

    private var quickAddTab: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    quickField(label: "Name", text: $quickName, placeholder: "e.g. Lunch out", isNumeric: false)
                    quickField(label: "Calories", text: $quickCalories, placeholder: "500", isNumeric: true)

                    HStack(spacing: 10) {
                        quickField(label: "Protein (g)", text: $quickProtein, placeholder: "0", isNumeric: true)
                        quickField(label: "Carbs (g)", text: $quickCarbs, placeholder: "0", isNumeric: true)
                        quickField(label: "Fat (g)", text: $quickFat, placeholder: "0", isNumeric: true)
                    }
                }
                .padding(.top, 8)

                Button {
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
                    dismiss()
                } label: {
                    Text("Add Entry")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            quickCalories.isEmpty ? PepTheme.elevated : PepTheme.teal,
                            in: .rect(cornerRadius: 12)
                        )
                }
                .disabled(quickCalories.isEmpty)
                .sensoryFeedback(.impact(weight: .light), trigger: quickCalories)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func quickField(label: String, text: Binding<String>, placeholder: String, isNumeric: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)

            TextField(placeholder, text: text)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
                .keyboardType(isNumeric ? .decimalPad : .default)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Shared Components

    private func nutritionSummaryCard(items: [EstimatedFoodItem]) -> some View {
        let totalCal = items.reduce(0) { $0 + $1.calories }
        let totalP = items.reduce(0) { $0 + $1.protein }
        let totalC = items.reduce(0) { $0 + $1.carbs }
        let totalF = items.reduce(0) { $0 + $1.fat }

        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(totalCal)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
                Text("cal")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            dividerLine

            macroColumn(label: "Protein", value: Int(totalP), color: PepTheme.teal)
                .frame(maxWidth: .infinity)

            dividerLine

            macroColumn(label: "Carbs", value: Int(totalC), color: PepTheme.amber)
                .frame(maxWidth: .infinity)

            dividerLine

            macroColumn(label: "Fat", value: Int(totalF), color: PepTheme.violet)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.teal.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(PepTheme.glassBorderTop)
            .frame(width: 0.5, height: 32)
    }

    private func macroColumn(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)g")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func estimatedItemRow(item: EstimatedFoodItem, index: Int, accent: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 34, height: 34)
                Text("\(index + 1)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(item.amount)
                    Text("·")
                    Text("P:\(Int(item.protein))g")
                    Text("C:\(Int(item.carbs))g")
                    Text("F:\(Int(item.fat))g")
                }
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(item.calories)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("cal")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(11)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func addAllButton(items: [EstimatedFoodItem]) -> some View {
        Button {
            for item in items {
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
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Add to \(mealTime.rawValue)")
                    .font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(PepTheme.invertedText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(PepTheme.teal, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.scale)
        .sensoryFeedback(.success, trigger: items.count)
    }

    // MARK: - Actions

    private func loadPhoto(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { return }
            capturedImage = uiImage
            analyzePhoto(data: data)
        }
    }

    private func analyzePhoto(data: Data) {
        isPhotoAnalyzing = true
        scanLineOffset = -120

        let compressedData: Data
        if let image = UIImage(data: data),
           let jpeg = image.jpegData(compressionQuality: 0.7) {
            compressedData = jpeg
        } else {
            compressedData = data
        }

        Task {
            do {
                let (result, overlays) = try await NutritionAIService.shared.estimateFromPhoto(compressedData)
                photoEstimatedItems = result.items
                photoOverlays = overlays
                photoHasResult = true
            } catch {
                photoEstimatedItems = [
                    EstimatedFoodItem(name: "Estimated Meal", amount: "1 serving", calories: 500, protein: 25, carbs: 50, fat: 18)
                ]
                photoOverlays = [
                    PhotoFoodOverlay(item: photoEstimatedItems[0], relativeX: 0.5, relativeY: 0.5)
                ]
                photoHasResult = true
            }
            isPhotoAnalyzing = false
        }
    }

    private func analyzeDescription() {
        isDescribeAnalyzing = true
        describeError = nil

        Task {
            do {
                let result = try await NutritionAIService.shared.estimateFromDescription(descriptionText)
                describeEstimatedItems = result.items
                describeHasResult = true
            } catch {
                describeError = "Could not estimate nutrition. Please try again."
            }
            isDescribeAnalyzing = false
        }
    }

    private func resetPhotoState() {
        capturedImage = nil
        selectedPhoto = nil
        photoEstimatedItems = []
        photoOverlays = []
        photoHasResult = false
    }
}


