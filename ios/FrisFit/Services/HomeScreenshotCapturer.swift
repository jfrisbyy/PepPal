import UIKit
import SwiftUI

/// Captures the Home screen's scrollable content as a single tall PNG.
///
/// Strategy: temporarily expand the scroll view's frame to its full
/// contentSize so every cell is laid out and rendered, then snapshot
/// the scroll view itself with `afterScreenUpdates: true`. This is far
/// more reliable than the window-tile approach for SwiftUI content,
/// which uses compositing-server backed layers that often render black
/// with `afterScreenUpdates: false`.
@MainActor
enum HomeScreenshotCapturer {

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

    /// Pick the on-screen scroll view that owns the home content — the
    /// largest scrollable-area scroll view in the key window.
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

    // MARK: - Render

    private static func render(scrollView: UIScrollView) async -> UIImage? {
        guard let window = scrollView.window else { return nil }

        // Save state
        let savedFrame = scrollView.frame
        let savedOffset = scrollView.contentOffset
        let savedShowsV = scrollView.showsVerticalScrollIndicator
        let savedShowsH = scrollView.showsHorizontalScrollIndicator
        let savedClipsSuper = scrollView.superview?.clipsToBounds ?? true
        let savedClips = scrollView.clipsToBounds
        let savedMasksToBounds = scrollView.superview?.layer.masksToBounds ?? true

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        // Make sure the scroll view starts at the top and has laid out
        // every visible child before we expand it.
        scrollView.setContentOffset(.zero, animated: false)
        scrollView.layoutIfNeeded()
        await waitForFrame()

        let contentSize = scrollView.contentSize
        guard contentSize.width > 0, contentSize.height > 0 else {
            // Restore
            scrollView.showsVerticalScrollIndicator = savedShowsV
            scrollView.showsHorizontalScrollIndicator = savedShowsH
            return nil
        }

        // Expand the scroll view's frame to its full content size so
        // every section is laid out into the layer tree at the same time.
        // SwiftUI's default ScrollView renders all children eagerly, so
        // this works without lazy-stack tricks.
        scrollView.superview?.clipsToBounds = false
        scrollView.superview?.layer.masksToBounds = false
        scrollView.clipsToBounds = false
        scrollView.frame = CGRect(
            x: savedFrame.minX,
            y: savedFrame.minY,
            width: contentSize.width,
            height: contentSize.height
        )
        scrollView.layoutIfNeeded()
        window.layoutIfNeeded()

        // Let SwiftUI commit the expanded layout into the layer tree.
        await waitForFrame()
        await waitForFrame()
        await waitForFrame()

        let scale = window.screen.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: contentSize, format: format)
        let image = renderer.image { ctx in
            UIColor(PepTheme.background).setFill()
            ctx.fill(CGRect(origin: .zero, size: contentSize))
            // `afterScreenUpdates: true` forces a commit before drawing.
            // This is what makes SwiftUI's compositing-server layers
            // render correctly into the bitmap instead of returning black.
            scrollView.drawHierarchy(
                in: CGRect(origin: .zero, size: contentSize),
                afterScreenUpdates: true
            )
        }

        // Restore
        scrollView.frame = savedFrame
        scrollView.clipsToBounds = savedClips
        scrollView.superview?.clipsToBounds = savedClipsSuper
        scrollView.superview?.layer.masksToBounds = savedMasksToBounds
        scrollView.layoutIfNeeded()
        scrollView.setContentOffset(savedOffset, animated: false)
        scrollView.showsVerticalScrollIndicator = savedShowsV
        scrollView.showsHorizontalScrollIndicator = savedShowsH

        return image
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
