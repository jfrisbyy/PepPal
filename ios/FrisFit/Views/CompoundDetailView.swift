import SwiftUI

struct CompoundDetailView: View {
    let compound: CompoundProfile
    @State private var selectedTab: CompoundTab = .overview
    @State private var headerVisible: Bool = false
    @State private var contentVisible: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var trackingManager = CompoundTrackingManager.shared
    @State private var unitStore = UnitPreferenceStore.shared
    @State private var socialPosts: [FeedPost] = []
    @State private var socialLoading: Bool = false
    @State private var socialSort: SocialSort = .recent
    @State private var selectedSocialPost: FeedPost?
    @State private var selectedSocialUser: SocialUser?
    @State private var socialViewModel = SocialViewModel()
    @State private var realProtocolUsers: [ProtocolUser] = []
    @State private var liveStat: CompoundUsageStat?

    private enum SocialSort: String, CaseIterable {
        case recent = "Recent"
        case trending = "Trending"
    }

    private var compoundHashtag: String {
        compound.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    private struct ProtocolUser: Identifiable {
        let id: UUID
        let user: SocialUser
        let dosage: String
        let frequency: String
        let week: Int
        let totalWeeks: Int
    }

    private var usersOnProtocol: [ProtocolUser] { realProtocolUsers }

    private var displayedUserCount: Int {
        if let s = liveStat, s.recent_users > 0 { return s.recent_users }
        return compound.communityUsers
    }

    private var isTracking: Bool {
        trackingManager.isTracking(compound.name)
    }

    private var trackingCount: Int {
        isTracking ? 1 : 0
    }

    private var accentColor: Color {
        compound.categories.first?.color ?? PepTheme.teal
    }

    private enum CompoundTab: String, CaseIterable {
        case overview = "Overview"
        case protocols = "Protocols"
        case science = "Science"
        case social = "Social"
        case sourcing = "Sourcing"

        var icon: String {
            switch self {
            case .overview: return "info.circle.fill"
            case .protocols: return "list.bullet.clipboard.fill"
            case .science: return "flask.fill"
            case .social: return "person.3.fill"
            case .sourcing: return "building.2.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader
                tabBar
                    .padding(.top, 8)

                Group {
                    switch selectedTab {
                    case .overview:
                        overviewSection
                    case .protocols:
                        protocolsSection
                    case .science:
                        scienceSection
                    case .social:
                        communitySection
                    case .sourcing:
                        sourcingSection
                    }
                }
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 8)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                headerVisible = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                contentVisible = true
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.6, 0.4], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    accentColor.opacity(0.55), accentColor.opacity(0.28), PepTheme.violet.opacity(0.28),
                    accentColor.opacity(0.35), accentColor.opacity(0.45), PepTheme.blue.opacity(0.28),
                    PepTheme.background, PepTheme.background, PepTheme.background
                ]
            )
            .frame(height: 280)

