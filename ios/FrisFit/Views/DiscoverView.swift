import SwiftUI

struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var showBeginnersGuide: Bool = false
    @State private var showAIChat: Bool = false
    @State private var heroAppeared: Bool = false
    @State private var cardsAppeared: Bool = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.selectedSegment == .compounds {
                        compoundsContent
                    } else {
                        vendorsContent
                    }
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newValue in
                scrollOffset = newValue
            }
            .appBackground(accent: PepTheme.blue)
            .navigationBarTitleDisplayMode(.large)
            .navigationTitle("Discover")
            .overlay(alignment: .topTrailing) {
                discoverFloatingPill
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            .navigationDestination(for: CompoundProfile.self) { compound in
                CompoundDetailView(compound: compound)
            }
            .navigationDestination(for: Vendor.self) { vendor in
                VendorDetailView(vendor: vendor)
            }
            .sheet(isPresented: $showBeginnersGuide) {
                BeginnersGuideView()
            }
            .sheet(isPresented: $showAIChat) {
                PeptideAIChatView(
                    onNavigateToCompound: { _ in showAIChat = false },
                    onNavigateToVendor: { _ in showAIChat = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .bottomTrailing) {
                aiFloatingButton
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 0)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) { heroAppeared = true }
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) { cardsAppeared = true }
            }
            .task { await viewModel.refreshLiveStats() }
            .refreshable { await viewModel.forceRefreshLiveStats() }
        }
    }

    private var discoverFloatingPill: some View {
        FloatingNavPill(scrollOffset: scrollOffset) {
            ForEach(Array(DiscoverViewModel.DiscoverSegment.allCases.enumerated()), id: \.element) { idx, segment in
                if idx > 0 { FloatingPillDivider() }
                let isActive = viewModel.selectedSegment == segment
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue.uppercased())
                        .font(.system(size: 10, weight: isActive ? .heavy : .semibold))
                        .tracking(1.4)
                        .foregroundStyle(isActive ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.75))
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: viewModel.selectedSegment)
            }
        }
    }

    // MARK: - AI Floating Button

    private var aiFloatingButton: some View {
        Button {
            showAIChat = true
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)

                Image(systemName: "questionmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showAIChat)
        .padding(.trailing, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Compounds Content

    private var compoundsContent: some View {
        VStack(spacing: 0) {
            editorialHeroCard
                .padding(.top, 8)
                .padding(.bottom, 24)

            searchBar
                .padding(.horizontal)
                .padding(.bottom, 18)

            categoryPills
                .padding(.bottom, 24)

            trendingSection
                .padding(.bottom, 28)

            compoundsSectionHeader
                .padding(.horizontal)
                .padding(.bottom, 14)

            compoundsGrid
                .padding(.horizontal)
        }
    }

    private var vendorsContent: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 18)

            SectionEyebrow("Verified Vendors", number: "01", accent: PepTheme.teal)
                .padding(.horizontal)
                .padding(.bottom, 12)

            vendorsList
                .padding(.horizontal)
        }
    }

    // MARK: - Editorial Hero

    private var editorialHeroCard: some View {
        Button {
            showBeginnersGuide = true
        } label: {
            ZStack {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.5, 0.5], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1]
                    ],
                    colors: [
                        PepTheme.teal.opacity(0.8), PepTheme.blue.opacity(0.5), PepTheme.violet.opacity(0.5),
                        PepTheme.teal.opacity(0.5), PepTheme.blue.opacity(0.7), PepTheme.violet.opacity(0.6),
                        PepTheme.teal.opacity(0.2), PepTheme.blue.opacity(0.3), PepTheme.violet.opacity(0.3)
                    ]
                )
                .frame(height: 200)
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    Text("BEGINNER'S GUIDE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 10)

                    Text("Understanding\nPeptide Research")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .kerning(-0.5)
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .padding(.bottom, 10)

                    Text("Reconstitution, injection technique, storage & reading COAs")
                        .font(.system(.caption, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                        .padding(.bottom, 12)

                    HStack(spacing: 6) {
                        Text("Read the Guide")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.2)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .clipShape(.rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 22, x: 0, y: 10)
        }
        .buttonStyle(.scale)
        .padding(.horizontal)
        .opacity(heroAppeared ? 1 : 0)
        .offset(y: heroAppeared ? 0 : 16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))

            TextField(viewModel.selectedSegment == .compounds ? "Search compounds" : "Search vendors", text: $viewModel.searchText)
                .font(.system(.subheadline, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(
            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.18))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Category Pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PeptideCategory.allCases) { category in
                    let isSelected = viewModel.selectedCategory == category
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedCategory = category
                        }
                    } label: {
                        Text(category.rawValue.uppercased())
                            .font(.system(size: 10, weight: isSelected ? .heavy : .semibold))
                            .tracking(1.3)
                            .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background {
                                if isSelected {
                                    Capsule().fill(PepTheme.textPrimary)
                                } else {
                                    Capsule().strokeBorder(PepTheme.textPrimary.opacity(0.18), lineWidth: 0.5)
                                }
                            }
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.selectedCategory)
                }
            }
            .padding(.horizontal, 16)
        }
        .contentMargins(.horizontal, 0)
    }

    // MARK: - Trending Section

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Trending This Week", number: "01", accent: PepTheme.teal)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.trendingCompounds.enumerated()), id: \.element.id) { index, compound in
                        NavigationLink(value: compound) {
                            TrendingCompoundCard(
                                compound: compound,
                                rank: index + 1,
                                userCount: viewModel.liveUserCount(for: compound),
                                newStarts: viewModel.newStarts(for: compound)
                            )
                        }
                        .buttonStyle(.scale)
                        .opacity(cardsAppeared ? 1 : 0)
                        .offset(y: cardsAppeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.06), value: cardsAppeared)
                    }
                }
                .padding(.horizontal, 16)
            }
            .contentMargins(.horizontal, 0)
        }
    }

    // MARK: - Compounds Section Header

    private var compoundsSectionHeader: some View {
        SectionEyebrow(
            viewModel.selectedCategory == .all ? "Library" : viewModel.selectedCategory.rawValue,
            number: "02",
            accent: PepTheme.blue
        ) {
            Text("\(viewModel.filteredCompounds.count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
        }
    }

    // MARK: - Compounds Grid

    private var compoundsGrid: some View {
        LazyVStack(spacing: 10) {
            ForEach(viewModel.filteredCompounds) { compound in
                NavigationLink(value: compound) {
                    CompoundCardView(
                        compound: compound,
                        userCount: viewModel.liveUserCount(for: compound)
                    )
                }
                .buttonStyle(.scale)
            }
        }
    }

    // MARK: - Vendors

    private var vendorsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(viewModel.filteredVendors) { vendor in
                NavigationLink(value: vendor) {
                    VendorCardView(vendor: vendor)
                }
                .buttonStyle(.scale)
            }
        }
    }
}

