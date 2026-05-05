import SwiftUI

struct BodyGoalDetailView: View {
    @Bindable var viewModel: BodyGoalViewModel
    @State private var selectedTab: DetailTab = .weight

    enum DetailTab: String, CaseIterable {
        case weight = "Weight"
        case measurements = "Measurements"
        case photos = "Photos"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                editorialMasthead
                goalHeader
                quickActionsRow
                statTriptych
                tabPicker
                switch selectedTab {
                case .weight:
                    weightSection
                case .measurements:
                    measurementsSection
                case .photos:
                    photosSection
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showGoalPicker = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $viewModel.showWeighInSheet) {
            WeighInSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showMeasurementSheet) {
            MeasurementSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showGoalPicker) {
            GoalPickerSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Editorial Masthead

    private var editorialMasthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COMPOSITION  \u{2014}  VOL. 01")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(viewModel.currentGoal.color.opacity(0.85))

            Text(viewModel.currentGoal.rawValue)
                .font(.system(size: 34, weight: .black, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(viewModel.currentGoal.color)
                    .frame(width: 28, height: 2)
                Text(viewModel.currentGoal.subtitle.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionButton(icon: "scalemass.fill", label: "Log Weight", color: PepTheme.teal) {
                    viewModel.showWeighInSheet = true
                }
                actionButton(icon: "ruler.fill", label: "Measurements", color: PepTheme.amber) {
                    viewModel.showMeasurementSheet = true
                }
            }
            HStack(spacing: 10) {
                actionButton(icon: "target", label: "Change Goal", color: viewModel.currentGoal.color) {
                    viewModel.showGoalPicker = true
                }
                actionButton(icon: "chart.line.uptrend.xyaxis", label: "Trends", color: PepTheme.violet) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedTab = .weight
                    }
                }
            }
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
        .buttonStyle(.scale)
    }

    // MARK: - Stat Triptych

    private var statTriptych: some View {
        HStack(spacing: 0) {
            triptychCell(
                eyebrow: "START",
                value: viewModel.startingWeight > 0 ? String(format: "%.1f", viewModel.startingWeight) : "\u{2014}",
                unit: "lbs",
                color: PepTheme.textSecondary
            )
            divider
            triptychCell(
                eyebrow: "NOW",
                value: viewModel.currentWeight > 0 ? String(format: "%.1f", viewModel.currentWeight) : "\u{2014}",
                unit: "lbs",
                color: PepTheme.textPrimary
            )
            divider
            triptychCell(
                eyebrow: "GOAL",
                value: String(format: "%.1f", viewModel.targetWeight),
                unit: "lbs",
                color: viewModel.currentGoal.color
            )
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 1, height: 36)
    }

    private func triptychCell(eyebrow: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Goal Header

    private var goalHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(PepTheme.elevated, lineWidth: 8)
                        .frame(width: 110, height: 110)
                    Circle()
                        .trim(from: 0, to: viewModel.progressToGoal)
                        .stroke(
                            LinearGradient(
                                colors: [viewModel.currentGoal.color.opacity(0.6), viewModel.currentGoal.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: viewModel.progressToGoal)
                    VStack(spacing: 2) {
                        Text("\(Int(viewModel.progressToGoal * 100))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(viewModel.currentGoal.color)
                        Text("PERCENT")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("PROGRESS")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text(String(format: "%.1f lbs to go", viewModel.remainingToGoal))
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 4) {
                        Image(systemName: viewModel.weeklyChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%.1f lbs this week", abs(viewModel.weeklyChange)))
                            .font(.system(.caption, weight: .semibold))
                    }
                    .foregroundStyle(
                        viewModel.currentGoal.isLosing
                        ? (viewModel.weeklyChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                        : (viewModel.weeklyChange >= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.elevated.opacity(0.6))
                    .clipShape(.capsule)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                bmiMiniCard
                weeklyChangeMiniCard
            }

            if let estDate = viewModel.estimatedCompletionDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.teal)
                    Text("Est. goal date: \(estDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PepTheme.teal.opacity(0.08))
                .clipShape(.capsule)
            }

            if let avgWeekly = viewModel.averageWeeklyChange {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.flattrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("Avg. weekly change: \(String(format: "%+.1f", avgWeekly)) lbs")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
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

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var bmiMiniCard: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: min(viewModel.bmi.value / 40.0, 1.0))
                    .stroke(viewModel.bmi.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.1f", viewModel.bmi.value))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.bmi.color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("BMI")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(viewModel.bmi.category)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(viewModel.bmi.color)
            }
            Spacer()
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var weeklyChangeMiniCard: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(PepTheme.elevated)
                    .frame(width: 36, height: 36)
                Image(systemName: viewModel.weeklyChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(viewModel.weeklyChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: "%.1f lbs", abs(viewModel.weeklyChange)))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("This week")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(DetailTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? PepTheme.invertedText : PepTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? PepTheme.teal : PepTheme.elevated.opacity(0.5))
                        .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: selectedTab)
            }
        }
        .padding(4)
        .background(PepTheme.cardSurface)
        .clipShape(.capsule)
    }

    // MARK: - Weight Section

    private var weightSection: some View {
        VStack(spacing: 16) {
            weightChart

            Button {
                viewModel.showWeighInSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Log Weigh-In")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PepTheme.teal, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)

            weightHistory
        }
    }

    private var weightChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Weight Trend")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    if viewModel.weightEntries.count > 0 {
                        Text(String(format: "%.1f lbs total", abs(viewModel.totalChange)))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(
                                viewModel.currentGoal.isLosing
                                ? (viewModel.totalChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                                : (viewModel.totalChange >= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                            )
                    }
                }

                if viewModel.weightChartData.count > 1 {
                    WeightChartView(data: viewModel.weightChartData, goalColor: viewModel.currentGoal.color)
                        .frame(height: 160)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        Text("Log more weigh-ins to see your trend")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                }
            }
        }
    }