            VStack(alignment: .leading, spacing: 12) {
                Text(compound.peptideType.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(accentColor)
                    .opacity(headerVisible ? 1 : 0)

                Text(compound.name)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .kerning(-0.6)
                    .foregroundStyle(PepTheme.textPrimary)
                    .opacity(headerVisible ? 1 : 0)

                if !compound.subtitle.isEmpty {
                    Text(compound.subtitle)
                        .font(.system(.subheadline, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .opacity(headerVisible ? 1 : 0)
                }

                HStack(spacing: 6) {
                    if compound.isWADAProhibited {
                        editorialTag("WADA", color: .red)
                    }
                    ForEach(compound.categories) { cat in
                        editorialTag(cat.rawValue, color: cat.color)
                    }
                }
                .padding(.top, 2)

                statsRow
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func editorialTag(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .tracking(1.3)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                Capsule().strokeBorder(color.opacity(0.4), lineWidth: 0.5)
            )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    trackingManager.toggleTracking(compound.name)
                }
            } label: {
                statItem(
                    value: isTracking ? "On" : "Off",
                    label: "Tracking",
                    accent: isTracking ? accentColor : PepTheme.textSecondary
                )
            }
            .sensoryFeedback(.selection, trigger: isTracking)

            statDivider

            statItem(
                value: "\(compound.structuredSideEffects.count)",
                label: "Side Effects",
                accent: PepTheme.textPrimary
            )

            statDivider

            statItem(
                value: "\(compound.stackPartners.count)",
                label: "Stacks",
                accent: PepTheme.textPrimary
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .overlay(
            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.12))
                .frame(height: 0.5),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.12))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private func statItem(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(accent)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.3)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PepTheme.textPrimary.opacity(0.12))
            .frame(width: 0.5, height: 36)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CompoundTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue.uppercased())
                            .font(.system(size: 10, weight: selectedTab == tab ? .heavy : .semibold))
                            .tracking(1.1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(selectedTab == tab ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.7))
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(selectedTab == tab ? accentColor : Color.clear)
                            .frame(height: 1.5)
                    }
                    .padding(.top, 10)
                }
                .sensoryFeedback(.selection, trigger: selectedTab)
            }
        }
        .padding(.horizontal, 12)
        .overlay(
            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.08))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            disclaimerBanner

            if compound.isWADAProhibited && !compound.wadaCategory.isEmpty {
                wadaBanner
            }

            quickReferenceCard

            if !compound.whatIsIt.isEmpty {
                whatIsItCard
            }

            if !compound.howItWorks.isEmpty {
                howItWorksCard
            }

            if !compound.primaryUseCases.isEmpty {
                primaryUseCasesCard
            }

            keyFactsCard

            if !compound.whatToExpect.isEmpty {
                whatToExpectCard
            }

            if !compound.watchOut.isEmpty {
                watchOutCard
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "doc.text.fill", title: "About", color: accentColor)

                    Text(compound.overview)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                        .lineSpacing(5)
                }
            }

            if !compound.structuredSideEffects.isEmpty {
                sideEffectsCard
            }

            if hasDetailedSideEffects {
                detailedSideEffectsCard
            }

            if !compound.sideEffectManagement.isEmpty {
                sideEffectManagementCard
            }

            if !compound.detailedSideEffects.contraindications.isEmpty {
                contraindicationsCard
            }

            if !compound.drugInteractions.isEmpty {
                drugInteractionsCard
            }

            if !compound.womenConsiderations.isEmpty {
                womenConsiderationsCard
            }

            if !compound.stackDetails.isEmpty {
                stackDetailsCard
            } else if !compound.stackPartners.isEmpty {
                stackPartnersCard
            }

            if !compound.beginnerTips.isEmpty {
                beginnerTipsCard
            }

            if !compound.communityConsensus.isEmpty {
                communityConsensusCard
            }

            if compound.evidence.level != "\u{2014}" {
                evidenceCard
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - Quick Reference Card

    private var quickReferenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(accentColor)
                Text("QUICK REFERENCE")
                    .font(.system(.caption2, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(accentColor)
                Spacer()
                unitToggle
            }

            HStack(spacing: 0) {
                quickRefItem(
                    icon: "syringe.fill",
                    label: "Dose Range",
                    value: compound.keyFacts.typicalDoseRange,
                    color: accentColor
                )
                quickRefDivider
                quickRefItem(
                    icon: "drop.fill",
                    label: "Reconstitution",
                    value: compound.keyFacts.reconstitution,
                    color: PepTheme.blue
                )
                quickRefDivider
                quickRefItem(
                    icon: "thermometer.medium",
                    label: "Storage",
                    value: compound.keyFacts.storageTemp,
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [accentColor.opacity(0.08), accentColor.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.15), lineWidth: 1)
        )
    }

    private func quickRefItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var unitToggle: some View {
        let current = unitStore.effectiveUnit(for: compound.name)
        return Menu {
            Picker("Display Units", selection: Binding(
                get: { current },
                set: { newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        unitStore.setUnit(newValue, for: compound.name)
                    }
                }
            )) {
                Text("Micrograms (mcg)").tag(CompoundUnit.mcg)
                Text("Milligrams (mg)").tag(CompoundUnit.mg)
            }
            if unitStore.unitOverride(for: compound.name) != nil {
                Divider()
                Button("Reset to Default") {
                    unitStore.clearOverride(for: compound.name)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "ruler")
                    .font(.system(size: 9, weight: .bold))
                Text(current.rawValue)
                    .font(.system(.caption2, weight: .heavy))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accentColor.opacity(0.12))
            .clipShape(.capsule)
        }
        .sensoryFeedback(.selection, trigger: current)
    }

    private var quickRefDivider: some View {
        Rectangle()
            .fill(accentColor.opacity(0.12))
            .frame(width: 1, height: 44)
    }

    // MARK: - Key Facts Card

    private var keyFactsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "list.bullet.rectangle.fill", title: "Key Facts", color: accentColor)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    keyFactRow(label: "Peptide Type", value: compound.peptideType, icon: "testtube.2")
                    keyFactRow(label: "Molecular Weight", value: compound.keyFacts.molecularWeight, icon: "scalemass")
                    keyFactRow(label: "Administration", value: compound.keyFacts.administrationRoute, icon: "syringe")
                    keyFactRow(label: "Half-Life", value: compound.keyFacts.halfLife, icon: "clock")
                    keyFactRow(label: "Storage", value: compound.keyFacts.storageTemp, icon: "snowflake")
                    keyFactRow(label: "Reconstitution", value: compound.keyFacts.reconstitution, icon: "drop.fill")
                }
            }
        }
    }

    private func keyFactRow(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
            Text(value)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Side Effects Card

    private var sideEffectsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "exclamationmark.triangle.fill", title: "Commonly Reported Side Effects", color: .orange)

                VStack(spacing: 8) {
                    ForEach(compound.structuredSideEffects) { effect in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(effect.severity.color)
                                .frame(width: 8, height: 8)

                            Text(effect.name)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)

                            Spacer()

                            HStack(spacing: 6) {
                                Text(effect.severity.rawValue)
                                    .font(.system(.caption2, weight: .bold))
                                    .foregroundStyle(effect.severity.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(effect.severity.color.opacity(0.12))
                                    .clipShape(.capsule)

                                Text("\(effect.frequency)%")
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PepTheme.elevated.opacity(0.3))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }

                HStack(spacing: 8) {
                    legendDot(color: .green, label: "Mild")
                    legendDot(color: .yellow, label: "Moderate")
                    legendDot(color: .orange, label: "Significant")
                }
                .padding(.top, 4)
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var hasDetailedSideEffects: Bool {
        !compound.detailedSideEffects.common.isEmpty ||
        !compound.detailedSideEffects.uncommon.isEmpty ||
        !compound.detailedSideEffects.rare.isEmpty
    }

    private var detailedSideEffectsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(icon: "list.bullet.clipboard.fill", title: "Side Effect Breakdown", color: .orange)

                if !compound.detailedSideEffects.common.isEmpty {
                    sideEffectTierSection(
                        title: "Common",
                        icon: "circle.fill",
                        color: .yellow,
                        items: compound.detailedSideEffects.common
                    )
                }

                if !compound.detailedSideEffects.uncommon.isEmpty {
                    sideEffectTierSection(
                        title: "Uncommon",
                        icon: "circle.fill",
                        color: .orange,
                        items: compound.detailedSideEffects.uncommon
                    )
                }

                if !compound.detailedSideEffects.rare.isEmpty {
                    sideEffectTierSection(
                        title: "Rare",
                        icon: "circle.fill",
                        color: .red,
                        items: compound.detailedSideEffects.rare
                    )
                }
            }
        }
    }

    private func sideEffectTierSection(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(color.opacity(0.6))
                            .padding(.top, 3)
                        Text(item)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                            .lineSpacing(2)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.06))
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    // MARK: - Stack Partners Card

    private var stackPartnersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "link", title: "Common Stack Partners", color: PepTheme.violet)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(compound.stackPartners, id: \.self) { partner in
                            stackPartnerChip(partner: partner)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stackPartnerChip(partner: String) -> some View {
        let linked = CompoundDatabase.compound(named: partner)
        if let linked {
            NavigationLink(value: linked) {
                stackPartnerChipLabel(partner: partner, isLinked: true)
            }
            .buttonStyle(.plain)
        } else {
            stackPartnerChipLabel(partner: partner, isLinked: false)
        }
    }

    private func stackPartnerChipLabel(partner: String, isLinked: Bool) -> some View {
        HStack(spacing: 6) {
            Text(partner.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.2)
            if isLinked {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.violet.opacity(0.7))
            }
        }
        .foregroundStyle(PepTheme.violet)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(
            Capsule().strokeBorder(PepTheme.violet.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Protocols

    private var protocolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            disclaimerBanner

            if !compound.beforeYouStart.isEmpty {
                beforeYouStartCard
            }

            if !compound.dosingSchedule.isEmpty {
                dosingScheduleCard
            }

            if !compound.tieredDosing.isEmpty {
                tieredDosingCard
            }

            if !compound.cycleLength.isEmpty || compound.loadingProtocol != "No" || !compound.onOffCycling.isEmpty {
                cycleInfoCard
            }

            if !compound.injectionSiteGuide.isEmpty {
                injectionSiteCard
            }

            if !compound.discontinuationProtocol.isEmpty {
                discontinuationCard
            }

            if compound.protocols.isEmpty && compound.tieredDosing.isEmpty {
                emptyStateCard(
                    icon: "doc.text.magnifyingglass",
                    title: "No Protocol Data Yet",
                    subtitle: "Community-sourced protocols coming soon"
                )
            } else if !compound.protocols.isEmpty {
                ForEach(compound.protocols) { proto in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(accentColor)
                                    .frame(width: 4, height: 20)
                                Text(proto.goalName)
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(accentColor)
                            }

                            Text(proto.description)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)

                            HStack(spacing: 0) {
                                protocolMetric(icon: "syringe.fill", label: "Dose", value: proto.typicalDose, color: accentColor)
                                protocolMetric(icon: "clock.fill", label: "Frequency", value: proto.frequency, color: PepTheme.blue)
                                protocolMetric(icon: "calendar", label: "Duration", value: proto.duration, color: PepTheme.violet)
                            }
                            .padding(10)
                            .background(PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }
            }

            if compound.reconstitutionGuide.typicalVialSize != "\u{2014}" {
                reconstitutionCard
            }

            if !compound.bloodworkMarkers.isEmpty {
                bloodworkCard
            }

            if !compound.nutritionalSupport.isEmpty {
                nutritionalSupportCard
            }

            if !compound.trainingGuide.isEmpty {
                trainingGuideCard
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func protocolMetric(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tiered Dosing

    private var tieredDosingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "chart.bar.fill", title: "Dosing Tiers", color: accentColor)

                VStack(spacing: 8) {
                    ForEach(compound.tieredDosing) { tier in
                        HStack(spacing: 12) {
                            Text(tier.tier)
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 80)
                                .padding(.vertical, 6)
                                .background(
                                    tier.tier.contains("Beginner") ? .green.opacity(0.7) :
                                    tier.tier.contains("Intermediate") ? PepTheme.amber.opacity(0.7) :
                                    accentColor.opacity(0.7)
                                )
                                .clipShape(.rect(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text(tier.dose)
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text("·")
                                        .foregroundStyle(PepTheme.textSecondary)
                                    Text(tier.frequency)
                                        .font(.system(.caption, weight: .medium))
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                Text(tier.timingNotes)
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(PepTheme.elevated.opacity(0.3))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Cycle Info

    private var cycleInfoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "arrow.trianglehead.2.clockwise", title: "Cycle Information", color: PepTheme.blue)

                VStack(spacing: 8) {
                    if !compound.cycleLength.isEmpty {
                        cycleInfoRow(icon: "calendar.badge.clock", label: "Cycle Length", value: compound.cycleLength)
                    }
                    cycleInfoRow(icon: "arrow.up.right", label: "Loading Protocol", value: compound.loadingProtocol)
                    if !compound.onOffCycling.isEmpty {
                        cycleInfoRow(icon: "repeat", label: "On/Off Cycling", value: compound.onOffCycling)
                    }
                }
            }
        }
    }

    private func cycleInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(PepTheme.blue)
                .frame(width: 20)
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(10)
        .background(PepTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Reconstitution Guide

    private var reconstitutionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "drop.fill", title: "Reconstitution Guide", color: PepTheme.blue)

                VStack(spacing: 8) {
                    reconRow(label: "Vial Size", value: compound.reconstitutionGuide.typicalVialSize)
                    reconRow(label: "Diluent", value: compound.reconstitutionGuide.diluent)
                    if compound.reconstitutionGuide.reconstitutionMath != "\u{2014}" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mixing Math")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(compound.reconstitutionGuide.reconstitutionMath)
                                .font(.system(.caption, design: .monospaced, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineSpacing(4)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PepTheme.elevated.opacity(0.3))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    reconRow(label: "Storage (Powder)", value: compound.reconstitutionGuide.storageLyophilized)
                    reconRow(label: "Storage (Mixed)", value: compound.reconstitutionGuide.storageReconstituted)
                    reconRow(label: "Handling", value: compound.reconstitutionGuide.handlingNotes)
                }
            }
        }
    }

    private func reconRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
        }
        .padding(10)
        .background(PepTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Bloodwork Markers

    private var bloodworkCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "heart.text.clipboard.fill", title: "Bloodwork Monitoring", color: .red)

                VStack(spacing: 8) {
                    ForEach(compound.bloodworkMarkers) { marker in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(marker.marker)
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Spacer()
                                HStack(spacing: 8) {
                                    priorityBadge(label: "Pre", value: marker.baseline)
                                    priorityBadge(label: "On", value: marker.onCycle)
                                }
                            }
                            Text(marker.reason)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                                .lineSpacing(2)
                        }
                        .padding(10)
                        .background(PepTheme.elevated.opacity(0.3))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func priorityBadge(label: String, value: String) -> some View {
        let color: Color = value == "Required" ? .red : value == "Recommended" ? .orange : PepTheme.textSecondary
        return HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(.capsule)
    }

    // MARK: - Nutritional Support

    private var nutritionalSupportCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "leaf.fill", title: "Nutritional Support", color: .green)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(compound.nutritionalSupport.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                                .padding(.top, 2)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Community

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            communityStatsCard
            onProtocolSection
            feedSection
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .task(id: compound.id) {
            async let _: () = loadSocialPosts()
            async let _: () = loadRealProtocolUsers()
        }
        .navigationDestination(item: $selectedSocialPost) { post in
            PostDetailView(post: post, viewModel: socialViewModel)
        }
        .navigationDestination(item: $selectedSocialUser) { user in
            UserProfileView(user: user, viewModel: ProfileViewModel())
        }
    }

    private var communityStatsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(icon: "chart.bar.fill", title: "Community Stats", color: accentColor)

                HStack(spacing: 0) {
                    communityMetric(
                        value: formatNumber(displayedUserCount),
                        label: "Users"
                    )
                    statDivider
                    communityMetric(
                        value: "\(usersOnProtocol.count)",
                        label: "On Protocol"
                    )
                    statDivider
                    communityMetric(
                        value: "\(compound.stackPartners.count)",
                        label: "Stacks"
                    )
                    statDivider
                    communityMetric(
                        value: "\(compound.protocols.count)",
                        label: "Protocols"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var onProtocolSection: some View {
        let users = usersOnProtocol
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionEyebrow("On This Protocol", accent: accentColor)
                Spacer()
                if !users.isEmpty {
                    Text("\(users.count)".uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            if users.isEmpty {
                emptyStateCard(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "No Active Users Yet",
                    subtitle: "Be the first to start a protocol with \(compound.name)"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(users) { entry in
                            Button {
                                selectedSocialUser = entry.user
                            } label: {
                                protocolUserCard(entry)
                            }
                            .buttonStyle(.scale)
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
            }
        }
    }

    private func protocolUserCard(_ entry: ProtocolUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(entry.user.avatarColor.opacity(0.25))
                        .frame(width: 38, height: 38)
                    Text(entry.user.avatarInitial)
                        .font(.system(size: 15, weight: .heavy, design: .serif))
                        .foregroundStyle(entry.user.avatarColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.user.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    Text("@\(entry.user.username)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.1))
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.dosage) \u{00B7} \(entry.frequency)")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineLimit(1)
                Text("WK \(entry.week) / \(entry.totalWeeks)".uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(accentColor)
            }
        }
        .padding(14)
        .frame(width: 220, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.textPrimary.opacity(0.08), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionEyebrow("#\(compoundHashtag)", accent: accentColor)
                Spacer()
                feedSortToggle
            }

            if socialLoading {
                GlassCard {
                    HStack {
                        Spacer()
                        ProgressView().tint(accentColor)
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            } else if socialPosts.isEmpty {
                emptyStateCard(
                    icon: "bubble.left.and.bubble.right",
                    title: "No Posts Yet",
                    subtitle: "Be the first to post with #\(compoundHashtag)"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sortedSocialPosts) { post in
                        FeedPostCard(
                            post: post,
                            onLike: { socialViewModel.toggleFeedLike(for: post.id) },
                            onComment: { selectedSocialPost = post },
                            onRepost: { socialViewModel.toggleRepost(for: post.id) },
                            onTap: { selectedSocialPost = post },
                            onUserTap: { user in selectedSocialUser = user }
                        )
                    }
                }
            }
        }
    }

    private var feedSortToggle: some View {
        HStack(spacing: 14) {
            ForEach(SocialSort.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) { socialSort = mode }
                } label: {
                    VStack(spacing: 4) {
                        Text(mode.rawValue.uppercased())
                            .font(.system(size: 9, weight: socialSort == mode ? .heavy : .semibold))
                            .tracking(1.4)
                            .foregroundStyle(socialSort == mode ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.7))
                        Rectangle()
                            .fill(socialSort == mode ? accentColor : Color.clear)
                            .frame(height: 1)
                            .frame(width: 28)
                    }
                }
                .sensoryFeedback(.selection, trigger: socialSort)
            }
        }
    }

    private var sortedSocialPosts: [FeedPost] {
        switch socialSort {
        case .recent:
            return socialPosts.sorted { $0.timestamp > $1.timestamp }
        case .trending:
            return socialPosts.sorted { ($0.likeCount + $0.commentCount * 2 + $0.repostCount * 3) > ($1.likeCount + $1.commentCount * 2 + $1.repostCount * 3) }
        }
    }

    private func loadRealProtocolUsers() async {
        await CompoundStatsService.shared.loadIfNeeded()
        liveStat = CompoundStatsService.shared.stat(for: compound.name)
        let publicUsers = await CompoundStatsService.shared.fetchPublicUsers(for: compound.name, limit: 24)
        realProtocolUsers = publicUsers.map { p in
            let color = Self.colorFromHex(p.avatarColorHex) ?? PepTheme.teal
            let user = SocialUser(
                id: p.id,
                name: p.displayName,
                username: p.username,
                avatarInitial: p.avatarInitial,
                avatarColor: color,
                avatarURL: p.avatarURL,
                activeProgramName: p.activeProgram,
                streak: p.streak,
                totalFP: p.totalFP
            )
            let dosage: String
            if let dose = p.doseMcg, dose > 0 {
                dosage = dose >= 1000 ? String(format: "%.1f mg", dose / 1000.0) : "\(Int(dose))mcg"
            } else {
                dosage = "—"
            }
            let week: Int
            if let start = p.startedAt {
                week = max(1, Int(Date().timeIntervalSince(start) / (86400 * 7)) + 1)
            } else { week = 1 }
            return ProtocolUser(
                id: p.id,
                user: user,
                dosage: dosage,
                frequency: p.frequency ?? "",
                week: week,
                totalWeeks: p.totalWeeks ?? 0
            )
        }
    }

    private static func colorFromHex(_ hex: String?) -> Color? {
        guard var cleaned = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !cleaned.isEmpty else { return nil }
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let num = UInt64(cleaned, radix: 16) else { return nil }
        return Color(
            red: Double((num >> 16) & 0xFF) / 255.0,
            green: Double((num >> 8) & 0xFF) / 255.0,
            blue: Double(num & 0xFF) / 255.0
        )
    }

    private func loadSocialPosts() async {
        socialLoading = true
        defer { socialLoading = false }
        do {
            let userId = (try? AuthService.shared.currentUserId()) ?? ""
            let raw = try await SocialService.shared.searchPosts(query: "#\(compoundHashtag)", limit: 30)
            let postIds = raw.map { $0.id }
            let likedIds = (try? await SocialService.shared.fetchLikedPostIds(userId: userId, postIds: postIds)) ?? []
            let commentCounts = (try? await SocialService.shared.fetchCommentCounts(postIds: postIds)) ?? [:]

            let target = compoundHashtag
            let mapped: [FeedPost] = raw.compactMap { sp in
                let text = sp.text_content ?? ""
                let inline = Set(RichTextParser.extractHashtags(text))
                let hasTagField = (sp.tags ?? []).contains { $0.lowercased() == target || $0.lowercased().replacingOccurrences(of: " ", with: "-") == target }
                let hasInline = inline.contains(target)
                guard hasTagField || hasInline else { return nil }

                let user = SocialService.shared.socialUserFromAuthor(sp.profiles)
                var media: [FeedMediaItem] = (sp.media_urls ?? []).map { FeedMediaItem(type: .photo, imageURL: $0) }
                if let audio = sp.audio_url, !audio.isEmpty {
                    media.append(FeedMediaItem(type: .voice, imageURL: audio, voiceDuration: sp.audio_duration ?? 0))
                }
                let feedTags = (sp.tags ?? []).compactMap { FeedTag(rawValue: $0) }
                return FeedPost(
                    id: UUID(uuidString: sp.id) ?? UUID(),
                    user: user,
                    timestamp: SocialService.shared.parseDate(sp.created_at),
                    textContent: text,
                    media: media,
                    likeCount: sp.high_five_count ?? 0,
                    isLiked: likedIds.contains(sp.id),
                    comments: [],
                    commentCount: commentCounts[sp.id] ?? 0,
                    repostCount: sp.repost_count ?? 0,
                    isReposted: false,
                    tags: feedTags,
                    isFollowing: false,
                    supabaseId: sp.id
                )
            }
            socialPosts = mapped
            for p in mapped { socialViewModel.ensurePostInFeed(p) }
        } catch {
            socialPosts = []
        }
    }

    private func communityMetric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.3)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sourcing

    private var sourcingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            let matchingVendors = CompoundDatabase.vendors(for: compound.name)

            if matchingVendors.isEmpty {
                emptyStateCard(
                    icon: "building.2",
                    title: "No Verified Vendors",
                    subtitle: "Verified vendor listings coming soon"
                )
            } else {
                ForEach(matchingVendors) { vendor in
                    NavigationLink(value: vendor) {
                        VendorCardView(vendor: vendor)
                    }
                    .buttonStyle(.scale)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - WADA Banner

    private var wadaBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "nosign")
                .font(.system(size: 18))
                .foregroundStyle(.red)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("WADA Prohibited")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.red)
                Text(compound.wadaCategory)
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
                Text("Banned by the World Anti-Doping Agency — using this will cause you to fail a drug test in tested sports competition. This does not affect personal research use.")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                    .lineSpacing(2)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.red.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.red.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Primary Use Cases

    private var primaryUseCasesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "target", title: "Primary Use Cases", color: accentColor)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(compound.primaryUseCases.enumerated()), id: \.offset) { _, useCase in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 6, height: 6)
                            Text(useCase)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Contraindications

    private var contraindicationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "xmark.shield.fill", title: "Do Not Use If You Have", color: .red)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(compound.detailedSideEffects.contraindications.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                            Text(item)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stack Details

    private var stackDetailsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "link", title: "Common Stacks", color: PepTheme.violet)

                VStack(spacing: 8) {
                    ForEach(compound.stackDetails) { stack in
                        stackDetailRow(stack: stack)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stackDetailRow(stack: StackDetail) -> some View {
        let linked = CompoundDatabase.compound(named: stack.partner)
        Group {
            if let linked {
                NavigationLink(value: linked) {
                    stackDetailContent(stack: stack, isLinked: true)
                }
                .buttonStyle(.plain)
            } else {
                stackDetailContent(stack: stack, isLinked: false)
            }
        }
    }

    private func stackDetailContent(stack: StackDetail, isLinked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(stack.partner)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                if isLinked {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.violet.opacity(0.7))
                }
                Spacer()
                Text(stack.purpose)
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(PepTheme.violet)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PepTheme.violet.opacity(0.12))
                    .clipShape(.capsule)
            }
            if !stack.notes.isEmpty {
                Text(stack.notes)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(10)
        .background(PepTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Beginner Tips

    private var beginnerTipsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "lightbulb.fill", title: "Tips & Insights", color: PepTheme.amber)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(compound.beginnerTips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(PepTheme.amber)
                                .padding(.top, 2)
                            Text(tip)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Evidence Card

    private var evidenceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "book.fill", title: "Research Evidence", color: PepTheme.blue)

                HStack(spacing: 8) {
                    Text("Evidence Level:")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(compound.evidence.level)
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(evidenceLevelColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(evidenceLevelColor.opacity(0.12))
                        .clipShape(.capsule)
                }

                if !compound.evidence.keyStudies.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Key Studies")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                        ForEach(Array(compound.evidence.keyStudies.enumerated()), id: \.offset) { _, study in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(PepTheme.blue)
                                    .padding(.top, 2)
                                Text(study)
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                    .lineSpacing(2)
                            }
                        }
                    }
                }

                if !compound.evidence.researchGaps.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Research Gaps")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text(compound.evidence.researchGaps)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                            .lineSpacing(2)
                    }
                }
            }
        }
    }

    private var evidenceLevelColor: Color {
        let level = compound.evidence.level.lowercased()
        if level.contains("strong") { return .green }
        if level.contains("moderate") { return .orange }
        return PepTheme.textSecondary
    }

    // MARK: - What Is It

    private var whatIsItCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "questionmark.circle.fill", title: "What Is It?", color: accentColor)

                Text(compound.whatIsIt)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(5)
            }
        }
    }

    // MARK: - How It Works

    private var howItWorksCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "brain.head.profile.fill", title: "How It Works (Simple)", color: PepTheme.violet)

                Text(compound.howItWorks)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(5)
                    .italic()
            }
        }
    }

    // MARK: - What To Expect

    private var whatToExpectCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "calendar.badge.clock", title: "What to Expect (Timeline)", color: PepTheme.blue)

                VStack(spacing: 0) {
                    ForEach(Array(compound.whatToExpect.enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 10, height: 10)
                                if index < compound.whatToExpect.count - 1 {
                                    Rectangle()
                                        .fill(accentColor.opacity(0.3))
                                        .frame(width: 2)
                                }
                            }
                            .frame(width: 10)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.timeframe)
                                    .font(.system(.caption, weight: .bold))
                                    .foregroundStyle(accentColor)
                                Text(entry.description)
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                    .lineSpacing(3)
                            }
                            .padding(.bottom, index < compound.whatToExpect.count - 1 ? 14 : 0)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Watch Out

    private var watchOutCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Watch Out")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.orange)
                Text(compound.watchOut)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(3)
            }
        }
        .padding(12)
        .background(.orange.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Before You Start

    private var beforeYouStartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "checkmark.seal.fill", title: "Before You Start", color: .red)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(compound.beforeYouStart.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.square")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .padding(.top, 1)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Dosing Schedule

    private var dosingScheduleCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "calendar", title: "Standard Dosing Schedule", color: accentColor)

                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Phase")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Dose")
                            .frame(width: 70, alignment: .center)
                        Text("Freq")
                            .frame(width: 70, alignment: .center)
                    }
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)

                    ForEach(compound.dosingSchedule) { phase in
                        HStack(spacing: 0) {
                            Text(phase.phase)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(phase.dose)
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(accentColor)
                                .frame(width: 70, alignment: .center)
                            Text(phase.frequency)
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                                .frame(width: 70, alignment: .center)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(PepTheme.elevated.opacity(0.3))
                        .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Injection Site Guide

    private var injectionSiteCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "syringe.fill", title: "Injection Site Guide", color: PepTheme.blue)

                Text(compound.injectionSiteGuide)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Discontinuation Protocol

    private var discontinuationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "arrow.down.right.circle.fill", title: "Discontinuation Protocol", color: .orange)

                Text(compound.discontinuationProtocol)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Drug Interactions

    private var drugInteractionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "pills.fill", title: "Drug & Supplement Interactions", color: .red)

                VStack(spacing: 8) {
                    ForEach(compound.drugInteractions) { interaction in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(interaction.substance)
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Spacer()
                                let riskColor: Color = interaction.riskLevel == "High" ? .red : interaction.riskLevel == "Moderate" ? .orange : .yellow
                                Text(interaction.riskLevel)
                                    .font(.system(.caption2, weight: .bold))
                                    .foregroundStyle(riskColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(riskColor.opacity(0.12))
                                    .clipShape(.capsule)
                            }
                            Text(interaction.details)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                                .lineSpacing(2)
                        }
                        .padding(10)
                        .background(PepTheme.elevated.opacity(0.3))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Side Effect Management

    private var sideEffectManagementCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "cross.circle.fill", title: "Side Effect Management", color: .green)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(compound.sideEffectManagement.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "stethoscope")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                                .padding(.top, 2)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Women Considerations

    private var womenConsiderationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "figure.stand.dress", title: "Women-Specific Considerations", color: .pink)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(compound.womenConsiderations.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.pink)
                                .padding(.top, 2)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Community Consensus

    private var communityConsensusCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "quote.bubble.fill", title: "Community Consensus", color: PepTheme.teal)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(compound.communityConsensus.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "person.wave.2.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(PepTheme.teal)
                                .padding(.top, 2)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Training Guide

    private var trainingGuideCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "figure.strengthtraining.traditional", title: "Training Guide", color: accentColor)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(compound.trainingGuide.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(accentColor)
                                .padding(.top, 2)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Science Tab

    private var scienceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            disclaimerBanner

            if !compound.deepDive.isEmpty {
                deepDiveCard
            }

            if !compound.comparisons.isEmpty {
                comparisonCard
            }

            if !compound.legalStatus.isEmpty {
                legalStatusCard
            }

            if !compound.costInfo.isEmpty {
                costInfoCard
            }

            if !compound.faq.isEmpty {
                faqCard
            }

            if !compound.references.isEmpty {
                referencesCard
            }

            let hasNoScienceData = compound.deepDive.isEmpty && compound.comparisons.isEmpty && compound.faq.isEmpty && compound.references.isEmpty
            if hasNoScienceData {
                emptyStateCard(
                    icon: "flask",
                    title: "Deep Dive Coming Soon",
                    subtitle: "Advanced pharmacology and clinical data will be added"
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - Deep Dive

    private var deepDiveCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "atom", title: "Deep Dive (Advanced)", color: PepTheme.violet)

                Text(compound.deepDive)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Comparison Card

    private var comparisonCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "chart.bar.doc.horizontal.fill", title: "Comparison", color: PepTheme.blue)

                let compoundNames = comparisonCompoundNames

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Feature")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(compoundNames, id: \.self) { name in
                            Text(name)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                    ForEach(compound.comparisons) { comp in
                        HStack(spacing: 0) {
                            Text(comp.feature)
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(compoundNames, id: \.self) { name in
                                Text(comp.values[name] ?? "-")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(name == compound.name ? accentColor : PepTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(PepTheme.elevated.opacity(0.2))
                        .clipShape(.rect(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private var comparisonCompoundNames: [String] {
        var names: [String] = [compound.name]
        for comp in compound.comparisons {
            for key in comp.values.keys where !names.contains(key) {
                names.append(key)
            }
        }
        return names
    }

    // MARK: - Legal Status

    private var legalStatusCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "building.columns.fill", title: "Legal Status", color: PepTheme.amber)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(compound.legalStatus.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(PepTheme.amber)
                                .padding(.top, 1)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cost Info

    private var costInfoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "dollarsign.circle.fill", title: "Cost & Accessibility", color: .green)

                Text(compound.costInfo)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - FAQ

    private var faqCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(icon: "questionmark.bubble.fill", title: "FAQ", color: PepTheme.blue)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(compound.faq) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 6) {
                                Text("Q:")
                                    .font(.system(.caption, weight: .heavy))
                                    .foregroundStyle(PepTheme.blue)
                                Text(item.question)
                                    .font(.system(.caption, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
                            }
                            HStack(alignment: .top, spacing: 6) {
                                Text("A:")
                                    .font(.system(.caption, weight: .heavy))
                                    .foregroundStyle(PepTheme.textSecondary)
                                Text(item.answer)
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                    .lineSpacing(3)
                            }
                        }
                        .padding(10)
                        .background(PepTheme.elevated.opacity(0.3))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - References

    private var referencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "books.vertical.fill", title: "References", color: PepTheme.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(compound.references.enumerated()), id: \.offset) { index, ref in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(PepTheme.textSecondary)
                                .frame(width: 18, alignment: .trailing)
                            Text(ref)
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                                .lineSpacing(2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var disclaimerBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(PepTheme.amber)

            Text("For educational and research purposes only. Not medical advice. Consult a healthcare professional.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
        }
        .padding(12)
        .background(PepTheme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.amber.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        // Editorial eyebrow — icon param retained for compatibility but not rendered.
        SectionEyebrow(title, accent: color)
    }

    private func emptyStateCard(icon: String, title: String, subtitle: String) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(PepTheme.elevated)
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                }
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000.0)
        }
        return "\(num)"
    }
}
