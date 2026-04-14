import SwiftUI
import PhotosUI
import AVFoundation

struct CameraMealLogView: View {
    let mealTime: MealTime
    @Bindable var viewModel: NutritionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: MealLogMode = .scan
    @State private var capturedImage: UIImage? = nil
    @State private var isAnalyzing: Bool = false
    @State private var estimatedItems: [EstimatedFoodItem] = []
    @State private var overlays: [PhotoFoodOverlay] = []
    @State private var hasResult: Bool = false
    @State private var scanLineOffset: CGFloat = -150
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showClarifySheet: Bool = false
    @State private var selectedOverlayIndex: Int? = nil
    @State private var shutterScale: CGFloat = 1.0

    private enum MealLogMode: String, CaseIterable {
        case manual = "Manual"
        case search = "Search"
        case scan = "Scan"
        case describe = "Describe"

        var index: Int {
            switch self {
            case .manual: 0
            case .search: 1
            case .scan: 2
            case .describe: 3
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if capturedImage != nil && (isAnalyzing || hasResult) {
                capturedImageFlow
            } else {
                liveCameraFlow
            }
        }
        .statusBarHidden(true)
        .photosPicker(isPresented: Binding(
            get: { false },
            set: { _ in }
        ), selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            loadImage(from: newValue)
        }
        .sheet(isPresented: $showClarifySheet) {
            if let idx = selectedOverlayIndex, idx < estimatedItems.count {
                ClarifyItemSheet(item: $estimatedItems[idx])
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Live Camera Flow

    private var liveCameraFlow: some View {
        ZStack {
            cameraPreview
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()

                if selectedMode != .scan {
                    overlayPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                bottomControls
            }
        }
    }

    @State private var cameraManager = CameraSessionManager()

    private var cameraPreview: some View {
        Group {
            #if targetEnvironment(simulator)
            simulatorPlaceholder
            #else
            if AVCaptureDevice.default(for: .video) != nil {
                LiveCameraPreview(session: cameraManager.session)
                    .onAppear {
                        cameraManager.configure()
                        cameraManager.start()
                    }
                    .onDisappear {
                        cameraManager.stop()
                    }
            } else {
                simulatorPlaceholder
            }
            #endif
        }
    }

    private var simulatorPlaceholder: some View {
        ZStack {
            Color(white: 0.08)

            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.2))
                Text("Camera Preview")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Install on your device\nvia the Rork App to use the camera.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.2))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            Text(mealTime.rawValue)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            if selectedMode == .scan {
                scanControls
            }

            modeStrip
        }
        .padding(.bottom, 20)
    }

    private var scanControls: some View {
        HStack(alignment: .center) {
            galleryButton
                .frame(maxWidth: .infinity)

            shutterButton

            Color.clear
                .frame(width: 44, height: 44)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
    }

    private var galleryButton: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var shutterButton: some View {
        Button {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                shutterScale = 0.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    shutterScale = 1.0
                }
                captureFromCamera()
            }
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
        .sensoryFeedback(.impact(weight: .medium), trigger: shutterScale)
    }

    // MARK: - Mode Strip

    private var modeStrip: some View {
        HStack(spacing: 24) {
            ForEach(MealLogMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.rawValue.uppercased())
                        .font(.system(size: 13, weight: selectedMode == mode ? .bold : .medium))
                        .foregroundStyle(selectedMode == mode ? PepTheme.amber : .white.opacity(0.45))
                        .animation(.easeOut(duration: 0.2), value: selectedMode)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            Capsule()
                .fill(.black.opacity(0.5))
                .background(.ultraThinMaterial.opacity(0.3))
                .clipShape(Capsule())
        )
        .sensoryFeedback(.selection, trigger: selectedMode)
    }

    // MARK: - Overlay Panels

