import SwiftUI

struct OnboardingProgressBar: View {
    let activeChapter: OnboardingChapter
    let progressInChapter: Double

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingChapter.allCases, id: \.rawValue) { chapter in
                segment(for: chapter)
            }
        }
        .frame(height: 4)
    }

    private func segment(for chapter: OnboardingChapter) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PepTheme.elevated.opacity(0.6))
                Capsule()
                    .fill(PepTheme.teal)
                    .frame(width: geo.size.width * fillFraction(for: chapter))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: activeChapter)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: progressInChapter)
    }

    private func fillFraction(for chapter: OnboardingChapter) -> Double {
        if chapter.rawValue < activeChapter.rawValue { return 1 }
        if chapter.rawValue == activeChapter.rawValue { return max(0.08, min(progressInChapter, 1)) }
        return 0
    }
}
