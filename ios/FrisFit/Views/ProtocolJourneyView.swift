import SwiftUI

struct ProtocolJourneyView: View {
    @State private var viewModel: ProtocolJourneyViewModel
    @Environment(\.dismiss) private var dismiss

    init(protocolData: PeptideProtocol) {
        _viewModel = State(initialValue: ProtocolJourneyViewModel(protocolData: protocolData))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                journeyHero
                statsRow
                    .padding(.top, 20)
                    .padding(.horizontal)

                if !viewModel.weightTrend.isEmpty {
                    weightTrendSection
                        .padding(.top, 24)
                        .padding(.horizontal)
                }

                timelineHeader
                    .padding(.top, 28)
                    .padding(.horizontal)

                if viewModel.isLoading {
                    loadingState
                        .padding(.top, 40)
                } else if viewModel.journeyWeeks.isEmpty {
                    emptyTimeline
                        .padding(.top, 40)
                } else {
                    timelineContent
                        .padding(.top, 16)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Protocol Journey")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showProtocolDetail = true
                } label: {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .navigationDestination(isPresented: $viewModel.showProtocolDetail) {
            ProtocolDetailView(protocolData: viewModel.protocolData)
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - Hero Header

    private var journeyHero: some View {
        VStack(spacing: 0) {
            ZStack {
                heroBackground

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(PepTheme.textSecondary.opacity(0.15), lineWidth: 6)
                            .frame(width: 88, height: 88)

                        Circle()
                            .trim(from: 0, to: viewModel.adherenceRate)
                            .stroke(
                                viewModel.protocolData.goal.color,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 88, height: 88)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 2) {
                            Text("\(Int(viewModel.adherenceRate * 100))%")
                                .font(.system(.title3, design: .rounded, weight: .heavy))
                                .foregroundStyle(.white)
                            Text("adherence")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    VStack(spacing: 6) {
                        Text(viewModel.protocolData.name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            Image(systemName: viewModel.protocolData.goal.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(viewModel.protocolData.goal.color)
                            Text(viewModel.protocolData.goal.rawValue)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            Text("·")
                                .foregroundStyle(.white.opacity(0.4))
                            Text(viewModel.protocolData.weekLabel)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(viewModel.protocolData.goal.color)
                        }
                    }

                    if !viewModel.protocolData.compounds.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(viewModel.protocolData.compounds.prefix(3)) { compound in
                                Text("\(compound.compoundName) \(CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName))")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.12))
                                    .clipShape(.capsule)
                            }
                        }
                    }

                    Text("Day \(viewModel.protocolData.currentDay)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 2)
                }
                .padding(.vertical, 32)
                .padding(.horizontal)
            }
        }
    }

