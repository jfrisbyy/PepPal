import UIKit
import SwiftUI

/// Captures the Home screen's scrollable content as a single tall PNG.
///
/// We tried two simpler approaches first and both produced blank/black
/// PNGs on real builds:
///
/// 1. `drawHierarchy(afterScreenUpdates:true)` on an oversized scroll view
///    expanded to its full contentSize — SwiftUI's compositing-server layers
///    don't commit for the off-screen portion, so everything below the
///    viewport renders black.
/// 2. `ImageRenderer` on the SwiftUI view — only works for views we own as
///    `some View`, not for the already-mounted hosting controller.
///
/// The reliable approach is **tile + stitch**: scroll the view in
/// viewport-sized steps, snapshot the on-screen window at each step (which
/// is always fully committed because it's the live screen), crop to the
/// scroll view's rect in window coordinates, and paste each tile into a
/// tall bitmap.
@MainActor
enum HomeScreenshotCapturer {

    static func captureHomeScrollView() async -> UIImage? {
        guard let scrollView = locateHomeScrollView(),
              let window = scrollView.window else { return nil }
        return await renderByTiling(scrollView: scrollView, window: window)
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

    /// Pick the on-screen scroll view that owns the home content — the
    /// scroll view in the key window with the tallest contentSize.
    private static func locateHomeScrollView() -> UIScrollView? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }.filter { $0.isKeyWindow }
        guard let root = windows.first?.rootViewController?.view else { return nil }

        var best: UIScrollView?
        var bestScore: CGFloat = 0
        collect(in: root) { sv in
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

    // MARK: - Render by tiling

    private static func renderByTiling(scrollView: UIScrollView, window: UIWindow) async -> UIImage? {
        // Save state
        let savedOffset = scrollView.contentOffset
        let savedShowsV = scrollView.showsVerticalScrollIndicator
        let savedShowsH = scrollView.showsHorizontalScrollIndicator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        // Reset to top, let SwiftUI commit any pending updates.
        scrollView.setContentOffset(.zero, animated: false)
        scrollView.layoutIfNeeded()
        await waitForFrames(3)

        let contentSize = scrollView.contentSize
        let viewport = scrollView.bounds.size
        guard contentSize.width > 0, contentSize.height > 0,
              viewport.width > 0, viewport.height > 0 else {
            restore(scrollView, offset: savedOffset, showsV: savedShowsV, showsH: savedShowsH)
            return nil
        }

        // Visible rect of the scroll view in window coordinates — this is
        // the slice of the screen we crop out of each window snapshot.
        let windowRect = scrollView.convert(scrollView.bounds, to: window)
        let scale = window.screen.scale

        // Output bitmap (tall image at native scale).
        let outSize = CGSize(width: viewport.width, height: contentSize.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: outSize, format: format)

        let image = renderer.image { ctx in
            UIColor(PepTheme.background).setFill()
            ctx.fill(CGRect(origin: .zero, size: outSize))
        }

        // We need to redraw into the same bitmap context with each tile,
        // so use a CGContext-backed approach instead.
        UIGraphicsBeginImageContextWithOptions(outSize, true, scale)
        defer { UIGraphicsEndImageContext() }
        guard let cg = UIGraphicsGetCurrentContext() else {
            restore(scrollView, offset: savedOffset, showsV: savedShowsV, showsH: savedShowsH)
            return image
        }
        // Background fill
        cg.setFillColor(UIColor(PepTheme.background).cgColor)
        cg.fill(CGRect(origin: .zero, size: outSize))

        // Iterate viewport-sized tiles.
        let step = viewport.height
        var y: CGFloat = 0
        let maxOffset = max(0, contentSize.height - viewport.height)

        while y < contentSize.height {
            // Clamp last offset so we don't bounce.
            let targetOffset = min(y, maxOffset)
            scrollView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: false)
            scrollView.layoutIfNeeded()
            // Two frames is the sweet spot for SwiftUI to commit layer
            // updates without making capture feel sluggish.
            await waitForFrames(2)

            // Snapshot the live window (this always works because it's
            // the actual on-screen content), then crop to the scroll
            // view's rect in window space.
            guard let tile = snapshotWindow(window, cropTo: windowRect, scale: scale) else {
                y += step
                continue
            }

            // Where in the output bitmap does this tile go?
            // The bottom of the visible viewport corresponds to:
            //   tileTopInContent = targetOffset
            // ...unless this is the final tile and we clamped — in which
            // case the tile shows content from targetOffset to
            // targetOffset+viewport, and we want to draw only the
            // portion we haven't already drawn (from y to contentHeight).
            let tileTopInContent = targetOffset
            let drawY = tileTopInContent
            // Flip into UIKit coords for drawing.
            let dest = CGRect(x: 0, y: drawY, width: viewport.width, height: viewport.height)

            // Use UIImage drawing so we stay in UIKit coord space.
            UIGraphicsPushContext(cg)
            tile.draw(in: dest)
            UIGraphicsPopContext()

            if targetOffset >= maxOffset { break }
            y += step
        }

        let stitched = UIGraphicsGetImageFromCurrentImageContext()

        restore(scrollView, offset: savedOffset, showsV: savedShowsV, showsH: savedShowsH)
        return stitched
    }

    /// Snapshot the entire window then crop to a given window-space rect.
    /// Window snapshots are reliable for SwiftUI because the layers being
    /// drawn are the live, on-screen, fully-committed render server layers.
    private static func snapshotWindow(_ window: UIWindow, cropTo rect: CGRect, scale: CGFloat) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        let full = renderer.image { _ in
            // afterScreenUpdates:false — the screen is already up to date,
            // and asking for an update here forces an extra commit cycle
            // that can race with our scroll offset change and produce a
            // blank frame for the very first tile.
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }

        // Crop to the scroll view's window rect.
        let scaledRect = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        guard let cg = full.cgImage?.cropping(to: scaledRect) else { return full }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }

    private static func restore(_ sv: UIScrollView, offset: CGPoint, showsV: Bool, showsH: Bool) {
        sv.setContentOffset(offset, animated: false)
        sv.showsVerticalScrollIndicator = showsV
        sv.showsHorizontalScrollIndicator = showsH
    }

    /// Awaits `count` CADisplayLink ticks so SwiftUI has a chance to
    /// commit pending layer updates before we snapshot.
    private static func waitForFrames(_ count: Int) async {
        for _ in 0..<max(1, count) {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                let proxy = DisplayLinkProxy { cont.resume() }
                proxy.start()
            }
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
