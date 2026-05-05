import SwiftUI

struct SportSelectorView: View {
    let onSelect: (Sport) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LOG SESSION")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("What did you play?")
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .kerning(-0.4)
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Sport.allCases) { sport in
                            SportCard(sport: sport) {
                                onSelect(sport)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Log Sport")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }
}

private struct SportCard: View {
    let sport: Sport
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(sport.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: sport.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(sport.color)
                }

                Text(sport.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [sport.color.opacity(0.2), PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
    }
}
