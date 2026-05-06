import SwiftUI

struct MartialArtsSettingsView: View {
    @Bindable var maVM: MartialArtsViewModel
    @Environment(\.dismiss) private var dismiss

    private var accentColor: Color { maVM.primaryDiscipline.color }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    primaryDisciplineSection
                    trainedSection
                    rankSection
                    contextSection
                    seasonSummarySection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                Text("MARTIAL ARTS · SETTINGS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.95))
                Text("Tune your art.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Set your primary style, mark the disciplines you cross-train, and track your rank.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var primaryDisciplineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "Primary",
                title: "Your Style",
                accent: accentColor,
                trailing: AnyView(
                    Text(maVM.primaryDiscipline.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(MartialArtsDiscipline.allCases) { d in
                    let isSelected = maVM.primaryDiscipline == d
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            maVM.primaryDiscipline = d
                            maVM.trainedDisciplines.insert(d)
                            // Reset rank to first option of the new discipline.
                            if !d.ranks.contains(maVM.rank) {
                                maVM.rank = d.ranks.first ?? "Beginner"
                                maVM.stripes = 0
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: d.icon)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(d.rawValue)
                                    .font(.system(size: 13, weight: .semibold, design: .serif))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(d.tagline)
                                    .font(.system(size: 9, design: .serif))
                                    .italic()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(isSelected ? .black : (d == maVM.primaryDiscipline ? d.color : PepTheme.textSecondary))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(isSelected ? d.color : PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var trainedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "Cross-Train",
                title: "Disciplines You Train",
                accent: PepTheme.violet,
                trailing: AnyView(
                    Text("\(maVM.trainedDisciplines.count)")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.violet)
                )
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(MartialArtsDiscipline.allCases) { d in
                        let on = maVM.trainedDisciplines.contains(d)
                        Button {
                            if on {
                                if d != maVM.primaryDiscipline {
                                    maVM.trainedDisciplines.remove(d)
                                }
                            } else {
                                maVM.trainedDisciplines.insert(d)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: d.icon)
                                    .font(.system(size: 11))
                                Text(d.rawValue)
                                    .font(.system(size: 11, weight: .semibold, design: .serif))
                            }
                            .foregroundStyle(on ? .black : d.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(on ? d.color : d.color.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private var rankSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "Rank",
                title: "\(maVM.primaryDiscipline.rawValue) Belt",
                accent: PepTheme.amber,
                trailing: AnyView(
                    Text(rankDisplay)
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.amber)
                )
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(maVM.primaryDiscipline.ranks, id: \.self) { rank in
                        let isSelected = maVM.rank == rank
                        Button {
                            maVM.rank = rank
                        } label: {
                            Text(rank)
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(isSelected ? PepTheme.amber : PepTheme.elevated.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            HStack {
                Text("STRIPES")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                HStack(spacing: 12) {
                    Button { maVM.stripes = max(0, maVM.stripes - 1) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { idx in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(idx < maVM.stripes ? PepTheme.amber : PepTheme.elevated)
                                .frame(width: 6, height: 18)
                        }
                    }
                    Button { maVM.stripes = min(4, maVM.stripes + 1) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.amber)
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private var rankDisplay: String {
        if maVM.stripes > 0 {
            return "\(maVM.rank) · \(maVM.stripes)★"
        }
        return maVM.rank
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Home", title: "Gym & Coach", accent: accentColor)
            TextField("Gym / academy", text: $maVM.gymName)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
            TextField("Head coach (optional)", text: $maVM.coachName)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: accentColor)
    }

    private var seasonSummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Season", title: "Summary", accent: PepTheme.amber)

            if maVM.sessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.martial.arts")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No sessions logged yet.")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                VStack(spacing: 10) {
                    summaryRow(label: "Total Sessions", value: "\(maVM.totalSessions)")
                    summaryRow(label: "Mat Time", value: "\(maVM.totalMatTime) min")
                    summaryRow(label: "Live Sessions", value: "\(maVM.totalLiveSessions)")
                    summaryRow(label: "Total Rounds", value: "\(maVM.totalRoundsLogged)")
                    if maVM.totalTakedownsAttempted > 0 {
                        summaryRow(label: "Takedown %", value: String(format: "%.0f%%", maVM.takedownPercentage * 100))
                    }
                    summaryRow(label: "Subs Landed", value: "\(maVM.totalSubmissionsLanded)")
                    summaryRow(label: "Taps Received", value: "\(maVM.totalSubsReceived)")
                    if maVM.competitions.count > 0 {
                        summaryRow(label: "Competition", value: "\(maVM.competitionWins)W · \(maVM.competitionLosses)L")
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PepTheme.glassBorderTop)
                .frame(height: 0.5)
                .offset(y: 2)
        }
    }
}
