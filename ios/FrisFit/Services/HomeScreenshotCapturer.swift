import UIKit
import SwiftUI

/// Captures the Home screen's scrollable content as a single tall PNG.
///
/// SwiftUI scroll content does not re-render its layers within a single
/// runloop pass, so the classic "set contentOffset → drawHierarchy in a
/// renderer block" pattern produces a blank image. Instead this walks the
/// scroll view one viewport at a time, awaiting an actual frame between
/// each step, and snapshots the window's rendered pixels for the area the
/// scroll view occupies. The tiles are composited into one tall image.
@MainActor
enum HomeScreenshotCapturer {

    /// Async because we need real frame ticks between scroll steps for
    /// SwiftUI to flush new content into the layer tree before we snapshot.
    static func captureHomeScrollView() async -> UIImage? {
        guard let scrollView = locateHomeScrollView() else { return nil }
        return await render(scrollView: scrollView)
    }

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

    // MARK: - Locate

    /// Pick the on-screen scroll view that owns the home content. We choose
    /// the largest scrollable-area scroll view in the key window — Home's
    /// vertical ScrollView is by far the tallest content.
    private static func locateHomeScrollView() -> UIScrollView? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }.filter { $0.isKeyWindow }
        guard let root = windows.first?.rootViewController?.view else { return nil }

        var best: UIScrollView?
        var bestScore: CGFloat = 0
        collect(in: root) { sv in
            // Only consider scroll views that are actually visible and
            // currently scrollable (vertical content larger than viewport).
            guard sv.window != nil, sv.bounds.width > 0, sv.bounds.height > 0 else { return }
            let score = sv.contentSize.height
            if score > bestScore {
                bestScore = score
                best = sv
            }
        }
        return best
    }

    private static func collect(in view: UIView, _ found: (UIScrollView) -> Void) {
        if let sv = view as? UIScrollView { found(sv) }
        for sub in view.subviews { collect(in: sub, found) }
    }

    // MARK: - Render

    private static func render(scrollView: UIScrollView) async -> UIImage? {
        guard let window = scrollView.window else { return nil }

        let savedOffset = scrollView.contentOffset
        let savedShowsV = scrollView.showsVerticalScrollIndicator
        let savedShowsH = scrollView.showsHorizontalScrollIndicator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        // Frame of the scroll view in window coordinates — this is the
        // region we'll snapshot from the window per tile.
        let scrollRectInWindow = scrollView.convert(scrollView.bounds, to: window)

        // Total content extent, clamped to at least one viewport.
        let viewport = scrollView.bounds.size
        let totalHeight = max(scrollView.contentSize.height, viewport.height)
        let totalWidth = max(scrollView.contentSize.width, viewport.width)
        guard totalWidth > 0, totalHeight > 0 else { return nil }

        let scale = window.screen.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let canvasSize = CGSize(width: totalWidth, height: totalHeight)
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        // Compute tile offsets up front.
        var offsets: [CGFloat] = []
        var y: CGFloat = 0
        while y < totalHeight {
            offsets.append(y)
            y += viewport.height
        }

        // Snapshot each tile from the window after letting SwiftUI render.
        var tiles: [(offset: CGFloat, image: UIImage)] = []
        for off in offsets {
            scrollView.setContentOffset(CGPoint(x: 0, y: off), animated: false)
            scrollView.layoutIfNeeded()
            window.layoutIfNeeded()

            // Wait for two display links so SwiftUI flushes new content
            // into the layer tree before we capture.
            await waitForFrame()
            await waitForFrame()

            let tileFormat = UIGraphicsImageRendererFormat()
            tileFormat.scale = scale
            tileFormat.opaque = true
            let tileRenderer = UIGraphicsImageRenderer(size: scrollRectInWindow.size, format: tileFormat)
            let tile = tileRenderer.image { _ in
                // Draw the window, translated so the scroll-view region
                // lands at the origin of the tile.
                let drawRect = CGRect(
                    x: -scrollRectInWindow.origin.x,
                    y: -scrollRectInWindow.origin.y,
                    width: window.bounds.width,
                    height: window.bounds.height
                )
                window.drawHierarchy(in: drawRect, afterScreenUpdates: false)
            }
            tiles.append((off, tile))
        }

        // Restore scroll state before compositing so the user sees their
        // original position again.
        scrollView.setContentOffset(savedOffset, animated: false)
        scrollView.showsVerticalScrollIndicator = savedShowsV
        scrollView.showsHorizontalScrollIndicator = savedShowsH

        // Composite tiles into the final tall canvas.
        let final = renderer.image { ctx in
            UIColor(PepTheme.background).setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))
            for tile in tiles {
                let drawHeight = min(viewport.height, totalHeight - tile.offset)
                let src = CGRect(
                    x: 0,
                    y: 0,
                    width: scrollRectInWindow.width,
                    height: drawHeight
                )
                let dst = CGRect(
                    x: 0,
                    y: tile.offset,
                    width: scrollRectInWindow.width,
                    height: drawHeight
                )
                if let cg = tile.image.cgImage?.cropping(to: CGRect(
                    x: 0,
                    y: 0,
                    width: src.width * scale,
                    height: src.height * scale
                )) {
                    UIImage(cgImage: cg, scale: scale, orientation: .up).draw(in: dst)
                } else {
                    tile.image.draw(in: dst)
                }
            }
        }
        return final
    }

    /// Awaits the next CADisplayLink tick so SwiftUI has a chance to
    /// commit pending layer updates before we snapshot.
    private static func waitForFrame() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let proxy = DisplayLinkProxy { cont.resume() }
            proxy.start()
        }
    }
}

@MainActor
private final class DisplayLinkProxy: NSObject {
    private var link: CADisplayLink?
    private var fired = false
    private let onFire: () -> Void
    private var retainSelf: DisplayLinkProxy?

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
    }

    func start() {
        retainSelf = self
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick() {
        guard !fired else { return }
        fired = true
        link?.invalidate()
        link = nil
        onFire()
        retainSelf = nil
    }
}
