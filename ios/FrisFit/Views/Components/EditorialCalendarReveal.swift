import SwiftUI

/// Premium inline calendar that drops down beneath the editorial eyebrow.
///
/// - Week strip with weekday initials (tracked caps) and serif date numerals
/// - Swipe between weeks with a spring animation
/// - Toggle a magazine-style month grid in place
/// - "Back to Today" link when not on today
struct EditorialCalendarReveal: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var isExpanded: Bool

    @State private var showMonth: Bool = false
    @State private var weekAnchor: Date = Date()
    @State private var monthAnchor: Date = Date()
    @State private var dragOffset: CGFloat = 0

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 18) {
            if showMonth {
                monthView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            } else {
                weekStrip
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }

            footerControls
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
        .onAppear {
            weekAnchor = viewModel.selectedDate
            monthAnchor = viewModel.selectedDate
        }
        .onChange(of: viewModel.selectedDate) { _, newValue in
            weekAnchor = newValue
            monthAnchor = newValue
        }
    }

    // MARK: - Week strip

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
            select(date)
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

    // MARK: - Month grid

    private var monthView: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        if let d = calendar.date(byAdding: .month, value: -1, to: monthAnchor) {
                            monthAnchor = d
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 28, height: 28)
                }

                Spacer()

                Text(monthTitle(for: monthAnchor))
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        if let d = calendar.date(byAdding: .month, value: 1, to: monthAnchor) {
                            monthAnchor = d
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 28, height: 28)
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
            select(date)
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

    // MARK: - Footer

    private var footerControls: some View {
        HStack(spacing: 18) {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    showMonth.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(showMonth ? "Hide Month" : "View Month")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.6)
                        .textCase(.uppercase)
                    Image(systemName: showMonth ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(PepTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: showMonth)

            Spacer()

            if !calendar.isDateInToday(viewModel.selectedDate) {
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        viewModel.selectedDate = Date()
                        weekAnchor = Date()
                        monthAnchor = Date()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 9, weight: .bold))
                        Text("Back to Today")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.6)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(PepTheme.teal)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Helpers

    private func select(_ date: Date) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            viewModel.selectedDate = date
            weekAnchor = date
            monthAnchor = date
            isExpanded = false
        }
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
        // Reorder by firstWeekday (Sun=1 by default)
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
        // Pad to multiple of 7
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}