    private var weightHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(viewModel.weightEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if viewModel.weightEntries.isEmpty {
                EmptyStateView(
                    icon: "scalemass",
                    title: "No Weight Entries",
                    message: "Log your first weigh-in to start tracking your progress."
                )
            } else {
                ForEach(viewModel.weightEntries.reversed()) { entry in
                    weightEntryRow(entry)
                }
            }
        }
    }

    private func weightEntryRow(_ entry: WeightEntry) -> some View {
        let previousIndex = viewModel.weightEntries.firstIndex(where: { $0.id == entry.id }).map { $0 - 1 }
        let previousWeight = previousIndex.flatMap { $0 >= 0 ? viewModel.weightEntries[$0].weight : nil }
        let change = previousWeight.map { entry.weight - $0 }

        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(entry.date.formatted(.dateTime.day()))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(entry.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: "%.1f lbs", entry.weight))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change <= 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.1f", abs(change)))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(change <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (change <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255)).opacity(0.1)
                )
                .clipShape(.capsule)
            }
        }
        .padding(12)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
        .contextMenu {
            if entry.supabaseId != nil {
                Button(role: .destructive) {
                    viewModel.deleteWeightEntry(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Measurements Section

    private var measurementsSection: some View {
        VStack(spacing: 16) {
            Button {
                viewModel.showMeasurementSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Log Measurements")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PepTheme.teal, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)

            if viewModel.measurements.isEmpty {
                EmptyStateView(
                    icon: "ruler",
                    title: "No Measurements",
                    message: "Track your body measurements to see changes over time."
                )
            } else {
                if viewModel.measurements.count >= 2 {
                    measurementComparisonCard
                }

                ForEach(viewModel.measurements.reversed()) { measurement in
                    measurementCard(measurement)
                        .contextMenu {
                            if measurement.supabaseId != nil {
                                Button(role: .destructive) {
                                    viewModel.deleteMeasurement(measurement)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
        }
    }

    private func measurementCard(_ measurement: BodyMeasurement) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(measurement.date.formatted(.dateTime.month(.wide).day().year()))
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if let v = measurement.chest { measurementStat(label: "Chest", value: v) }
                    if let v = measurement.waist { measurementStat(label: "Waist", value: v) }
                    if let v = measurement.hips { measurementStat(label: "Hips", value: v) }
                    if let v = measurement.neck { measurementStat(label: "Neck", value: v) }
                    if let v = measurement.bicepLeft { measurementStat(label: "L Bicep", value: v) }
                    if let v = measurement.bicepRight { measurementStat(label: "R Bicep", value: v) }
                    if let v = measurement.thighLeft { measurementStat(label: "L Thigh", value: v) }
                    if let v = measurement.thighRight { measurementStat(label: "R Thigh", value: v) }
                }
            }
        }
    }

    private func measurementStat(label: String, value: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Text(String(format: "%.1f\"", value))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
        }
    }

    private var measurementComparisonCard: some View {
        let latest = viewModel.measurements.last!
        let previous = viewModel.measurements[viewModel.measurements.count - 2]

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(PepTheme.violet)
                    Text("Changes Since Last")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if let lc = latest.chest, let pc = previous.chest { measurementChange(label: "Chest", change: lc - pc) }
                    if let lw = latest.waist, let pw = previous.waist { measurementChange(label: "Waist", change: lw - pw) }
                    if let lh = latest.hips, let ph = previous.hips { measurementChange(label: "Hips", change: lh - ph) }
                    if let ln = latest.neck, let pn = previous.neck { measurementChange(label: "Neck", change: ln - pn) }
                    if let lb = latest.bicepLeft, let pb = previous.bicepLeft { measurementChange(label: "L Bicep", change: lb - pb) }
                    if let rb = latest.bicepRight, let prb = previous.bicepRight { measurementChange(label: "R Bicep", change: rb - prb) }
                    if let lt = latest.thighLeft, let pt = previous.thighLeft { measurementChange(label: "L Thigh", change: lt - pt) }
                    if let rt = latest.thighRight, let prt = previous.thighRight { measurementChange(label: "R Thigh", change: rt - prt) }
                }
            }
        }
    }

    private func measurementChange(label: String, change: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                HStack(spacing: 3) {
                    Image(systemName: change < 0 ? "arrow.down" : (change > 0 ? "arrow.up" : "minus"))
                        .font(.system(size: 8, weight: .bold))
                    Text(String(format: "%+.1f\"", change))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(change == 0 ? PepTheme.textSecondary : (change < 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : PepTheme.amber))
            }
            Spacer()
        }
    }

    // MARK: - Photos Section

    private var photosSection: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                icon: "camera.fill",
                title: "Progress Photos Coming Soon",
                message: "Photo tracking with side-by-side comparisons will be available in a future update."
            )
        }
    }
}

