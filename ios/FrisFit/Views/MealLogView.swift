import SwiftUI
import PhotosUI
import AVFoundation
import Photos

enum MealLogMode: Int, CaseIterable {
    case scan = 0
    case describe = 1
    case search = 2
    case manual = 3

    var label: String {
        switch self {
        case .scan: return "SCAN"
        case .describe: return "DESCRIBE"
        case .search: return "SEARCH"
        case .manual: return "MANUAL"
        }
    }
}

struct MealLogView: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: MealLogMode = .scan
    @State private var cameraManager = CameraSessionManager()
    @State private var galleryThumbnail: UIImage? = nil

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var isPhotoAnalyzing: Bool = false
    @State private var photoEstimatedItems: [EstimatedFoodItem] = []
    @State private var photoOverlays: [PhotoFoodOverlay] = []
    @State private var photoHasResult: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showClarifySheet: Bool = false
    @State private var selectedOverlayIndex: Int? = nil
    @State private var scanLineOffset: CGFloat = -120

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

    @State private var shutterScale: CGFloat = 1.0

    private var isScanMode: Bool { selectedMode == .scan }
    private var showsCapturedPhoto: Bool { capturedImage != nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            cameraLayer
                .ignoresSafeArea()

            if showsCapturedPhoto {
                capturedPhotoLayer
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topBar
                Spacer()

                if !showsCapturedPhoto {
                    if !isScanMode {
                        overlayPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    bottomControls
                        .padding(.bottom, 8)
                } else if isPhotoAnalyzing {
                    analyzingOverlay
                } else if photoHasResult {
                    resultSheet
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: showsCapturedPhoto)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: photoHasResult)
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            loadPhoto(from: newValue)
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
            loadGalleryThumbnail()
            #if !targetEnvironment(simulator)
            Task.detached {
                cameraManager.configure()
                cameraManager.start()
            }
            #endif
        }
        .onDisappear {
            #if !targetEnvironment(simulator)
            cameraManager.stop()
            #endif
        }
        .onChange(of: selectedMode) { _, _ in
            viewModel.searchText = ""
            viewModel.selectedCategory = nil
        }
        .statusBarHidden(true)
    }

    // MARK: - Camera Layer

    private var cameraLayer: some View {
        Group {
            #if targetEnvironment(simulator)
            ZStack {
                Color(white: 0.08)
                VStack(spacing: 14) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Camera Preview")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Install on your device\nvia the Rork App to use camera")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                }
            }
            #else
            LiveCameraPreview(session: cameraManager.session)
            #endif
        }
    }

    private var capturedPhotoLayer: some View {
        Group {
            if let image = capturedImage {
                Color.black
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipped()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                if showsCapturedPhoto && !isPhotoAnalyzing {
                    resetPhotoState()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: showsCapturedPhoto ? "chevron.left" : "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 1) {
                Text("Log Meal")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(mealTime.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if showsCapturedPhoto {
                Button {
                    resetPhotoState()
                } label: {
                    Text("Retake")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 8))
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Bottom Controls (Scan Mode)

    private var bottomControls: some View {
        VStack(spacing: 16) {
            if isScanMode {
                HStack(alignment: .bottom) {
                    galleryButton
                    Spacer()
                    shutterButton
                    Spacer()
                    Color.clear.frame(width: 50, height: 50)
                }
                .padding(.horizontal, 32)
            }

            modeStrip
        }
    }

    private var galleryButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            Group {
                if let thumb = galleryThumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
            )
        }
    }

    private var shutterButton: some View {
        Button {
            capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
            }
            .scaleEffect(shutterScale)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: capturedImage != nil)
    }

    // MARK: - Mode Strip

    private var modeStrip: some View {
        HStack(spacing: 24) {
            ForEach(MealLogMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.label)
                        .font(.system(size: 13, weight: selectedMode == mode ? .bold : .medium))
                        .foregroundStyle(selectedMode == mode ? .white : .white.opacity(0.45))
                        .scaleEffect(selectedMode == mode ? 1.0 : 0.92)
                }
                .sensoryFeedback(.selection, trigger: selectedMode)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            Capsule()
                .fill(.black.opacity(0.35))
                .background(.ultraThinMaterial.opacity(0.3))
                .clipShape(Capsule())
        )
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    let currentIndex = selectedMode.rawValue
                    if value.translation.width < -30, currentIndex < MealLogMode.allCases.count - 1 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedMode = MealLogMode(rawValue: currentIndex + 1) ?? selectedMode
                        }
                    } else if value.translation.width > 30, currentIndex > 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedMode = MealLogMode(rawValue: currentIndex - 1) ?? selectedMode
                        }
                    }
                }
        )
    }

    // MARK: - Overlay Panels

    private var overlayPanel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Group {
                switch selectedMode {
                case .describe:
                    describePanel
                case .search:
                    searchPanel
                case .manual:
                    manualPanel
                case .scan:
                    EmptyView()
                }
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.52)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .shadow(color: .black.opacity(0.3), radius: 20, y: -5)
        )
        .clipShape(.rect(cornerRadius: 24))
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    // MARK: - Describe Panel

    private var describePanel: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !describeHasResult {
                    describeInputContent
                } else {
                    describeResultContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var describeInputContent: some View {
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

            if let error = describeError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(10)
                .background(.orange.opacity(0.15))
                .clipShape(.rect(cornerRadius: 8))
            }

            Button {
                analyzeDescription()
            } label: {
                HStack(spacing: 10) {
                    if isDescribeAnalyzing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isDescribeAnalyzing ? "Analyzing..." : "Estimate Nutrition")
                        .font(.system(.body, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDescribeAnalyzing
                        ? Color.white.opacity(0.2) : Color.white,
                    in: .rect(cornerRadius: 12)
                )
            }
            .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDescribeAnalyzing)
            .sensoryFeedback(.impact(weight: .medium), trigger: isDescribeAnalyzing)

            let suggestions = [
                "Chicken breast with rice and broccoli",
                "Two slices of pepperoni pizza",
                "Greek yogurt with granola",
                "Protein shake with banana"
            ]

            FlowLayout(spacing: 6) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        descriptionText = suggestion
                    } label: {
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

    private var describeResultContent: some View {
        VStack(spacing: 12) {
            nutritionSummaryCard(items: describeEstimatedItems)

            ForEach(Array(describeEstimatedItems.enumerated()), id: \.element.id) { index, item in
                estimatedItemRow(item: item, index: index, accent: PepTheme.violet)
            }

            addAllButton(items: describeEstimatedItems)

            Button {
                describeHasResult = false
                describeEstimatedItems = []
            } label: {
                Text("Re-describe")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Search Panel

    private var searchPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                TextField("Search foods...", text: $viewModel.searchText)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
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

            searchCategoryFilter

            if viewModel.filteredFoods.isEmpty {
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
            } else {
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
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
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
                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : .white.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    private func searchFoodRow(_ food: FoodItem) -> some View {
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

    // MARK: - Manual Panel

    private var manualPanel: some View {
        ScrollView {
            VStack(spacing: 14) {
                manualField(label: "Name", text: $quickName, placeholder: "e.g. Lunch out", isNumeric: false)
                manualField(label: "Calories", text: $quickCalories, placeholder: "500", isNumeric: true)

                HStack(spacing: 10) {
                    manualField(label: "Protein (g)", text: $quickProtein, placeholder: "0", isNumeric: true)
                    manualField(label: "Carbs (g)", text: $quickCarbs, placeholder: "0", isNumeric: true)
                    manualField(label: "Fat (g)", text: $quickFat, placeholder: "0", isNumeric: true)
                }

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
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func manualField(label: String, text: Binding<String>, placeholder: String, isNumeric: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            TextField(placeholder, text: text)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.white)
                .keyboardType(isNumeric ? .decimalPad : .default)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    // MARK: - Analyzing Overlay

    private var analyzingOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [PepTheme.teal.opacity(0), PepTheme.teal.opacity(0.7), PepTheme.teal.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 3)
                        .offset(y: scanLineOffset)
                        .onAppear {
                            scanLineOffset = -100
                            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: true)) {
                                scanLineOffset = 100
                            }
                        }
                }
                .frame(height: 200)
                .clipped()

                VStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.1)
                    Text("Analyzing your meal...")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Identifying items & estimating nutrition")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Result Sheet

    private var resultSheet: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 12) {
                        if let image = capturedImage {
                            photoWithOverlays(image: image)
                        }

                        nutritionSummaryCard(items: photoEstimatedItems)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Detected Items")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("Tap to adjust")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.3))
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
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.08), in: .rect(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .clipShape(.rect(cornerRadius: 24))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Shared Components

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
        .frame(height: 200)
        .clipShape(.rect(cornerRadius: 14))
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

    private func nutritionSummaryCard(items: [EstimatedFoodItem]) -> some View {
        let totalCal = items.reduce(0) { $0 + $1.calories }
        let totalP = items.reduce(0) { $0 + $1.protein }
        let totalC = items.reduce(0) { $0 + $1.carbs }
        let totalF = items.reduce(0) { $0 + $1.fat }

        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(totalCal)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
                Text("cal")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
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
        .padding(.vertical, 12)
        .background(.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(width: 0.5, height: 30)
    }

    private func macroColumn(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)g")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func estimatedItemRow(item: EstimatedFoodItem, index: Int, accent: Color) -> some View {
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
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(PepTheme.teal, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.scale)
        .sensoryFeedback(.success, trigger: items.count)
    }

    // MARK: - Actions

    private func capturePhoto() {
        withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
            shutterScale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                shutterScale = 1.0
            }
        }

        #if targetEnvironment(simulator)
        return
        #else
        cameraManager.capturePhoto { [self] image in
            Task { @MainActor in
                guard let image else { return }
                capturedImage = image
                cameraManager.stop()
                if let data = image.jpegData(compressionQuality: 0.7) {
                    analyzePhoto(data: data)
                }
            }
        }
        #endif
    }

    private func loadPhoto(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { return }
            capturedImage = uiImage
            #if !targetEnvironment(simulator)
            cameraManager.stop()
            #endif
            analyzePhoto(data: data)
        }
    }

    private func analyzePhoto(data: Data) {
        isPhotoAnalyzing = true
        scanLineOffset = -100

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
        isPhotoAnalyzing = false
        scanLineOffset = -100
        #if !targetEnvironment(simulator)
        cameraManager.start()
        #endif
    }

    private func loadGalleryThumbnail() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let asset = assets.firstObject else { return }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 100, height: 100),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            Task { @MainActor in
                galleryThumbnail = image
            }
        }
    }
}
