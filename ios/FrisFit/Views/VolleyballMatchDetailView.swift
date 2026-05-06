import SwiftUI

struct VolleyballMatchDetailView: View {
    let match: VolleyballMatch
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.95, green: 0.30, blue: 0.20)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                if !match.sets.isEmpty {
                    setsCard
                }
                statsCard
                if !match.teammates.isEmpty || !match.venue.isEmpty {
                    contextCard
                }
                if !match.notes.isEmpty {
                    notesCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .appBackground(accent: accentColor)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(match.sessionType.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    if let result = match.result {
                        Text(result.label.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(result.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(result.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(heroTitle)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                Text(match.date.formatted(.dateTime.weekday().month(.wide).day().year()))
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    heroStat(value: "\(match.stats.kills)", label: "KILLS")
                    heroDivider
                    heroStat(value: "\(match.stats.aces)", label: "ACES")
                    heroDivider
                    heroStat(value: "\(match.stats.totalBlocks)", label: "BLOCKS")
                    heroDivider
                    heroStat(value: "\(match.stats.digs)", label: "DIGS")
                }
            }
        }
    }

    private var heroTitle: String {
        if !match.opponentName.isEmpty {
            return "vs \(match.opponentName)"
        }
        return match.sessionType.rawValue
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

    private var heroDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private var setsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Score", title: "Set-by-Set", accent: accentColor)
            VStack(spacing: 8) {
                ForEach(Array(match.sets.enumerated()), id: \.offset) { idx, set in
                    HStack {
                        Text("SET \(idx + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 50, alignment: .leading)
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(set.teamPoints)")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(set.teamWon ? .green : PepTheme.textPrimary)
                            Text("–")
                                .font(.system(size: 12))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("\(set.opponentPoints)")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(!set.teamWon ? .red : PepTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        if idx < match.sets.count - 1 {
                            Rectangle()
                                .fill(PepTheme.glassBorderTop)
                                .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Box", title: "Stat Line", accent: PepTheme.amber)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                statTile(value: "\(match.stats.kills)", label: "Kills", color: accentColor)
                statTile(value: "\(match.stats.attackAttempts)", label: "Attempts", color: PepTheme.amber)
                statTile(value: String(format: "%+.3f", match.stats.hittingPercentage), label: "Hit %", color: match.stats.hittingPercentage >= 0.2 ? .green : accentColor)
                statTile(value: "\(match.stats.aces)", label: "Aces", color: .green)
                statTile(value: "\(match.stats.totalBlocks)", label: "Blocks", color: PepTheme.violet)
                statTile(value: "\(match.stats.digs)", label: "Digs", color: .blue)
                statTile(value: "\(match.stats.assists)", label: "Assists", color: PepTheme.amber)
                if match.stats.receptionAttempts > 0 {
                    statTile(value: String(format: "%.2f", match.stats.passingRating), label: "Pass Rating", color: .green)
                } else {
                    statTile(value: "\(match.stats.serviceErrors)", label: "Serve Errs", color: .red)
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.10))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Context", title: "Where & With", accent: PepTheme.violet)
            VStack(alignment: .leading, spacing: 10) {
                if !match.venue.isEmpty {
                    contextRow(label: "Venue", value: match.venue, icon: "building.2.fill")
                }
                contextRow(label: "Position", value: match.position.rawValue, icon: match.position.icon)
                contextRow(label: "Duration", value: "\(match.durationMinutes) min", icon: "clock")
                if !match.teammates.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PLAYED WITH")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textSecondary)
                        FlowChips(teammates: match.teammates)
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private func contextRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.violet)
                .frame(width: 22)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Story", title: "Notes", accent: accentColor)
            Text(match.notes)
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: accentColor)
    }
}

private struct FlowChips: View {
    let teammates: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(teammates, id: \.self) { name in
                Text(name)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PepTheme.violet.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}
