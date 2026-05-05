import SwiftUI

struct ExpandedDateSelectorView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.selectedTimePeriod {
            case .daily:
                WeekStripSelectorView(viewModel: viewModel)
            case .weekly:
                WeekCalendarStripView(viewModel: viewModel)
            case .monthly:
                MonthCalendarStripView(viewModel: viewModel)
            }

            TimePeriodPicker(viewModel: viewModel)

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
}

struct TimePeriodPicker: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
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
    }
}

struct WeekStripSelectorView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
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
                WeekStripDayButton(day: day) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedDate = day.date
                        viewModel.selectedTimePeriod = .daily
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
}

struct WeekStripDayButton: View {
    let day: CalendarDay
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
    }
}

struct WeekCalendarStripView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            weekNavigationHeader

            HStack(spacing: 0) {
                ForEach(viewModel.weekNavigationWeeks) { week in
                    WeekItemButton(week: week) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedWeekStart = week.weekStart
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.selection, trigger: viewModel.selectedWeekStart)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var weekNavigationHeader: some View {
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
    }
}

struct WeekItemButton: View {
    let week: WeekItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
    }
}

struct MonthCalendarStripView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthNavigationHeader

            HStack(spacing: 0) {
                ForEach(viewModel.monthNavigationMonths) { month in
                    MonthItemButton(month: month) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedMonthDate = month.date
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.selection, trigger: viewModel.selectedMonthDate)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var monthNavigationHeader: some View {
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
    }
}

struct MonthItemButton: View {
    let month: MonthItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
    }
}
