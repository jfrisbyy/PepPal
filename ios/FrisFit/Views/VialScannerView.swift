import SwiftUI
import AVFoundation
import PhotosUI

nonisolated enum VialScanAction: Sendable {
    case addToInventory
    case reconstitute
    case createProtocol
}

nonisolated enum VialCaptureStep: Int, Sendable, CaseIterable {
    case front, back, cap

    var title: String {
        switch self {
        case .front: return "Capture the FRONT label"
        case .back: return "Now flip — capture the BACK"
        case .cap: return "Capture the TOP / cap"
        }
    }
    var subtitle: String {
        switch self {
        case .front: return "Make sure compound name and vial size are visible."
        case .back: return "Look for lot #, vial #, and expiration date."
        case .cap: return "Final angle helps fill in anything missed."
        }
    }
    var label: String {
        switch self {
        case .front: return "Front"
        case .back: return "Back"
        case .cap: return "Cap"
        }
    }
}

struct VialScannerView: View {
    let onComplete: (ScannedVialLabel, VialScanAction) -> Void
    var allowBatch: Bool = true

    @Environment(\.dismiss) private var dismiss

    @State private var cameraManager = CameraSessionManager()
    @State private var capturedImages: [UIImage] = []
    @State private var capturedFilenames: [String] = []
    @State private var captureStep: VialCaptureStep = .front
    @State private var isAnalyzing: Bool = false
    @State private var scan: ScannedVialLabel? = nil
    @State private var errorMessage: String? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var pulse: Bool = false
    @State private var showReview: Bool = false
    @State private var torchOn: Bool = false

    @State private var batchMode: Bool = false
    @State private var batchItems: [BatchScanItem] = []
    @State private var showBatchReview: Bool = false
    @State private var lockGlow: Bool = false

    nonisolated struct BatchScanItem: Identifiable, Sendable {
        let id: UUID
        var scan: ScannedVialLabel
        var imageFilenames: [String]

        init(id: UUID = UUID(), scan: ScannedVialLabel, imageFilenames: [String]) {
            self.id = id
            self.scan = scan
            self.imageFilenames = imageFilenames
        }

        var primaryFilename: String? { imageFilenames.first }
    }

