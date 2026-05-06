import SwiftUI

/// Premium inline calendar that drops down beneath the editorial eyebrow.
///
/// - Day / Week / Month segmented control replaces the legacy "View Month" link
/// - Day: magazine week strip (swipe to change weeks, tap to pick a day)
/// - Week: list of recent weeks with prev/next + "Current" link
/// - Month: magazine month grid with prev/next + "Current" link
/// - Picking a period also drives `viewModel.selectedTimePeriod` so the home
///   page renders the matching daily / weekly / monthly content below.
struct EditorialCalendarReveal: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var isExpanded: Bool

    @State private var weekAnchor: Date = Date()
    @State private var monthAnchor: Date = Date()
    @State private var dragOffset: CGFloat = 0

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 18) {
            Group {
                switch viewModel.selectedTimePeriod {
                case .daily:
                    weekStrip
                        .transition(.opacity.combined(with: .move(edge: .top)))
                case .weekly:
                    weekListView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                case .monthly:
                    monthView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: viewModel.selectedTimePeriod)

            footerControls
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
        .onAppear {
            weekAnchor = viewModel.selectedDate
            monthAnchor = viewModel.selectedMonthDate
        }
        .onChange(of: viewModel.selectedDate) { _, newValue in
            weekAnchor = newValue
        }
        .onChange(of: viewModel.selectedMonthDate) { _, newValue in
            monthAnchor = newValue
        }
    }

    // MARK: - Day mode (week strip)

    private var weekStrip: some View {
        let days = weekDays(anchor: weekAnchor)
        return HStack(spacing: 0) {
            ForEach(days, id: \.self) { date in
                dayCell(for: date)
                    .frame(maxWidth: .infinity)
            }
        }
        .offset(x: dragOffset)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    dragOffset = value.translation.width * 0.35
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        if value.translation.width < -threshold {
                            shiftWeek(by: 1)
                        } else if value.translation.width > threshold {
                            shiftWeek(by: -1)
                        }
                        dragOffset = 0
                    }
                }
        )
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > calendar.startOfDay(for: Date()).addingTimeInterval(86400 - 1)

        return Button {
            selectDay(date)
        } label: {
            VStack(spacing: 8) {
                Text(weekdayInitial(for: date))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(
                        isSelected
                            ? PepTheme.teal
                            : (isFuture ? PepTheme.textSecondary.opacity(0.45) : PepTheme.textSecondary.opacity(0.85))
                    )

                ZStack {
                    Circle()
                        .fill(isSelected ? PepTheme.teal.opacity(0.16) : Color.clear)
                        .frame(width: 38, height: 38)

                    if isSelected {
                        Circle()
                            .strokeBorder(PepTheme.teal.opacity(0.55), lineWidth: 0.8)
                            .frame(width: 38, height: 38)
                    }

                    Text(dayNumeral(for: date))
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(
                            isSelected
                                ? PepTheme.textPrimary
                                : (isFuture ? PepTheme.textPrimary.opacity(0.45) : PepTheme.textPrimary)
                        )
                }

                Circle()
                    .fill(isToday && !isSelected ? PepTheme.teal : Color.clear)
                    .frame(width: 3, height: 3)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected && calendar.isDate(date, inSameDayAs: viewModel.selectedDate))
    }

    // MARK: - Week mode (list of weeks)

    private var weekListView: some View {
        VStack(spacing: 12) {
            HStack {
                navButton(icon: "chevron.left") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        viewModel.navigateWeek(by: -1)
                    }
                }

                Spacer()

                Text(viewModel.selectedWeekLabel.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                navButton(icon: "chevron.right") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        viewModel.navigateWeek(by: 1)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(viewModel.weekNavigationWeeks) { week in
                    weekRow(week: week)
                    if week.id != viewModel.weekNavigationWeeks.last?.id {
                        Rectangle()
                            .fill(PepTheme.textPrimary.opacity(0.06))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private func weekRow(week: WeekItem) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                viewModel.selectedWeekStart = week.weekStart
                isExpanded = false
            }
        } label: {
            HStack(spacing: 12) {
                Text(weekRowLabel(week: week))
                    .font(.system(size: 16, weight: week.isSelected ? .semibold : .regular, design: .serif))
                    .foregroundStyle(
                        week.isSelected
                            ? PepTheme.textPrimary
                            : PepTheme.textPrimary.opacity(0.78)
                    )

                Spacer()

                if week.isCurrent {
                    Text("THIS WEEK")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(PepTheme.teal)
                }

                if week.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: viewModel.selectedWeekStart)
    }

    private func weekRowLabel(week: WeekItem) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: week.weekStart)) – \(f.string(from: week.weekEnd))"
    }

    // MARK: - Month grid

    private var monthView: some View {
        VStack(spacing: 14) {
            HStack {
                navButton(icon: "chevron.left") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        if let d = calendar.date(byAdding: .month, value: -1, to: monthAnchor) {
                            monthAnchor = d
                            viewModel.selectedMonthDate = d
                        }
                    }
                }

                Spacer()

                Text(monthTitle(for: monthAnchor))
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                navButton(icon: "chevron.right") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        if let d = calendar.date(byAdding: .month, value: 1, to: monthAnchor) {
                            monthAnchor = d
                            viewModel.selectedMonthDate = d
                        }
                    }
                }
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let cells = monthCells(for: monthAnchor)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 10) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        monthDayCell(for: date)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }

            // Hairline divider
            LinearGradient(
                colors: [
                    PepTheme.textPrimary.opacity(0.0),
                    PepTheme.textPrimary.opacity(0.12),
                    PepTheme.textPrimary.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
        }
    }

    private func monthDayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > calendar.startOfDay(for: Date()).addingTimeInterval(86400 - 1)
        let inMonth = calendar.isDate(date, equalTo: monthAnchor, toGranularity: .month)

        return Button {
            // Tapping a day in the month grid pivots back to daily for that date.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                viewModel.selectedDate = date
                viewModel.selectedTimePeriod = .daily
                weekAnchor = date
                isExpanded = false
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(PepTheme.teal.opacity(0.18))
                        .overlay(Circle().strokeBorder(PepTheme.teal.opacity(0.55), lineWidth: 0.8))
                        .frame(width: 36, height: 36)
                }

                VStack(spacing: 2) {
                    Text(dayNumeral(for: date))
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(
                            !inMonth
                                ? PepTheme.textPrimary.opacity(0.18)
                                : (isFuture
                                    ? PepTheme.textPrimary.opacity(0.45)
                                    : PepTheme.textPrimary)
                        )

                    Circle()
                        .fill(isToday && !isSelected ? PepTheme.teal : Color.clear)
                        .frame(width: 3, height: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer (period segmented + back-to-current)

    private var footerControls: some View {
        VStack(spacing: 12) {
            periodSegmentedControl

            if let backLabel = backToCurrentLabel {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            jumpToCurrent()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9, weight: .bold))
                            Text(backLabel.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.6)
                        }
                        .foregroundStyle(PepTheme.teal)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
        }
    }

    private var periodSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(HomeTimePeriod.allCases) { period in
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        viewModel.selectedTimePeriod = period
                    }
                } label: {
                    Text(periodLabel(period).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(
                            viewModel.selectedTimePeriod == period
                                ? PepTheme.textPrimary
                                : PepTheme.textSecondary.opacity(0.7)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if viewModel.selectedTimePeriod == period {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(PepTheme.teal.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(PepTheme.teal.opacity(0.4), lineWidth: 0.6)
                                        )
                                }
                            }
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: viewModel.selectedTimePeriod)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PepTheme.elevated.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.textPrimary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private func periodLabel(_ p: HomeTimePeriod) -> String {
        switch p {
        case .daily: return "Day"
        case .weekly: return "Week"
        case .monthly: return "Month"
        }
    }

    private var backToCurrentLabel: String? {
        switch viewModel.selectedTimePeriod {
        case .daily:
            return calendar.isDateInToday(viewModel.selectedDate) ? nil : "Back to Today"
        case .weekly:
            return viewModel.isSelectedWeekCurrent ? nil : "This Week"
        case .monthly:
            return viewModel.isSelectedMonthCurrent ? nil : "This Month"
        }
    }

    private func jumpToCurrent() {
        switch viewModel.selectedTimePeriod {
        case .daily:
            viewModel.selectedDate = Date()
            weekAnchor = Date()
        case .weekly:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            viewModel.selectedWeekStart = start
        case .monthly:
            viewModel.selectedMonthDate = Date()
            monthAnchor = Date()
        }
    }

    // MARK: - Helpers

    private func selectDay(_ date: Date) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            viewModel.selectedDate = date
            weekAnchor = date
            isExpanded = false
        }
    }

    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    private func shiftWeek(by offset: Int) {
        if let d = calendar.date(byAdding: .weekOfYear, value: offset, to: weekAnchor) {
            weekAnchor = d
        }
    }

    private func weekDays(anchor: Date) -> [Date] {
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func weekdayInitial(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // single letter
        return f.string(from: date)
    }

    private func dayNumeral(for date: Date) -> String {
        "\(calendar.component(.day, from: date))"
    }

    private func weekdaySymbols() -> [String] {
        let f = DateFormatter()
        let symbols = f.veryShortStandaloneWeekdaySymbols ?? ["S","M","T","W","T","F","S"]
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func monthTitle(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    /// Returns 42 cells (6 rows x 7) with nil for padding so weekday columns line up.
    private func monthCells(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30

        var cells: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in 0..<daysInMonth {
            if let d = calendar.date(byAdding: .day, value: day, to: monthInterval.start) {
                cells.append(d)
            }
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}
