import SwiftUI

nonisolated enum PepTheme: Sendable {
    // MARK: - Canvas

    /// Primary canvas. Deep ink in dark, warm off-white in light.
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 8/255, green: 9/255, blue: 13/255, alpha: 1)        // ink black
            : UIColor(red: 248/255, green: 246/255, blue: 242/255, alpha: 1)   // warm off-white
    })

    /// Secondary canvas (slightly lifted from background).
    static let backgroundElevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 14/255, green: 16/255, blue: 22/255, alpha: 1)
            : UIColor(red: 252/255, green: 250/255, blue: 247/255, alpha: 1)
    })

    /// Card surface — used inside `GlassCard`.
    static let cardSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 22/255, green: 24/255, blue: 32/255, alpha: 1)
            : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
    })

    /// More elevated surface (sheets, popovers, second-level cards).
    static let elevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 30/255, green: 33/255, blue: 42/255, alpha: 1)
            : UIColor(red: 240/255, green: 238/255, blue: 233/255, alpha: 1)
    })

    // MARK: - Accent palette

    /// Signature accent — refined teal-cyan.
    static let teal = Color(red: 0/255, green: 196/255, blue: 173/255)
    /// Slightly cooler teal used for gradients with `teal`.
    static let tealDeep = Color(red: 0/255, green: 154/255, blue: 156/255)

    static let amber = Color(red: 255/255, green: 178/255, blue: 70/255)
    static let violet = Color(red: 145/255, green: 102/255, blue: 247/255)
    static let blue = Color(red: 86/255, green: 162/255, blue: 255/255)
    static let coral = Color(red: 255/255, green: 122/255, blue: 105/255)
    static let success = Color(red: 64/255, green: 200/255, blue: 132/255)
    static let warning = Color(red: 255/255, green: 178/255, blue: 70/255)
    static let danger = Color(red: 255/255, green: 96/255, blue: 92/255)

    @available(*, deprecated, renamed: "teal")
    static let cyan = teal

    // MARK: - Text

    static let textPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.94)
            : UIColor(red: 18/255, green: 20/255, blue: 26/255, alpha: 1).withAlphaComponent(0.92)
    })

    static let textSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.62)
            : UIColor(red: 18/255, green: 20/255, blue: 26/255, alpha: 1).withAlphaComponent(0.58)
    })

    static let textTertiary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.40)
            : UIColor(red: 18/255, green: 20/255, blue: 26/255, alpha: 1).withAlphaComponent(0.38)
    })

    // MARK: - Glass tokens

    /// Inner top highlight on glass cards (gives the "lifted" feel).
    static let glassHighlight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.white.withAlphaComponent(0.85)
    })

    static let glassBorderTop = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.12)
            : UIColor.black.withAlphaComponent(0.07)
    })

    static let glassBorderBottom = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.02)
            : UIColor.black.withAlphaComponent(0.02)
    })

    static let cardOverlay = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.03)
            : UIColor.black.withAlphaComponent(0.015)
    })

    static let shimmerHighlight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.black.withAlphaComponent(0.04)
    })

    static let separatorColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.08)
    })

    static let invertedText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 8/255, green: 9/255, blue: 13/255, alpha: 1)
            : UIColor.white
    })

    /// Adaptive shadow color that respects appearance.
    static let shadowColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.55)
            : UIColor.black.withAlphaComponent(0.10)
    })
}

// MARK: - Spacing & radius scale

nonisolated enum PepSpacing: Sendable {
    /// 4-pt grid.
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

nonisolated enum PepRadius: Sendable {
    /// Compact controls (chips, buttons).
    static let sm: CGFloat = 12
    /// Standard cards.
    static let md: CGFloat = 20
    /// Hero / sheet cards.
    static let lg: CGFloat = 28
}

// MARK: - Section accent tints (used for mesh backgrounds & accents)

nonisolated enum PepSection: Sendable {
    /// Compounds / protocols — cool cyan/teal.
    static let compound = PepTheme.teal
    /// Nutrition / meals — warm amber.
    static let nutrition = PepTheme.amber
    /// Training / activity — energetic coral.
    static let training = PepTheme.coral
    /// Analytics / data — calm blue.
    static let analytics = PepTheme.blue
    /// Social / community — violet.
    static let community = PepTheme.violet
}
