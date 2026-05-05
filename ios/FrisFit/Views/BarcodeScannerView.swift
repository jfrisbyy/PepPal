import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scanned: String? = nil
    @State private var manualCode: String = ""
    @State private var cameraAuthorized: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                #if targetEnvironment(simulator)
                simulatorPlaceholder
                #else
                BarcodeCameraView(onScan: handleScan)
                    .ignoresSafeArea()
                #endif

                VStack {
                    Spacer()
                    scannerFrame
                    Spacer()
                    instructions
                }

                VStack {
                    Spacer()
                    manualEntryCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var simulatorPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.4))
            Text("Barcode Scanner")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
            Text("Install on your device via the Rork App\nto scan product barcodes.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var scannerFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(PepTheme.teal, lineWidth: 3)
                .frame(width: 280, height: 170)
            VStack {
                HStack {
                    cornerMarker(rotation: 0)
                    Spacer()
                    cornerMarker(rotation: 90)
                }
                Spacer()
                HStack {
                    cornerMarker(rotation: 270)
                    Spacer()
                    cornerMarker(rotation: 180)
                }
            }
            .frame(width: 280, height: 170)
        }
    }

    private func cornerMarker(rotation: Double) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 20))
            p.addLine(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(PepTheme.teal, lineWidth: 4)
        .frame(width: 20, height: 20)
        .rotationEffect(.degrees(rotation))
    }

    private var instructions: some View {
        VStack(spacing: 6) {
            Text("Align the barcode in the frame")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white)
            Text("UPC, EAN, and QR codes supported")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.bottom, 140)
    }

    private var manualEntryCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundStyle(.white.opacity(0.6))
                TextField("Enter barcode manually", text: $manualCode)
                    .keyboardType(.numberPad)
                    .foregroundStyle(.white)
                    .tint(PepTheme.teal)
                Button {
                    guard !manualCode.isEmpty else { return }
                    handleScan(manualCode)
                } label: {
                    Text("Use")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PepTheme.teal, in: .rect(cornerRadius: 6))
                }
                .disabled(manualCode.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            .environment(\.colorScheme, .dark)
        }
    }

    private func handleScan(_ code: String) {
        guard scanned == nil else { return }
        scanned = code
        onScan(code)
        dismiss()
    }
}

#if !targetEnvironment(simulator)
struct BarcodeCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerController {
        let vc = BarcodeScannerController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerController, context: Context) {}
}

final class BarcodeScannerController: UIViewController {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var didReport = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        didReport = false
        Task.detached {
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .code93, .qr, .pdf417, .itf14]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.preview = previewLayer
    }
}

extension BarcodeScannerController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        Task { @MainActor in
            guard !self.didReport else { return }
            self.didReport = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.onScan?(value)
        }
    }
}
#endif
