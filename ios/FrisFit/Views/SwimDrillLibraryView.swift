import SwiftUI

struct SwimDrillLibraryView: View {
    @Bindable var swimVM: SwimmingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var selectedCategory: SwimDrillCategory? = nil
    @State private var selectedDifficulty: SwimDrillDifficulty? = nil

    private let accentColor = Color(red: 0.2, green: 0.6, blue: 1.0)

    private var filteredDrills: [SwimDrill] {
        SwimDrillLibraryData.all.filter { drill in
            let matchesSearch = searchText.isEmpty || drill.name.localizedStandardContains(searchText) || drill.description.localizedStandardContains(searchText)
            let matchesCategory = selectedCategory == nil || drill.category == selectedCategory
            let matchesDifficulty = selectedDifficulty == nil || drill.difficulty == selectedDifficulty
            return matchesSearch && matchesCategory && matchesDifficulty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    filterBar

                    if filteredDrills.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                            Text("No drills found")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredDrills) { drill in
                                drillCard(drill)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Swim Drills")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search drills...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(label: "All", isSelected: selectedCategory == nil) {
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
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    private func filterChip(label: String, isSelected: Bool, color: Color = Color(red: 0.2, green: 0.6, blue: 1.0), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : PepTheme.elevated.opacity(0.5))
                .clipShape(Capsule())
        }
    }

    private func drillCard(_ drill: SwimDrill) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(drill.category.color.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: drill.category.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(drill.category.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(drill.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    HStack(spacing: 8) {
                        Text(drill.category.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(drill.category.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(drill.category.color.opacity(0.12))
                            .clipShape(Capsule())
                        Text(drill.difficulty.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(drill.difficulty.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(drill.difficulty.color.opacity(0.12))
                            .clipShape(Capsule())
                        if let stroke = drill.targetStroke {
                            Text(stroke.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(stroke.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(stroke.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(drill.durationMinutes)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                    Text("min")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Text(drill.description)
                .font(.system(size: 12))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.system(size: 9))
                    .foregroundStyle(accentColor.opacity(0.7))
                Text(drill.purpose)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                    .lineLimit(1)
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
