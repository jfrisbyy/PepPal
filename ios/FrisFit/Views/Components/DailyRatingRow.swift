import SwiftUI

struct DailyRatingRow: View {
    let label: String
    let icon: String
    let category: String
    let viewModel: ProtocolDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(PepTheme.textSecondary)
                Text(label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if let rating = viewModel.todayRating(for: category) {
                    Text("\(rating)/10")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(ratingColor(rating))
                }
            }

            HStack(spacing: 3) {
                ForEach(1...10, id: \.self) { value in
                    let isSelected = viewModel.todayRating(for: category) ?? 0 >= value
                    Button {
                        viewModel.addRating(category: category, value: value)
                    } label: {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected ? ratingColor(value) : PepTheme.elevated)
                            .frame(height: 24)
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.todayRating(for: category))
                }
            }
        }
    }

    private func ratingColor(_ value: Int) -> Color {
        if value <= 3 { return .green }
        if value <= 6 { return .yellow }
        if value <= 8 { return .orange }
        return .red
    }
}
