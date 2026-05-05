import SwiftUI

struct SoccerDrillLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedCategory: SoccerDrillCategory? = nil

    private let accentColor = Color(red: 0.2, green: 0.78, blue: 0.35)

    private var filteredDrills: [SoccerDrill] {
        var drills = SoccerDrillLibrary.all
        if let cat = selectedCategory {
            drills = drills.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            drills = drills.filter { $0.name.localizedStandardContains(searchText) || $0.category.rawValue.localizedStandardContains(searchText) }
        }
        return drills
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    categoryFilter

                    ForEach(filteredDrills) { drill in
                        drillRow(drill)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Soccer Drills")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search drills")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterChip(label: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(SoccerDrillCategory.allCases) { cat in
                    filterChip(label: cat.rawValue, icon: cat.icon, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private func filterChip(label: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { action() }
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? accentColor : PepTheme.elevated)
            .clipShape(Capsule())
        }
    }

    private func drillRow(_ drill: SoccerDrill) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(drill.category.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: drill.category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(drill.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(drill.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    Text(drill.difficulty.rawValue)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(drill.difficulty.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(drill.difficulty.color.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(drill.purpose)
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Label("\(drill.durationMinutes) min", systemImage: "clock")
                    Label(drill.equipment, systemImage: "sportscourt")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(drill.durationMinutes)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("min")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }
}
