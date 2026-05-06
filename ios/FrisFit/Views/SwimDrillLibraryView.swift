import SwiftUI

struct SwimDrillLibraryView: View {
    @Bindable var swimVM: SwimmingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var selectedCategory: SwimDrillCategory? = nil
    @State private var selectedDifficulty: SwimDrillDifficulty? = nil
    @State private var selectedStroke: SwimStrokeType? = nil
    @State private var selectedDrill: SwimDrill? = nil

    private let accentColor = Color(red: 0.2, green: 0.6, blue: 1.0)

    private var filteredDrills: [SwimDrill] {
        SwimDrillLibraryData.all.filter { drill in
            let matchesSearch = searchText.isEmpty
                || drill.name.localizedStandardContains(searchText)
                || drill.description.localizedStandardContains(searchText)
                || drill.purpose.localizedStandardContains(searchText)
            let matchesCategory = selectedCategory == nil || drill.category == selectedCategory
            let matchesDifficulty = selectedDifficulty == nil || drill.difficulty == selectedDifficulty
            let matchesStroke = selectedStroke == nil || drill.targetStroke == selectedStroke
            return matchesSearch && matchesCategory && matchesDifficulty && matchesStroke
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    filterBar

                    if filteredDrills.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredDrills) { drill in
                                Button {
                                    selectedDrill = drill
                                } label: {
                                    drillCard(drill)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search drills, strokes, focus...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .sheet(item: $selectedDrill) { drill in
                SwimDrillDetailView(drill: drill)
            }
        }
    }

    private var headerCard: some View {
        EditorialSportHeader(
            kicker: "Drill Library",
            title: "Sharpen the stroke",
            subtitle: "\(SwimDrillLibraryData.all.count) drills across technique, kick, pull, speed, endurance and recovery.",
            accent: accentColor,
            stats: [
                EditorialStat("\(SwimDrillLibraryData.all.count)", "Total"),
                EditorialStat("\(SwimDrillCategory.allCases.count)", "Cats"),
                EditorialStat("\(filteredDrills.count)", "Showing")
            ]
        )
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "Filter", title: "Find your set", accent: accentColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(label: "All", isSelected: selectedCategory == nil, color: accentColor) {
                        selectedCategory = nil
                    }
                    ForEach(SwimDrillCategory.allCases) { cat in
                        filterChip(label: cat.rawValue, isSelected: selectedCategory == cat, color: cat.color) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SwimDrillDifficulty.allCases) { diff in
                        filterChip(label: diff.rawValue, isSelected: selectedDifficulty == diff, color: diff.color) {
                            selectedDifficulty = selectedDifficulty == diff ? nil : diff
                        }
                    }

                    Rectangle()
                        .fill(PepTheme.shimmerHighlight)
                        .frame(width: 0.5, height: 18)
                        .padding(.horizontal, 4)

                    ForEach(SwimStrokeType.allCases) { stroke in
                        filterChip(label: stroke.rawValue, isSelected: selectedStroke == stroke, color: stroke.color) {
                            selectedStroke = selectedStroke == stroke ? nil : stroke
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
        .editorialCard(accent: accentColor)
    }

    private func filterChip(label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(isSelected ? .black : color.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected
                    ? AnyShapeStyle(color)
                    : AnyShapeStyle(color.opacity(0.10))
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(isSelected ? 0 : 0.25), lineWidth: 0.5)
                )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
            Text("No drills match")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Try a different filter or clear search.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func drillCard(_ drill: SwimDrill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(drill.category.color.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: drill.category.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(drill.category.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: drill.category.icon)
                            .font(.system(size: 8, weight: .bold))
                        Text(drill.category.rawValue.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.4)
                    }
                    .foregroundStyle(drill.category.color)

                    Text(drill.name)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .kerning(-0.2)
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(drill.durationMinutes)")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("MIN")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Text(drill.purpose)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                pill(text: drill.difficulty.rawValue, color: drill.difficulty.color)
                if let stroke = drill.targetStroke {
                    pill(text: stroke.rawValue, color: stroke.color)
                }
                if let setsReps = drill.setsReps {
                    pill(text: setsReps, color: PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
        }
        .editorialCard(accent: drill.category.color, cornerRadius: 14)
    }

    private func pill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.18), lineWidth: 0.5))
    }
}
