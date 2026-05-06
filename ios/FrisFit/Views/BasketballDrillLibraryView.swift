import SwiftUI

struct BasketballDrillLibraryView: View {
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable, Identifiable {
        case drills = "Drills"
        case templates = "Templates"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .drills
    @State private var searchText: String = ""
    @State private var selectedCategory: DrillCategory? = nil
    @State private var selectedDifficulty: DrillDifficulty? = nil
    @State private var selectedEquipment: DrillEquipment? = nil
    @State private var maxDuration: Int = 30
    @State private var selectedDrills: Set<UUID> = []
    @State private var isBuilding: Bool = false
    @State private var planName: String = ""

    private let accentColor = BasketballPalette.courtOrange

    private var filteredDrills: [BasketballDrill] {
        var drills = BasketballDrillLibrary.all
        if let cat = selectedCategory { drills = drills.filter { $0.category == cat } }
        if let diff = selectedDifficulty { drills = drills.filter { $0.difficulty == diff } }
        if let eq = selectedEquipment { drills = drills.filter { $0.equipment.contains(eq) } }
        drills = drills.filter { $0.durationMinutes <= maxDuration }
        if !searchText.isEmpty {
            drills = drills.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.purpose.localizedStandardContains(searchText) ||
                $0.category.rawValue.localizedStandardContains(searchText)
            }
        }
        return drills
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    tabSwitcher

                    if tab == .drills {
                        drillFilters
                        if isBuilding { buildPlanHeader }
                        drillList
                    } else {
                        templatesList
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search drills")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
                if tab == .drills {
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
                                    .font(.system(size: 11))
                                Text(isBuilding ? "Cancel" : "Build Plan")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(accentColor)
                        }
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

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases) { t in
                let isActive = tab == t
                Button {
                    withAnimation(.spring(duration: 0.25)) { tab = t }
                } label: {
                    Text(t.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(isActive ? .black : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isActive ? accentColor : PepTheme.elevated.opacity(0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isActive)
            }
        }
    }

    // MARK: - Filters

    private var drillFilters: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    chip(label: "All", isSelected: selectedCategory == nil) { selectedCategory = nil }
                    ForEach(DrillCategory.allCases) { cat in
                        chip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: selectedCategory == cat) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(DrillDifficulty.allCases) { diff in
                        chip(label: diff.rawValue, color: diff.color, isSelected: selectedDifficulty == diff) {
                            selectedDifficulty = selectedDifficulty == diff ? nil : diff
                        }
                    }
                    Rectangle().fill(PepTheme.glassBorderTop).frame(width: 1, height: 14)
                    ForEach(DrillEquipment.allCases) { eq in
                        chip(label: eq.rawValue, icon: eq.icon, isSelected: selectedEquipment == eq) {
                            selectedEquipment = selectedEquipment == eq ? nil : eq
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("Up to \(maxDuration) min")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 90, alignment: .leading)
                Slider(value: Binding(get: { Double(maxDuration) }, set: { maxDuration = Int($0) }), in: 5...30, step: 1)
                    .tint(accentColor)
            }
            .padding(.horizontal, 4)
        }
    }

    private func chip(label: String, icon: String? = nil, color: Color = BasketballPalette.courtOrange, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(isSelected ? color : PepTheme.elevated.opacity(0.5))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Build header

    private var buildPlanHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 13))
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
                .font(.system(size: 14, design: .serif))
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
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Drill List

    private var drillList: some View {
        VStack(spacing: 8) {
            ForEach(filteredDrills) { drill in
                drillRow(drill)
            }
            if filteredDrills.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text("No drills match those filters.")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
    }

    private func drillRow(_ drill: BasketballDrill) -> some View {
        let isSelected = selectedDrills.contains(drill.id)
        let mastery = bbVM.mastery(for: drill)
        let count = bbVM.sessionCount(for: drill)

        return Button {
            if isBuilding {
                withAnimation(.spring(duration: 0.2)) {
                    if isSelected { selectedDrills.remove(drill.id) }
                    else { selectedDrills.insert(drill.id) }
                }
            } else {
                bbVM.selectedDrill = drill
                bbVM.showDrillDetail = true
            }
        } label: {
            HStack(spacing: 12) {
                if isBuilding {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19))
                        .foregroundStyle(isSelected ? accentColor : PepTheme.textSecondary)
                }

                ZStack {
                    Circle()
                        .fill(drill.category.color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: drill.category.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(drill.category.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(drill.name)
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        Text(drill.difficulty.rawValue)
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(drill.difficulty.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(drill.difficulty.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(drill.purpose)
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(drill.durationMinutes)m")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                    if count > 0 {
                        Text(mastery.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(mastery.color)
                    } else {
                        Text("NEW")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    }
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

    // MARK: - Templates

    private var templatesList: some View {
        VStack(spacing: 12) {
            ForEach(BasketballPlanTemplates.all) { template in
                templateCard(template)
            }
        }
    }

    private func templateCard(_ template: PracticePlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(accentColor)
                    .frame(width: 32, height: 32)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(template.drills.count) drills · \(template.totalDuration) min")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
            }

            Text(template.templateBlurb)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 4) {
                ForEach(template.drills) { d in
                    HStack(spacing: 8) {
                        Image(systemName: d.drill.category.icon)
                            .font(.system(size: 9))
                            .foregroundStyle(d.drill.category.color)
                        Text(d.drill.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text("\(d.drill.durationMinutes)m")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    bbVM.runningPlan = template
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Run Now")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(accentColor)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.scale)

                Button {
                    bbVM.adoptTemplate(template)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Save")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(accentColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.18), PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Save Plan

    private var savePlanBar: some View {
        Button {
            let drillsList = BasketballDrillLibrary.all.filter { selectedDrills.contains($0.id) }
            let plan = PracticePlan(
                name: planName.isEmpty ? "Practice Plan" : planName,
                drills: drillsList.map { PracticePlanDrill(drill: $0) }
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
                Text("Save Plan (\(selectedDrills.count))")
                    .font(.system(size: 15, weight: .bold, design: .serif))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accentColor)
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: accentColor.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.scalePrimary)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(
            PepTheme.background
                .shadow(color: .black.opacity(0.5), radius: 20, y: -8)
                .ignoresSafeArea()
        )
    }
}
