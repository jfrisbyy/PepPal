import SwiftUI
import UIKit

/// Lightweight share sheet wrapper that previews the captured Home screenshot
/// and exposes a `ShareLink` plus a Save-to-Photos action. Presented after the
/// debug capture button finishes rendering.
struct ScreenshotShareSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var savedToPhotos: Bool = false
    @State private var saveError: String? = nil

    private var uiImage: UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let img = uiImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                            )
                            .padding(.horizontal)
                    } else {
                        ProgressView().padding()
                    }

                    if let img = uiImage {
                        VStack(spacing: 10) {
                            ShareLink(item: url, preview: SharePreview("Home screenshot", image: Image(uiImage: img))) {
                                Label("Share or Save", systemImage: "square.and.arrow.up")
                                    .font(.system(.body, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                                    .foregroundStyle(.white)
                            }

                            Button {
                                saveToPhotos(img)
                            } label: {
                                Label(savedToPhotos ? "Saved to Photos" : "Save to Photos",
                                      systemImage: savedToPhotos ? "checkmark.circle.fill" : "photo.badge.plus")
                                    .font(.system(.body, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(PepTheme.cardSurface, in: .rect(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                                    )
                                    .foregroundStyle(PepTheme.textPrimary)
                            }
                            .disabled(savedToPhotos)
                        }
                        .padding(.horizontal)
                    }

                    if let saveError {
                        Text(saveError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    Text("File: \(url.lastPathComponent)")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Home Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func saveToPhotos(_ image: UIImage) {
        let saver = PhotoSaver { error in
            Task { @MainActor in
                if let error {
                    saveError = error.localizedDescription
                } else {
                    savedToPhotos = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
        UIImageWriteToSavedPhotosAlbum(image, saver, #selector(PhotoSaver.image(_:didFinishSavingWithError:contextInfo:)), nil)
        // Retain saver until callback fires.
        objc_setAssociatedObject(image, &PhotoSaver.assocKey, saver, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private final class PhotoSaver: NSObject {
    nonisolated(unsafe) static var assocKey: UInt8 = 0
    let completion: (Error?) -> Void
    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion(error)
    }
}
