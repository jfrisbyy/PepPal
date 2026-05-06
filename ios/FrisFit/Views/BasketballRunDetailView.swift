import SwiftUI

struct BasketballRunDetailView: View {
    let game: BasketballGame
    var bbVM: BasketballViewModel = .shared

    private let accentColor = BasketballPalette.courtOrange

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                vibeCard
                if !game.partners.isEmpty {
                    partnersCard
                }
                if !game.drillsCompleted.isEmpty {
                    drillsCard
                }
                if game.stats.hasAnyStats {
                    boxScoreCard
                }
                if !game.shotChart.isEmpty {
                    shotChartCard
                }
                if !game.notes.isEmpty {
                    notesCard
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .appBackground(accent: accentColor)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(game.sessionType.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor)
                    Spacer()
                    Text(game.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text(headline)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !game.location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                            .foregroundStyle(accentColor)
                        Text(game.location)
                            .font(.system(size: 13, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    heroStat(value: "\(game.durationMinutes)", label: "MIN")
                    divider
                    heroStat(value: "\(game.caloriesBurned)", label: "KCAL")
                    if let result = game.result, let ts = game.teamScore, let os = game.opponentScore {
                        divider
                        heroStat(value: "\(ts)–\(os)", label: result.rawValue)
                    } else if game.stats.points > 0 {
                        divider
                        heroStat(value: "\(game.stats.points)", label: "PTS")
                    }
                }
            }
        }
    }

    private var headline: String {
        switch game.sessionType {
        case .fullGame5v5, .fullGame3v3, .pickupGame:
            if let result = game.result {
                return result == .win ? "Got the W." : "Tough one — back at it."
            }
            return "Hooped it up."
        case .soloShooting: return "Got shots up."
        case .skillsPractice: return "Worked on the craft."
        case .teamPractice: return "Locked in with the squad."
        case .conditioning: return "Built the engine."
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Vibe

    private var vibeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "How it felt", title: "Vibe", accent: BasketballPalette.courtAmber)

            HStack(spacing: 12) {
                vibeRing(label: "Energy", value: game.energyRating, color: BasketballPalette.courtAmber)
                vibeRing(label: "Legs", value: game.legsRating, color: Color(red: 0.20, green: 0.78, blue: 0.35))
                vibeRing(label: "Confidence", value: game.confidenceRating, color: PepTheme.violet)
            }
        }
        .editorialCard(accent: BasketballPalette.courtAmber)
    }

    private func vibeRing(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 6)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: Double(value) / 10)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(value)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Partners

    private var partnersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Ran with", title: "Squad", accent: accentColor)

            HStack(spacing: 6) {
                ForEach(game.partners, id: \.self) { partner in
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                        Text(partner)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(PepTheme.textPrimary)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                Spacer()
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Drills

    private var drillsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Worked on", title: "Drills", accent: accentColor)

            VStack(spacing: 8) {
                ForEach(game.drillsCompleted, id: \.self) { slug in
                    if let drill = BasketballDrillLibrary.drill(forSlug: slug) {
                        HStack(spacing: 10) {
                            Image(systemName: drill.category.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(drill.category.color)
                                .frame(width: 28, height: 28)
                                .background(drill.category.color.opacity(0.12))
                                .clipShape(Circle())
                            Text(drill.name)
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Text("\(drill.durationMinutes)m")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Box Score

    private var boxScoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Box Score", title: "Stats", accent: accentColor)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                statCell("\(game.stats.points)", "PTS", accentColor)
                statCell("\(game.stats.totalRebounds)", "REB", .green)
                statCell("\(game.stats.assists)", "AST", .blue)
                statCell("\(game.stats.steals)", "STL", BasketballPalette.courtAmber)
                statCell("\(game.stats.blocks)", "BLK", .red)
                statCell("\(game.stats.turnovers)", "TO", PepTheme.textSecondary)
            }

            if game.stats.fieldGoalsAttempted > 0 {
                HStack(spacing: 14) {
                    pctChip(label: "FG", made: game.stats.fieldGoalsMade, att: game.stats.fieldGoalsAttempted, color: accentColor)
                    pctChip(label: "3PT", made: game.stats.threePointersMade, att: game.stats.threePointersAttempted, color: .green)
                    pctChip(label: "FT", made: game.stats.freeThrowsMade, att: game.stats.freeThrowsAttempted, color: BasketballPalette.courtAmber)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func statCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func pctChip(label: String, made: Int, att: Int, color: Color) -> some View {
        let pct = att > 0 ? Double(made) / Double(att) * 100 : 0
        return VStack(spacing: 2) {
            Text(String(format: "%.0f%%", pct))
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(color)
            Text("\(label) \(made)/\(att)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shot Chart

    private var shotChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Map", title: "Shot Chart", accent: accentColor)

            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 200
                ZStack {
                    courtShape(width: w, height: h)
                    ForEach(game.shotChart) { entry in
                        let pos = entry.zone.position
                        Circle()
                            .fill(entry.made ? Color.green.opacity(0.85) : Color.red.opacity(0.7))
                            .frame(width: 9, height: 9)
                            .position(x: w * pos.x, y: h * pos.y)
                    }
                }
                .frame(height: h)
            }
            .frame(height: 200)

            let made = game.shotChart.filter(\.made).count
            let total = game.shotChart.count
            let pct = total > 0 ? Double(made) / Double(total) * 100 : 0
            HStack(spacing: 12) {
                Text("\(made)/\(total)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(String(format: "%.0f%% FG", pct))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func courtShape(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(PepTheme.elevated.opacity(0.6), lineWidth: 1)
                .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: 2)
                .stroke(PepTheme.elevated.opacity(0.5), lineWidth: 1)
                .frame(width: width * 0.32, height: height * 0.35)
                .offset(y: height * 0.325)
            Circle()
                .stroke(PepTheme.elevated.opacity(0.4), lineWidth: 1)
                .frame(width: width * 0.22, height: width * 0.22)
                .offset(y: height * 0.15)
            Path { path in
                let centerX = width / 2
                let radius = width * 0.42
                path.addArc(center: CGPoint(x: centerX, y: height), radius: radius, startAngle: .degrees(160), endAngle: .degrees(20), clockwise: true)
            }
            .stroke(PepTheme.elevated.opacity(0.4), lineWidth: 1)
        }
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Reflection", title: "Notes", accent: PepTheme.violet)
            Text(game.notes)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: PepTheme.violet)
    }
}
