import SwiftUI
import PhotosUI
import AVFoundation

enum MealLogMode: Int, CaseIterable {
    case photo = 0
    case describe = 1
    case quickAdd = 2

    var label: String {
        switch self {
        case .photo: return "Photo"
        case .describe: return "Describe"
        case .quickAdd: return "Quick Add"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "camera.fill"
        case .describe: return "text.bubble.fill"
        case .quickAdd: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .photo: return FrisTheme.amber
        case .describe: return FrisTheme.violet
        case .quickAdd: return FrisTheme.cyan
        }
    }
}

struct MealLogView: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: MealLogMode = .photo

    var body: some View {
        ZStack(alignment: .top) {
            FrisTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                modeSelector
                tabContent
            }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FrisTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(FrisTheme.elevated)
                    .clipShape(Circle())
            }

            Spacer()

            Text("Log \(mealTime.rawValue)")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(FrisTheme.textPrimary)

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var modeSelector: some View {
        HStack(spacing: 4) {
            ForEach(MealLogMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(mode.label)
                            .font(.system(.caption, weight: .semibold))
                    }
                    .foregroundStyle(selectedMode == mode ? FrisTheme.invertedText : FrisTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedMode == mode ? mode.color : Color.clear,
                        in: .rect(cornerRadius: 10)
                    )
                }
                .sensoryFeedback(.selection, trigger: selectedMode)
            }
        }
        .padding(4)
        .background(FrisTheme.elevated)
        .clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var tabContent: some View {
        TabView(selection: $selectedMode) {
            PhotoMealTab(viewModel: viewModel, mealTime: mealTime, dismissParent: { dismiss() })
                .tag(MealLogMode.photo)

            DescribeMealTab(viewModel: viewModel, mealTime: mealTime, dismissParent: { dismiss() })
                .tag(MealLogMode.describe)

            QuickAddTab(viewModel: viewModel, mealTime: mealTime, dismissParent: { dismiss() })
                .tag(MealLogMode.quickAdd)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedMode)
    }
}

