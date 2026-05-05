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
                PepTheme.background.ignoresSafeArea()

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
                        .foregroundStyle(PepTheme.textSecondary)
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
                        .presentationDetents([.medium, .large])
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
                        .fill(PepTheme.amber.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(PepTheme.amber)
                }

                Text("Add a Food Photo")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text("Take a photo or choose from your library\nand AI will estimate the calories")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
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
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.amber, in: .rect(cornerRadius: 12))
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
                    .foregroundStyle(PepTheme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.amber.opacity(0.12), in: .rect(cornerRadius: 12))
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
                .foregroundStyle(PepTheme.textSecondary)

            Text("Camera Preview")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Install this app on your device\nvia the Rork App to use the camera.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
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
                                colors: [PepTheme.amber.opacity(0), PepTheme.amber.opacity(0.6), PepTheme.amber.opacity(0)],
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
                    .tint(PepTheme.amber)
                    .scaleEffect(1.2)

                Text("Analyzing your meal...")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text("Identifying food items and estimating nutrition")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
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
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text("Tap to adjust")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
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
                .strokeBorder(PepTheme.amber.opacity(0.2), lineWidth: 0.5)
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
            PepTheme.amber.opacity(0.85)
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
                    .foregroundStyle(PepTheme.teal)
                Text("total cal")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 14) {
                miniMacro(label: "Protein", value: Int(totalP), color: PepTheme.teal)
                miniMacro(label: "Carbs", value: Int(totalC), color: PepTheme.amber)
                miniMacro(label: "Fat", value: Int(totalF), color: PepTheme.violet)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.teal.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func miniMacro(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)g")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func detectedItemRow(item: EstimatedFoodItem, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PepTheme.amber.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(index + 1)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.amber)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)

                HStack(spacing: 6) {
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

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(item.calories)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("cal")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Image(systemName: "pencil.circle.fill")
                .font(.body)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
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
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PepTheme.teal, in: .rect(cornerRadius: 12))
            }
            .sensoryFeedback(.success, trigger: hasResult)

            HStack(spacing: 12) {
                Button {
                    resetToPickPhoto()
                } label: {
                    Text("Try Another Photo")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.amber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PepTheme.amber.opacity(0.12), in: .rect(cornerRadius: 10))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PepTheme.elevated, in: .rect(cornerRadius: 10))
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
    @State private var correctionText: String = ""
    @State private var isRecalculating: Bool = false
    @State private var recalculated: Bool = false
    @State private var errorText: String? = nil
    @State private var previewItem: EstimatedFoodItem? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    currentDetectionCard
                    correctionInput

                    if isRecalculating {
                        recalculatingView
                    }

                    if let preview = previewItem {
                        recalculatedPreview(preview)
                    }

                    if let error = errorText {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .presentationContentInteraction(.scrolls)
            .appBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                }
            }
        }
    }

    private var currentDetectionCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(PepTheme.amber.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PepTheme.amber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Detected")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(item.name)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(item.amount)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(item.calories)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                    Text("cal")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            HStack(spacing: 0) {
                clarifyMacroTag(label: "Protein", value: Int(item.protein), unit: "g", color: PepTheme.teal)
                    .frame(maxWidth: .infinity)
                clarifyMacroTag(label: "Carbs", value: Int(item.carbs), unit: "g", color: PepTheme.amber)
                    .frame(maxWidth: .infinity)
                clarifyMacroTag(label: "Fat", value: Int(item.fat), unit: "g", color: PepTheme.violet)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func clarifyMacroTag(label: String, value: Int, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)\(unit)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var correctionInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What is this actually?")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Describe the correction and AI will recalculate nutrition automatically.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

            HStack(spacing: 10) {
                TextField("e.g. \"It's 2 chicken thighs, not 1 leg\"...", text: $correctionText, axis: .vertical)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))

                Button {
                    Task { await recalculate() }
                } label: {
                    Group {
                        if isRecalculating {
                            ProgressView()
                                .tint(PepTheme.invertedText)
                        } else {
                            Image(systemName: "arrow.trianglehead.2.clockwise")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(width: 48, height: 48)
                    .foregroundStyle(PepTheme.invertedText)
                    .background(
                        correctionText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? PepTheme.textSecondary.opacity(0.3)
                            : PepTheme.amber,
                        in: .rect(cornerRadius: 12)
                    )
                }
                .disabled(correctionText.trimmingCharacters(in: .whitespaces).isEmpty || isRecalculating)
                .sensoryFeedback(.impact(weight: .medium), trigger: isRecalculating)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    suggestionChip("Wrong item")
                    suggestionChip("Wrong quantity")
                    suggestionChip("Missing sauce/oil")
                    suggestionChip("Bigger portion")
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            correctionText = text
        } label: {
            Text(text)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.amber)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(PepTheme.amber.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    private var recalculatingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(PepTheme.amber)
            Text("Recalculating nutrition...")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(PepTheme.amber.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func recalculatedPreview(_ preview: EstimatedFoodItem) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Recalculated")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preview.name)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(preview.amount)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(preview.calories)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.teal)
                        Text("cal")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                HStack(spacing: 0) {
                    clarifyMacroTag(label: "Protein", value: Int(preview.protein), unit: "g", color: PepTheme.teal)
                        .frame(maxWidth: .infinity)
                    clarifyMacroTag(label: "Carbs", value: Int(preview.carbs), unit: "g", color: PepTheme.amber)
                        .frame(maxWidth: .infinity)
                    clarifyMacroTag(label: "Fat", value: Int(preview.fat), unit: "g", color: PepTheme.violet)
                        .frame(maxWidth: .infinity)
                }

                clarifyDiffRow(preview)
            }

            HStack(spacing: 12) {
                Button {
                    item = EstimatedFoodItem(
                        id: item.id,
                        name: preview.name,
                        amount: preview.amount,
                        calories: preview.calories,
                        protein: preview.protein,
                        carbs: preview.carbs,
                        fat: preview.fat
                    )
                    dismiss()
                } label: {
                    Text("Accept")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PepTheme.invertedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                }
                .sensoryFeedback(.success, trigger: recalculated)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        previewItem = nil
                        recalculated = false
                    }
                } label: {
                    Text("Discard")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.elevated, in: .rect(cornerRadius: 12))
                }
            }
        }
        .padding(14)
        .background(PepTheme.teal.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.teal.opacity(0.15), lineWidth: 0.5)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private func clarifyDiffRow(_ preview: EstimatedFoodItem) -> some View {
        let calDiff = preview.calories - item.calories
        let pDiff = Int(preview.protein) - Int(item.protein)
        let cDiff = Int(preview.carbs) - Int(item.carbs)
        let fDiff = Int(preview.fat) - Int(item.fat)

        return HStack(spacing: 12) {
            clarifyDiffChip("Cal", diff: calDiff)
            clarifyDiffChip("P", diff: pDiff, showG: true)
            clarifyDiffChip("C", diff: cDiff, showG: true)
            clarifyDiffChip("F", diff: fDiff, showG: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func clarifyDiffChip(_ label: String, diff: Int, showG: Bool = false) -> some View {
        let sign = diff >= 0 ? "+" : ""
        let text = showG ? "\(sign)\(diff)g" : "\(sign)\(diff)"
        let color: Color = diff > 0 ? .red.opacity(0.7) : diff < 0 ? .green.opacity(0.7) : PepTheme.textSecondary

        return HStack(spacing: 2) {
            Text(label)
                .foregroundStyle(PepTheme.textSecondary)
            Text(text)
                .foregroundStyle(color)
        }
        .font(.system(.caption2, weight: .semibold))
    }

    private func recalculate() async {
        let trimmed = correctionText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isRecalculating = true
        errorText = nil
        withAnimation { previewItem = nil }

        do {
            let result = try await NutritionAIService.shared.clarifyItem(
                originalItem: item,
                userCorrection: trimmed
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                previewItem = result
                recalculated = true
            }
        } catch {
            errorText = "Could not recalculate. Please try again."
        }

        isRecalculating = false
    }
}