// MARK: - Trending Compound Card

struct TrendingCompoundCard: View {
    let compound: CompoundProfile
    let rank: Int
    let userCount: Int
    let newStarts: Int

    private var accentColor: Color {
        compound.categories.first?.color ?? PepTheme.teal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Editorial header strip — accent gradient + rank eyebrow only
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [accentColor.opacity(0.22), accentColor.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 64)

                Text(String(format: "N°%02d", rank))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(accentColor)
                    .padding(12)
            }
            .frame(height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text((compound.categories.first?.rawValue ?? "Compound").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(accentColor.opacity(0.9))

                Text(compound.name)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                Text(formatCompact(userCount))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)

                if newStarts > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .heavy))
                        Text("\(newStarts) this week")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(width: 156)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func formatCompact(_ num: Int) -> String {
        if num >= 1000 { return String(format: "%.1fK users", Double(num) / 1000.0) }
        return "\(num) users"
    }
}

// MARK: - Compound Card

struct CompoundCardView: View {
    let compound: CompoundProfile
    let userCount: Int

    init(compound: CompoundProfile, userCount: Int? = nil) {
        self.compound = compound
        self.userCount = userCount ?? compound.communityUsers
    }

    private var accentColor: Color {
        compound.categories.first?.color ?? PepTheme.teal
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 8) {
                // Eyebrow row — category + WADA tag if any
                HStack(spacing: 8) {
                    Text((compound.categories.first?.rawValue ?? "Compound").uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.3)
                        .foregroundStyle(accentColor)

                    if compound.isWADAProhibited {
                        Text("WADA")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(.red.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(
                                Capsule().strokeBorder(.red.opacity(0.35), lineWidth: 0.5)
                            )
                    }
                    Spacer()
                }

                Text(compound.name)
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text(compound.peptideType)
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)

                Text(metaLine)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                .padding(.trailing, 14)
        }
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var metaLine: String {
        var parts: [String] = []
        if userCount > 0 {
            parts.append("\(formatCompact(userCount)) users")
        } else {
            parts.append("Be the first")
        }
        if !compound.sideEffects.isEmpty {
            parts.append("\(compound.sideEffects.count) cautions")
        }
        return parts.joined(separator: "  ·  ")
    }

    private func formatCompact(_ num: Int) -> String {
        if num >= 1000 { return String(format: "%.1fK", Double(num) / 1000.0) }
        return "\(num)"
    }
}

// MARK: - Vendor Card

struct VendorCardView: View {
    let vendor: Vendor

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: vendor.isVerified
                            ? [PepTheme.teal, PepTheme.teal.opacity(0.25)]
                            : [PepTheme.textSecondary.opacity(0.4), PepTheme.textSecondary.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text(vendor.isVerified ? "VERIFIED VENDOR" : "VENDOR")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.3)
                    .foregroundStyle(vendor.isVerified ? PepTheme.teal : PepTheme.textSecondary)

                HStack(spacing: 6) {
                    Text(vendor.name)
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if vendor.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.teal)
                    }
                }

                Text(metaLine)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                .padding(.trailing, 14)
        }
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var metaLine: String {
        let rating = String(format: "%.1f rating", vendor.rating)
        return "\(rating)  ·  \(vendor.reviewCount) reviews  ·  \(vendor.compoundsCarried.count) compounds"
    }
}

extension CompoundProfile: Hashable {
    nonisolated static func == (lhs: CompoundProfile, rhs: CompoundProfile) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Vendor: Hashable {
    nonisolated static func == (lhs: Vendor, rhs: Vendor) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