// MARK: - Weight Chart

struct WeightChartView: View {
    let data: [(date: Date, weight: Double)]
    let goalColor: Color

    var body: some View {
        GeometryReader { geo in
            let minW = data.map(\.weight).min() ?? 0
            let maxW = data.map(\.weight).max() ?? 1
            let range = max(maxW - minW, 1)
            let padding: Double = range * 0.1

            let adjustedMin = minW - padding
            let adjustedRange = range + padding * 2

            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let y = geo.size.height * (1 - CGFloat(i) / 3.0)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(PepTheme.shimmerHighlight, lineWidth: 0.5)

                    let labelValue = adjustedMin + adjustedRange * (Double(i) / 3.0)
                    Text(String(format: "%.0f", labelValue))
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        .position(x: 16, y: y - 8)
                }

                Path { path in
                    for (index, point) in data.enumerated() {
                        let x = data.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(data.count - 1) : geo.size.width / 2
                        let y = geo.size.height * (1 - CGFloat((point.weight - adjustedMin) / adjustedRange))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [goalColor.opacity(0.5), goalColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )

                Path { path in
                    for (index, point) in data.enumerated() {
                        let x = data.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(data.count - 1) : geo.size.width / 2
                        let y = geo.size.height * (1 - CGFloat((point.weight - adjustedMin) / adjustedRange))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    if let last = data.last {
                        let lastX = data.count > 1 ? geo.size.width : geo.size.width / 2
                        let lastY = geo.size.height * (1 - CGFloat((last.weight - adjustedMin) / adjustedRange))
                        path.addLine(to: CGPoint(x: lastX, y: geo.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        path.closeSubpath()
                    }
                }
                .fill(
                    LinearGradient(
                        colors: [goalColor.opacity(0.15), goalColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                ForEach(data.indices, id: \.self) { index in
                    let point = data[index]
                    let x = data.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(data.count - 1) : geo.size.width / 2
                    let y = geo.size.height * (1 - CGFloat((point.weight - adjustedMin) / adjustedRange))
                    Circle()
                        .fill(goalColor)
                        .frame(width: index == data.count - 1 ? 8 : 5, height: index == data.count - 1 ? 8 : 5)
                        .shadow(color: goalColor.opacity(0.5), radius: index == data.count - 1 ? 4 : 0)
                        .position(x: x, y: y)
                }
            }
        }
    }
}
