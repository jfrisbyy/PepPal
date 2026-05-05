import Foundation
import UIKit

nonisolated final class VialLabelImageStore: Sendable {
    static let shared = VialLabelImageStore()

    private let folderName = "VialLabels"

    private var folderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// Save an image and return the relative filename (UUID.jpg).
    @discardableResult
    func save(_ image: UIImage, quality: CGFloat = 0.8) -> String? {
        let resized = resize(image, maxDim: 1400) ?? image
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        let url = folderURL.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    func load(_ filename: String) -> UIImage? {
        let url = folderURL.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func delete(_ filename: String) {
        let url = folderURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    private func resize(_ image: UIImage, maxDim: CGFloat) -> UIImage? {
        let size = image.size
        let scale = min(1, maxDim / max(size.width, size.height))
        if scale >= 1 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return out
    }
}