struct PhotoMealTab: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    let dismissParent: () -> Void
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var isAnalyzing: Bool = false
    @State private var estimatedItems: [EstimatedFoodItem] = []
    @State private var overlays: [PhotoFoodOverlay] = []
    @State private var hasResult: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var showClarifySheet: Bool = false
    @State private var selectedOverlayIndex: Int? = nil
    @State private var scanLineOffset: CGFloat = 0

    var body: some View {
        Group {
            if capturedImage == nil {
                captureState
            } else if isAnalyzing {
                analyzingState
            } else if hasResult {
                resultState
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            loadImage(from: newValue)
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
            if let idx = selectedOverlayIndex, idx < estimatedItems.count {
                ClarifyItemSheet(item: $estimatedItems[idx])
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            #if targetEnvironment(simulator)
            #else
            if capturedImage == nil && !hasResult {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showCamera = true
                }
            }
            #endif
        }
    }

    private var captureState: some View {
        VStack(spacing: 24) {
            Spacer()

            #if targetEnvironment(simulator)
            VStack(spacing: 16) {
                Image(systemName: "camera.badge.ellipsis")
                    .font(.system(size: 44))
                    .foregroundStyle(FrisTheme.textSecondary)

                Text("Camera Preview")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)

                Text("Install this app on your device\nvia the Rork App to use the camera.")
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(FrisTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
            )
            .padding(.horizontal, 24)
            #endif

            VStack(spacing: 12) {
                Button {
                    #if targetEnvironment(simulator)
                    #else
                    showCamera = true
                    #endif
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                            .font(.system(.body, weight: .semibold))
                    }
                    .foregroundStyle(FrisTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FrisTheme.amber, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scale)

                Button {
                    showPhotoPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Choose from Library")
                            .font(.system(.body, weight: .semibold))
                    }
                    .foregroundStyle(FrisTheme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FrisTheme.amber.opacity(0.12), in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scale)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var analyzingState: some View {
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
                                colors: [FrisTheme.amber.opacity(0), FrisTheme.amber.opacity(0.6), FrisTheme.amber.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 3)
                        .offset(y: scanLineOffset)
                        .onAppear {
                            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                                scanLineOffset = 120
                            }
                        }
                }
                .frame(height: 280)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(FrisTheme.amber)
                    .scaleEffect(1.2)

                Text("Analyzing your meal...")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)

                Text("Identifying food items and estimating nutrition")
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()
        }
    }

    private var resultState: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = capturedImage {
                    photoWithOverlays(image: image)
                }

                totalSummaryCard

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Detected Items")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Spacer()
                        Text("Tap to adjust")
                            .font(.caption2)
                            .foregroundStyle(FrisTheme.textSecondary.opacity(0.6))
                    }
                    .padding(.horizontal, 4)

                    ForEach(Array(estimatedItems.enumerated()), id: \.element.id) { index, item in
                        Button {
                            selectedOverlayIndex = index
                            showClarifySheet = true
                        } label: {
                            detectedItemRow(item: item, index: index)
                        }
                        .buttonStyle(.scale)
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
                        .foregroundStyle(FrisTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FrisTheme.cyan, in: .rect(cornerRadius: 12))
                    }

                    Button {
                        resetState()
                    } label: {
                        Text("Try Another Photo")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(FrisTheme.amber)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FrisTheme.amber.opacity(0.12), in: .rect(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
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

                ForEach(Array(overlays.enumerated()), id: \.element.id) { index, overlay in
                    let x = overlay.relativeX * geo.size.width
                    let y = overlay.relativeY * geo.size.height

                    overlayTag(item: overlay.item)
                        .position(x: min(max(x, 60), geo.size.width - 60), y: min(max(y, 20), geo.size.height - 20))
                }
            }
        }
        .frame(height: 260)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(FrisTheme.amber.opacity(0.2), lineWidth: 0.5)
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
        .background(FrisTheme.amber.opacity(0.85).background(.ultraThinMaterial))
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
    }

    private var totalSummaryCard: some View {
        let totalCal = estimatedItems.reduce(0) { $0 + $1.calories }
        let totalP = estimatedItems.reduce(0) { $0 + $1.protein }
        let totalC = estimatedItems.reduce(0) { $0 + $1.carbs }
        let totalF = estimatedItems.reduce(0) { $0 + $1.fat }

        return HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(totalCal)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(FrisTheme.cyan)
                Text("total cal")
                    .font(.caption2)
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            Spacer()
            HStack(spacing: 14) {
                miniMacro(label: "Protein", value: Int(totalP), color: FrisTheme.cyan)
                miniMacro(label: "Carbs", value: Int(totalC), color: FrisTheme.amber)
                miniMacro(label: "Fat", value: Int(totalF), color: FrisTheme.violet)
            }
        }
        .padding(14)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(FrisTheme.cyan.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func miniMacro(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)g")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
    }

    private func detectedItemRow(item: EstimatedFoodItem, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(FrisTheme.amber.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(index + 1)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(FrisTheme.amber)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(FrisTheme.textPrimary)
                HStack(spacing: 6) {
                    Text(item.amount)
                    Text("·")
                    Text("P:\(Int(item.protein))g")
                    Text("C:\(Int(item.carbs))g")
                    Text("F:\(Int(item.fat))g")
                }
                .font(.caption2)
                .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(item.calories)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text("cal")
                    .font(.caption2)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Image(systemName: "pencil.circle.fill")
                .font(.body)
                .foregroundStyle(FrisTheme.textSecondary.opacity(0.4))
        }
        .padding(12)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
        )
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
        dismissParent()
    }

    private func resetState() {
        capturedImage = nil
        selectedPhoto = nil
        estimatedItems = []
        overlays = []
        hasResult = false
    }
}

