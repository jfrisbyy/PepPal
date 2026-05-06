import SwiftUI

struct SoccerDrillLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedCategory: SoccerDrillCategory? = nil
    @State private var selectedDifficulty: SoccerDrillDifficulty? = nil

    private let accentColor = Color(red: 0.2, green: 0.78, blue: 0.35)

    private var filteredDrills: [SoccerDrill] {
        var drills = SoccerDrillLibrary.all
        if let cat = selectedCategory {
            drills = drills.filter { $0.category == cat }
        }
        if let diff = selectedDifficulty {
            drills = drills.filter { $0.difficulty == diff }
        }
        if !searchText.isEmpty {
            drills = drills.filter {
                $0.name.localizedStandardContains(searchText)
                || $0.category.rawValue.localizedStandardContains(searchText)
                || $0.purpose.localizedStandardContains(searchText)
            }
        }
        return drills
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    categoryFilter
                    difficultyFilter
                    drillList
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search drills")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
            .sheet(item: $bound) { drill in
                SoccerDrillDetailView(drill: drill)
            }
        }
    }

    @State private var bound: SoccerDrill? = nil

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("DRILL LIBRARY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    Text("\(filteredDrills.count) of \(SoccerDrillLibrary.all.count)")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text("Sharpen the touch.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)

                Text("Curated drills across \(SoccerDrillCategory.allCases.count) skill areas — tap any drill for the full breakdown, coaching cues, and progressions.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CATEGORY")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    filterChip(label: "All", icon: nil, color: accentColor, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(SoccerDrillCategory.allCases) { cat in
                        filterChip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: selectedCategory == cat) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private var difficultyFilter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DIFFICULTY")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary)

            HStack(spacing: 8) {
                difficultyChip(label: "Any", color: PepTheme.textSecondary, isSelected: selectedDifficulty == nil) {
                    selectedDifficulty = nil
                }
                ForEach(SoccerDrillDifficulty.allCases) { diff in
                    difficultyChip(label: diff.rawValue, color: diff.color, isSelected: selectedDifficulty == diff) {
                        selectedDifficulty = (selectedDifficulty == diff) ? nil : diff
                    }
                }
            }
        }
    }

    private func difficultyChip(label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { action() }
        } label: {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(isSelected ? .black : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? color : color.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func filterChip(label: String, icon: String?, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { action() }
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
            }
            .foregroundStyle(isSelected ? .black : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.10))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var drillList: some View {
        VStack(spacing: 10) {
            if filteredDrills.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text("No drills match those filters.")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(filteredDrills) { drill in
                    Button {
                        bound = drill
                    } label: {
                        drillRow(drill)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func drillRow(_ drill: SoccerDrill) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 5) {
                    Image(systemName: drill.category.icon)
                        .font(.system(size: 9, weight: .bold))
                    Text(drill.category.rawValue.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.6)
                }
                .foregroundStyle(drill.category.color)

                Spacer()

                Text(drill.difficulty.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(drill.difficulty.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(drill.difficulty.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(drill.name)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .kerning(-0.2)
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)

            Text(drill.purpose)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            LinearGradient(
                colors: [drill.category.color.opacity(0.25), drill.category.color.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.5)

            HStack(spacing: 14) {
                metaChip(icon: "clock", text: "\(drill.durationMinutes) min")
                metaChip(icon: "sportscourt", text: drill.equipment)
                if let setsReps = drill.setsReps {
                    metaChip(icon: "repeat", text: setsReps)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
        }
        .editorialCard(accent: drill.category.color)
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(PepTheme.textSecondary)
    }
}
