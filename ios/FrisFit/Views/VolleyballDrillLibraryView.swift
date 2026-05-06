import SwiftUI

struct VolleyballDrillLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedCategory: VolleyballDrillCategory? = nil
    @State private var selectedDifficulty: VolleyballDrillDifficulty? = nil
    @State private var selectedDrill: VolleyballDrill? = nil

    private let accentColor = Color(red: 0.95, green: 0.30, blue: 0.20)

    private var filteredDrills: [VolleyballDrill] {
        var drills = VolleyballDrillLibrary.all
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
            .sheet(item: $selectedDrill) { drill in
                VolleyballDrillDetailView(drill: drill)
            }
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("DRILL LIBRARY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    Text("\(filteredDrills.count) of \(VolleyballDrillLibrary.all.count)")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text("Sharpen the touch.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)

                Text("Curated drills across \(VolleyballDrillCategory.allCases.count) skill areas — tap any drill for the full breakdown, coaching cues, and progressions.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "Filter", title: "Category", accent: accentColor)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip(label: "All", color: accentColor, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(VolleyballDrillCategory.allCases) { cat in
                        chip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: selectedCategory == cat) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .editorialCard(accent: accentColor)
    }

    private var difficultyFilter: some View {
        HStack(spacing: 8) {
            chip(label: "Any Level", color: PepTheme.textSecondary, isSelected: selectedDifficulty == nil) {
                selectedDifficulty = nil
            }
            ForEach(VolleyballDrillDifficulty.allCases) { diff in
                chip(label: diff.rawValue, color: diff.color, isSelected: selectedDifficulty == diff) {
                    selectedDifficulty = (selectedDifficulty == diff) ? nil : diff
                }
            }
        }
    }

    private func chip(label: String, icon: String? = nil, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
            }
            .foregroundStyle(isSelected ? .black : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var drillList: some View {
        VStack(spacing: 10) {
            if filteredDrills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text("No drills match those filters.")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .editorialCard(accent: accentColor)
            } else {
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

    private func drillCard(_ drill: VolleyballDrill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(drill.category.color.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: drill.category.icon)
                        .font(.system(size: 17))
                        .foregroundStyle(drill.category.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(drill.name)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(drill.category.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(drill.category.color)
                        Text("·")
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text(drill.difficulty.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(drill.difficulty.color)
                        Text("·")
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("\(drill.durationMinutes)m")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }

            Text(drill.purpose)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorialCard(accent: drill.category.color)
    }
}

// MARK: - Drill detail

struct VolleyballDrillDetailView: View {
    let drill: VolleyballDrill
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    if !drill.steps.isEmpty { stepsCard }
                    if !drill.cues.isEmpty { cuesCard }
                    metaCard
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground(accent: drill.category.color)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(drill.category.color)
                }
            }
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: drill.category.color) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(drill.category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(drill.category.color.opacity(0.9))
                    Spacer()
                    Text(drill.difficulty.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(drill.difficulty.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(drill.difficulty.color.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(drill.name)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)

                Text(drill.purpose)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                Text(drill.description)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "How To", title: "The Steps", accent: drill.category.color)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(drill.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(format: "%02d", idx + 1))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(drill.category.color)
                            .frame(width: 24, alignment: .leading)
                        Text(step)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .editorialCard(accent: drill.category.color)
    }

    private var cuesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Coaching", title: "Cues", accent: PepTheme.amber)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(drill.cues, id: \.self) { cue in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.amber.opacity(0.7))
                        Text(cue)
                            .font(.system(size: 13, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private var metaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Setup", title: "Logistics", accent: PepTheme.violet)
            VStack(spacing: 10) {
                metaRow(label: "Duration", value: "\(drill.durationMinutes) min")
                metaRow(label: "Equipment", value: drill.equipment)
                if let setsReps = drill.setsReps {
                    metaRow(label: "Sets / Reps", value: setsReps)
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}