struct DescribeMealTab: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    let dismissParent: () -> Void
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
        ScrollView {
            VStack(spacing: 20) {
                if !hasResult {
                    inputSection
                } else {
                    resultSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var inputSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(FrisTheme.violet.opacity(0.12))
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulseAnimation ? 1.08 : 1.0)

                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(FrisTheme.violet)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseAnimation = true
                    }
                }

                Text("Describe What You Ate")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(FrisTheme.textPrimary)

                Text("AI will estimate the calories and macros")
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $description)
                    .font(.body)
                    .foregroundStyle(FrisTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(14)
                    .background(FrisTheme.elevated)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
                    )

                Text("e.g. \"Two scrambled eggs, toast with butter, and orange juice\"")
                    .font(.caption2)
                    .foregroundStyle(FrisTheme.textSecondary.opacity(0.6))
                    .padding(.horizontal, 4)
            }

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
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
                            .tint(FrisTheme.invertedText)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isAnalyzing ? "Analyzing..." : "Estimate Nutrition")
                        .font(.system(.body, weight: .semibold))
                }
                .foregroundStyle(FrisTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing
                        ? FrisTheme.elevated : FrisTheme.violet,
                    in: .rect(cornerRadius: 12)
                )
            }
            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)

            quickSuggestions
        }
    }

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick suggestions")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)

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
                            .foregroundStyle(FrisTheme.violet.opacity(0.6))
                        Text(suggestion)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(FrisTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(FrisTheme.cardSurface)
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
                        .foregroundStyle(FrisTheme.cyan)
                    Text("calories")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                Spacer()
                HStack(spacing: 16) {
                    resultMacro(label: "Protein", value: Int(totalProtein), color: FrisTheme.cyan)
                    resultMacro(label: "Carbs", value: Int(totalCarbs), color: FrisTheme.amber)
                    resultMacro(label: "Fat", value: Int(totalFat), color: FrisTheme.violet)
                }
            }
            .padding(16)
            .background(FrisTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 12) {
                Text("Estimated Items")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)

                ForEach($estimatedItems) { $item in
                    describeItemRow(item: $item)
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
                    .foregroundStyle(FrisTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FrisTheme.cyan, in: .rect(cornerRadius: 12))
                }

                Button {
                    hasResult = false
                    estimatedItems = []
                } label: {
                    Text("Re-describe")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(FrisTheme.violet)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(FrisTheme.violet.opacity(0.12), in: .rect(cornerRadius: 10))
                }
            }
        }
    }

    private func resultMacro(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)g")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(FrisTheme.textSecondary)
        }
    }

    private func describeItemRow(item: Binding<EstimatedFoodItem>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.wrappedValue.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text(item.wrappedValue.amount)
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            VStack(spacing: 1) {
                TextField("", value: item.calories, format: .number)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(FrisTheme.textPrimary)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 54)
                Text("cal")
                    .font(.caption2)
                    .foregroundStyle(FrisTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
        )
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
        dismissParent()
    }
}

struct QuickAddTab: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    let dismissParent: () -> Void
    @State private var name: String = ""
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(FrisTheme.cyan.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(FrisTheme.cyan)
                    }

                    Text("Quick Add")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(FrisTheme.textPrimary)

                    Text("Manually enter calories & macros")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                .padding(.top, 8)

                VStack(spacing: 14) {
                    quickField(label: "Name (optional)", text: $name, placeholder: "e.g. Lunch out")
                    quickField(label: "Calories *", text: $caloriesText, placeholder: "e.g. 500")
                    HStack(spacing: 12) {
                        quickField(label: "Protein (g)", text: $proteinText, placeholder: "0")
                        quickField(label: "Carbs (g)", text: $carbsText, placeholder: "0")
                        quickField(label: "Fat (g)", text: $fatText, placeholder: "0")
                    }
                }

                Button {
                    let cal = Int(caloriesText) ?? 0
                    guard cal > 0 else { return }
                    viewModel.quickAddMeal(
                        name: name,
                        calories: cal,
                        protein: Double(proteinText) ?? 0,
                        carbs: Double(carbsText) ?? 0,
                        fat: Double(fatText) ?? 0,
                        mealTime: mealTime
                    )
                    dismissParent()
                } label: {
                    Text("Add Entry")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(FrisTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            (caloriesText.isEmpty ? FrisTheme.elevated : FrisTheme.cyan),
                            in: .rect(cornerRadius: 12)
                        )
                }
                .disabled(caloriesText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func quickField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(FrisTheme.textSecondary)
            TextField(placeholder, text: text)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(FrisTheme.textPrimary)
                .keyboardType(label.contains("Name") ? .default : .decimalPad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FrisTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}
