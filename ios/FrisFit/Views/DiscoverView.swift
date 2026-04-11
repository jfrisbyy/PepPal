import SwiftUI

struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var showBeginnersGuide: Bool = false
    @State private var showAIChat: Bool = false
    @State private var heroAppeared: Bool = false
    @State private var cardsAppeared: Bool = false

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
            .background(PepTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.large)
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    segmentToggle
                }
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
                    onNavigateToCompound: { compound in
                        showAIChat = false
                    },
                    onNavigateToVendor: { vendor in
                        showAIChat = false
                    }
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
                withAnimation(.easeOut(duration: 0.7)) {
                    heroAppeared = true
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    cardsAppeared = true
                }
            }
        }
    }

    private var segmentToggle: some View {
        HStack(spacing: 0) {
            ForEach(DiscoverViewModel.DiscoverSegment.allCases, id: \.self) { segment in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(.system(.caption2, weight: viewModel.selectedSegment == segment ? .bold : .medium))
                        .foregroundStyle(viewModel.selectedSegment == segment ? PepTheme.invertedText : PepTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.selectedSegment == segment ? PepTheme.teal : Color.clear)
                        .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: viewModel.selectedSegment)
            }
        }
        .padding(2)
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    // MARK: - AI Floating Button

    private var aiFloatingButton: some View {
        Button {
            showAIChat = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PepTheme.teal, PepTheme.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: PepTheme.teal.opacity(0.4), radius: 12, x: 0, y: 4)

                Image(systemName: "questionmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: showAIChat)
        .padding(.trailing, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Compounds Content

    private var compoundsContent: some View {
        VStack(spacing: 0) {
            editorialHeroCard
                .padding(.top, 8)
                .padding(.bottom, 20)

            searchBar
                .padding(.horizontal)
                .padding(.bottom, 16)

            categoryPills
                .padding(.bottom, 20)

            trendingSection
                .padding(.bottom, 24)

            compoundsSectionHeader
                .padding(.horizontal)
                .padding(.bottom, 12)

            compoundsGrid
                .padding(.horizontal)
        }
    }

    private var vendorsContent: some View {
        VStack(spacing: 16) {
            searchBar
                .padding(.horizontal)
                .padding(.top, 8)

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
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Image(systemName: "atom")
                            .font(.system(size: 90, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.06))
                            .rotationEffect(.degrees(-12))
                            .offset(x: -12, y: 10)
                        Image(systemName: "hexagon")
                            .font(.system(size: 50, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.05))
                            .offset(x: -80, y: 6)
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 28, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.04))
                            .offset(x: -30, y: 70)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 10))
                        Text("BEGINNER'S GUIDE")
                            .font(.system(.caption2, weight: .heavy))
                            .tracking(1.5)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 8)

                    Text("Understanding\nPeptide Research")
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .padding(.bottom, 8)

                    Text("Reconstitution, injection technique, storage & reading COAs")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                        .padding(.bottom, 8)

                    HStack(spacing: 5) {
                        Text("Read the Guide")
                            .font(.system(.caption, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.15))
                    .clipShape(.capsule)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .clipShape(.rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 10)
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)

            TextField(viewModel.selectedSegment == .compounds ? "Search compounds..." : "Search vendors...", text: $viewModel.searchText)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .overlay(
            Capsule().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    // MARK: - Category Pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PeptideCategory.allCases) { category in
                    let isSelected = viewModel.selectedCategory == category
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: category.icon)
                                .font(.system(size: 11))
                            Text(category.rawValue)
                                .font(.system(.caption, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? .white : PepTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background {
                            if isSelected {
                                Capsule().fill(category.color)
                                    .shadow(color: category.color.opacity(0.4), radius: 6, y: 2)
                            } else {
                                Capsule().fill(PepTheme.cardSurface)
                                    .overlay(Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 1))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text("Trending This Week")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(viewModel.trendingCompounds.count) compounds")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.trendingCompounds.enumerated()), id: \.element.id) { index, compound in
                        NavigationLink(value: compound) {
                            TrendingCompoundCard(compound: compound, rank: index + 1)
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedCategory == .all ? "All Compounds" : viewModel.selectedCategory.rawValue)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("\(viewModel.filteredCompounds.count) available")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Compounds Grid

    private var compoundsGrid: some View {
        LazyVStack(spacing: 10) {
            ForEach(viewModel.filteredCompounds) { compound in
                NavigationLink(value: compound) {
                    CompoundCardView(compound: compound)
                }
                .buttonStyle(.scale)
            }
        }
    }

    // MARK: - Vendors

    private var vendorsList: some View {
        LazyVStack(spacing: 12) {
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

    private var accentColor: Color {
        compound.categories.first?.color ?? PepTheme.teal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [accentColor.opacity(0.2), accentColor.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 72)

                Image(systemName: compound.iconName)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(accentColor.opacity(0.15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)

                Text("#\(rank)")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.15))
                    .clipShape(.capsule)
                    .padding(10)
            }
            .frame(height: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(compound.name)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                Text(compound.categories.first?.rawValue ?? "")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", compound.averageRating))
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(formatCompact(compound.communityUsers))
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 150)
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
        if num >= 1000 { return String(format: "%.1fK", Double(num) / 1000.0) }
        return "\(num)"
    }
}

// MARK: - Compound Card

struct CompoundCardView: View {
    let compound: CompoundProfile

    private var accentColor: Color {
        compound.categories.first?.color ?? PepTheme.teal
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .padding(.vertical, 10)

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.22), accentColor.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: compound.iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(accentColor)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(compound.name)
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text(compound.peptideType)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", compound.averageRating))
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(accentColor.opacity(0.7))
                            Text(formatCompact(compound.communityUsers))
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }

                        if !compound.sideEffects.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.orange.opacity(0.7))
                                Text("\(compound.sideEffects.count)")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(compound.categories.prefix(2)) { cat in
                        Text(cat.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(cat.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(cat.color.opacity(0.12))
                            .clipShape(.capsule)
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
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

    private func formatCompact(_ num: Int) -> String {
        if num >= 1000 { return String(format: "%.1fK", Double(num) / 1000.0) }
        return "\(num)"
    }
}

// MARK: - Vendor Card

struct VendorCardView: View {
    let vendor: Vendor

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: vendor.isVerified
                                ? [PepTheme.teal.opacity(0.2), PepTheme.teal.opacity(0.08)]
                                : [PepTheme.elevated, PepTheme.elevated],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: vendor.isVerified ? "checkmark.shield.fill" : "building.2.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(vendor.isVerified ? PepTheme.teal : PepTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(vendor.name)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    if vendor.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.teal)
                    }
                }

                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", vendor.rating))
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("(\(vendor.reviewCount))")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "pill.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.teal.opacity(0.7))
                        Text("\(vendor.compoundsCarried.count) compounds")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(14)
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
}

extension CompoundProfile: Hashable {
    nonisolated static func == (lhs: CompoundProfile, rhs: CompoundProfile) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Vendor: Hashable {
    nonisolated static func == (lhs: Vendor, rhs: Vendor) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
