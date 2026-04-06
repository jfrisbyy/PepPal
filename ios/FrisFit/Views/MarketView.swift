import SwiftUI

struct MarketView: View {
    @State private var viewModel = MarketViewModel()
    @State private var heroPage: Int = 0
    @State private var heroTimer: Timer?
    @State private var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    SkeletonMarketView()
                        .padding(.top, 8)
                        .transition(.opacity)
                } else {
                VStack(spacing: 24) {
                    heroCarousel
                    categorySection(title: "Trending This Week", programs: viewModel.trendingPrograms)
                    categorySection(title: "Top Rated Splits", programs: viewModel.topRatedSplits)
                    categorySection(title: "30-Day Challenges", programs: viewModel.challenges)
                    categorySection(title: "Nutrition Plans", programs: viewModel.nutritionPlans)
                    categorySection(title: "Complete Bundles", programs: viewModel.bundles)
                }
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Market")
            
            .searchable(text: $viewModel.searchText, prompt: "Search programs, plans & creators")
            .navigationDestination(for: MarketProgram.self) { program in
                MarketProgramDetailView(program: program, viewModel: viewModel)
            }
            .navigationDestination(for: MarketCreator.self) { creator in
                CreatorProfileView(creator: creator, viewModel: viewModel)
            }
        }
        .onAppear {
            startHeroTimer()
            if isLoading {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isLoading = false
                    }
                }
            }
        }
        .onDisappear { heroTimer?.invalidate() }
    }

    private var heroCarousel: some View {
        let featured = viewModel.featuredPrograms
        return TabView(selection: $heroPage) {
            ForEach(Array(featured.enumerated()), id: \.element.id) { index, program in
                NavigationLink(value: program) {
                    heroCard(program: program)
                }
                .buttonStyle(.plain)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 320)
    }

    private func heroCard(program: MarketProgram) -> some View {
        let colors = program.gradientColors
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: colors.map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: .black.opacity(0.8), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    itemTypeBadge(program.itemType)
                    Text(program.difficulty.rawValue)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text(program.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("by \(program.creatorName)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 12) {
                    ratingStars(program.rating)
                    Text("\(program.reviewCount) reviews")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("\(program.totalFP) FP")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .padding(20)

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: program.iconName)
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.08))
                        .padding(20)
                }
                Spacer()
            }
        }
        .clipShape(.rect(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    private func categorySection(title: String, programs: [MarketProgram]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(programs) { program in
                        NavigationLink(value: program) {
                            marketCard(program: program)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 16)
            .scrollIndicators(.hidden)
        }
    }

    private func marketCard(program: MarketProgram) -> some View {
        let colors = program.gradientColors
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: colors.map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.2),
                        .init(color: .black.opacity(0.6), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image(systemName: program.iconName)
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(10)
            }
            .frame(height: 110)
            .overlay(alignment: .top) {
                topAccentBorder(for: program.itemType)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(program.creatorName)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)

                HStack(spacing: 4) {
                    ratingStars(program.rating, size: .caption2)
                    Spacer()
                    if program.totalFP > 0 {
                        Text("\(program.totalFP) FP")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PepTheme.teal)
                    }
                }
            }
            .padding(10)
            .background(PepTheme.cardSurface)
        }
        .frame(width: 160)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    private func topAccentBorder(for type: MarketItemType) -> some View {
        Group {
            switch type {
            case .workoutSplit:
                PepTheme.teal.frame(height: 3)
            case .timedProgram:
                PepTheme.amber.frame(height: 3)
            case .nutritionPlan:
                Color.green.frame(height: 3)
            case .bundle:
                LinearGradient(colors: [PepTheme.teal, PepTheme.amber, PepTheme.violet], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 3)
            }
        }
    }

    private func itemTypeBadge(_ type: MarketItemType) -> some View {
        let color: Color = switch type {
        case .workoutSplit: PepTheme.teal
        case .timedProgram: PepTheme.amber
        case .nutritionPlan: .green
        case .bundle: PepTheme.violet
        }
        return Text(type.rawValue)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func ratingStars(_ rating: Double, size: Font = .caption) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: Double(star) <= rating ? "star.fill" : (Double(star) - 0.5 <= rating ? "star.leadinghalf.filled" : "star"))
                    .font(size)
                    .foregroundStyle(.yellow)
            }
            Text(String(format: "%.1f", rating))
                .font(size.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func startHeroTimer() {
        heroTimer?.invalidate()
        heroTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            Task { @MainActor in
                let count = viewModel.featuredPrograms.count
                guard count > 0 else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    heroPage = (heroPage + 1) % count
                }
            }
        }
    }
}

extension MarketProgram: Hashable {
    nonisolated static func == (lhs: MarketProgram, rhs: MarketProgram) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension MarketCreator: Hashable {
    nonisolated static func == (lhs: MarketCreator, rhs: MarketCreator) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
