import SwiftUI
import HealthKit

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var appeared: Bool = false
    @State private var showPepChat: Bool = false
    @State private var showProtocolWizard: Bool = false
    @State private var showReconCalculator: Bool = false
    @State private var showQuickActions: Bool = false
    @State private var showNutrition: Bool = false
    @State private var showDailyTasks: Bool = false
    @State private var showStepDetail: Bool = false
    @State private var bodyGoalViewModel = BodyGoalViewModel()
    @State private var dateSelectorHeight: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    SkeletonHomeView()
                        .padding(.top, 8)
                        .transition(.opacity)
                } else {
                    Group {
                        switch viewModel.selectedTimePeriod {
                        case .daily:
                            dailyContent
                        case .weekly:
                            VStack(spacing: 20) {
                                WeeklySummaryView(summary: viewModel.weeklySummary, bodyGoalViewModel: bodyGoalViewModel, selectedWeekStart: viewModel.selectedWeekStart)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        case .monthly:
                            VStack(spacing: 20) {
                                MonthlySummaryView(summary: viewModel.monthlySummary, bodyGoalViewModel: bodyGoalViewModel, selectedMonthDate: viewModel.selectedMonthDate)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await viewModel.refresh()
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Welcome, \(viewModel.userFirstName)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                ToolbarItem(placement: .principal) {
                    dateHeaderButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    streakToolbarIcon
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if viewModel.isDateSelectorExpanded {
                    expandedDateSelector
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear { viewModel.onAppear() }
            .sheet(isPresented: $viewModel.showEditSplit) {
                EditSplitSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Daily Content

    private var dailyContent: some View {
        VStack(spacing: 20) {
            if !viewModel.isSelectedDateToday {
                selectedDateBanner
            }
            protocolCard
            BodyGoalSectionView(viewModel: bodyGoalViewModel)
            nutritionCard
            if viewModel.healthKit.isAuthorized {
                stepsModuleCard
                healthStatsCard
            }
            if let encouragement = viewModel.streakEncouragement {
                streakEncouragementCard(message: encouragement)
            }
            todaysPlanCard
            pepInsightCard
            activityFeedSection
            quickStatsBar
        }
        .padding(.horizontal)
        .padding(.bottom, 80)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .sheet(isPresented: $showProtocolWizard) {
            ProtocolSetupWizardView { proto in
                viewModel.activeProtocol = proto
            }
        }
        .sheet(isPresented: $showReconCalculator) {
            ReconstitutionCalculatorView()
        }
    }

    // MARK: - Protocol Card

    private var protocolCard: some View {
        Group {
            if let proto = viewModel.activeProtocol {
                activeProtocolCard(proto)
            } else {
                startProtocolCard
            }
        }
    }

    private func activeProtocolCard(_ proto: PeptideProtocol) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "pill.fill")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.teal)
                            Text("Active Protocol")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text(proto.name)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Day \(proto.currentDay)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.teal)
                        Text(proto.currentPhase.rawValue)
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(proto.currentPhase.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(proto.currentPhase.color.opacity(0.12))
                            .clipShape(.capsule)
                    }
                }

                if let nextDose = proto.nextDose {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PepTheme.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next Dose")
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("\(Int(nextDose.doseMcg))mcg \(nextDose.compoundName)")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        Spacer()
                        Button {
                        } label: {
                            Text("Log Dose")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(PepTheme.invertedText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(PepTheme.teal, in: .capsule)
                        }
                        .buttonStyle(.scale)
                    }
                    .padding(10)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 10))
                }

                let total = max(1, proto.loadingWeeks + proto.maintenanceWeeks + proto.taperingWeeks + proto.offCycleWeeks)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        if proto.loadingWeeks > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(CyclePhase.loading.color)
                                .frame(width: geo.size.width * CGFloat(proto.loadingWeeks) / CGFloat(total))
                        }
                        if proto.maintenanceWeeks > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(CyclePhase.maintenance.color)
                                .frame(width: geo.size.width * CGFloat(proto.maintenanceWeeks) / CGFloat(total))
                        }
                        if proto.taperingWeeks > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(CyclePhase.tapering.color)
                                .frame(width: geo.size.width * CGFloat(proto.taperingWeeks) / CGFloat(total))
                        }
                        if proto.offCycleWeeks > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(CyclePhase.offCycle.color)
                                .frame(width: geo.size.width * CGFloat(proto.offCycleWeeks) / CGFloat(total))
                        }
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private var startProtocolCard: some View {
        Button {
            showProtocolWizard = true
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [PepTheme.teal.opacity(0.15), PepTheme.blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)

                    VStack(spacing: 10) {
                        Image(systemName: "pill.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(PepTheme.teal)

                        Text("Start Your First Protocol")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }

                Text("Set up your peptide protocol with dose scheduling, cycle planning, and injection tracking")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(16)
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
        .sensoryFeedback(.impact(weight: .medium), trigger: showProtocolWizard)
    }

    // MARK: - Date Header Button

    private var dateHeaderButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                viewModel.isDateSelectorExpanded.toggle()
                if !viewModel.isDateSelectorExpanded {
                    viewModel.isFullCalendarExpanded = false
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(viewModel.toolbarDateString)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                    .rotationEffect(.degrees(viewModel.isDateSelectorExpanded ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(PepTheme.elevated)
            .clipShape(.capsule)
        }
        .sensoryFeedback(.selection, trigger: viewModel.isDateSelectorExpanded)
    }

    // MARK: - Expanded Date Selector

    private var expandedDateSelector: some View {
        VStack(spacing: 12) {
            switch viewModel.selectedTimePeriod {
            case .daily:
                weekStripSelector
            case .weekly:
                weekCalendarStrip
            case .monthly:
                monthCalendarStrip
            }

            HStack(spacing: 2) {
                ForEach(HomeTimePeriod.allCases) { period in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.selectedTimePeriod = period
                        }
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 12, weight: viewModel.selectedTimePeriod == period ? .bold : .medium))
                            .foregroundStyle(viewModel.selectedTimePeriod == period ? PepTheme.invertedText : PepTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.selectedTimePeriod == period ? PepTheme.teal : Color.clear
                            )
                            .clipShape(.capsule)
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.selectedTimePeriod)
                }
            }
            .padding(3)
            .background(PepTheme.elevated)
            .clipShape(.capsule)

            if viewModel.isFullCalendarExpanded && viewModel.selectedTimePeriod == .daily {
                DatePicker(
                    "Select Date",
                    selection: $viewModel.selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(PepTheme.teal)
                .padding(.horizontal, 4)
                .onChange(of: viewModel.selectedDate) { _, _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.isFullCalendarExpanded = false
                        viewModel.isDateSelectorExpanded = false
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if viewModel.selectedTimePeriod == .daily {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.isFullCalendarExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.isFullCalendarExpanded ? "Hide Calendar" : "Pick a Date")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .rotationEffect(.degrees(viewModel.isFullCalendarExpanded ? 180 : 0))
                    }
                    .foregroundStyle(PepTheme.teal)
                }
                .sensoryFeedback(.selection, trigger: viewModel.isFullCalendarExpanded)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            PepTheme.cardSurface
                .overlay(PepTheme.cardOverlay)
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        )
    }

    // MARK: - Week Strip Selector

    private var weekStripSelector: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.navigateWeekStrip(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 28, height: 28)
            }

            ForEach(viewModel.weekStripDays) { day in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedDate = day.date
                        viewModel.selectedTimePeriod = .daily
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(day.dayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(day.isSelected ? PepTheme.teal : PepTheme.textSecondary)

                        ZStack {
                            Circle()
                                .fill(day.isSelected ? PepTheme.teal : Color.clear)
                                .frame(width: 34, height: 34)

                            if !day.isSelected && day.isToday {
                                Circle()
                                    .strokeBorder(PepTheme.teal.opacity(0.5), lineWidth: 1.5)
                                    .frame(width: 34, height: 34)
                            }

                            Text(day.dayNumber)
                                .font(.system(.subheadline, design: .rounded, weight: day.isSelected || day.isToday ? .bold : .medium))
                                .foregroundStyle(day.isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                        }

                        Circle()
                            .fill(day.hasActivity && !day.isSelected ? PepTheme.teal : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .sensoryFeedback(.selection, trigger: viewModel.selectedDate)
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.navigateWeekStrip(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 28, height: 28)
            }
        }
    }

    // MARK: - Streak Toolbar Icon

    private var streakToolbarIcon: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, PepTheme.amber],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolEffect(.pulse, options: .repeating, isActive: viewModel.streakManager.hasActivityToday)
            Text("\(viewModel.quickStats.streakDays)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PepTheme.cardSurface)
        .clipShape(.capsule)
        .overlay(
            Capsule()
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    // MARK: - Selected Date Banner

    private var selectedDateBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
            Text(viewModel.selectedDateLabel)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.selectedDate = Date()
                }
            } label: {
                Text("Back to Today")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.teal.opacity(0.12))
                    .clipShape(.capsule)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.teal.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Calendar Strip (Legacy)

    private var calendarStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.isSelectedDateToday {
                HStack(spacing: 6) {
                    Text(viewModel.selectedDateLabel)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedDate = Date()
                        }
                    } label: {
                        Text("Today")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack(spacing: 0) {
                ForEach(viewModel.calendarWeekDays) { day in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedDate = day.date
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(day.dayName)
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(day.isSelected ? PepTheme.teal : PepTheme.textSecondary)

                            ZStack {
                                Circle()
                                    .fill(day.isSelected ? PepTheme.teal : Color.clear)
                                    .frame(width: 36, height: 36)

                                if !day.isSelected && day.isToday {
                                    Circle()
                                        .strokeBorder(PepTheme.teal.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 36, height: 36)
                                }

                                Text(day.dayNumber)
                                    .font(.system(.subheadline, design: .rounded, weight: day.isSelected || day.isToday ? .bold : .medium))
                                    .foregroundStyle(day.isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                            }

                            Circle()
                                .fill(day.hasActivity && !day.isSelected ? PepTheme.teal : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.selection, trigger: viewModel.selectedDate)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Week Calendar Strip

    private var weekCalendarStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.navigateWeek(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(PepTheme.elevated)
                        .clipShape(.circle)
                }

                Spacer()

                Text(viewModel.selectedWeekLabel)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                if !viewModel.isSelectedWeekCurrent {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedWeekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                        }
                    } label: {
                        Text("Current")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.navigateWeek(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(PepTheme.elevated)
                        .clipShape(.circle)
                }
            }

            HStack(spacing: 0) {
                ForEach(viewModel.weekNavigationWeeks) { week in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedWeekStart = week.weekStart
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(week.isSelected ? PepTheme.teal : Color.clear)
                                    .frame(height: 36)

                                if !week.isSelected && week.isCurrent {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(PepTheme.teal.opacity(0.5), lineWidth: 1.5)
                                        .frame(height: 36)
                                }

                                Text(week.shortLabel)
                                    .font(.system(size: 11, weight: week.isSelected || week.isCurrent ? .bold : .medium))
                                    .foregroundStyle(week.isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.selection, trigger: viewModel.selectedWeekStart)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Month Calendar Strip

    private var monthCalendarStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.navigateMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(PepTheme.elevated)
                        .clipShape(.circle)
                }

                Spacer()

                Text(viewModel.selectedMonthLabel)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                if !viewModel.isSelectedMonthCurrent {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedMonthDate = Date()
                        }
                    } label: {
                        Text("Current")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.navigateMonth(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(PepTheme.elevated)
                        .clipShape(.circle)
                }
            }

            HStack(spacing: 0) {
                ForEach(viewModel.monthNavigationMonths) { month in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedMonthDate = month.date
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(month.yearLabel)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(month.isSelected ? PepTheme.teal : PepTheme.textSecondary.opacity(0.6))

                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(month.isSelected ? PepTheme.teal : Color.clear)
                                    .frame(height: 40)

                                if !month.isSelected && month.isCurrent {
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(PepTheme.teal.opacity(0.5), lineWidth: 1.5)
                                        .frame(height: 40)
                                }

                                Text(month.shortLabel)
                                    .font(.system(.subheadline, weight: month.isSelected || month.isCurrent ? .bold : .medium))
                                    .foregroundStyle(month.isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.selection, trigger: viewModel.selectedMonthDate)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Day Summary (shown for past dates)

    private var daySummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Day Summary")
                }

                if viewModel.selectedDateActivities.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.title2)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                            Text("No activity logged")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(.vertical, 8)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 16) {
                        if viewModel.selectedDateWorkoutCount > 0 {
                            daySummaryStat(
                                icon: "figure.strengthtraining.traditional",
                                value: "\(viewModel.selectedDateWorkoutCount)",
                                label: viewModel.selectedDateWorkoutCount == 1 ? "Workout" : "Workouts",
                                color: PepTheme.teal
                            )
                        }
                        if viewModel.selectedDateSportCount > 0 {
                            daySummaryStat(
                                icon: "sportscourt.fill",
                                value: "\(viewModel.selectedDateSportCount)",
                                label: viewModel.selectedDateSportCount == 1 ? "Sport" : "Sports",
                                color: PepTheme.teal
                            )
                        }
                    }
                }

                let dayNutrition = viewModel.selectedDateNutrition
                VStack(spacing: 8) {
                    NutritionProgressBar(
                        label: "Calories",
                        current: dayNutrition.caloriesConsumed,
                        target: dayNutrition.caloriesTarget,
                        color: PepTheme.teal
                    )
                    NutritionProgressBar(
                        label: "Protein",
                        current: dayNutrition.proteinConsumed,
                        target: dayNutrition.proteinTarget,
                        color: PepTheme.amber
                    )
                }
            }
        }
    }

    private func daySummaryStat(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }



    // MARK: - Today's Plan

    private var todaysPlanCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    viewModel.isPlanExpanded.toggle()
                }
            } label: {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.teal)
                            SubheadText(text: viewModel.isSelectedDateToday ? "Today's Plan" : "Plan")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                                .rotationEffect(.degrees(viewModel.isPlanExpanded ? 180 : 0))
                        }

                        if viewModel.todaysPlan.isRestDay {
                            restDayContent
                        } else {
                            workoutPlanSummary
                        }
                    }
                }
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.selection, trigger: viewModel.isPlanExpanded)

            if viewModel.isPlanExpanded && !viewModel.todaysPlan.isRestDay {
                expandedPlanContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var workoutPlanSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.todaysPlan.name)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            HStack(spacing: 16) {
                Label("\(viewModel.todaysPlan.exercises) exercises", systemImage: "dumbbell.fill")
                Label("\(viewModel.todaysPlan.estimatedMinutes) min", systemImage: "clock.fill")
            }
            .font(.caption)
            .foregroundStyle(PepTheme.textSecondary)

            if !viewModel.isPlanExpanded {
                splitDayStrip
            }
        }
    }

    private var splitDayStrip: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.todaysPlan.splitDays) { day in
                Text(day.name)
                    .font(.system(size: 10, weight: day.isToday ? .bold : .medium))
                    .foregroundStyle(day.isToday ? PepTheme.invertedText : (day.isRest ? PepTheme.textSecondary.opacity(0.5) : PepTheme.textSecondary))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        day.isToday ? PepTheme.teal : PepTheme.elevated.opacity(day.isRest ? 0.4 : 1)
                    )
                    .clipShape(.capsule)
            }
        }
        .padding(.top, 2)
    }

    private var expandedPlanContent: some View {
        VStack(spacing: 0) {
            splitDayStripExpanded
                .padding(.horizontal, 16)
                .padding(.top, 10)

            VStack(spacing: 8) {
                ForEach(Array(viewModel.todaysPlan.planExercises.enumerated()), id: \.element.id) { index, exercise in
                    planExerciseRow(exercise, index: index + 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            if viewModel.isSelectedDateToday {
                VStack(spacing: 10) {
                    Button {
                    } label: {
                        Text("Start Workout")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(PepTheme.invertedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.scalePrimary)

                    Button {
                        viewModel.showEditSplit = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Edit Split")
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PepTheme.teal.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(PepTheme.teal.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.scale)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        .padding(.top, -8)
    }

    private var splitDayStripExpanded: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.todaysPlan.splitDays) { day in
                VStack(spacing: 4) {
                    Text("D\(day.dayIndex + 1)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(day.isToday ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))
                    Text(day.name)
                        .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? PepTheme.invertedText : (day.isRest ? PepTheme.textSecondary.opacity(0.5) : PepTheme.textPrimary.opacity(0.7)))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            day.isToday ? PepTheme.teal : PepTheme.elevated.opacity(day.isRest ? 0.3 : 0.7)
                        )
                        .clipShape(.rect(cornerRadius: 8))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func planExerciseRow(_ exercise: PlanExercise, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.teal.opacity(0.6))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: exercise.equipmentIcon)
                            .font(.system(size: 9))
                        Text(exercise.muscle)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(PepTheme.textSecondary)

                    Text("\(exercise.sets) × \(exercise.repsMin)-\(exercise.repsMax)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PepTheme.teal.opacity(0.8))
                }
            }

            Spacer()

            Text("\(exercise.sets)s")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PepTheme.elevated)
                .clipShape(.capsule)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var restDayContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bed.double.fill")
                    .font(.title2)
                    .foregroundStyle(PepTheme.amber)
                Text("Rest Day")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            if let tip = viewModel.todaysPlan.recoveryTip {
                Text(tip)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Nutrition

    private var nutritionCard: some View {
        Button {
            showNutrition = true
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.teal)
                        SubheadText(text: "Nutrition Snapshot")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }

                    let dayNutrition = viewModel.selectedDateNutrition
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(dayNutrition.caloriesConsumed)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("/ \(dayNutrition.caloriesTarget) cal")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    NutritionProgressBar(
                        label: "Calories",
                        current: dayNutrition.caloriesConsumed,
                        target: dayNutrition.caloriesTarget,
                        color: PepTheme.teal
                    )

                    NutritionProgressBar(
                        label: "Protein",
                        current: dayNutrition.proteinConsumed,
                        target: dayNutrition.proteinTarget,
                        color: PepTheme.amber
                    )
                }
            }
        }
        .buttonStyle(.scale)
        .navigationDestination(isPresented: $showNutrition) {
            NutritionView()
        }
    }

    // MARK: - Finn Insight

    private var pepInsightCard: some View {
        Button {
            showPepChat = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    PepAvatar(size: 44)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Pep's Daily Insight")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.violet)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(PepTheme.violet.opacity(0.5))
                        }

                        Text(viewModel.pepInsight)
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                            .lineSpacing(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(16)
            .background(
                PepTheme.violet.opacity(0.08)
                    .overlay(PepTheme.cardSurface.opacity(0.7))
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [PepTheme.violet.opacity(0.25), PepTheme.violet.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: PepTheme.violet.opacity(0.15), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.scale)
        .fullScreenCover(isPresented: $showPepChat) {
            PepChatView()
        }
    }

    // MARK: - Activity Feed

    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HeadlineText(text: "Activity Feed")
                Spacer()
                Button {
                } label: {
                    Text("See All")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.teal)
                }
            }

            if viewModel.activityFeed.isEmpty {
                EmptyStateView(
                    icon: "person.2.wave.2",
                    title: "No Activity Yet",
                    message: "Add friends to see their workouts here."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.activityFeed) { activity in
                        ActivityFeedRow(activity: activity) {
                            viewModel.toggleHighFive(for: activity)
                        }

                        if activity.id != viewModel.activityFeed.last?.id {
                            Divider()
                                .overlay(PepTheme.shimmerHighlight)
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(12)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
            }
        }
    }

    // MARK: - Streak Encouragement

    private func streakEncouragementCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                FinnAvatar(size: 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pep says...")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                        .lineSpacing(3)
                }
            }
        }
        .padding(16)
        .background(
            PepTheme.violet.opacity(0.06)
                .overlay(PepTheme.cardSurface.opacity(0.8))
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.violet.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Quick Stats

    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            QuickStatItem(
                icon: "figure.strengthtraining.traditional",
                value: "\(viewModel.quickStats.workoutsThisWeek)",
                label: "This Week",
                iconColor: PepTheme.teal
            )

            quickStatDivider

            QuickStatItem(
                icon: "flame.fill",
                value: "\(viewModel.quickStats.streakDays)",
                label: "Streak",
                iconColor: PepTheme.amber
            )
        }
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var quickStatDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 1, height: 36)
    }

    // MARK: - Steps Module Card

    private var stepsModuleCard: some View {
        Button {
            showStepDetail = true
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.teal)
                            SubheadText(text: "Steps")
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formattedStepsNumber(viewModel.healthKit.steps))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.textPrimary)
                                .contentTransition(.numericText())
                        }

                        Text("\(String(format: "%.1f", viewModel.healthKit.distanceMiles)) mi \u{00b7} \(viewModel.healthKit.flightsClimbed) floors")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))

                        stepProgressRing
                    }
                }

                stepHourlyMiniChart
                    .padding(.top, 12)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.scale)
        .navigationDestination(isPresented: $showStepDetail) {
            StepDetailView()
        }
    }

    private var stepProgressRing: some View {
        let goal = max(UserDefaults.standard.integer(forKey: "step_goal"), 10000)
        let progress = min(Double(viewModel.healthKit.steps) / Double(goal == 0 ? 10000 : goal), 1.0)

        return ZStack {
            Circle()
                .stroke(PepTheme.elevated, lineWidth: 5)
                .frame(width: 48, height: 48)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    PepTheme.teal,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.teal)
        }
    }

    private var stepHourlyMiniChart: some View {
        GeometryReader { geo in
            let currentHour = Calendar.current.component(.hour, from: Date())
            let hours = (0...max(currentHour, 1))
            let barCount = max(hours.count, 1)
            let spacing: CGFloat = 1.5
            let barWidth = max((geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount), 2)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(hours), id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(PepTheme.teal.opacity(0.4))
                        .frame(width: barWidth, height: max(3, 28 * miniChartRatio(for: hour)))
                }
            }
        }
        .frame(height: 28)
    }

    private func miniChartRatio(for hour: Int) -> CGFloat {
        let typicalDistribution: [CGFloat] = [
            0.02, 0.01, 0.01, 0.01, 0.02, 0.03, 0.05, 0.08,
            0.10, 0.08, 0.07, 0.06, 0.08, 0.06, 0.05, 0.06,
            0.07, 0.08, 0.06, 0.04, 0.03, 0.02, 0.01, 0.01
        ]
        guard hour < typicalDistribution.count else { return 0.02 }
        let maxRatio = typicalDistribution.max() ?? 0.1
        return typicalDistribution[hour] / maxRatio
    }

    private func formattedStepsNumber(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    // MARK: - Apple Health Stats

    private var healthStatsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                SubheadText(text: "Apple Health")
                Spacer()
                Image(systemName: "apple.logo")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                healthStatCell(
                    icon: "figure.walk",
                    value: formattedSteps(viewModel.healthKit.steps),
                    label: "Steps",
                    color: PepTheme.teal
                )
                healthStatCell(
                    icon: "flame.fill",
                    value: "\(Int(viewModel.healthKit.activeCalories))",
                    label: "Active Cal",
                    color: .orange
                )
                healthStatCell(
                    icon: "heart.fill",
                    value: viewModel.healthKit.heartRate > 0 ? "\(Int(viewModel.healthKit.heartRate))" : "--",
                    label: "BPM",
                    color: .red
                )
                healthStatCell(
                    icon: "figure.run",
                    value: String(format: "%.1f", viewModel.healthKit.distanceMiles),
                    label: "Miles",
                    color: .green
                )
                healthStatCell(
                    icon: "timer",
                    value: "\(Int(viewModel.healthKit.exerciseMinutes))",
                    label: "Exercise Min",
                    color: PepTheme.amber
                )
                healthStatCell(
                    icon: "bed.double.fill",
                    value: viewModel.healthKit.sleepHours > 0 ? String(format: "%.1f", viewModel.healthKit.sleepHours) : "--",
                    label: "Sleep Hrs",
                    color: PepTheme.violet
                )
            }

            if !viewModel.healthKit.workoutsToday.isEmpty {
                Divider()
                    .overlay(PepTheme.shimmerHighlight)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Workouts")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    ForEach(viewModel.healthKit.workoutsToday, id: \.uuid) { workout in
                        HStack(spacing: 10) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 14))
                                .foregroundStyle(PepTheme.teal)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.workoutActivityType.displayName)
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                HStack(spacing: 6) {
                                    let durationMin = Int(workout.duration / 60)
                                    Text("\(durationMin) min")
                                        .font(.system(.caption2, weight: .medium))
                                        .foregroundStyle(PepTheme.textSecondary)
                                    if let stats = workout.statistics(for: HKQuantityType(.activeEnergyBurned)),
                                       let sum = stats.sumQuantity() {
                                        Text("\(Int(sum.doubleValue(for: .kilocalorie()))) cal")
                                            .font(.system(.caption2, weight: .medium))
                                            .foregroundStyle(PepTheme.textSecondary)
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    private func healthStatCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func formattedSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
}

struct NutritionProgressBar: View {
    let label: String
    let current: Int
    let target: Int
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(current)g / \(target)g")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PepTheme.elevated)
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

struct ActivityFeedRow: View {
    let activity: FriendActivity
    let onHighFive: () -> Void

    @State private var highFiveTap: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PepTheme.teal.opacity(0.3), PepTheme.violet.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(activity.friendName.prefix(1)))
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.friendName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(activity.workoutName)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                HStack(spacing: 6) {
                    Text(activity.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            Button {
                onHighFive()
                highFiveTap += 1
            } label: {
                Image(systemName: activity.highFived ? "hand.raised.fill" : "hand.raised")
                    .font(.system(size: 18))
                    .foregroundStyle(activity.highFived ? PepTheme.amber : PepTheme.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: highFiveTap)
        }
        .padding(.vertical, 8)
    }
}

struct QuickStatItem: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
