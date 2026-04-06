import SwiftUI

struct AchievementsView: View {
    let viewModel: ProfileViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progressHeader
                streakMilestonesSection

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.allAchievements) { badge in
                        AchievementCard(achievement: badge)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(FrisTheme.background.ignoresSafeArea())
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
        
    }

    private var progressHeader: some View {
        let totalCount = viewModel.allAchievements.count
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(FrisTheme.elevated, lineWidth: 6)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: totalCount > 0 ? Double(viewModel.unlockedCount) / Double(totalCount) : 0)
                    .stroke(FrisTheme.amber, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(viewModel.unlockedCount)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(FrisTheme.amber)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.unlockedCount) of \(totalCount)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(FrisTheme.textPrimary)
                Text("achievements unlocked")
                    .font(.subheadline)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var streakMilestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(FrisTheme.amber)
                Text("Streak Milestones")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
            }

            HStack(spacing: 8) {
                ForEach(StreakMilestone.allCases, id: \.rawValue) { milestone in
                    let reached = viewModel.streakManager.streakMilestonesReached.contains(milestone)
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(reached ? FrisTheme.amber.opacity(0.15) : FrisTheme.elevated)
                                .frame(width: 44, height: 44)
                            Image(systemName: milestone.badgeIcon)
                                .font(.system(size: 18))
                                .foregroundStyle(reached ? FrisTheme.amber : FrisTheme.textSecondary.opacity(0.3))
                        }
                        Text("\(milestone.rawValue)d")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(reached ? FrisTheme.amber : FrisTheme.textSecondary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }
}

private struct AchievementCard: View {
    let achievement: Achievement

    private var accentColor: Color {
        switch achievement.accentColor {
        case .cyan: FrisTheme.cyan
        case .amber: FrisTheme.amber
        case .violet: FrisTheme.violet
        case .green: Color.green
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? accentColor.opacity(0.15) : FrisTheme.elevated)
                    .frame(width: 52, height: 52)

                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(achievement.isUnlocked ? accentColor : FrisTheme.textSecondary.opacity(0.4))

                if !achievement.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(FrisTheme.textSecondary)
                        .offset(x: 18, y: 18)
                }
            }

            VStack(spacing: 4) {
                Text(achievement.name)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? FrisTheme.textPrimary : FrisTheme.textSecondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(achievement.description)
                    .font(.system(size: 10))
                    .foregroundStyle(FrisTheme.textSecondary.opacity(achievement.isUnlocked ? 0.8 : 0.4))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            if achievement.isUnlocked, let date = achievement.unlockedDate {
                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(accentColor.opacity(0.7))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            achievement.isUnlocked
                ? FrisTheme.cardSurface.overlay(accentColor.opacity(0.03))
                : FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay)
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    achievement.isUnlocked ? accentColor.opacity(0.15) : FrisTheme.glassBorderBottom,
                    lineWidth: 0.5
                )
        )
        .opacity(achievement.isUnlocked ? 1 : 0.65)
    }
}
