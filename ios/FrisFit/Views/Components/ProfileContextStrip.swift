import SwiftUI

/// Editorial "above-the-feed" strip shown at the top of the Posts tab on
/// any profile. Surfaces bio, active program / phase, member-since, and
/// social links so the unified header stays clean.
struct ProfileContextStrip: View {
    let bio: String
    let activeProgram: String?
    let phase: String?
    let memberSinceText: String?
    let socialLinks: [SocialLinkEntry]

    struct SocialLinkEntry: Identifiable {
        let platform: SocialPlatform
        let url: URL
        var id: String { platform.rawValue }
    }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 14) {
                if !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !metaLine.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(metaLine.indices, id: \.self) { idx in
                            if idx > 0 {
                                Text("·")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.45))
                            }
                            Text(metaLine[idx])
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                        }
                    }
                }

                if !socialLinks.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(socialLinks) { entry in
                            Link(destination: entry.url) {
                                Image(systemName: entry.platform.iconName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(entry.platform.color)
                                    .frame(width: 32, height: 32)
                                    .background(entry.platform.color.opacity(0.14))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().strokeBorder(entry.platform.color.opacity(0.35), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(entry.platform.displayName)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(height: 0.5)
            }
        }
    }

    private var hasContent: Bool {
        !bio.isEmpty || !metaLine.isEmpty || !socialLinks.isEmpty
    }

    private var metaLine: [String] {
        var parts: [String] = []
        if let activeProgram, !activeProgram.isEmpty {
            parts.append(activeProgram.uppercased())
        }
        if let phase, !phase.isEmpty {
            parts.append(phase.uppercased())
        }
        if let memberSinceText, !memberSinceText.isEmpty {
            parts.append(memberSinceText.uppercased())
        }
        return parts
    }
}
