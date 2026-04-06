import SwiftUI

struct CreatorProfileView: View {
    let creator: MarketCreator
    let viewModel: MarketViewModel

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                statsRow
                programsGrid
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(FrisTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FrisTheme.cyan.opacity(0.3), FrisTheme.violet.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: creator.avatarSystemName)
                    .font(.system(size: 44))
                    .foregroundStyle(FrisTheme.cyan.opacity(0.7))
            }

            Text(creator.name)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(FrisTheme.textPrimary)

            Text(creator.bio)
                .font(.subheadline)
                .foregroundStyle(FrisTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)

            Button {
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Follow")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(FrisTheme.cyan)
                .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.top, 16)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            creatorStatItem(value: formatCount(creator.followerCount), label: "Followers")
            statDivider
            creatorStatItem(value: "\(creator.programsPublished)", label: "Programs")
            statDivider
            creatorStatItem(value: String(format: "%.1f", creator.averageRating), label: "Avg Rating", valueColor: .yellow)
        }
        .padding(.vertical, 14)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 16)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(width: 1, height: 32)
    }

    private func creatorStatItem(value: String, label: String, valueColor: Color = FrisTheme.textPrimary) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline)
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption2)
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var programsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Programs")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(FrisTheme.textPrimary)
                .padding(.horizontal, 16)

            let programs = viewModel.programsBy(creatorId: creator.id)

            if programs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title)
                        .foregroundStyle(FrisTheme.textSecondary)
                    Text("No programs yet")
                        .font(.subheadline)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(programs) { program in
                        NavigationLink(value: program) {
                            creatorProgramCard(program: program)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func creatorProgramCard(program: MarketProgram) -> some View {
        let colors = program.gradientColors
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: colors.map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.2),
                        .init(color: .black.opacity(0.5), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image(systemName: program.iconName)
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(8)
            }
            .frame(height: 100)
            .overlay(alignment: .top) {
                accentBorder(for: program.itemType)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", program.rating))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Text("\(program.durationWeeks)w")
                        .font(.caption2)
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
            .padding(10)
            .background(FrisTheme.cardSurface)
        }
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }

    private func accentBorder(for type: MarketItemType) -> some View {
        Group {
            switch type {
            case .workoutSplit:
                FrisTheme.cyan.frame(height: 3)
            case .timedProgram:
                FrisTheme.amber.frame(height: 3)
            case .nutritionPlan:
                Color.green.frame(height: 3)
            case .bundle:
                LinearGradient(colors: [FrisTheme.cyan, FrisTheme.amber, FrisTheme.violet], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 3)
            }
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}
