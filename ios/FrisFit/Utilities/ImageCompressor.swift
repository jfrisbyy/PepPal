import Foundation
import UIKit

/// Centralised image downsizing for any user-uploaded photo.
///
/// Goal: keep our Supabase Storage egress bill in check and keep upload latency
/// snappy on cellular. iPhone cameras produce 12 MB JPEGs; sending the raw
/// data is wasteful for avatars, banners, meal photos, and progress photos
/// that we never display at full resolution.
///
/// Usage:
/// ```swift
/// let data = ImageCompressor.compress(image, kind: .avatar)
/// ```
enum ImageCompressor {
    enum Kind {
        case avatar          // 512 x 512, q 0.85 → ~80 KB typical
        case banner          // 1600 x 600, q 0.82 → ~250 KB typical
        case feedPhoto       // 1600 long-edge, q 0.82 → ~400 KB typical
        case progressPhoto   // 1800 long-edge, q 0.82 → ~600 KB typical
        case mealPhoto       // 1280 long-edge, q 0.78 → ~250 KB typical
        case thumbnail       // 256 long-edge, q 0.7

        var maxDimension: CGFloat {
            switch self {
            case .avatar: return 512
            case .banner: return 1600
            case .feedPhoto: return 1600
            case .progressPhoto: return 1800
            case .mealPhoto: return 1280
            case .thumbnail: return 256
            }
        }

        var quality: CGFloat {
            switch self {
            case .avatar: return 0.85
            case .banner: return 0.82
            case .feedPhoto: return 0.82
            case .progressPhoto: return 0.82
            case .mealPhoto: return 0.78
            case .thumbnail: return 0.7
            }
        }
    }

    /// Resize + JPEG-compress. Returns nil if the image is unreadable.
    static func compress(_ image: UIImage, kind: Kind) -> Data? {
        let resized = downsize(image, maxDimension: kind.maxDimension) ?? image
        return resized.jpegData(compressionQuality: kind.quality)
    }

    /// Convenience for callers that already have raw `Data`.
    static func compress(data: Data, kind: Kind) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return compress(image, kind: kind)
    }

    /// Downsize the longest edge to `maxDimension` while preserving aspect.
    /// Returns the original image if it's already smaller than the target.
    static func downsize(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
