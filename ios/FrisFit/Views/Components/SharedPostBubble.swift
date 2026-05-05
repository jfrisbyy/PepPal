import SwiftUI

/// Renders a `.post` direct-message attachment as a tappable post preview.
/// Tapping opens the post via the deep-link router so it shows in the feed.
struct SharedPostBubble: View {
    let attachment: DirectMessageAttachment
    let isFromMe: Bool

    var body: some View {
        Button {
            guard let id = attachment.postId else { return }
            DeepLinkRouter.shared.navigate(to: .post(id))
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isFromMe ? .white : PepTheme.teal)
                    .frame(width: 32, height: 32)
                    .background(
                        (isFromMe ? Color.white.opacity(0.18) : PepTheme.teal.opacity(0.15))
                    )
                    .clipShape(.circle)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SHARED POST")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(isFromMe ? .white.opacity(0.8) : PepTheme.textSecondary)
                    Text(attachment.previewText ?? "Open post")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(isFromMe ? .white : PepTheme.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 240, alignment: .leading)
            .background(
                isFromMe
                ? AnyShapeStyle(LinearGradient(colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(PepTheme.cardSurface)
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isFromMe ? Color.clear : PepTheme.separatorColor, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}