    var body: some View {
        if PeptideAccessManager.shared.shouldShowTrackAEmptyState {
            NavigationStack {
                TrackAEmptyStateView(
                    surface: .scanner,
                    icon: "camera.viewfinder",
                    title: "Scan vials in seconds",
                    blurb: "Tracking peptides? EPTI scans vials, captures compound, lot, and expiration in one shot, and tracks your supply."
                )
                .navigationTitle("Vial Scanner")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .preferredColorScheme(.dark)
        } else {
            scannerBody
        }
    }

    @ViewBuilder
    private var scannerBody: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                cameraLayer
                    .ignoresSafeArea()

                dimmedOverlay
                    .ignoresSafeArea()

                VStack {
                    instructionCapsule
                        .padding(.top, 16)
                    if !batchMode {
                        progressDots
                            .padding(.top, 8)
                    }
                    Spacer()
                    if !batchMode && !capturedImages.isEmpty {
                        capturedStrip
                            .padding(.bottom, 8)
                            .transition(.opacity)
                    }
                    if batchMode && !batchItems.isEmpty {
                        batchTray
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    bottomBar
                        .padding(.bottom, 24)
                }

                if isAnalyzing {
                    analyzingOverlay
                        .transition(.opacity)
                }

                if let error = errorMessage {
                    errorBanner(error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { closeScanner() } label: {
                        glassIconButton(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .principal) {
                    if allowBatch {
                        batchToggle
                    }
                }
                #if !targetEnvironment(simulator)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { toggleTorch() } label: {
                        glassIconButton(systemName: torchOn ? "bolt.fill" : "bolt.slash.fill", tint: torchOn ? .yellow : .white)
                    }
                }
                #endif
            }
            .onAppear {
                startCamera()
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onDisappear { cameraManager.stop() }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await loadLibraryPhoto(item) }
            }
            .sheet(isPresented: $showReview) {
                if let binding = Binding($scan) {
                    VialScanReviewSheet(
                        scan: binding,
                        capturedImages: capturedImages,
                        onChoose: { action in
                            let result = binding.wrappedValue
                            showReview = false
                            recordHistory(result)
                            dismiss()
                            onComplete(result, action)
                        },
                        onAddAnotherAngle: {
                            showReview = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showBatchReview) {
                VialBatchReviewSheet(
                    items: $batchItems,
                    onDone: { finalItems in
                        showBatchReview = false
                        dismiss()
                        saveBatch(finalItems)
                    },
                    onCancel: {
                        showBatchReview = false
                    }
                )
            }
        }
    }

    // MARK: - Camera

    @ViewBuilder
    private var cameraLayer: some View {
        #if targetEnvironment(simulator)
        simulatorPlaceholder
        #else
        if AVCaptureDevice.default(for: .video) != nil {
            LiveCameraPreview(session: cameraManager.session)
        } else {
            simulatorPlaceholder
        }
        #endif
    }

    private var simulatorPlaceholder: some View {
        ZStack {
            Color(white: 0.08)
            VStack(spacing: 14) {
                Image(systemName: "testtube.2")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Vial Scanner")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Install on your device via the Rork App\nto scan real vials, or pick a photo below.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var dimmedOverlay: some View {
        GeometryReader { geo in
            let frameW = min(geo.size.width - 40, 340)
            let frameH: CGFloat = 220

            ZStack {
                Color.black.opacity(0.55)
                    .mask(
                        ZStack {
                            Rectangle()
                            RoundedRectangle(cornerRadius: 24)
                                .frame(width: frameW, height: frameH)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )

                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder((lockGlow ? Color.green : .white.opacity(0.5)), lineWidth: lockGlow ? 2 : 1)
                    .frame(width: frameW, height: frameH)
                    .shadow(color: lockGlow ? .green.opacity(0.6) : .clear, radius: 14)
                    .animation(.easeInOut(duration: 0.25), value: lockGlow)

                scanningBrackets(width: frameW, height: frameH)
            }
        }
    }

    private func scanningBrackets(width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geo in
            let midX = geo.size.width / 2
            let midY = geo.size.height / 2
            let left = midX - width / 2 + 14
            let right = midX + width / 2 - 14
            let top = midY - height / 2 + 14
            let bottom = midY + height / 2 - 14

            ZStack {
                bracket(rotation: 0).position(x: left, y: top)
                bracket(rotation: 90).position(x: right, y: top)
                bracket(rotation: 270).position(x: left, y: bottom)
                bracket(rotation: 180).position(x: right, y: bottom)
            }
        }
        .allowsHitTesting(false)
    }

    private func bracket(rotation: Double) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 24))
            p.addLine(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 24, y: 0))
        }
        .stroke(lockGlow ? Color.green : PepTheme.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .frame(width: 24, height: 24)
        .rotationEffect(.degrees(rotation))
        .opacity(pulse ? 1.0 : 0.55)
    }

    private var instructionCapsule: some View {
        VStack(spacing: 4) {
            Text(batchMode ? "Batch Scan" : captureStep.title)
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(.white)
            Text(batchMode
                 ? "Tap the shutter for each vial — review them all at the end"
                 : captureStep.subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(glassCapsuleBackground)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(VialCaptureStep.allCases, id: \.rawValue) { step in
                let isFilled = step.rawValue < capturedImages.count
                let isCurrent = step.rawValue == capturedImages.count
                Capsule()
                    .fill(isFilled ? PepTheme.teal : (isCurrent ? Color.white.opacity(0.6) : Color.white.opacity(0.25)))
                    .frame(width: isCurrent ? 22 : 10, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: capturedImages.count)
            }
        }
    }

    private var batchToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                batchMode.toggle()
                if batchMode {
                    resetMultiAngleState()
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: batchMode ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                    .font(.system(size: 12, weight: .bold))
                Text(batchMode ? "Batch On" : "Batch")
                    .font(.system(.caption, weight: .bold))
            }
            .foregroundStyle(batchMode ? PepTheme.teal : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(glassCapsuleBackground)
        }
    }

