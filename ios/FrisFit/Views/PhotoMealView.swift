import SwiftUI
import PhotosUI
import AVFoundation

struct PhotoMealView: View {
    @Bindable var viewModel: NutritionViewModel
    let mealTime: MealTime
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var isAnalyzing: Bool = false
    @State private var estimatedItems: [EstimatedFoodItem] = []
    @State private var overlays: [PhotoFoodOverlay] = []
    @State private var hasResult: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showPhotoPicker: Bool = false
    @State private var showClarifySheet: Bool = false
    @State private var selectedOverlayIndex: Int? = nil
    @State private var scanLineOffset: CGFloat = 0
    @State private var showCamera: Bool = false
    @State private var sourceSelection: SourceSelection? = nil

    private enum SourceSelection {
        case camera
        case library
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FrisTheme.background.ignoresSafeArea()

                if capturedImage == nil {
                    pickSourceState
                } else if isAnalyzing {
                    analyzingState
                } else if hasResult {
                    resultState
                }
            }
            .navigationTitle("Photo Meal")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FrisTheme.textSecondary)
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
        }
    }

    private var pickSourceState: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(FrisTheme.amber.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(FrisTheme.amber)
                }

                Text("Add a Food Photo")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(FrisTheme.textPrimary)

                Text("Take a photo or choose from your library\nand AI will estimate the calories")
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    #if targetEnvironment(simulator)
                    sourceSelection = .camera
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
            .padding(.horizontal, 40)

            #if targetEnvironment(simulator)
            if sourceSelection == .camera {
                cameraUnavailablePlaceholder
                    .transition(.opacity)
            }
            #endif

            Spacer()
        }
    }

    #if targetEnvironment(simulator)
    private var cameraUnavailablePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 28))
                .foregroundStyle(FrisTheme.textSecondary)

            Text("Camera Preview")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(FrisTheme.textPrimary)

            Text("Install this app on your device\nvia the Rork App to use the camera.")
                .font(.caption)
                .foregroundStyle(FrisTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
        )
        .padding(.horizontal, 40)
    }
    #endif

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
                .frame(height: 300)
                .padding(.horizontal)
                .padding(.top, 12)
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

                actionButtons
            }
            .padding(.horizontal)
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

                    overlayTag(item: overlay.item, index: index)
                        .position(x: min(max(x, 60), geo.size.width - 60), y: min(max(y, 20), geo.size.height - 20))
                }
            }
        }
        .frame(height: 280)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(FrisTheme.amber.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func overlayTag(item: EstimatedFoodItem, index: Int) -> some View {
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
        .background(
            FrisTheme.amber.opacity(0.85)
                .background(.ultraThinMaterial)
        )
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
        .transition(.scale.combined(with: .opacity))
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

    private var actionButtons: some View {
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
            .sensoryFeedback(.success, trigger: hasResult)

            HStack(spacing: 12) {
                Button {
                    resetToPickPhoto()
                } label: {
                    Text("Try Another Photo")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(FrisTheme.amber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(FrisTheme.amber.opacity(0.12), in: .rect(cornerRadius: 10))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(FrisTheme.elevated, in: .rect(cornerRadius: 10))
                }
            }
        }
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
        errorMessage = nil
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
                errorMessage = "Could not analyze photo. Please try again."
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
        dismiss()
    }

    private func resetToPickPhoto() {
        capturedImage = nil
        selectedPhoto = nil
        estimatedItems = []
        overlays = []
        hasResult = false
        errorMessage = nil
        sourceSelection = nil
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        nonisolated func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            Task { @MainActor in
                if let image {
                    onCapture(image)
                }
                dismiss()
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            Task { @MainActor in
                dismiss()
            }
        }
    }
}

struct ClarifyItemSheet: View {
    @Binding var item: EstimatedFoodItem
    @Environment(\.dismiss) private var dismiss
    @State private var nameText: String = ""
    @State private var amountText: String = ""
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Image(systemName: "pencil.and.outline")
                        .font(.title2)
                        .foregroundStyle(FrisTheme.amber)
                    Text("Adjust Estimate")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(FrisTheme.textPrimary)
                }

                VStack(spacing: 14) {
                    clarifyField(label: "Name", text: $nameText)
                    clarifyField(label: "Amount", text: $amountText)
                    clarifyField(label: "Calories", text: $caloriesText, isNumeric: true)
                    HStack(spacing: 12) {
                        clarifyField(label: "Protein (g)", text: $proteinText, isNumeric: true)
                        clarifyField(label: "Carbs (g)", text: $carbsText, isNumeric: true)
                        clarifyField(label: "Fat (g)", text: $fatText, isNumeric: true)
                    }
                }

                Button {
                    applyChanges()
                    dismiss()
                } label: {
                    Text("Save Changes")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(FrisTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FrisTheme.amber, in: .rect(cornerRadius: 12))
                }

                Spacer()
            }
            .padding(20)
            .background(FrisTheme.background.ignoresSafeArea())
            .onAppear {
                nameText = item.name
                amountText = item.amount
                caloriesText = "\(item.calories)"
                proteinText = String(format: "%.0f", item.protein)
                carbsText = String(format: "%.0f", item.carbs)
                fatText = String(format: "%.0f", item.fat)
            }
        }
    }

    private func clarifyField(label: String, text: Binding<String>, isNumeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(FrisTheme.textSecondary)

            TextField(label, text: text)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(FrisTheme.textPrimary)
                .keyboardType(isNumeric ? .decimalPad : .default)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FrisTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    private func applyChanges() {
        item.name = nameText
        item.amount = amountText
        item.calories = Int(caloriesText) ?? item.calories
        item.protein = Double(proteinText) ?? item.protein
        item.carbs = Double(carbsText) ?? item.carbs
        item.fat = Double(fatText) ?? item.fat
    }
}
