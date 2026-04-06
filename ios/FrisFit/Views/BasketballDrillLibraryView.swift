import SwiftUI

struct BasketballDrillLibraryView: View {
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedCategory: DrillCategory? = nil
    @State private var selectedDrills: Set<UUID> = []
    @State private var isBuilding: Bool = false
    @State private var planName: String = ""

    private let accentColor = Color(red: 1.0, green: 0.55, blue: 0.1)

    private var filteredDrills: [BasketballDrill] {
        var drills = BasketballDrillLibrary.all
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
                    
                    if isBuilding {
                        buildPlanHeader
                    }

                    ForEach(filteredDrills) { drill in
                        drillRow(drill)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Drill Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search drills")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            isBuilding.toggle()
                            if !isBuilding {
                                selectedDrills.removeAll()
                                planName = ""
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isBuilding ? "xmark" : "plus.rectangle.on.folder")
                                .font(.system(size: 12))
                            Text(isBuilding ? "Cancel" : "Build Plan")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(accentColor)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isBuilding && !selectedDrills.isEmpty {
                    savePlanBar
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
                ForEach(DrillCategory.allCases) { cat in
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

    private var buildPlanHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(accentColor)
                Text("Building Practice Plan")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(selectedDrills.count) drills")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            TextField("Plan Name", text: $planName)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)
                .padding(12)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
        }
        .padding(14)
        .background(accentColor.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func drillRow(_ drill: BasketballDrill) -> some View {
        let isSelected = selectedDrills.contains(drill.id)

        return Button {
            if isBuilding {
                withAnimation(.spring(duration: 0.2)) {
                    if isSelected { selectedDrills.remove(drill.id) }
                    else { selectedDrills.insert(drill.id) }
                }
            }
        } label: {
            HStack(spacing: 12) {
                if isBuilding {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? accentColor : PepTheme.textSecondary)
                }

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
            .background(isSelected ? accentColor.opacity(0.06) : PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? accentColor.opacity(0.3) : PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var savePlanBar: some View {
        Button {
            let selectedDrillsList = BasketballDrillLibrary.all.filter { selectedDrills.contains($0.id) }
            let plan = PracticePlan(
                name: planName.isEmpty ? "Practice Plan" : planName,
                drills: selectedDrillsList.map { PracticePlanDrill(drill: $0) }
            )
            bbVM.savePracticePlan(plan)
            isBuilding = false
            selectedDrills.removeAll()
            planName = ""
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("Save Plan (\(selectedDrills.count) drills)")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(accentColor)
            .clipShape(.rect(cornerRadius: 14))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(
            PepTheme.background
                .shadow(color: .black.opacity(0.5), radius: 20, y: -8)
                .ignoresSafeArea()
        )
    }
}