    @ViewBuilder
    private var glassCapsuleBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
        } else {
            Capsule().fill(.black.opacity(0.4))
        }
    }

    private func glassIconButton(systemName: String, tint: Color = .white) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background {
                if #available(iOS 26.0, *) {
                    Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                } else {
                    Circle().fill(.black.opacity(0.45))
                }
            }
    }

    // MARK: - Captured Strip (multi-angle)

    private var capturedStrip: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(Array(capturedImages.enumerated()), id: \.offset) { idx, image in
                    capturedThumb(image: image, index: idx)
                }
                if capturedImages.count < VialCaptureStep.allCases.count {
                    placeholderThumb
                }
            }

            if capturedImages.count >= 1 && capturedImages.count < VialCaptureStep.allCases.count {
                Button {
                    Task { await analyzeCurrentSet() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12, weight: .bold))
                        Text("Skip & Analyze (\(capturedImages.count) photo\(capturedImages.count == 1 ? "" : "s"))")
                            .font(.system(.caption, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PepTheme.teal, in: .capsule)
                }
                .disabled(isAnalyzing)
            }
        }
        .padding(.horizontal, 18)
    }

    private func capturedThumb(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(PepTheme.teal.opacity(0.6), lineWidth: 1)
                )
                .overlay(alignment: .bottomLeading) {
                    Text(VialCaptureStep(rawValue: index)?.label ?? "#\(index + 1)")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: .capsule)
                        .padding(3)
                }

            Button {
                removeCapturedImage(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, .black.opacity(0.7))
                    .offset(x: 6, y: -6)
            }
        }
        .frame(width: 64, height: 64)
    }

    private var placeholderThumb: some View {
        let nextStep = VialCaptureStep(rawValue: capturedImages.count)
        return VStack(spacing: 2) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.5))
            Text(nextStep?.label ?? "")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(width: 64, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    // MARK: - Batch Tray

    private var batchTray: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(batchItems.count) scanned")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showBatchReview = true
                } label: {
                    Text("Review & Save")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PepTheme.teal, in: .capsule)
                }
            }
            .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(batchItems) { item in
                        batchThumb(item)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
        .padding(.vertical, 10)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.black.opacity(0.45))
            }
        }
        .padding(.horizontal, 16)
    }

    private func batchThumb(_ item: BatchScanItem) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                thumbImage(for: item)
                    .frame(width: 58, height: 58)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if item.imageFilenames.count > 1 {
                            Text("+\(item.imageFilenames.count - 1)")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.black.opacity(0.7), in: .capsule)
                                .padding(2)
                        }
                    }

                Button {
                    removeBatchItem(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .offset(x: 6, y: -6)
                }
            }
            Text(item.scan.compoundName.isEmpty ? "Unknown" : item.scan.compoundName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: 70)
        }
    }

    @ViewBuilder
    private func thumbImage(for item: BatchScanItem) -> some View {
        if let name = item.primaryFilename, let img = VialLabelImageStore.shared.load(name) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            Color.white.opacity(0.1).overlay(
                Image(systemName: "testtube.2")
                    .foregroundStyle(.white.opacity(0.5))
            )
        }
    }

    private func removeBatchItem(_ item: BatchScanItem) {
        withAnimation {
            batchItems.removeAll { $0.id == item.id }
        }
        for name in item.imageFilenames {
            VialLabelImageStore.shared.delete(name)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.15), in: .circle)
            }
            .frame(maxWidth: .infinity)

            Button { captureFromCamera() } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                    if isAnalyzing {
                        Circle()
                            .trim(from: 0, to: 0.75)
                            .stroke(PepTheme.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 86, height: 86)
                            .rotationEffect(.degrees(pulse ? 360 : 0))
                    }
                }
            }
            .disabled(isAnalyzing)
            .sensoryFeedback(.selection, trigger: capturedImages.count)

            Button {
                if !batchItems.isEmpty {
                    showBatchReview = true
                }
            } label: {
                Image(systemName: batchItems.isEmpty ? "square.stack.3d.up" : "tray.full.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(batchItems.isEmpty ? .white.opacity(0.12) : PepTheme.teal.opacity(0.8), in: .circle)
                    .overlay(alignment: .topTrailing) {
                        if !batchItems.isEmpty {
                            Text("\(batchItems.count)")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.white, in: .capsule)
                                .offset(x: 6, y: -4)
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .disabled(batchItems.isEmpty && !batchMode)
            .opacity((batchMode || !batchItems.isEmpty) ? 1 : 0)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Analyzing

    private var analyzingOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                ShimmerBar()
                    .frame(height: 4)
                    .clipShape(.capsule)

                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text(capturedImages.count > 1 ? "Combining \(capturedImages.count) angles…" : "Reading label…")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation { errorMessage = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 16)
            .padding(.top, 70)
            Spacer()
        }
    }

    // MARK: - Actions

    private func closeScanner() {
        if batchMode && !batchItems.isEmpty {
            showBatchReview = true
        } else {
            dismiss()
        }
    }

    private func startCamera() {
        #if !targetEnvironment(simulator)
        cameraManager.configure()
        cameraManager.start()
        #endif
    }

    private func captureFromCamera() {
        #if targetEnvironment(simulator)
        withAnimation { errorMessage = "Camera not available in simulator. Use the photo library button." }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #else
        cameraManager.capturePhoto { image in
            Task { @MainActor in
                guard let image else { return }
                if batchMode {
                    if let data = image.jpegData(compressionQuality: 0.85) {
                        await analyzeBatchShot(data: data, image: image)
                    }
                } else {
                    await ingestNewAngle(image: image)
                }
            }
        }
        #endif
    }

    private func loadLibraryPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        if batchMode {
            await analyzeBatchShot(data: data, image: image)
        } else {
            await ingestNewAngle(image: image)
        }
        await MainActor.run { selectedPhoto = nil }
    }

    /// In multi-angle mode: append a new angle, advance the step, and auto-analyze when full.
    private func ingestNewAngle(image: UIImage) async {
        let filename = VialLabelImageStore.shared.save(image) ?? UUID().uuidString
        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                capturedImages.append(image)
                capturedFilenames.append(filename)
                if let next = VialCaptureStep(rawValue: capturedImages.count) {
                    captureStep = next
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
        if capturedImages.count >= VialCaptureStep.allCases.count {
            await analyzeCurrentSet()
        }
    }

    private func removeCapturedImage(at index: Int) {
        guard index < capturedImages.count else { return }
        let filename = capturedFilenames[index]
        VialLabelImageStore.shared.delete(filename)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            capturedImages.remove(at: index)
            capturedFilenames.remove(at: index)
            captureStep = VialCaptureStep(rawValue: min(capturedImages.count, VialCaptureStep.allCases.count - 1)) ?? .front
        }
    }

    private func resetMultiAngleState() {
        for name in capturedFilenames {
            VialLabelImageStore.shared.delete(name)
        }
        capturedImages.removeAll()
        capturedFilenames.removeAll()
        captureStep = .front
    }

    private func analyzeCurrentSet() async {
        guard !capturedImages.isEmpty else { return }
        await MainActor.run { withAnimation { isAnalyzing = true; errorMessage = nil } }
        let datas = capturedImages.compactMap { $0.jpegData(compressionQuality: 0.85) }
        do {
            var result = try await VialLabelScanService.shared.scan(imagesData: datas)
            result.labelImageFilename = capturedFilenames.first

            let hasBarcode = result.sources["lotNumber"] == .barcode || result.sources["expirationDate"] == .barcode
            if hasBarcode { await flashLockGlow() }

            await MainActor.run {
                withAnimation { isAnalyzing = false }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                scan = result
                showReview = true
            }
        } catch {
            await MainActor.run {
                withAnimation {
                    isAnalyzing = false
                    errorMessage = "Couldn't read label. Try another angle or better light."
                }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    /// Batch mode = single shot per vial.
    private func analyzeBatchShot(data: Data, image: UIImage) async {
        await MainActor.run { withAnimation { isAnalyzing = true; errorMessage = nil } }
        do {
            var result = try await VialLabelScanService.shared.scan(imageData: data)
            let imageFilename = VialLabelImageStore.shared.save(image)
            result.labelImageFilename = imageFilename

            let hasBarcode = result.sources["lotNumber"] == .barcode || result.sources["expirationDate"] == .barcode
            if hasBarcode { await flashLockGlow() }

            await MainActor.run {
                withAnimation { isAnalyzing = false }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                let filenames = imageFilename.map { [$0] } ?? []
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    batchItems.append(BatchScanItem(scan: result, imageFilenames: filenames))
                }
                VialScanHistoryStore.shared.add(scan: result, imageFilenames: filenames)
            }
        } catch {
            await MainActor.run {
                withAnimation {
                    isAnalyzing = false
                    errorMessage = "Couldn't read label. Try another angle or better light."
                }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func flashLockGlow() async {
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.15)) { lockGlow = true }
        }
        try? await Task.sleep(for: .milliseconds(600))
        await MainActor.run {
            withAnimation(.easeIn(duration: 0.3)) { lockGlow = false }
        }
    }

    private func recordHistory(_ scan: ScannedVialLabel) {
        VialScanHistoryStore.shared.add(scan: scan, imageFilenames: capturedFilenames)
    }

    private func saveBatch(_ items: [BatchScanItem]) {
        let store = VialInventoryStore.shared
        for item in items {
            let scan = item.scan
            guard !scan.compoundName.isEmpty, let mg = scan.vialSizeMg, mg > 0 else { continue }
            let vial = Vial(
                compoundName: scan.compoundName,
                vialSizeMg: mg,
                lotNumber: scan.lotNumber,
                vialNumber: scan.vialNumber,
                expirationDate: scan.expirationDate,
                typicalDoseMcg: defaultDoseMcg(for: scan.compoundName),
                budDays: ReconHelper.defaultBUDDays(for: scan.compoundName),
                labelImageFilename: item.primaryFilename
            )
            store.add(vial)
        }
    }

    private func defaultDoseMcg(for name: String) -> Double {
        if let profile = CompoundDatabase.all.first(where: { $0.name == name }),
           let tiered = profile.tieredDosing.first(where: { $0.tier == "Intermediate" }) ?? profile.tieredDosing.first,
           let doseNum = tiered.dose.matches(of: /\d+(?:\.\d+)?/).first.flatMap({ Double($0.output) }) {
            let isMg = tiered.dose.lowercased().contains("mg") && !tiered.dose.lowercased().contains("mcg")
            return isMg ? doseNum * 1000 : doseNum
        }
        return 250
    }

    private func toggleTorch() {
        #if !targetEnvironment(simulator)
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchOn ? .off : .on
            device.unlockForConfiguration()
            torchOn.toggle()
        } catch {
            print("[VialScanner] Torch error: \(error)")
        }
        #endif
    }
}

