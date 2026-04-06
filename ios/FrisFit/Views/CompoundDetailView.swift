import SwiftUI

struct CompoundDetailView: View {
    let compound: CompoundProfile
    @State private var selectedTab: CompoundTab = .overview

    private enum CompoundTab: String, CaseIterable {
        case overview = "Overview"
        case protocols = "Protocols"
        case community = "Community"
        case sourcing = "Sourcing"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                tabBar
                    .padding(.top, 16)

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
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                (compound.categories.first?.color ?? PepTheme.teal).opacity(0.2),
                                PepTheme.background
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 140)

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((compound.categories.first?.color ?? PepTheme.teal).opacity(0.15))
                            .frame(width: 72, height: 72)

                        Image(systemName: compound.iconName)
                            .font(.system(size: 32))
                            .foregroundStyle(compound.categories.first?.color ?? PepTheme.teal)
                    }

                    VStack(spacing: 4) {
                        Text(compound.name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)

                        Text(compound.peptideType)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .offset(y: 20)
            }

            HStack(spacing: 6) {
                ForEach(compound.categories) { cat in
                    HStack(spacing: 4) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 10))
                        Text(cat.rawValue)
                            .font(.system(.caption, weight: .semibold))
                    }
                    .foregroundStyle(cat.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(cat.color.opacity(0.12))
                    .clipShape(.capsule)
                }
            }
            .padding(.top, 24)

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", compound.averageRating))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Text("Rating")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    Text("\(compound.communityUsers)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Tracking")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Rectangle()
                    .fill(PepTheme.separatorColor)
                    .frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    Text("\(compound.sideEffects.count)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Side Effects")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
            .padding(.horizontal)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CompoundTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(.caption, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(selectedTab == tab ? PepTheme.textPrimary : PepTheme.textSecondary)
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(selectedTab == tab ? PepTheme.teal : .clear)
                            .frame(height: 2)
                            .clipShape(.capsule)
                    }
                }
                .sensoryFeedback(.selection, trigger: selectedTab)
            }
        }
        .padding(.horizontal)
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            disclaimerBanner

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(PepTheme.teal)
                        Text("About")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }

                    Text(compound.overview)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                        .lineSpacing(4)
                }
            }

            if !compound.sideEffects.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Commonly Reported Side Effects")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(compound.sideEffects, id: \.self) { effect in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(.orange.opacity(0.6))
                                        .frame(width: 5, height: 5)
                                    Text(effect)
                                        .font(.subheadline)
                                        .foregroundStyle(PepTheme.textPrimary.opacity(0.8))
                                }
                            }
                        }
                    }
                }
            }

            if !compound.stackPartners.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .foregroundStyle(PepTheme.violet)
                            Text("Common Stack Partners")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }

                        HStack(spacing: 8) {
                            ForEach(compound.stackPartners, id: \.self) { partner in
                                HStack(spacing: 4) {
                                    Image(systemName: "pill.fill")
                                        .font(.system(size: 10))
                                    Text(partner)
                                        .font(.system(.caption, weight: .semibold))
                                }
                                .foregroundStyle(PepTheme.violet)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(PepTheme.violet.opacity(0.1))
                                .clipShape(.capsule)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var disclaimerBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title3)
                .foregroundStyle(PepTheme.amber)

            Text("This information is for educational and research purposes only. It is not medical advice. Consult a healthcare professional before using any peptide.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
        }
        .padding(12)
        .background(PepTheme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.amber.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var protocolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            disclaimerBanner

            ForEach(compound.protocols) { proto in
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(proto.goalName)
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.teal)

                        Text(proto.description)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary.opacity(0.85))

                        HStack(spacing: 16) {
                            protocolStat(label: "Dose", value: proto.typicalDose)
                            protocolStat(label: "Frequency", value: proto.frequency)
                            protocolStat(label: "Duration", value: proto.duration)
                        }
                    }
                }
            }

            if compound.protocols.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No protocol data available yet")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func protocolStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(PepTheme.teal)
                        Text("Community Stats")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }

                    HStack(spacing: 0) {
                        communityStat(value: "\(compound.communityUsers)", label: "Users Tracking", icon: "person.2.fill", color: PepTheme.teal)
                        communityStat(value: String(format: "%.1f", compound.averageRating), label: "Avg Rating", icon: "star.fill", color: .yellow)
                        communityStat(value: "\(compound.stackPartners.count)", label: "Stack Partners", icon: "link", color: PepTheme.violet)
                    }
                }
            }

            GlassCard {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.title2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text("Community reviews coming soon")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("Rate and review this compound to help others in the community.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func communityStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var sourcingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let matchingVendors = CompoundDatabase.vendors(for: compound.name)

            if matchingVendors.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "building.2")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No verified vendors listed yet")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
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
}
