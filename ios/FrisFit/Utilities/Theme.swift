import SwiftUI

nonisolated enum PepTheme: Sendable {
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1)
            : UIColor(red: 245/255, green: 245/255, blue: 248/255, alpha: 1)
    })

    static let cardSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 20/255, green: 20/255, blue: 26/255, alpha: 1)
            : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
    })

    static let elevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 28/255, green: 28/255, blue: 36/255, alpha: 1)
            : UIColor(red: 235/255, green: 235/255, blue: 240/255, alpha: 1)
    })

    static let teal = Color(red: 0, green: 201/255, blue: 167/255)
    static let amber = Color(red: 255/255, green: 184/255, blue: 0)
    static let violet = Color(red: 139/255, green: 92/255, blue: 246/255)
    static let blue = Color(red: 74/255, green: 158/255, blue: 255/255)

    @available(*, deprecated, renamed: "teal")
    static let cyan = teal

    static let textPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.9)
            : UIColor.black.withAlphaComponent(0.85)
    })

    static let textSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.6)
            : UIColor.black.withAlphaComponent(0.5)
    })

    static let glassBorderTop = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.06)
    })

    static let glassBorderBottom = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.02)
            : UIColor.black.withAlphaComponent(0.02)
    })

    static let cardOverlay = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.04)
            : UIColor.black.withAlphaComponent(0.02)
    })

    static let shimmerHighlight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.black.withAlphaComponent(0.04)
    })

    static let separatorColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.black.withAlphaComponent(0.08)
    })

    static let invertedText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1)
            : UIColor.white
    })
}
