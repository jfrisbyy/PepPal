import SwiftUI
import PhotosUI
import AVFoundation

struct VialIntegrityCheckView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var cameraManager = CameraSessionManager()
    @State private var capturedImage: UIImage? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isAnalyzing: Bool = false
    @State private var result: VialIntegrityResult? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                PepTheme.background.ignoresSafeArea()

                if let result, let image = capturedImage {
                    resultView(result: result, image: image)
                } else {
                    captureView
                }
            }
            .navigationTitle("Vial Integrity Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                if result != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Retake") {
                            withAnimation { result = nil; capturedImage = nil }
                        }
                    }
                }
            }
            .onAppear {
                #if !targetEnvironment(simulator)
                cameraManager.configure()
                cameraManager.start()
                #endif
            }
            .onDisappear { cameraManager.stop() }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await loadLibrary(item) }
            }
        }
    }

    private var captureView: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Check your vial for issues")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("Hold the vial against a plain, well-lit background. We'll look for cloudiness, particulates, color shifts, or tamper signs.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            ZStack {
                Color.black
                #if targetEnvironment(simulator)
                simulatorPlaceholder
                #else
                if AVCaptureDevice.default(for: .video) != nil {
                    LiveCameraPreview(session: cameraManager.session)
                } else {
                    simulatorPlaceholder
                }
                #endif

                if isAnalyzing {
                    Color.black.opacity(0.5)
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Inspecting…")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 360)
            .clipShape(.rect(cornerRadius: 20))
            .padding(.horizontal, 16)

            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("From Library", systemImage: "photo.on.rectangle")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(PepTheme.elevated, in: .capsule)
                }

                Button {
                    capture()
                } label: {
                    Label("Capture", systemImage: "camera.fill")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.invertedText)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal, in: .capsule)
                }
                .disabled(isAnalyzing)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 16)
    }

    private var simulatorPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "testtube.2")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.4))
            Text("Camera not available")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Text("Use the photo library to pick a vial photo.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func resultView(result: VialIntegrityResult, image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(.rect(cornerRadius: 18))
                    .padding(.horizontal, 16)

                statusCard(result)
                    .padding(.horizontal, 16)

                if !result.observations.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("OBSERVATIONS")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(1.2)
                                .foregroundStyle(PepTheme.textSecondary)
                            ForEach(result.observations, id: \.self) { obs in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 5))
                                        .foregroundStyle(statusColor(result.status))
                                        .padding(.top, 7)
                                    Text(obs)
                                        .font(.subheadline)
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if !result.recommendation.isEmpty {
                    GlassCard(accent: statusColor(result.status)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Guidance", systemImage: "lightbulb.fill")
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(statusColor(result.status))
                            Text(result.recommendation)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Text("Educational only. When in doubt, do not inject — contact your provider or pharmacy.")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
            }
            .padding(.bottom, 32)
        }
    }

    private func statusCard(_ r: VialIntegrityResult) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor(r.status).opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: r.status.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(statusColor(r.status))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(r.status.label)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(statusColor(r.status))
                Text(statusSubtitle(r.status))
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(statusColor(r.status).opacity(0.3), lineWidth: 1)
        )
    }

    private func statusColor(_ s: VialIntegrityStatus) -> Color {
        switch s {
        case .pass: return .green
        case .warn: return PepTheme.amber
        case .fail: return .red
        case .unknown: return PepTheme.textSecondary
        }
    }

    private func statusSubtitle(_ s: VialIntegrityStatus) -> String {
        switch s {
        case .pass: return "Looks clean — safe to proceed."
        case .warn: return "Something looks off. Review before injecting."
        case .fail: return "Clear issue detected. Do not inject."
        case .unknown: return "Couldn't determine status. Try a clearer photo."
        }
    }

    private func capture() {
        #if targetEnvironment(simulator)
        return
        #else
        cameraManager.capturePhoto { image in
            Task { @MainActor in
                guard let image else { return }
                capturedImage = image
                if let data = image.jpegData(compressionQuality: 0.85) {
                    await analyze(data)
                }
            }
        }
        #endif
    }

    private func loadLibrary(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        capturedImage = image
        await analyze(data)
    }

    private func analyze(_ data: Data) async {
        withAnimation { isAnalyzing = true }
        let r = await VialIntegrityService.shared.inspect(imageData: data)
        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isAnalyzing = false
                result = r
            }
            UINotificationFeedbackGenerator().notificationOccurred(r.status == .pass ? .success : (r.status == .fail ? .error : .warning))
        }
    }
}