    private var overlayPanel: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            Group {
                switch selectedMode {
                case .describe: describePanel
                case .search: searchPanel
                case .manual: manualPanel
                case .scan: EmptyView()
                }
            }
            .padding(.bottom, 8)
        }
        .background(
            Color.black.opacity(0.85)
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadii: .init(topLeading: 24, topTrailing: 24)))
        )
    }

    // MARK: - Describe Panel

    @State private var descriptionText: String = ""
    @State private var isDescribing: Bool = false

    private var describePanel: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "text.bubble.fill")
                    .foregroundStyle(PepTheme.violet)
                Text("Describe what you ate")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                TextField("e.g. grilled chicken with rice and broccoli", text: $descriptionText, axis: .vertical)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 12))
                    .tint(PepTheme.violet)

                Button {
                    analyzeDescription()
                } label: {
                    Group {
                        if isDescribing {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .foregroundStyle(descriptionText.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.2) : PepTheme.violet)
                }
                .disabled(descriptionText.trimmingCharacters(in: .whitespaces).isEmpty || isDescribing)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    describeChip("chicken and rice")
                    describeChip("protein shake")
                    describeChip("salad with dressing")
                    describeChip("oatmeal with banana")
                }
            }
            .contentMargins(.horizontal, 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func describeChip(_ text: String) -> some View {
        Button {
            descriptionText = text
        } label: {
            Text(text)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.08))
                .clipShape(Capsule())
        }
    }

    // MARK: - Search Panel

    @State private var searchText: String = ""

    private var searchPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search foods...", text: $searchText)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(PepTheme.teal)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08))
            .clipShape(.rect(cornerRadius: 12))
            .padding(.horizontal, 20)

            let filtered = searchResults
            if filtered.isEmpty && !searchText.isEmpty {
                Text("No results found")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered.prefix(8)) { food in
                            Button {
                                logFoodDirectly(food)
                            } label: {
                                searchFoodRow(food)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(.bottom, 8)
    }

    private var searchResults: [FoodItem] {
        guard !searchText.isEmpty else { return Array(FoodDatabase.allFoods.prefix(8)) }
        return FoodDatabase.allFoods.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.brand.localizedStandardContains(searchText)
        }
    }

    private func searchFoodRow(_ food: FoodItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(food.calories) cal · P:\(Int(food.protein))g C:\(Int(food.carbs))g F:\(Int(food.fat))g")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(PepTheme.teal)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func logFoodDirectly(_ food: FoodItem) {
        viewModel.logMeal(food: food, servings: 1.0, mealTime: mealTime)
        dismiss()
    }

    // MARK: - Manual Panel

    @State private var manualName: String = ""
    @State private var manualCalories: String = ""
    @State private var manualProtein: String = ""
    @State private var manualCarbs: String = ""
    @State private var manualFat: String = ""

    private var manualPanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(PepTheme.teal)
                Text("Quick Add")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
            }

            manualField(label: "Name", text: $manualName, placeholder: "e.g. Lunch out", keyboard: .default)
            manualField(label: "Calories *", text: $manualCalories, placeholder: "500", keyboard: .numberPad)

            HStack(spacing: 10) {
                manualField(label: "Protein", text: $manualProtein, placeholder: "0g", keyboard: .decimalPad)
                manualField(label: "Carbs", text: $manualCarbs, placeholder: "0g", keyboard: .decimalPad)
                manualField(label: "Fat", text: $manualFat, placeholder: "0g", keyboard: .decimalPad)
            }

            Button {
                let cal = Int(manualCalories) ?? 0
                guard cal > 0 else { return }
                viewModel.quickAddMeal(
                    name: manualName,
                    calories: cal,
                    protein: Double(manualProtein) ?? 0,
                    carbs: Double(manualCarbs) ?? 0,
                    fat: Double(manualFat) ?? 0,
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
                        manualCalories.isEmpty ? .white.opacity(0.15) : PepTheme.teal,
                        in: .rect(cornerRadius: 12)
                    )
            }
            .disabled(manualCalories.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func manualField(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            TextField(placeholder, text: text)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.white)
                .keyboardType(keyboard)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
                .tint(PepTheme.teal)
        }
    }

    // MARK: - Captured Image Flow

    private var capturedImageFlow: some View {
        ZStack {
            if isAnalyzing {
                analyzingView
            } else if hasResult {
                resultView
            }
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 0) {
            if let image = capturedImage {
                ZStack {
                    Color.black
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
                                colors: [PepTheme.amber.opacity(0), PepTheme.amber.opacity(0.6), PepTheme.amber.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 3)
                        .offset(y: scanLineOffset)
                        .onAppear {
                            scanLineOffset = -150
                            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                                scanLineOffset = 150
                            }
                        }
                }
                .frame(height: 340)
                .padding(.horizontal, 16)
                .padding(.top, 60)
            }

            Spacer()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(PepTheme.amber)
                    .scaleEffect(1.2)
                Text("Analyzing your meal...")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Identifying food items and estimating nutrition")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()
        }
    }

    private var resultView: some View {
        NutritionResultView(
            capturedImage: capturedImage!,
            estimatedItems: $estimatedItems,
            overlays: overlays,
            mealTime: mealTime,
            onAddAll: {
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
            },
            onRetake: {
                resetCapture()
            },
            onDismiss: {
                dismiss()
            },
            onSaveMeal: { name, cal, pro, carbs, fat in
                let meal = SavedMeal(
                    name: name,
                    calories: cal,
                    protein: pro,
                    carbs: carbs,
                    fat: fat
                )
                viewModel.saveMeal(meal)
            }
        )
    }

    // MARK: - Actions

    private func captureFromCamera() {
        #if targetEnvironment(simulator)
        return
        #else
        cameraManager.capturePhoto { image in
            Task { @MainActor in
                guard let image else { return }
                capturedImage = image
                if let data = image.jpegData(compressionQuality: 0.7) {
                    analyzePhoto(data: data)
                }
            }
        }
        #endif
    }

    private func loadImage(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { return }
            capturedImage = uiImage
            analyzePhoto(data: data)
        }
    }

    private func analyzePhoto(data: Data) {
        isAnalyzing = true
        scanLineOffset = -150

        let compressedData: Data
        if let image = UIImage(data: data),
           let jpeg = image.jpegData(compressionQuality: 0.7) {
            compressedData = jpeg
        } else {
            compressedData = data
        }

        Task {
            do {
                let (result, photoOverlays) = try await NutritionAIService.shared.estimateFromPhoto(compressedData)
                estimatedItems = result.items
                overlays = photoOverlays
                hasResult = true
            } catch {
                estimatedItems = [
                    EstimatedFoodItem(name: "Estimated Meal", amount: "1 serving", calories: 500, protein: 25, carbs: 50, fat: 18)
                ]
                overlays = [
                    PhotoFoodOverlay(item: estimatedItems[0], relativeX: 0.5, relativeY: 0.5)
                ]
                hasResult = true
            }
            isAnalyzing = false
        }
    }

    private func analyzeDescription() {
        let text = descriptionText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isDescribing = true

        Task {
            do {
                let result = try await NutritionAIService.shared.estimateFromDescription(text)
                for item in result.items {
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
            } catch {
                isDescribing = false
            }
        }
    }

    private func resetCapture() {
        capturedImage = nil
        selectedPhoto = nil
        estimatedItems = []
        overlays = []
        hasResult = false
        isAnalyzing = false
    }
}
