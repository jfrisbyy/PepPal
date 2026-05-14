import UIKit
import SwiftUI

/// Walks the live UIKit hierarchy to find the Home screen's `UIScrollView`
/// and renders its full `contentSize` into a single tall PNG by scrolling
/// through the content and stitching native-resolution viewport snapshots
/// together. Used by the screenshot-mode debug capture button.
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

    /// Tile-based capture: walk the scroll view from top to bottom one
    /// viewport at a time, snapshot each viewport with `drawHierarchy`, and
    /// composite into one tall image. This is reliable even for content
    /// outside the on-screen frame, where naively expanding the scroll
    /// view's frame produces a blank image.
    private static func render(scrollView: UIScrollView) -> UIImage? {
        let savedOffset = scrollView.contentOffset
        let savedShowsV = scrollView.showsVerticalScrollIndicator
        let savedShowsH = scrollView.showsHorizontalScrollIndicator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        let viewport = scrollView.bounds.size
        let totalSize = CGSize(
            width: max(scrollView.contentSize.width, viewport.width),
            height: max(scrollView.contentSize.height, viewport.height)
        )
        guard totalSize.width > 0, totalSize.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: totalSize, format: format)

        let image = renderer.image { ctx in
            UIColor(PepTheme.background).setFill()
            ctx.fill(CGRect(origin: .zero, size: totalSize))

            var y: CGFloat = 0
            while y < totalSize.height {
                let tileHeight = min(viewport.height, totalSize.height - y)
                scrollView.contentOffset = CGPoint(x: 0, y: y)
                scrollView.layoutIfNeeded()
                // Let the run loop flush so any newly visible cells/lazy
                // views finish laying out before the snapshot.
                RunLoop.current.run(until: Date().addingTimeInterval(0.04))

                let cg = ctx.cgContext
                cg.saveGState()
                cg.translateBy(x: 0, y: y)
                // Clip to the tile so adjacent floating chrome (if any)
                // doesn't bleed into neighboring tiles.
                cg.clip(to: CGRect(x: 0, y: 0, width: totalSize.width, height: tileHeight))
                scrollView.drawHierarchy(in: scrollView.bounds, afterScreenUpdates: true)
                cg.restoreGState()

                y += viewport.height
            }
        }

        scrollView.contentOffset = savedOffset
        scrollView.showsVerticalScrollIndicator = savedShowsV
        scrollView.showsHorizontalScrollIndicator = savedShowsH
        return image
    }
}
