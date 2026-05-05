import SwiftUI

struct AvatarCropSheet: View {
    let sourceImage: UIImage
    let onSave: (Data) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isSaving: Bool = false

    private let cropSize: CGFloat = 300

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer(minLength: 0)

                    Text("Position & Scale")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Pinch to zoom, drag to reposition")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))

                    cropCanvas
                        .padding(.vertical, 12)

                    HStack(spacing: 12) {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundStyle(.white.opacity(0.7))
                        Slider(value: $scale, in: 1.0...4.0)
                            .tint(PepTheme.teal)
                            .onChange(of: scale) { _, _ in
                                clampOffset()
                            }
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 32)

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.12))
                            .clipShape(.capsule)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveCrop()
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Text("Use")
                                .fontWeight(.semibold)
                                .foregroundStyle(PepTheme.teal)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var cropCanvas: some View {
        ZStack {
            Color.black
                .frame(width: cropSize, height: cropSize)

            Image(uiImage: sourceImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cropSize, height: cropSize)
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: cropSize, height: cropSize)
                .clipped()

            Circle()
                .inset(by: 1)
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: cropSize, height: cropSize)
                .allowsHitTesting(false)

            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: cropSize, height: cropSize)
                .mask(
                    ZStack {
                        Rectangle()
                        Circle().blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
                .allowsHitTesting(false)
        }
        .frame(width: cropSize, height: cropSize)
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        clampOffset()
                        lastOffset = offset
                    },
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = max(1.0, min(4.0, lastScale * value))
                        scale = newScale
                    }
                    .onEnded { _ in
                        lastScale = scale
                        clampOffset()
                        lastOffset = offset
                    }
            )
        )
    }

    private func clampOffset() {
        let imageAspect = sourceImage.size.width / max(sourceImage.size.height, 1)
        let displayedWidth: CGFloat
        let displayedHeight: CGFloat
        if imageAspect >= 1 {
            displayedHeight = cropSize * scale
            displayedWidth = displayedHeight * imageAspect
        } else {
            displayedWidth = cropSize * scale
            displayedHeight = displayedWidth / imageAspect
        }
        let maxX = max(0, (displayedWidth - cropSize) / 2)
        let maxY = max(0, (displayedHeight - cropSize) / 2)
        let clampedX = min(max(offset.width, -maxX), maxX)
        let clampedY = min(max(offset.height, -maxY), maxY)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            offset = CGSize(width: clampedX, height: clampedY)
        }
    }

    private func saveCrop() {
        isSaving = true
        let outputSize: CGFloat = 600
        let ratio = outputSize / cropSize

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize),
            format: {
                let f = UIGraphicsImageRendererFormat()
                f.scale = 1
                f.opaque = true
                return f
            }()
        )

        let image = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: outputSize, height: outputSize))

            let imageAspect = sourceImage.size.width / max(sourceImage.size.height, 1)
            var baseWidth: CGFloat
            var baseHeight: CGFloat
            if imageAspect >= 1 {
                baseHeight = cropSize
                baseWidth = cropSize * imageAspect
            } else {
                baseWidth = cropSize
                baseHeight = cropSize / imageAspect
            }
            let scaledWidth = baseWidth * scale * ratio
            let scaledHeight = baseHeight * scale * ratio
            let centerX = outputSize / 2 + offset.width * ratio
            let centerY = outputSize / 2 + offset.height * ratio
            let rect = CGRect(
                x: centerX - scaledWidth / 2,
                y: centerY - scaledHeight / 2,
                width: scaledWidth,
                height: scaledHeight
            )
            sourceImage.draw(in: rect)
        }

        guard let data = image.jpegData(compressionQuality: 0.88) else {
            isSaving = false
            return
        }
        onSave(data)
        dismiss()
    }
}
