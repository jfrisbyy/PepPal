import SwiftUI

struct ProgressPhotoComparisonView: View {
    let photos: [ProgressPhoto]

    @State private var leftIndex: Int = 0
    @State private var rightIndex: Int = 0

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if photos.count < 2 {
                    emptyState
                } else {
                    comparisonView
                    pickerRow(title: "Before", index: $leftIndex)
                    pickerRow(title: "After", index: $rightIndex)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Compare Photos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if photos.count >= 2 {
                leftIndex = photos.count - 1
                rightIndex = 0
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 40))
                .foregroundStyle(PepTheme.teal.opacity(0.5))
            Text("Add at least two progress photos to compare them side-by-side.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }

    private var comparisonView: some View {
        HStack(spacing: 8) {
            photoPane(photo: photos[leftIndex], label: "Before")
            photoPane(photo: photos[rightIndex], label: "After")
        }
    }

    private func photoPane(photo: ProgressPhoto, label: String) -> some View {
        VStack(spacing: 4) {
            Color(PepTheme.elevated)
                .frame(height: 360)
                .overlay {
                    if let urlStr = photo.photoUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            } else {
                                ProgressView()
                            }
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    Text(label)
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .clipShape(.capsule)
                        .padding(8)
                }

            Text(dateFormatter.string(from: photo.date))
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func pickerRow(title: String, index: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { idx, photo in
                        Button {
                            index.wrappedValue = idx
                        } label: {
                            Color(PepTheme.elevated)
                                .frame(width: 58, height: 58)
                                .overlay {
                                    if let urlStr = photo.photoUrl, let url = URL(string: urlStr) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                                            }
                                        }
                                    }
                                }
                                .clipShape(.rect(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(index.wrappedValue == idx ? PepTheme.teal : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }
}
