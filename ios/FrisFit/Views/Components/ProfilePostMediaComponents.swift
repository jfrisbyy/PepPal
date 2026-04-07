import SwiftUI

struct ProfilePostMediaGrid: View {
    let mediaUrls: [String]

    var body: some View {
        if mediaUrls.count == 1 {
            singleImage(mediaUrls[0])
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(mediaUrls, id: \.self) { url in
                        multiImage(url)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func singleImage(_ urlString: String) -> some View {
        Color(.tertiarySystemFill)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        case .empty:
                            ProgressView()
                                .tint(PepTheme.teal)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 10))
    }

    private func multiImage(_ urlString: String) -> some View {
        Color(.tertiarySystemFill)
            .frame(width: 180, height: 180)
            .overlay {
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        case .empty:
                            ProgressView()
                                .tint(PepTheme.teal)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 10))
    }
}

struct ProfilePostAudioBadge: View {
    let duration: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.teal)

            Text(formatDuration(duration))
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    private func formatDuration(_ d: Double) -> String {
        let minutes = Int(d) / 60
        let seconds = Int(d) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
