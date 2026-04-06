import SwiftUI

struct CompoundDetailView: View {
    let compound: CompoundProfile
    @State private var selectedTab: CompoundTab = .overview
    @State private var headerVisible: Bool = false
    @State private var contentVisible: Bool = false
    @State private var scrollOffset: CGFloat = 0

    private var accentColor: Color {
        compound.categories.first?.color ?? PepTheme.teal
    }

    private enum CompoundTab: String, CaseIterable {
        case overview = "Overview"
        case protocols = "Protocols"
        case social = "Social"
        case sourcing = "Sourcing"

        var icon: String {
            switch self {
            case .overview: return "info.circle.fill"
            case .protocols: return "list.bullet.clipboard.fill"
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
        .background(PepTheme.background.ignoresSafeArea())
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
                    accentColor.opacity(0.6), accentColor.opacity(0.3), PepTheme.violet.opacity(0.3),
                    accentColor.opacity(0.4), accentColor.opacity(0.5), PepTheme.blue.opacity(0.3),
                    PepTheme.background, PepTheme.background, PepTheme.background
                ]
            )
            .frame(height: 280)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 76, height: 76)
                    Image(systemName: compound.iconName)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(accentColor)
                        .symbolRenderingMode(.hierarchical)
                }
                .opacity(headerVisible ? 1 : 0)
                .scaleEffect(headerVisible ? 1 : 0.85)

                VStack(spacing: 5) {
                    Text(compound.name)
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text(compound.peptideType)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .opacity(headerVisible ? 1 : 0)

                HStack(spacing: 6) {
                    if compound.isWADAProhibited {
                        HStack(spacing: 4) {
                            Image(systemName: "nosign")
                                .font(.system(size: 9))
                            Text("WADA")
                                .font(.system(.caption2, weight: .bold))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.red.opacity(0.12))
                        .clipShape(.capsule)
                    }
                    ForEach(compound.categories) { cat in
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 9))
                            Text(cat.rawValue)
                                .font(.system(.caption2, weight: .bold))
                        }
                        .foregroundStyle(cat.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(cat.color.opacity(0.12))
                        .clipShape(.capsule)
                    }
                }

                statsRow
                    .padding(.top, 4)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: String(format: "%.1f", compound.averageRating),
                label: "Rating",
                icon: "star.fill",
                iconColor: .yellow
            )

            statDivider

            statItem(
                value: formatNumber(compound.communityUsers),
                label: "Tracking",
                icon: "person.2.fill",
                iconColor: accentColor
            )

            statDivider

            statItem(
                value: "\(compound.structuredSideEffects.count)",
                label: "Side Effects",
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange
            )

            statDivider

            statItem(
                value: "\(compound.stackPartners.count)",
                label: "Stacks",
                icon: "link",
                iconColor: PepTheme.violet
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }

    private func statItem(value: String, label: String, icon: String, iconColor: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PepTheme.separatorColor)
            .frame(width: 1, height: 40)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(CompoundTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10))
                        Text(tab.rawValue)
                            .font(.system(.caption, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? accentColor : PepTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? accentColor.opacity(0.1) : .clear)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .sensoryFeedback(.selection, trigger: selectedTab)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            disclaimerBanner

            if compound.isWADAProhibited && !compound.wadaCategory.isEmpty {
                wadaBanner
            }

            quickReferenceCard

            if !compound.primaryUseCases.isEmpty {
                primaryUseCasesCard
            }

            keyFactsCard

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

            if !compound.detailedSideEffects.contraindications.isEmpty {
                contraindicationsCard
            }

            if !compound.stackDetails.isEmpty {
                stackDetailsCard
            } else if !compound.stackPartners.isEmpty {
                stackPartnersCard
            }

            if !compound.beginnerTips.isEmpty {
                beginnerTipsCard
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
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(accentColor.opacity(0.7))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Text(value)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
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

    // MARK: - Stack Partners Card

    private var stackPartnersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "link", title: "Common Stack Partners", color: PepTheme.violet)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(compound.stackPartners, id: \.self) { partner in
                            HStack(spacing: 5) {
                                Image(systemName: "pill.fill")
                                    .font(.system(size: 10))
                                Text(partner)
                                    .font(.system(.caption, weight: .bold))
                            }
                            .foregroundStyle(PepTheme.violet)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [PepTheme.violet.opacity(0.12), PepTheme.violet.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(.capsule)
                            .overlay(
                                Capsule().strokeBorder(PepTheme.violet.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Protocols

    private var protocolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            disclaimerBanner

            if !compound.tieredDosing.isEmpty {
                tieredDosingCard
            }

            if !compound.cycleLength.isEmpty || compound.loadingProtocol != "No" || !compound.onOffCycling.isEmpty {
                cycleInfoCard
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
        VStack(alignment: .leading, spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(icon: "chart.bar.fill", title: "Community Stats", color: accentColor)

                    HStack(spacing: 0) {
                        communityMetric(
                            value: formatNumber(compound.communityUsers),
                            label: "Users",
                            icon: "person.2.fill",
                            color: accentColor
                        )
                        communityMetric(
                            value: String(format: "%.1f", compound.averageRating),
                            label: "Rating",
                            icon: "star.fill",
                            color: .yellow
                        )
                        communityMetric(
                            value: "\(compound.stackPartners.count)",
                            label: "Stacks",
                            icon: "link",
                            color: PepTheme.violet
                        )
                        communityMetric(
                            value: "\(compound.protocols.count)",
                            label: "Protocols",
                            icon: "list.bullet",
                            color: PepTheme.blue
                        )
                    }
                }
            }

            ratingBreakdownCard

            emptyStateCard(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Community Reviews Coming Soon",
                subtitle: "Rate and review this compound to help others"
            )
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var ratingBreakdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "star.fill", title: "Rating Breakdown", color: .yellow)

                VStack(spacing: 6) {
                    ForEach((1...5).reversed(), id: \.self) { star in
                        let percentage = ratingPercentage(for: star)
                        HStack(spacing: 8) {
                            Text("\(star)")
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(PepTheme.textSecondary)
                                .frame(width: 12)
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.yellow)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(PepTheme.elevated)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(.yellow.opacity(0.7))
                                        .frame(width: geo.size.width * percentage, height: 6)
                                }
                            }
                            .frame(height: 6)

                            Text("\(Int(percentage * 100))%")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func ratingPercentage(for star: Int) -> Double {
        let rating = compound.averageRating
        switch star {
        case 5: return min(1.0, max(0, (rating - 4.0) / 1.0) * 0.6)
        case 4: return min(1.0, max(0, rating / 5.0) * 0.3)
        case 3: return 0.07
        case 2: return 0.02
        default: return 0.01
        }
    }

    private func communityMetric(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
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
        HStack(spacing: 10) {
            Image(systemName: "nosign")
                .font(.system(size: 18))
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("WADA Prohibited")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.red)
                Text(compound.wadaCategory)
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
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
                sectionHeader(icon: "xmark.shield.fill", title: "Contraindications", color: .red)

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
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "pill.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PepTheme.violet)
                                Text(stack.partner)
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
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
                }
            }
        }
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
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(title)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
        }
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
