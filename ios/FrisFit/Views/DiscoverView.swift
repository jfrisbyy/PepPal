import SwiftUI

struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var showBeginnersGuide: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                segmentPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        searchBar
                            .padding(.horizontal)

                        if viewModel.selectedSegment == .compounds {
                            beginnersGuideCard
                                .padding(.horizontal)

                            categoryPills

                            compoundsList
                                .padding(.horizontal)
                        } else {
                            vendorsList
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
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

    private var beginnersGuideCard: some View {
        Button {
            showBeginnersGuide = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [PepTheme.teal, PepTheme.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Beginner's Guide")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Learn the basics — reconstitution, injection technique, storage & COAs")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(colors: [PepTheme.teal.opacity(0.3), PepTheme.blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.scale)
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

    private var compoundsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(viewModel.filteredCompounds) { compound in
                NavigationLink(value: compound) {
                    CompoundCardView(compound: compound)
                }
                .buttonStyle(.scale)
            }
        }
    }

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

struct CompoundCardView: View {
    let compound: CompoundProfile

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(compound.categories.first?.color.opacity(0.15) ?? PepTheme.teal.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: compound.iconName)
                    .font(.title3)
                    .foregroundStyle(compound.categories.first?.color ?? PepTheme.teal)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(compound.name)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)

                Text(compound.peptideType)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", compound.averageRating))
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.teal)
                        Text("\(compound.communityUsers)")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(compound.categories.prefix(2)) { cat in
                    Text(cat.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(cat.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(cat.color.opacity(0.12))
                        .clipShape(.capsule)
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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
                    .fill(vendor.isVerified ? PepTheme.teal.opacity(0.15) : PepTheme.elevated)
                    .frame(width: 50, height: 50)

                Image(systemName: vendor.isVerified ? "checkmark.shield.fill" : "building.2.fill")
                    .font(.title3)
                    .foregroundStyle(vendor.isVerified ? PepTheme.teal : PepTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
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

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", vendor.rating))
                            .font(.system(.caption2, weight: .semibold))
                        Text("(\(vendor.reviewCount))")
                            .font(.caption2)
                    }
                    .foregroundStyle(PepTheme.textSecondary)

                    Text("\(vendor.compoundsCarried.count) compounds")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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
