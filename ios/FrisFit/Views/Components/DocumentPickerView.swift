import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .png, .jpeg, .heic, .image]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        nonisolated func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            Task { @MainActor in
                guard let url = urls.first else {
                    onCancel()
                    return
                }

                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }

                if let data = try? Data(contentsOf: url) {
                    let imageData: Data?
                    if url.pathExtension.lowercased() == "pdf" {
                        imageData = renderPDFToImage(data: data)
                    } else {
                        imageData = data
                    }

                    if let result = imageData {
                        onPick(result)
                    } else {
                        onCancel()
                    }
                } else {
                    onCancel()
                }
            }
        }

        nonisolated func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            Task { @MainActor in
                onCancel()
            }
        }

        nonisolated private func renderPDFToImage(data: Data) -> Data? {
            guard let provider = CGDataProvider(data: data as CFData),
                  let document = CGPDFDocument(provider),
                  let page = document.page(at: 1) else { return nil }

            let rect = page.getBoxRect(.mediaBox)
            let scale: CGFloat = 2.0
            let size = CGSize(width: rect.width * scale, height: rect.height * scale)

            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))

                let context = ctx.cgContext
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: scale, y: -scale)
                context.drawPDFPage(page)
            }

            return image.jpegData(compressionQuality: 0.85)
        }
    }
}
