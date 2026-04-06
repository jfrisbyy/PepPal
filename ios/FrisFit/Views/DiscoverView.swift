import SwiftUI

struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var showBeginnersGuide: Bool = false
    @State private var heroAppeared: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    segmentPicker
                        .padding(.horizontal)

                    if viewModel.selectedSegment == .compounds {
                        searchBar
                            .padding(.horizontal)

                        featuredHeroBanner

                        categoryPills

                        compoundsGrid
                            .padding(.horizontal)
                    } else {
                        searchBar
                            .padding(.horizontal)

                        vendorsList
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: CompoundProfile.self) { compound in
                CompoundDetailView(compound: compound)
            }
            .navigationDestination(for: Vendor.self) { vendor in
                VendorDetailView(vendor: vendor)
            }
            .sheet(isPresented: $showBeginnersGuide) {
                BeginnersGuideView()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    heroAppeared = true
                }
            }
        }
    }

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(DiscoverViewModel.DiscoverSegment.allCases, id: \.self) { segment in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(.system(.subheadline, weight: viewModel.selectedSegment == segment ? .bold : .medium))
                        .foregroundStyle(viewModel.selectedSegment == segment ? PepTheme.invertedText : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.selectedSegment == segment ? PepTheme.teal : Color.clear)
                        .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: viewModel.selectedSegment)
            }
        }
        .padding(3)
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)

            TextField("Search compounds, vendors...", text: $viewModel.searchText)
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
        .background(PepTheme.elevated)
        .clipShape(.capsule)
    }

    private var featuredHeroBanner: some View {
        VStack(spacing: 12) {
            Button {
                showBeginnersGuide = true
            } label: {
                ZStack(alignment: .bottomLeading) {
                    MeshGradient(
                        width: 3, height: 3,
                        points: [
                            [0, 0], [0.5, 0], [1, 0],
                            [0, 0.5], [0.5, 0.5], [1, 0.5],
                            [0, 1], [0.5, 1], [1, 1]
                        ],
                        colors: [
                            PepTheme.teal.opacity(0.8), PepTheme.blue.opacity(0.6), PepTheme.violet.opacity(0.5),
                            PepTheme.teal.opacity(0.6), PepTheme.blue.opacity(0.4), PepTheme.violet.opacity(0.7),
                            PepTheme.teal.opacity(0.3), PepTheme.blue.opacity(0.5), PepTheme.violet.opacity(0.4)
                        ]
                    )
                    .frame(height: 160)
                    .overlay {
                        VStack {
                            Spacer()
                            LinearGradient(
                                colors: [.black.opacity(0.6), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: 100)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.15))
                            .rotationEffect(.degrees(-15))
                            .offset(x: -20, y: 15)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 13))
                            Text("BEGINNER'S GUIDE")
                                .font(.system(.caption2, weight: .heavy))
                                .tracking(1.2)
                        }
                        .foregroundStyle(.white.opacity(0.8))

                        Text("Master the Basics")
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Reconstitution, injection technique, storage & reading COAs")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(16)
                }
                .clipShape(.rect(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
            }
            .buttonStyle(.scale)
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.featuredCompounds) { compound in
                        NavigationLink(value: compound) {
                            FeaturedCompoundPill(compound: compound)
                        }
                        .buttonStyle(.scale)
                    }
                }
                .padding(.horizontal, 16)
            }
            .contentMargins(.horizontal, 0)
        }
    }

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
                        .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? AnyShapeStyle(category.color) : AnyShapeStyle(PepTheme.cardSurface))
                        .clipShape(.capsule)
                        .overlay(
                            Capsule().strokeBorder(isSelected ? Color.clear : PepTheme.separatorColor, lineWidth: 1)
                        )
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.selectedCategory)
                }
            }
            .padding(.horizontal, 16)
        }
        .contentMargins(.horizontal, 0)
    }

    private var compoundsGrid: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredCompounds) { compound in
                NavigationLink(value: compound) {
                    CompoundCardView(compound: compound)
                }
                .buttonStyle(.scale)
            }
        }
    }

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

struct FeaturedCompoundPill: View {
    let compound: CompoundProfile

    private var accentColor: Color {
        compound.categories.first?.color ?? PepTheme.teal
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: compound.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(compound.name)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", compound.averageRating))
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.capsule)
        .overlay(
            Capsule().strokeBorder(
                LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
        )
    }
}

struct CompoundCardView: View {
    let compound: CompoundProfile

    private var accentColor: Color {
        compound.categories.first?.color ?? PepTheme.teal
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.2), accentColor.opacity(0.08)],
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
                        .font(.system(.subheadline, weight: .bold))
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
                            Text("\(compound.communityUsers)")
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
            .padding(.horizontal, 14)
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
}

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