// MARK: - Shimmer

private struct ShimmerBar: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [PepTheme.teal.opacity(0.2), PepTheme.teal, PepTheme.blue, PepTheme.teal.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: phase * geo.size.width)
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

// MARK: - Review Sheet

struct VialScanReviewSheet: View {
    @Binding var scan: ScannedVialLabel
    let capturedImages: [UIImage]
    let onChoose: (VialScanAction) -> Void
    var onAddAnotherAngle: (() -> Void)? = nil

    @State private var vialSizeText: String = ""
    @State private var diluentVolText: String = ""
    @State private var hasExpirationDate: Bool = false
    @State private var expirationDate: Date = Date()
    @State private var showCompoundPicker: Bool = false
    @State private var carouselIndex: Int = 0

    /// Back-compat single-image initializer (for history detail).
    init(
        scan: Binding<ScannedVialLabel>,
        capturedImage: UIImage?,
        onChoose: @escaping (VialScanAction) -> Void,
        onAddAnotherAngle: (() -> Void)? = nil
    ) {
        self._scan = scan
        self.capturedImages = capturedImage.map { [$0] } ?? []
        self.onChoose = onChoose
        self.onAddAnotherAngle = onAddAnotherAngle
    }

    init(
        scan: Binding<ScannedVialLabel>,
        capturedImages: [UIImage],
        onChoose: @escaping (VialScanAction) -> Void,
        onAddAnotherAngle: (() -> Void)? = nil
    ) {
        self._scan = scan
        self.capturedImages = capturedImages
        self.onChoose = onChoose
        self.onAddAnotherAngle = onAddAnotherAngle
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if !capturedImages.isEmpty {
                        imageCarousel
                    }

                    if scan.unknownCompound {
                        unknownCompoundBanner
                    }

                    if let missing = missingCriticalFields, !missing.isEmpty {
                        missingInfoBanner(missing: missing)
                    }

                    fieldsCard

                    Text("Tap any field to edit. Green = barcode, teal = AI read, gray = missing.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    actionsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Review Scan")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: populate)
            .sheet(isPresented: $showCompoundPicker) {
                CompoundPickerSheet { profile in
                    scan.compoundName = profile.name
                    scan.confidence["compoundName"] = .high
                    scan.sources["compoundName"] = .user
                    scan.unknownCompound = false
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Image carousel

    private var imageCarousel: some View {
        VStack(spacing: 8) {
            TabView(selection: $carouselIndex) {
                ForEach(Array(capturedImages.enumerated()), id: \.offset) { idx, img in
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .clipShape(.rect(cornerRadius: 14))
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: capturedImages.count > 1 ? .always : .never))
            .frame(height: 200)
            .overlay(alignment: .topTrailing) {
                if scan.isDiluent {
                    Label("Diluent", systemImage: "drop.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PepTheme.blue, in: .capsule)
                        .padding(8)
                }
            }
            .overlay(alignment: .topLeading) {
                if capturedImages.count > 1 {
                    Text("\(carouselIndex + 1) / \(capturedImages.count)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: .capsule)
                        .padding(8)
                }
            }
        }
    }

    // MARK: - Banners

    private var unknownCompoundBanner: some View {
        Button { showCompoundPicker = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(PepTheme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unknown peptide")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("We don't recognize \"\(scan.compoundName)\" — tap to pick from the database.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(12)
            .background(PepTheme.amber.opacity(0.12), in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(PepTheme.amber.opacity(0.3), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private var missingCriticalFields: [String]? {
        guard !scan.isDiluent else { return nil }
        var missing: [String] = []
        if scan.vialSizeMg == nil || (scan.vialSizeMg ?? 0) <= 0 { missing.append("Strength (mg)") }
        if scan.lotNumber.isEmpty { missing.append("Lot #") }
        if scan.expirationDate == nil { missing.append("Expiration") }
        return missing.isEmpty ? nil : missing
    }

    private func missingInfoBanner(missing: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(PepTheme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Missing info")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(missing.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
            }

            if let onAddAnotherAngle {
                Button {
                    onAddAnotherAngle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add Another Angle")
                            .font(.system(.caption, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PepTheme.amber, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(PepTheme.amber.opacity(0.10), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.amber.opacity(0.3), lineWidth: 0.8)
        )
    }

    // MARK: - Fields

    private var fieldsCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                compoundRow
                divider
                if scan.isDiluent {
                    diluentVolumeRow
                } else {
                    strengthRow
                }
                divider
                vialNumberRow
                divider
                lotRow
                divider
                expirationRow
                divider
                manufacturerRow
            }
        }
    }

    private var compoundRow: some View {
        Button { showCompoundPicker = true } label: {
            fieldRow(
                label: scan.isDiluent ? "Diluent" : "Peptide",
                source: scan.sources["compoundName"] ?? .none,
                confidence: scan.confidence["compoundName"] ?? .missing,
                content: {
                    HStack {
                        Text(scan.compoundName.isEmpty ? "Tap to select" : scan.compoundName)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(scan.compoundName.isEmpty ? PepTheme.textSecondary : PepTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private var strengthRow: some View {
        fieldRow(
            label: "Strength",
            source: scan.sources["vialSizeMg"] ?? .none,
            confidence: scan.confidence["vialSizeMg"] ?? .missing,
            content: {
                HStack {
                    TextField("e.g. 5", text: $vialSizeText)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .keyboardType(.decimalPad)
                        .onChange(of: vialSizeText) { _, new in
                            scan.vialSizeMg = Double(new)
                            if scan.sources["vialSizeMg"] != .barcode {
                                scan.sources["vialSizeMg"] = .user
                            }
                        }
                    Text("mg")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        )
    }

    private var diluentVolumeRow: some View {
        fieldRow(
            label: "Volume",
            source: .ocr,
            confidence: scan.diluentVolumeMl != nil ? .high : .missing,
            content: {
                HStack {
                    TextField("e.g. 30", text: $diluentVolText)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .keyboardType(.decimalPad)
                        .onChange(of: diluentVolText) { _, new in
                            scan.diluentVolumeMl = Double(new)
                        }
                    Text("mL")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        )
    }

    private var vialNumberRow: some View {
        fieldRow(
            label: "Vial #",
            source: scan.sources["vialNumber"] ?? .none,
            confidence: scan.confidence["vialNumber"] ?? .missing,
            content: {
                TextField("Optional", text: $scan.vialNumber)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .autocorrectionDisabled()
                    .onChange(of: scan.vialNumber) { _, _ in
                        if scan.sources["vialNumber"] != .barcode {
                            scan.sources["vialNumber"] = .user
                        }
                    }
            }
        )
    }

    private var lotRow: some View {
        fieldRow(
            label: "Lot / Batch",
            source: scan.sources["lotNumber"] ?? .none,
            confidence: scan.confidence["lotNumber"] ?? .missing,
            content: {
                TextField("Optional", text: $scan.lotNumber)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .autocorrectionDisabled()
            }
        )
    }

    private var expirationRow: some View {
        fieldRow(
            label: "Expiration",
            source: scan.sources["expirationDate"] ?? .none,
            confidence: scan.confidence["expirationDate"] ?? .missing,
            content: {
                HStack {
                    Toggle("", isOn: $hasExpirationDate)
                        .labelsHidden()
                        .tint(PepTheme.teal)
                        .onChange(of: hasExpirationDate) { _, on in
                            scan.expirationDate = on ? expirationDate : nil
                        }
                    if hasExpirationDate {
                        DatePicker("", selection: $expirationDate, displayedComponents: .date)
                            .labelsHidden()
                            .onChange(of: expirationDate) { _, d in
                                scan.expirationDate = d
                            }
                    } else {
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        )
    }

    private var manufacturerRow: some View {
        fieldRow(
            label: "Manufacturer",
            source: scan.sources["manufacturer"] ?? .none,
            confidence: scan.confidence["manufacturer"] ?? .missing,
            content: {
                TextField("Optional", text: $scan.manufacturer)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .autocorrectionDisabled()
            }
        )
    }

    private func fieldRow<Content: View>(label: String, source: ScannedVialLabel.Source, confidence: ScannedVialLabel.Confidence, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(confidenceColor(confidence))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(PepTheme.textSecondary)
                    sourceChip(source)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func sourceChip(_ s: ScannedVialLabel.Source) -> some View {
        switch s {
        case .barcode:
            Label("Barcode", systemImage: "barcode")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.green)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15), in: .capsule)
        case .ocr:
            Text("AI")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(PepTheme.teal)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(PepTheme.teal.opacity(0.15), in: .capsule)
        case .user:
            Text("EDITED")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(PepTheme.violet)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(PepTheme.violet.opacity(0.15), in: .capsule)
        case .none:
            EmptyView()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.separatorColor)
            .frame(height: 0.5)
    }

    private func confidenceColor(_ c: ScannedVialLabel.Confidence) -> Color {
        switch c {
        case .high: return .green
        case .low: return PepTheme.amber
        case .missing: return PepTheme.textSecondary.opacity(0.4)
        }
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(spacing: 10) {
            Text("WHAT NEXT?")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            actionButton(
                title: scan.isDiluent ? "Use for Reconstitution" : "Reconstitute Now",
                subtitle: scan.isDiluent ? "Pre-fill this diluent in the calculator" : "Calculate draw volume with BAC water",
                icon: "drop.fill",
                color: PepTheme.blue,
                enabled: hasEnoughInfo,
                action: { onChoose(.reconstitute) }
            )

            if !scan.isDiluent {
                actionButton(
                    title: "Add to Inventory",
                    subtitle: "Save this vial to track doses & BUD",
                    icon: "tray.and.arrow.down.fill",
                    color: PepTheme.teal,
                    enabled: hasEnoughInfo,
                    action: { onChoose(.addToInventory) }
                )

                actionButton(
                    title: "Create a Protocol",
                    subtitle: "Build a dosing schedule with this peptide",
                    icon: "list.bullet.rectangle.fill",
                    color: PepTheme.violet,
                    enabled: !scan.compoundName.isEmpty,
                    action: { onChoose(.createProtocol) }
                )
            }
        }
    }

    private var hasEnoughInfo: Bool {
        if scan.isDiluent {
            return !scan.compoundName.isEmpty
        }
        return !scan.compoundName.isEmpty && (scan.vialSizeMg ?? 0) > 0
    }

    private func actionButton(title: String, subtitle: String, icon: String, color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(color.opacity(0.2), lineWidth: 0.8)
            )
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .sensoryFeedback(.impact(weight: .medium), trigger: enabled)
    }

    private func populate() {
        if let mg = scan.vialSizeMg {
            vialSizeText = mg == mg.rounded() ? String(Int(mg)) : String(format: "%.2f", mg)
        }
        if let ml = scan.diluentVolumeMl {
            diluentVolText = ml == ml.rounded() ? String(Int(ml)) : String(format: "%.1f", ml)
        }
        if let exp = scan.expirationDate {
            hasExpirationDate = true
            expirationDate = exp
        }
    }
}
