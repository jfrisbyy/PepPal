import SwiftUI

struct CompoundDetailView: View {
    let compound: CompoundProfile
    @State private var selectedTab: CompoundTab = .overview
    @State private var headerVisible: Bool = false

    private var accentColor: Color {
        compound.categories.first?.color ?? PepTheme.teal
    }

    private enum CompoundTab: String, CaseIterable {
        case overview = "Overview"
        case protocols = "Protocols"
        case community = "Community"
        case sourcing = "Sourcing"

        var icon: String {
            switch self {
            case .overview: return "info.circle.fill"
            case .protocols: return "list.bullet.clipboard.fill"
            case .community: return "person.3.fill"
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

                switch selectedTab {
                case .overview:
                    overviewSection
                case .protocols:
                    protocolsSection
                case .community:
                    communitySection
                case .sourcing:
                    sourcingSection
                }
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                headerVisible = true
            }
        }
    }

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
            .frame(height: 260)

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
                .offset(y: headerVisible ? 0 : 10)

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
                value: "\(compound.sideEffects.count)",
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
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
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
            .frame(width: 1, height: 36)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(CompoundTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 4) {
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

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "doc.text.fill", title: "About", color: accentColor)

                    Text(compound.overview)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                        .lineSpacing(5)
                }
            }

            if !compound.sideEffects.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(icon: "exclamationmark.triangle.fill", title: "Commonly Reported Side Effects", color: .orange)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                            ForEach(compound.sideEffects, id: \.self) { effect in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(.orange.opacity(0.6))
                                        .frame(width: 5, height: 5)
                                    Text(effect)
                                        .font(.system(.caption, weight: .medium))
                                        .foregroundStyle(PepTheme.textPrimary.opacity(0.8))
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.orange.opacity(0.06))
                                .clipShape(.rect(cornerRadius: 8))
                            }
                        }
                    }
                }
            }

            if !compound.stackPartners.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(icon: "link", title: "Common Stack Partners", color: PepTheme.violet)

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
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - Protocols

    private var protocolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            disclaimerBanner

            if compound.protocols.isEmpty {
                emptyStateCard(
                    icon: "doc.text.magnifyingglass",
                    title: "No Protocol Data Yet",
                    subtitle: "Community-sourced protocols coming soon"
                )
            } else {
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
