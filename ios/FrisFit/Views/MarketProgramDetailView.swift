import SwiftUI

struct MarketProgramDetailView: View {
    let program: MarketProgram
    let viewModel: MarketViewModel

    @State private var selectedTab: DetailTab = .overview

    nonisolated enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case schedule = "Schedule"
        case reviews = "Reviews"
        case creator = "Creator"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader
                    statsBar
                    tabSelector
                    tabContent
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)

            bottomButton
        }
        .background(FrisTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        
    }

    private var heroHeader: some View {
        let colors = program.gradientColors
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: colors.map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .frame(height: 280)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.2),
                    .init(color: .black.opacity(0.85), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)

            Image(systemName: program.iconName)
                .font(.system(size: 100))
                .foregroundStyle(.white.opacity(0.06))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(24)

            VStack(alignment: .leading, spacing: 8) {
                itemTypeBadge(program.itemType)

                Text(program.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                NavigationLink(value: viewModel.creatorFor(id: program.creatorId)) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("by \(program.creatorName)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                HStack(spacing: 12) {
                    ratingView
                    Text("(\(program.reviewCount))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(20)
        }
    }

    private var ratingView: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: Double(star) <= program.rating ? "star.fill" : (Double(star) - 0.5 <= program.rating ? "star.leadinghalf.filled" : "star"))
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            Text(String(format: "%.1f", program.rating))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: "\(program.durationWeeks)w", label: "Duration")
            statDivider
            statItem(value: program.difficulty.rawValue, label: "Level")
            statDivider
            statItem(value: program.equipment, label: "Equipment")
            statDivider
            statItem(value: "\(program.totalFP)", label: "Total FP", valueColor: FrisTheme.cyan)
        }
        .padding(.vertical, 14)
        .background(FrisTheme.cardSurface)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(width: 1, height: 32)
    }

    private func statItem(value: String, label: String, valueColor: Color = FrisTheme.textPrimary) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? FrisTheme.cyan : FrisTheme.textSecondary)
                        Rectangle()
                            .fill(selectedTab == tab ? FrisTheme.cyan : .clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
        .background(FrisTheme.cardSurface)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .schedule:
            scheduleContent
        case .reviews:
            reviewsContent
        case .creator:
            creatorContent
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("About This Program")
                        .font(.headline)
                        .foregroundStyle(FrisTheme.textPrimary)
                    Text(program.overview)
                        .font(.body)
                        .foregroundStyle(FrisTheme.textSecondary)
                        .lineSpacing(4)
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's Included")
                        .font(.headline)
                        .foregroundStyle(FrisTheme.textPrimary)

                    includeRow(icon: "calendar", text: "\(program.durationWeeks) weeks, \(program.daysPerWeek) days/week")
                    includeRow(icon: "figure.strengthtraining.traditional", text: "Detailed exercise instructions")
                    includeRow(icon: "chart.line.uptrend.xyaxis", text: "Progressive overload built in")
                    includeRow(icon: "bell.badge", text: "Rest timer recommendations")
                    if program.itemType == .bundle || program.itemType == .nutritionPlan {
                        includeRow(icon: "fork.knife", text: "Nutrition guidelines included")
                    }
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Best For")
                        .font(.headline)
                        .foregroundStyle(FrisTheme.textPrimary)
                    HStack(spacing: 8) {
                        tagChip(program.difficulty.rawValue)
                        tagChip(program.itemType.rawValue)
                        tagChip("\(program.daysPerWeek)x/week")
                    }
                }
            }
        }
        .padding(16)
    }

    private func includeRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(FrisTheme.cyan)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(FrisTheme.textPrimary)
        }
    }

    private func tagChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(FrisTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(FrisTheme.elevated)
            .clipShape(Capsule())
    }

    private var scheduleContent: some View {
        VStack(spacing: 12) {
            if program.scheduleSummary.isEmpty {
                sectionCard {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title)
                            .foregroundStyle(FrisTheme.cyan)
                        Text("Schedule Preview")
                            .font(.headline)
                            .foregroundStyle(FrisTheme.textPrimary)
                        Text("\(program.daysPerWeek) training days per week for \(program.durationWeeks) weeks. Get the program to see the full schedule.")
                            .font(.subheadline)
                            .foregroundStyle(FrisTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(program.scheduleSummary) { day in
                    sectionCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.dayName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(FrisTheme.cyan)
                                Text(day.focus)
                                    .font(.subheadline)
                                    .foregroundStyle(FrisTheme.textPrimary)
                            }
                            Spacer()
                            Text("\(day.exerciseCount) exercises")
                                .font(.caption)
                                .foregroundStyle(FrisTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(FrisTheme.elevated)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            let restDays = max(0, 7 - program.daysPerWeek)
            if restDays > 0 {
                sectionCard {
                    HStack(spacing: 10) {
                        Image(systemName: "bed.double.fill")
                            .foregroundStyle(FrisTheme.violet)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(restDays) Rest Day\(restDays > 1 ? "s" : "")")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FrisTheme.textPrimary)
                            Text("Active recovery recommended")
                                .font(.caption)
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
    }

    private var reviewsContent: some View {
        VStack(spacing: 12) {
            sectionCard {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", program.rating))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(FrisTheme.textPrimary)
                        ratingView
                        Text("\(program.reviewCount) ratings")
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        ratingBar(stars: 5, fill: 0.72)
                        ratingBar(stars: 4, fill: 0.18)
                        ratingBar(stars: 3, fill: 0.06)
                        ratingBar(stars: 2, fill: 0.03)
                        ratingBar(stars: 1, fill: 0.01)
                    }
                }
            }

            ForEach(program.reviews) { review in
                sectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(review.userName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FrisTheme.textPrimary)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                        Text(review.text)
                            .font(.subheadline)
                            .foregroundStyle(FrisTheme.textSecondary)
                            .lineSpacing(3)
                        Text(review.date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(FrisTheme.textSecondary.opacity(0.6))
                    }
                }
            }
        }
        .padding(16)
    }

    private func ratingBar(stars: Int, fill: Double) -> some View {
        HStack(spacing: 4) {
            Text("\(stars)")
                .font(.caption2)
                .foregroundStyle(FrisTheme.textSecondary)
                .frame(width: 12)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FrisTheme.elevated)
                    Capsule()
                        .fill(.yellow)
                        .frame(width: geo.size.width * fill)
                }
            }
            .frame(width: 120, height: 6)
        }
    }

    private var creatorContent: some View {
        VStack(spacing: 12) {
            if let creator = viewModel.creatorFor(id: program.creatorId) {
                sectionCard {
                    VStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(FrisTheme.cyan.opacity(0.6))

                        Text(creator.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FrisTheme.textPrimary)

                        Text(creator.bio)
                            .font(.subheadline)
                            .foregroundStyle(FrisTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)

                        HStack(spacing: 24) {
                            creatorStat(value: formatCount(creator.followerCount), label: "Followers")
                            creatorStat(value: "\(creator.programsPublished)", label: "Programs")
                            creatorStat(value: String(format: "%.1f", creator.averageRating), label: "Avg Rating")
                        }
                        .padding(.top, 4)

                        NavigationLink(value: creator) {
                            Text("View Full Profile")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FrisTheme.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(FrisTheme.cyan.opacity(0.12))
                                .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
    }

    private func creatorStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(FrisTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(FrisTheme.textSecondary)
        }
    }

    private var bottomButton: some View {
        Button {
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Get Program")
                    .fontWeight(.bold)
            }
            .font(.body)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(FrisTheme.cyan)
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.scalePrimary)
        .sensoryFeedback(.impact(weight: .medium), trigger: false)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: FrisTheme.background, location: 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func sectionCard(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    private func itemTypeBadge(_ type: MarketItemType) -> some View {
        let color: Color = switch type {
        case .workoutSplit: FrisTheme.cyan
        case .timedProgram: FrisTheme.amber
        case .nutritionPlan: .green
        case .bundle: FrisTheme.violet
        }
        return Text(type.rawValue)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}
