import SwiftUI

struct PeptideStackBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String> = []
    @State private var search: String = ""
    @State private var expandedInteraction: UUID? = nil
    @State private var expandedBadgeFor: String? = nil
    @State private var activeBadge: StackBadge? = nil

    private var filtered: [CompoundProfile] {
        if search.isEmpty { return CompoundDatabase.all }
        return CompoundDatabase.all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var selectedProfiles: [CompoundProfile] {
        selected.compactMap { name in CompoundDatabase.all.first(where: { $0.name == name }) }
    }

    private var interactions: [CompoundInteraction] {
        DrugInteractionDatabase.interactions(among: Array(selected))
    }

    private var warningCount: Int { interactions.filter { $0.severity == .warning }.count }
    private var cautionCount: Int { interactions.filter { $0.severity == .caution }.count }
    private var synergyCount: Int { interactions.filter { $0.severity == .info }.count }

    private var safety: StackSafetySummary {
        StackSafetyEngine.evaluate(selected: Array(selected))
    }

    var body: some View {
        if PeptideAccessManager.shared.shouldShowTrackAEmptyState {
            NavigationStack {
                TrackAEmptyStateView(
                    surface: .stackBuilder,
                    icon: "square.stack.3d.up.fill",
                    title: "Build a safe stack",
                    blurb: "Pick compounds and EPTI flags conflicts, synergies, and a suggested weekly timing. Activate peptide tracking to design your stack."
                )
                .navigationTitle("Stack Builder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .preferredColorScheme(.dark)
        } else {
            builderBody
        }
    }

    @ViewBuilder
    private var builderBody: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if !selected.isEmpty {
                        safetyScoreCard
                        selectedStrip
                        stackCompoundsSection
                        if !safety.swapSuggestions.isEmpty {
                            swapSuggestionsCard
                        }
                        interactionSummary
                        if !interactions.isEmpty {
                            interactionList
                        }
                        weeklySchedule
                    }
                    searchField
                    compoundGrid
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Stack Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Design your stack")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Pick compounds to see known conflicts, synergies, and a suggested weekly timing.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedProfiles) { profile in
                    HStack(spacing: 8) {
                        Image(systemName: profile.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                        Text(profile.name)
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.white)
                        Button { toggle(profile.name) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white, .white.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(PepTheme.teal, in: .capsule)
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    private var interactionSummary: some View {
        HStack(spacing: 10) {
            summaryBadge(label: "Warnings", count: warningCount, color: .red, icon: "exclamationmark.octagon.fill")
            summaryBadge(label: "Cautions", count: cautionCount, color: PepTheme.amber, icon: "exclamationmark.triangle.fill")
            summaryBadge(label: "Synergy", count: synergyCount, color: .green, icon: "checkmark.seal.fill")
        }
    }

    private func summaryBadge(label: String, count: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text("\(count)")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var interactionList: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("INTERACTIONS & SYNERGIES")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                ForEach(interactions) { inter in
                    interactionRow(inter)
                    if inter.id != interactions.last?.id {
                        Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                    }
                }
            }
        }
    }

    private func interactionRow(_ i: CompoundInteraction) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                expandedInteraction = expandedInteraction == i.id ? nil : i.id
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: i.severity.icon)
                    .foregroundStyle(i.severity.color)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(i.compoundA)
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text(i.compoundB)
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text(i.severity.rawValue.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(i.severity.color)
                    }
                    Text(i.note)
                        .font(.caption)
                        .foregroundStyle(expandedInteraction == i.id ? PepTheme.textPrimary : PepTheme.textSecondary)
                        .lineLimit(expandedInteraction == i.id ? nil : 2)
                        .multilineTextAlignment(.leading)
                }
            }
            .contentShape(.rect)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var weeklySchedule: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("SUGGESTED WEEKLY TIMING")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                ForEach(selectedProfiles) { p in
                    HStack(spacing: 10) {
                        Image(systemName: p.iconName)
                            .foregroundStyle(PepTheme.teal)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name)
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(suggestedTiming(for: p))
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Spacer()
                    }
                }
                Text("Rough guidance only. GHRH/GHRP blends work best pre-bed fasted. GLP-1s one day a week. Recovery peptides morning or post-workout.")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    private func suggestedTiming(for p: CompoundProfile) -> String {
        let lower = p.name.lowercased()
        if lower.contains("semaglutide") || lower.contains("tirzepatide") || lower.contains("retatrutide") {
            return "Once weekly, same day each week"
        }
        if lower.contains("ipamorelin") || lower.contains("cjc") || lower.contains("sermorelin") || lower.contains("tesamorelin") || lower.contains("ghrp") {
            return "Pre-bed fasted — combine GHRH + GHRP in one shot"
        }
        if lower.contains("bpc") || lower.contains("tb-500") {
            return "Morning or post-workout — rotate injection sites"
        }
        if lower.contains("melanotan") || lower.contains("pt-141") {
            return "As needed — start low due to flushing/nausea"
        }
        return "Daily at a consistent time"
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PepTheme.textSecondary)
            TextField("Search compounds", text: $search)
                .foregroundStyle(PepTheme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var compoundGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(filtered) { profile in
                let isOn = selected.contains(profile.name)
                Button { toggle(profile.name) } label: {
                    compoundCard(profile, isOn: isOn)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func compoundCard(_ p: CompoundProfile, isOn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill((isOn ? PepTheme.teal : PepTheme.textSecondary).opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: p.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isOn ? PepTheme.teal : PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? PepTheme.teal : PepTheme.textSecondary.opacity(0.6))
            }
            Text(p.name)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
            Text(p.peptideType)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isOn ? PepTheme.teal.opacity(0.5) : PepTheme.glassBorderTop, lineWidth: isOn ? 1.2 : 0.5)
        )
    }

    private func toggle(_ name: String) {
        withAnimation(.spring(response: 0.3)) {
            if selected.contains(name) { selected.remove(name) } else { selected.insert(name) }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private var safetyScoreCard: some View {
        let s = safety
        let color: Color = s.score >= 80 ? .green : (s.score >= 60 ? PepTheme.amber : .red)
        return GlassCard(accent: color) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.15), lineWidth: 6)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(s.score) / 100)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 64, height: 64)
                    Text("\(s.score)")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stack Safety")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(s.score >= 80 ? "Looks solid" : (s.score >= 60 ? "Review cautions" : "Significant conflicts"))
                        .font(.caption)
                        .foregroundStyle(color)
                    HStack(spacing: 8) {
                        scoreChip("\(s.synergyCount)", "synergies", .green)
                        scoreChip("\(s.cautionCount)", "cautions", PepTheme.amber)
                        scoreChip("\(s.conflictCount)", "conflicts", .red)
                    }
                }
                Spacer()
            }
        }
    }

    private func scoreChip(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(value).font(.system(.caption2, design: .rounded, weight: .heavy)).foregroundStyle(color)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(color.opacity(0.12)).clipShape(.capsule)
    }

    private var stackCompoundsSection: some View {
        let s = safety
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR STACK")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                ForEach(selectedProfiles) { p in
                    stackCompoundRow(p, badges: s.badgesByCompound[p.name] ?? [])
                    if p.id != selectedProfiles.last?.id {
                        Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                    }
                }
            }
        }
        .sheet(item: $activeBadge) { badge in
            badgeDetailSheet(badge)
        }
    }

    private func stackCompoundRow(_ p: CompoundProfile, badges: [StackBadge]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: p.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 30, height: 30)
                    .background(PepTheme.teal.opacity(0.14), in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.name)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(p.peptideType)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(badges) { badge in
                            Button { activeBadge = badge } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: badge.kind.icon)
                                        .font(.system(size: 9, weight: .bold))
                                    Text(badge.title)
                                        .font(.system(size: 10, weight: .bold))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(badge.kind.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badge.kind.color.opacity(0.14))
                                .clipShape(.capsule)
                                .overlay(
                                    Capsule().strokeBorder(badge.kind.color.opacity(0.25), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func badgeDetailSheet(_ badge: StackBadge) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(badge.kind.color.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: badge.kind.icon)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(badge.kind.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(badge.kind.label)
                                .font(.system(.caption, weight: .heavy))
                                .foregroundStyle(badge.kind.color)
                                .textCase(.uppercase)
                                .tracking(1)
                            Text(badge.title)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        Spacer()
                    }
                    Text(badge.detail)
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    if let swap = badge.saferSwap {
                        GlassCard(accent: .green) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(.green)
                                    Text("Safer alternative")
                                        .font(.system(.subheadline, weight: .bold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                }
                                Text(swap)
                                    .font(.callout)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .appBackground()
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { activeBadge = nil }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var swapSuggestionsCard: some View {
        GlassCard(accent: .red) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.orange)
                    Text("SUGGESTED SWAPS")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ForEach(safety.swapSuggestions) { s in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(s.replace)
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(.red)
                                .strikethrough()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("Drop this")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text(s.suggestion)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(s.reason)
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                    if s.id != safety.swapSuggestions.last?.id {
                        Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                    }
                }
            }
        }
    }
}
