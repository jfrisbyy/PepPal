import SwiftUI

struct ProfileAvatarView: View {
    let avatarUrl: String?
    let initials: String
    let avatarColor: Color
    let size: CGFloat

    var body: some View {
        if let urlString = avatarUrl, let url = URL(string: urlString), !urlString.isEmpty {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [avatarColor.opacity(0.8), PepTheme.violet.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                        case .failure:
                            initialsView
                        default:
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                    }
                }
                .clipShape(Circle())
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [avatarColor.opacity(0.8), PepTheme.violet.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay { initialsView }
        }
    }

    private var initialsView: some View {
        Text(initials)
            .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }
}