    private var heroBackground: some View {
        let goalColor = viewModel.protocolData.goal.color
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        goalColor.opacity(0.8),
                        goalColor.opacity(0.4),
                        Color(red: 15/255, green: 15/255, blue: 20/255)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(red: 15/255, green: 15/255, blue: 20/255).opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill(
                icon: "syringe.fill",
                value: "\(viewModel.totalDoses)",
                label: "Doses",
                color: PepTheme.teal
            )
            if let change = viewModel.totalWeightChange {
                statPill(
                    icon: "scalemass.fill",
                    value: "\(change > 0 ? "+" : "")\(String(format: "%.1f", change))",
                    label: "lbs",
                    color: change <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255)
                )
            }
            if viewModel.totalBloodworkPanels > 0 {
                statPill(
                    icon: "drop.fill",
                    value: "\(viewModel.totalBloodworkPanels)",
                    label: "Labs",
                    color: PepTheme.blue
                )
            }
            statPill(
                icon: "exclamationmark.triangle.fill",
                value: "\(viewModel.protocolData.sideEffectLog.count)",
                label: "Effects",
                color: PepTheme.amber
            )
        }
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Weight Trend

    private var weightTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 76/255, green: 217/255, blue: 100/255))
                Text("Weight Trend")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                if let change = viewModel.totalWeightChange {
                    Text("\(change > 0 ? "+" : "")\(String(format: "%.1f", change)) lbs")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(change <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                }
            }

            weightChart
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    }

    private var weightChart: some View {
        let data = viewModel.weightTrend
        let weights = data.map(\.weight)
        let minW = (weights.min() ?? 0) - 2
        let maxW = (weights.max() ?? 0) + 2
        let range = max(maxW - minW, 1)

        return VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height

                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        let y = height * CGFloat(i) / 3
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(PepTheme.separatorColor, lineWidth: 0.5)
                    }

                    if data.count >= 2 {
                        let points = data.enumerated().map { i, entry -> CGPoint in
                            let x = width * CGFloat(i) / CGFloat(data.count - 1)
                            let y = height - (height * CGFloat(entry.weight - minW) / CGFloat(range))
                            return CGPoint(x: x, y: y)
                        }

                        Path { path in
                            path.move(to: points[0])
                            for i in 1..<points.count {
                                let prev = points[i - 1]
                                let curr = points[i]
                                let midX = (prev.x + curr.x) / 2
                                path.addCurve(
                                    to: curr,
                                    control1: CGPoint(x: midX, y: prev.y),
                                    control2: CGPoint(x: midX, y: curr.y)
                                )
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [PepTheme.teal, Color(red: 76/255, green: 217/255, blue: 100/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )

                        Path { path in
                            path.move(to: CGPoint(x: points[0].x, y: height))
                            path.addLine(to: points[0])
                            for i in 1..<points.count {
                                let prev = points[i - 1]
                                let curr = points[i]
                                let midX = (prev.x + curr.x) / 2
                                path.addCurve(
                                    to: curr,
                                    control1: CGPoint(x: midX, y: prev.y),
                                    control2: CGPoint(x: midX, y: curr.y)
                                )
                            }
                            path.addLine(to: CGPoint(x: points.last!.x, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [PepTheme.teal.opacity(0.2), PepTheme.teal.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        if let lastPoint = points.last {
                            Circle()
                                .fill(PepTheme.teal)
                                .frame(width: 8, height: 8)
                                .shadow(color: PepTheme.teal.opacity(0.4), radius: 4)
                                .position(lastPoint)
                        }
                    }
                }
            }
            .frame(height: 120)

            if data.count >= 2 {
                HStack {
                    Text(data.first!.date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(data.last!.date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Timeline

    private var timelineHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Timeline")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("\(viewModel.allEvents.count) events across \(viewModel.protocolData.currentWeek) weeks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            eventFilterChips
        }
    }

    private var eventFilterChips: some View {
        Menu {
            Button("All Weeks") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.selectedWeekFilter = nil
                }
            }
            ForEach((1...viewModel.protocolData.currentWeek).reversed(), id: \.self) { week in
                Button("Week \(week)") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedWeekFilter = week
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedWeekFilter.map { "Week \($0)" } ?? "All")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(PepTheme.teal)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(PepTheme.teal.opacity(0.1))
            .clipShape(.capsule)
        }
    }

    private var timelineContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.journeyWeeks) { week in
                weekSection(week)
            }
        }
    }

    private func weekSection(_ week: JourneyWeek) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            weekHeader(week)
                .padding(.bottom, 12)

            if week.events.isEmpty {
                emptyWeekRow
            } else {
                ForEach(Array(week.events.enumerated()), id: \.element.id) { index, event in
                    timelineEventRow(event, isLast: index == week.events.count - 1)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private func weekHeader(_ week: JourneyWeek) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(week.isCurrentWeek ? viewModel.protocolData.goal.color : PepTheme.elevated)
                    .frame(width: 32, height: 32)

                if week.isCurrentWeek {
                    Circle()
                        .fill(viewModel.protocolData.goal.color)
                        .frame(width: 32, height: 32)
                        .shadow(color: viewModel.protocolData.goal.color.opacity(0.4), radius: 6)
                }

                Text("\(week.weekNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(week.isCurrentWeek ? .white : PepTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Week \(week.weekNumber)")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if week.isCurrentWeek {
                        Text("NOW")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(viewModel.protocolData.goal.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(viewModel.protocolData.goal.color.opacity(0.12))
                            .clipShape(.capsule)
                    }
                }
                Text("\(week.startDate, format: .dateTime.month(.abbreviated).day()) – \(week.endDate, format: .dateTime.month(.abbreviated).day())")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            if !week.events.isEmpty {
                eventTypeDots(week.events)
            }
        }
    }

    private func eventTypeDots(_ events: [JourneyEvent]) -> some View {
        let types = Array(Set(events.map(\.type.rawValue)))
        return HStack(spacing: 3) {
            ForEach(types.prefix(5), id: \.self) { typeRaw in
                if let type = JourneyEventType(rawValue: typeRaw) {
                    Circle()
                        .fill(type.color)
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    private func timelineEventRow(_ event: JourneyEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(event.type.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: event.type.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(event.type.color)
                    }

                if !isLast {
                    Rectangle()
                        .fill(PepTheme.separatorColor)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text(event.date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text(event.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(event.type.color)

                if let detail = event.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(event.type.color.opacity(0.1), lineWidth: 0.5)
            )
        }
        .padding(.leading, 14)
    }

    private var emptyWeekRow: some View {
        HStack(spacing: 12) {
            VStack {
                Circle()
                    .fill(PepTheme.elevated.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    }
            }
            .frame(width: 36)

            Text("No events logged")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                .padding(.vertical, 10)

            Spacer()
        }
        .padding(.leading, 14)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)
            Text("Building your journey...")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyTimeline: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.3))
            Text("Your journey starts here")
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Log doses, weigh-ins, and bloodwork to see your progress plotted along the protocol timeline.")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}
