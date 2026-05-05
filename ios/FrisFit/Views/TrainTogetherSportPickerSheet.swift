import SwiftUI

struct TrainTogetherSportPickerSheet: View {
    let friend: FriendStatSnapshot
    var onSelect: (BuddySport) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header

                    VStack(spacing: 10) {
                        ForEach(BuddySport.allCases) { sport in
                            sportRow(sport)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Train Together")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Pick a session")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("You and \(friend.user.name.components(separatedBy: " ").first ?? friend.user.name) will start synced.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func sportRow(_ sport: BuddySport) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
            onSelect(sport)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint(for: sport).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: sport.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint(for: sport))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(sport.title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle(for: sport))
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .background(PepTheme.cardSurface, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func tint(for sport: BuddySport) -> Color {
        switch sport {
        case .strength: return PepTheme.teal
        case .run: return PepTheme.amber
        case .cycle: return PepTheme.violet
        case .hiit: return .red
        case .walk: return .green
        }
    }

    private func subtitle(for sport: BuddySport) -> String {
        switch sport {
        case .strength: return "Sets, reps, live progress"
        case .run: return "Distance and pace, synced"
        case .cycle: return "Distance and speed, synced"
        case .hiit: return "Freestyle rounds, synced"
        case .walk: return "Easy distance, synced timer"
        }
    }
}
