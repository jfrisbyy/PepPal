import SwiftUI

struct RunningDashboardView: View {
    @Bindable var runVM: RunningViewModel
    let accentColor: Color
    let onStartRun: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            quickStatsHeader
            startRunCard
            weeklyMileageChart
            recentRunsList
            racePredictionsCard
            paceProgressCard
            shoeRackCard
            personalRecordsCard
            workoutBuilderButton
        }
    }

    // MARK: - Quick Stats Header

    private var quickStatsHeader: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.05)],
                                    center: .center, startRadius: 0, endRadius: 32
                                )
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "figure.run")
                            .font(.system(size: 24))
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Running")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Text("\(runVM.thisWeekRuns.count) run\(runVM.thisWeekRuns.count == 1 ? "" : "s") this week · \(String(format: "%.1f", runVM.thisWeekMiles)) mi")
                            .font(.caption)
                            .foregroundStyle(FrisTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        runVM.showRunSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(FrisTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(FrisTheme.elevated.opacity(0.6))
                            .clipShape(Circle())
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    quickStat(value: String(format: "%.0f", runVM.totalMilesAllTime), label: "Total Mi", icon: "road.lanes")
                    quickStat(value: "\(runVM.totalRunsAllTime)", label: "Runs", icon: "list.bullet")
                    quickStat(value: formatPace(runVM.averagePaceAllTime), label: "Avg Pace", icon: "speedometer")
                    quickStat(value: String(format: "%.1f", runVM.longestRunEver), label: "Longest", icon: "arrow.up.right")
                }
            }
        }
    }

    private func quickStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(accentColor.opacity(0.7))
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(FrisTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(FrisTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Start Run Card

    private var startRunCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach([RunType.easyRun, .tempoRun, .intervalSession, .longRun], id: \.id) { type in
                    Button {
                        runVM.selectedRunType = type
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16))
                            Text(type.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(runVM.selectedRunType == type ? .black : FrisTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(runVM.selectedRunType == type ? type.color : FrisTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }

            HStack(spacing: 10) {
                Toggle(isOn: $runVM.isTreadmillMode) {
                    Label("Treadmill", systemImage: "figure.run.treadmill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(accentColor)

                Spacer()

                if !runVM.shoes.filter({ !$0.isRetired }).isEmpty {
                    Menu {
                        Button("No Shoe") {
                            runVM.selectedShoeId = nil
                        }
                        ForEach(runVM.shoes.filter { !$0.isRetired }) { shoe in
                            Button("\(shoe.brand) \(shoe.name)") {
                                runVM.selectedShoeId = shoe.id
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "shoe.fill")
                                .font(.system(size: 10))
                            Text(runVM.selectedShoeId.flatMap { id in runVM.shoes.first { $0.id == id }?.name } ?? "Select Shoe")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(FrisTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(FrisTheme.elevated.opacity(0.5))
                        .clipShape(Capsule())
                    }
                }
            }

            Button {
                onStartRun()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                    Text("Start Run")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.8)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.scalePrimary)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.15), FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Weekly Mileage Chart

    private var weeklyMileageChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Weekly Mileage")
                Spacer()
                Text("\(String(format: "%.1f", runVM.thisWeekMiles)) mi this week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor)
            }

            let mileageData = runVM.weeklyMileageHistory
            let maxMiles = max(mileageData.map(\.totalMiles).max() ?? 1, 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(mileageData) { week in
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", week.totalMiles))
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(week.totalMiles > 0 ? accentColor : FrisTheme.textSecondary.opacity(0.4))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    week.totalMiles > 0 ?
                                    LinearGradient(colors: [accentColor, accentColor.opacity(0.5)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [FrisTheme.elevated, FrisTheme.elevated], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 24, height: max(CGFloat(week.totalMiles / maxMiles) * 80, 4))

                            Text(weekLabel(week.weekStart))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                }
                .frame(height: 110)
            }
            .contentMargins(.horizontal, 4)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Recent Runs

    private var recentRunsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Recent Runs")
                Spacer()
                Text("\(runVM.completedRuns.count) total")
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            if runVM.completedRuns.isEmpty {
                noDataPlaceholder("No runs logged yet")
            } else {
                ForEach(runVM.completedRuns.prefix(5)) { run in
                    Button {
                        runVM.selectedRun = run
                        runVM.showRunDetail = true
                    } label: {
                        recentRunRow(run)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func recentRunRow(_ run: CompletedRun) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(run.runType.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: run.runType.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(run.runType.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(run.runType.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    if run.isTreadmill {
                        Text("TREADMILL")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(FrisTheme.violet)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(FrisTheme.violet.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(run.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 10))
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.2f mi", run.distanceMiles))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                Text(run.averagePaceFormatted + " /mi")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FrisTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Race Predictions

    private var racePredictionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(FrisTheme.amber)
                HeadlineText(text: "Race Predictions")
                Spacer()
            }

            let predictions = runVM.racePredictions
            if predictions.isEmpty {
                noDataPlaceholder("Run more to get predictions")
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(predictions) { pred in
                        VStack(spacing: 6) {
                            Text(pred.raceName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(FrisTheme.textSecondary)
                            Text(pred.predictedTimeFormatted)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(FrisTheme.textPrimary)
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(pred.confidence > 0.7 ? .green : pred.confidence > 0.5 ? .yellow : .orange)
                                    .frame(width: 5, height: 5)
                                Text("\(Int(pred.confidence * 100))% confidence")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(FrisTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FrisTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Pace Progress

    private var paceProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Pace Trend")
                Spacer()
            }

            let data = runVM.paceOverTimeData
            if data.count < 2 {
                noDataPlaceholder("Need 2+ runs to show trend")
            } else {
                let minPace = (data.map(\.pace).min() ?? 6) - 0.5
                let maxPace = (data.map(\.pace).max() ?? 12) + 0.5
                let range = maxPace - minPace

                GeometryReader { geo in
                    let width = geo.size.width
                    let height: CGFloat = 100
                    let stepX = width / CGFloat(max(data.count - 1, 1))

                    ZStack(alignment: .topLeading) {
                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = CGFloat((point.pace - minPace) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = CGFloat((point.pace - minPace) / range) * height
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            if let last = data.indices.last {
                                path.addLine(to: CGPoint(x: CGFloat(last) * stepX, y: height))
                                path.addLine(to: CGPoint(x: 0, y: height))
                                path.closeSubpath()
                            }
                        }
                        .fill(
                            LinearGradient(colors: [accentColor.opacity(0.2), accentColor.opacity(0)], startPoint: .top, endPoint: .bottom)
                        )
                    }
                    .frame(height: height)
                }
                .frame(height: 100)

                HStack {
                    Text("↓ Lower = Faster")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Spacer()
                    if let first = data.first, let last = data.last {
                        let diff = first.pace - last.pace
                        HStack(spacing: 3) {
                            Image(systemName: diff > 0 ? "arrow.down.right" : "arrow.up.right")
                                .font(.system(size: 9))
                            Text(String(format: "%+.1f min/mi", -diff))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(diff > 0 ? .green : .orange)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Shoe Rack

    private var shoeRackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shoe.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Shoe Rack")
                Spacer()
                Button {
                    runVM.showShoeManager = true
                } label: {
                    Text("Manage")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }

            let activeShoes = runVM.shoes.filter { !$0.isRetired }
            if activeShoes.isEmpty {
                noDataPlaceholder("Add shoes to track mileage")
            } else {
                ForEach(activeShoes) { shoe in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(shoe.statusColor.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "shoe.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(shoe.statusColor)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(shoe.brand) \(shoe.name)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FrisTheme.textPrimary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(FrisTheme.elevated)
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(shoe.statusColor)
                                        .frame(width: geo.size.width * shoe.usagePercentage, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.0f mi", shoe.totalMiles))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(shoe.statusColor)
                            Text(String(format: "%.0f mi left", shoe.milesRemaining))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Personal Records

    private var personalRecordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(FrisTheme.amber)
                HeadlineText(text: "Personal Records")
                Spacer()
            }

            if runVM.completedRuns.isEmpty {
                noDataPlaceholder("Start running to set records")
            } else {
                let fastest = runVM.completedRuns.filter { $0.bestPace > 0 }.min(by: { $0.bestPace < $1.bestPace })
                let longest = runVM.completedRuns.max(by: { $0.distanceMiles < $1.distanceMiles })
                let mostElevation = runVM.completedRuns.max(by: { $0.totalElevationGain < $1.totalElevationGain })

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    if let run = fastest {
                        prCell(icon: "bolt.fill", label: "Fastest", value: run.bestPaceFormatted + "/mi", color: .green)
                    }
                    if let run = longest {
                        prCell(icon: "road.lanes", label: "Longest", value: String(format: "%.1f mi", run.distanceMiles), color: accentColor)
                    }
                    if let run = mostElevation {
                        prCell(icon: "mountain.2.fill", label: "Most Climb", value: String(format: "%.0f ft", run.totalElevationGain), color: .orange)
                    }
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func prCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(FrisTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Workout Builder Button

    private var workoutBuilderButton: some View {
        Button {
            runVM.showWorkoutBuilder = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus.rectangle.on.folder")
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create Run Workout")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Text("Build interval, tempo & custom workouts")
                        .font(.system(size: 11))
                        .foregroundStyle(FrisTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .padding(16)
            .background(FrisTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(cardBorder())
        }
        .buttonStyle(.scale)
    }

    // MARK: - Helpers

    private func noDataPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(FrisTheme.textSecondary.opacity(0.5))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .padding(.vertical, 16)
            Spacer()
        }
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }

    private func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}
