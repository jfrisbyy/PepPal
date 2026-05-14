import UIKit
import SwiftUI

/// Walks the live UIKit hierarchy to find the Home screen's `UIScrollView`
/// and renders its full `contentSize` into a single tall PNG. Used by the
/// screenshot-mode debug capture button so we can produce one big marketing
/// image at native resolution.
@MainActor
enum HomeScreenshotCapturer {

    static func captureHomeScrollView() -> UIImage? {
        guard let scrollView = locateLargestScrollView() else { return nil }
        return render(scrollView: scrollView)
    }

    /// Writes the captured image to a temp PNG file suitable for `ShareLink`
    /// / `UIActivityViewController`. Returns the file URL.
    static func writeTempPNG(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        let name = "Home-\(f.string(from: Date())).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private static func locateLargestScrollView() -> UIScrollView? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }.filter { $0.isKeyWindow }
        guard let root = windows.first?.rootViewController?.view else { return nil }

        var best: UIScrollView?
        var bestArea: CGFloat = 0
        collect(in: root) { sv in
            let area = sv.contentSize.width * sv.contentSize.height
            if area > bestArea {
                bestArea = area
                best = sv
            }
        }
        return best
    }

    private static func collect(in view: UIView, _ found: (UIScrollView) -> Void) {
        if let sv = view as? UIScrollView, sv.window != nil, sv.bounds.width > 0 {
            found(sv)
        }
        for sub in view.subviews { collect(in: sub, found) }
    }

    private static func render(scrollView: UIScrollView) -> UIImage? {
        let savedOffset = scrollView.contentOffset
        let savedFrame = scrollView.frame
        let savedShowsV = scrollView.showsVerticalScrollIndicator
        let savedShowsH = scrollView.showsHorizontalScrollIndicator

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        // Expand the scrollview's frame to its full content so every laid-out
        // subview ends up inside the rendered region.
        let contentSize = CGSize(
            width: max(scrollView.contentSize.width, scrollView.bounds.width),
            height: max(scrollView.contentSize.height, scrollView.bounds.height)
        )
        scrollView.contentOffset = .zero
        scrollView.frame = CGRect(origin: scrollView.frame.origin, size: contentSize)
        scrollView.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: contentSize, format: format)

        let image = renderer.image { ctx in
            // Paint app background so areas behind transparent cards aren't pure black.
            UIColor(PepTheme.background).setFill()
            ctx.fill(CGRect(origin: .zero, size: contentSize))
            scrollView.drawHierarchy(in: CGRect(origin: .zero, size: contentSize), afterScreenUpdates: true)
        }

        scrollView.contentOffset = savedOffset
        scrollView.frame = savedFrame
        scrollView.showsVerticalScrollIndicator = savedShowsV
        scrollView.showsHorizontalScrollIndicator = savedShowsH
        return image
    }
}
