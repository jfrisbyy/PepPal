import SwiftUI
import UIKit

/// Renders the signed-in user's avatar (or initials fallback) into UIImages
/// sized for the bottom tab bar. ContentView observes this store and feeds
/// the rendered icons into the Profile `Tab`'s label.
@MainActor
@Observable
final class ProfileTabAvatarStore {
    static let shared = ProfileTabAvatarStore()

    /// Unselected tab icon (no ring). `nil` means "fall back to SF Symbol".
    var icon: UIImage?
    /// Selected tab icon (with teal ring). `nil` means "fall back to SF Symbol".
    var selectedIcon: UIImage?

    private var lastAvatarURL: String?
    private var lastInitials: String = ""
    private var lastColorKey: String = ""
    private var loadTask: Task<Void, Never>?

    /// Tab bar icons are rendered around 25–28pt; we draw at 28pt to leave
    /// a touch of breathing room for the selected-state ring.
    private let renderSize: CGFloat = 28

    private init() {}

    /// Update the rendered tab icons. Cheap to call repeatedly — bails out
    /// early when nothing relevant changed.
    func update(avatarURL: String?, initials: String, color: Color, colorKey: String?) {
        let trimmedURL = avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURL = (trimmedURL?.isEmpty ?? true) ? nil : trimmedURL
        let key = colorKey ?? ""
        let needsRefresh = normalizedURL != lastAvatarURL
            || initials != lastInitials
            || key != lastColorKey
            || icon == nil
        guard needsRefresh else { return }

        lastAvatarURL = normalizedURL
        lastInitials = initials
        lastColorKey = key

        loadTask?.cancel()

        // Always start with an initials placeholder so the tab bar updates
        // immediately, before any network fetch resolves.
        let placeholder = renderInitials(initials: initials, color: color)
        icon = placeholder.normal
        selectedIcon = placeholder.selected

        guard let urlString = normalizedURL, let url = URL(string: urlString) else { return }

        loadTask = Task { [weak self, renderSize] in
            guard let downloaded = await Self.fetchImage(url: url, targetSize: renderSize) else { return }
            if Task.isCancelled { return }
            guard let self else { return }
            let rendered = self.renderAvatar(image: downloaded)
            if Task.isCancelled { return }
            self.icon = rendered.normal
            self.selectedIcon = rendered.selected
        }
    }

    nonisolated private static func fetchImage(url: URL, targetSize: CGFloat) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    // MARK: - Rendering

    private func renderInitials(initials: String, color: Color) -> (normal: UIImage, selected: UIImage) {
        let normal = drawCircle(size: renderSize, ring: false) { rect, _ in
            UIColor(color).setFill()
            UIBezierPath(ovalIn: rect).fill()
            drawInitials(initials, in: rect)
        }
        let selected = drawCircle(size: renderSize, ring: true) { rect, _ in
            UIColor(color).setFill()
            UIBezierPath(ovalIn: rect).fill()
            drawInitials(initials, in: rect)
        }
        return (normal, selected)
    }

    private func renderAvatar(image: UIImage) -> (normal: UIImage, selected: UIImage) {
        let normal = drawCircle(size: renderSize, ring: false) { rect, _ in
            drawAspectFill(image: image, in: rect)
        }
        let selected = drawCircle(size: renderSize, ring: true) { rect, _ in
            drawAspectFill(image: image, in: rect)
        }
        return (normal, selected)
    }

    private func drawCircle(
        size: CGFloat,
        ring: Bool,
        body: (CGRect, CGContext) -> Void
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let inset: CGFloat = ring ? 2.5 : 0
            let circleRect = bounds.insetBy(dx: inset, dy: inset)

            cg.saveGState()
            cg.addEllipse(in: circleRect)
            cg.clip()
            body(circleRect, cg)
            cg.restoreGState()

            if ring {
                let ringRect = bounds.insetBy(dx: 0.9, dy: 0.9)
                cg.addEllipse(in: ringRect)
                cg.setStrokeColor(UIColor(PepTheme.teal).cgColor)
                cg.setLineWidth(1.6)
                cg.strokePath()
            }
        }
        return image.withRenderingMode(.alwaysOriginal)
    }

    private func drawInitials(_ initials: String, in rect: CGRect) {
        let text = initials.isEmpty ? "?" : initials
        let font = UIFont.systemFont(ofSize: rect.height * 0.42, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()
        let origin = CGPoint(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2
        )
        attrStr.draw(at: origin)
    }

    private func drawAspectFill(image: UIImage, in rect: CGRect) {
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }
        let scale = max(rect.width / imgSize.width, rect.height / imgSize.height)
        let drawSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(in: drawRect)
    }
}
