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
    @State private var heroAppeared: Bool = false

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

    private var featuredDrill: BasketballDrill? {
        // Pick a stable "drill of the day" from the full library.
        let all = BasketballDrillLibrary.all
        guard !all.isEmpty else { return nil }
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return all[dayIndex % all.count]
    }

    private var hasActiveFilters: Bool {
        selectedCategory != nil || selectedDifficulty != nil || selectedEquipment != nil || maxDuration < 30
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    heroHeader

                    tabSwitcher

                    if tab == .drills {
                        if !isBuilding, !hasActiveFilters, searchText.isEmpty, let featured = featuredDrill {
                            featuredCard(featured)
                        }

                        filtersSection

                        if isBuilding { buildPlanHeader }

                        drillsSection
                    } else {
                        templatesSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search drills, cues, categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 13, weight: .semibold, design: .serif))
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
                            HStack(spacing: 5) {
                                Image(systemName: isBuilding ? "xmark" : "list.clipboard")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(isBuilding ? "Cancel" : "Build Plan")
                                    .font(.system(size: 12, weight: .semibold, design: .serif))
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
            .task {
                withAnimation(.spring(duration: 0.6)) { heroAppeared = true }
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        let allCount = BasketballDrillLibrary.all.count
        let totalMin = BasketballDrillLibrary.all.reduce(0) { $0 + $1.durationMinutes }
        let categoryCount = DrillCategory.allCases.count

        return PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("THE LIBRARY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                }
                .foregroundStyle(accentColor)

                Text("Build the work,\nrep by rep.")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineSpacing(2)

                Text("A curated catalog of drills and practice plans for every kind of session — from a quiet form-fix to a conditioning killer.")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                HStack(spacing: 0) {
                    heroStat(value: "\(allCount)", label: "DRILLS")
                    heroDivider
                    heroStat(value: "\(categoryCount)", label: "CATEGORIES")
                    heroDivider
                    heroStat(value: "\(totalMin / 60)h", label: "OF WORK")
                }
            }
        }
        .opacity(heroAppeared ? 1 : 0)
        .offset(y: heroAppeared ? 0 : 8)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { t in
                let isActive = tab == t
                Button {
                    withAnimation(.spring(duration: 0.25)) { tab = t }
                } label: {
                    VStack(spacing: 6) {
                        Text(t.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2.0)
                            .foregroundStyle(isActive ? accentColor : PepTheme.textSecondary)
                        Rectangle()
                            .fill(isActive ? accentColor : Color.clear)
                            .frame(height: 1.5)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isActive)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PepTheme.glassBorderTop)
                .frame(height: 0.5)
        }
    }

    // MARK: - Featured Drill Card

    private func featuredCard(_ drill: BasketballDrill) -> some View {
        Button {
            bbVM.selectedDrill = drill
            bbVM.showDrillDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(
                    kicker: "Drill of the Day",
                    title: drill.name,
                    accent: drill.category.color,
                    trailing: AnyView(
                        HStack(spacing: 4) {
                            Image(systemName: drill.category.icon)
                                .font(.system(size: 9))
                            Text(drill.category.rawValue.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                        }
                        .foregroundStyle(drill.category.color)
                    )
                )

                Text(drill.purpose)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)

                HStack(spacing: 12) {
                    featuredMetric(icon: "clock", value: "\(drill.durationMinutes) min")
                    featuredMetric(icon: "flame", value: drill.difficulty.rawValue)
                    if let sr = drill.setsReps {
                        featuredMetric(icon: "repeat", value: sr)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        Text("OPEN")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(drill.category.color)
                }
            }
            .editorialCard(accent: drill.category.color)
        }
        .buttonStyle(.plain)
    }

    private func featuredMetric(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Refine",
                title: "Filter the Library",
                accent: accentColor,
                trailing: hasActiveFilters ? AnyView(
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedCategory = nil
                            selectedDifficulty = nil
                            selectedEquipment = nil
                            maxDuration = 30
                        }
                    } label: {
                        Text("RESET")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(accentColor)
                    }
                ) : nil
            )

            // Categories
            VStack(alignment: .leading, spacing: 6) {
                filterEyebrow("Category")
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        chip(label: "All", isSelected: selectedCategory == nil) { selectedCategory = nil }
                        ForEach(DrillCategory.allCases) { cat in
                            chip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: selectedCategory == cat) {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedCategory = selectedCategory == cat ? nil : cat
                                }
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }

            // Difficulty
            VStack(alignment: .leading, spacing: 6) {
                filterEyebrow("Difficulty")
                HStack(spacing: 6) {
                    ForEach(DrillDifficulty.allCases) { diff in
                        chip(label: diff.rawValue, color: diff.color, isSelected: selectedDifficulty == diff) {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedDifficulty = selectedDifficulty == diff ? nil : diff
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            // Equipment
            VStack(alignment: .leading, spacing: 6) {
                filterEyebrow("Equipment")
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(DrillEquipment.allCases) { eq in
                            chip(label: eq.rawValue, icon: eq.icon, isSelected: selectedEquipment == eq) {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedEquipment = selectedEquipment == eq ? nil : eq
                                }
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }

            // Duration
            VStack(alignment: .leading, spacing: 6) {
                filterEyebrow("Max Duration")
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(accentColor)
                    Text("Up to")
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("\(maxDuration) min")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 56, alignment: .leading)
                    Slider(value: Binding(get: { Double(maxDuration) }, set: { maxDuration = Int($0) }), in: 5...30, step: 1)
                        .tint(accentColor)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func filterEyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(PepTheme.textSecondary)
    }

    private func chip(label: String, icon: String? = nil, color: Color = BasketballPalette.courtOrange, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
            }
            .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(isSelected ? color : PepTheme.elevated.opacity(0.5))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.5) : PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Build header

    private var buildPlanHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Build a Plan",
                title: "Practice Plan in Progress",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(selectedDrills.count) DRILLS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                )
            )

            TextField("Name your plan…", text: $planName)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(accentColor.opacity(0.18), lineWidth: 0.5)
                )

            Text("Tap drills below to add them to your plan. Re-tap to remove.")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Drills Section

    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: filteredDrills.count == 1 ? "1 Drill" : "\(filteredDrills.count) Drills",
                title: drillsTitle,
                accent: accentColor
            )

            if filteredDrills.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredDrills) { drill in
                        drillRow(drill)
                    }
                }
            }
        }
    }

    private var drillsTitle: String {
        if let cat = selectedCategory {
            return cat.rawValue
        }
        if !searchText.isEmpty {
            return "Search Results"
        }
        return "The Catalog"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(accentColor.opacity(0.55))
            Text("Nothing Matches")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Loosen the filters and the right drill will surface.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)

            if hasActiveFilters {
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        selectedCategory = nil
                        selectedDifficulty = nil
                        selectedEquipment = nil
                        maxDuration = 30
                    }
                } label: {
                    Text("RESET FILTERS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .editorialCard(accent: accentColor)
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
            VStack(alignment: .leading, spacing: 10) {
                // Top row: kicker + difficulty pill
                HStack(spacing: 6) {
                    if isBuilding {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundStyle(isSelected ? accentColor : PepTheme.textSecondary.opacity(0.6))
                    }
                    Image(systemName: drill.category.icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(drill.category.color)
                    Text(drill.category.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(drill.category.color)
                    Spacer(minLength: 0)
                    Text(drill.difficulty.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(drill.difficulty.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(drill.difficulty.color.opacity(0.12))
                        .clipShape(Capsule())
                }

                // Title
                Text(drill.name)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .kerning(-0.2)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Purpose
                Text(drill.purpose)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Hairline
                LinearGradient(
                    colors: [drill.category.color.opacity(0.22), drill.category.color.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                // Footer row
                HStack(spacing: 12) {
                    rowMeta(icon: "clock", text: "\(drill.durationMinutes) min")
                    if let eq = drill.equipment.first {
                        rowMeta(icon: eq.icon, text: eq.rawValue)
                    } else {
                        rowMeta(icon: "person.fill", text: "Solo")
                    }
                    Spacer(minLength: 0)
                    masteryBadge(mastery: mastery, count: count)
                }
            }
            .padding(14)
            .background {
                if isSelected {
                    accentColor.opacity(0.08)
                } else {
                    PepTheme.cardSurface.overlay(PepTheme.cardOverlay)
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: isSelected
                            ? [accentColor.opacity(0.4), accentColor.opacity(0.1)]
                            : [drill.category.color.opacity(0.16), PepTheme.glassBorderBottom],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func rowMeta(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(PepTheme.textSecondary)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
        }
    }

    private func masteryBadge(mastery: DrillMastery, count: Int) -> some View {
        HStack(spacing: 4) {
            if count > 0 {
                Circle()
                    .fill(mastery.color)
                    .frame(width: 5, height: 5)
                Text(mastery.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(mastery.color)
            } else {
                Text("NEW")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }
        }
    }

    // MARK: - Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "Practice Plans",
                title: "Curated Templates",
                accent: accentColor
            )
            Text("Pre-built sessions you can run as-is or save and tweak. Every template is built around a theme — form, conditioning, handles, finishing.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            VStack(spacing: 12) {
                ForEach(BasketballPlanTemplates.all) { template in
                    templateCard(template)
                }
            }
        }
    }

    private func templateCard(_ template: PracticePlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("PRACTICE PLAN")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.8)
                Spacer(minLength: 0)
                Text("\(template.totalDuration) MIN")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
            }
            .foregroundStyle(accentColor)

            Text(template.name)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .kerning(-0.3)
                .foregroundStyle(PepTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !template.templateBlurb.isEmpty {
                Text(template.templateBlurb)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LinearGradient(
                colors: [accentColor.opacity(0.22), accentColor.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.5)

            VStack(spacing: 8) {
                ForEach(Array(template.drills.enumerated()), id: \.offset) { idx, d in
                    HStack(spacing: 10) {
                        Text(String(format: "%02d", idx + 1))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                            .frame(width: 18, alignment: .leading)
                        Image(systemName: d.drill.category.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(d.drill.category.color)
                            .frame(width: 14)
                        Text(d.drill.name)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(d.drill.durationMinutes)m")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
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
                            .font(.system(size: 12, weight: .semibold))
                        Text("Run Now")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.85)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(.rect(cornerRadius: 11))
                }
                .buttonStyle(.scalePrimary)

                Button {
                    bbVM.adoptTemplate(template)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Save")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accentColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Save Plan

    private var savePlanBar: some View {
        EditorialPrimaryButton(
            "Save Plan (\(selectedDrills.count) drills)",
            icon: "checkmark.circle.fill",
            accent: accentColor
        ) {
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
