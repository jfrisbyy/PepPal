import SwiftUI

/// Thin glowing band painted underneath the timeline rule for the duration of
/// the user's current activity streak. Color graduates with streak length:
/// soft accent → warm → golden as the user crosses 30 / 90 / 365.
struct JourneyStreakBand: View {
    let startX: CGFloat
    let endX: CGFloat
    let streakDays: Int

    private var width: CGFloat { max(0, endX - startX) }

    private var palette: [Color] {
        switch streakDays {
        case 0..<30:
            return [
                Color(red: 0/255, green: 201/255, blue: 167/255).opacity(0.35),
                Color(red: 0/255, green: 201/255, blue: 167/255).opacity(0.55)
            ]
        case 30..<90:
            return [
                Color(red: 255/255, green: 165/255, blue: 70/255).opacity(0.45),
                Color(red: 255/255, green: 200/255, blue: 90/255).opacity(0.65)
            ]
        case 90..<365:
            return [
                Color(red: 240/255, green: 170/255, blue: 30/255).opacity(0.55),
                Color(red: 255/255, green: 215/255, blue: 90/255).opacity(0.85)
            ]
        default:
            return [
                Color(red: 255/255, green: 200/255, blue: 50/255).opacity(0.7),
                Color(red: 255/255, green: 235/255, blue: 130/255).opacity(0.95)
            ]
        }
    }

    private var glowColor: Color {
        palette.last ?? .yellow
    }

    private var milestoneIcon: String? {
        if streakDays >= 365 { return "crown.fill" }
        if streakDays >= 90 { return "shield.checkered" }
        if streakDays >= 30 { return "flame.circle.fill" }
        if streakDays >= 7 { return "flame.fill" }
        return nil
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: palette,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 3)
                .shadow(color: glowColor.opacity(0.55), radius: 6)
                .offset(x: startX + width / 2 - width / 2)
                .position(x: startX + width / 2, y: 1.5)

            if let icon = milestoneIcon, width > 24 {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .heavy))
                    Text("\(streakDays)d")
                        .font(.system(size: 10, weight: .heavy))
                        .monospacedDigit()
                }
                .foregroundStyle(glowColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.black.opacity(0.5))
                        .overlay(Capsule().strokeBorder(glowColor.opacity(0.6), lineWidth: 0.6))
                )
                .shadow(color: glowColor.opacity(0.45), radius: 4)
                .position(x: endX - 4, y: -2)
            }
        }
        .frame(height: 12)
        .allowsHitTesting(false)
    }
}
