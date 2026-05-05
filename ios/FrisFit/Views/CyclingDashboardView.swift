import SwiftUI

struct CyclingDashboardView: View {
    @Bindable var cyclingVM: CyclingViewModel
    let accentColor: Color
    let onStartRide: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            quickStatsHeader
            startRideCard
            SportCoachCard(sport: .cycling, accent: accentColor)
            weeklyDistanceChart
            recentRidesList
            elevationProfileCard
            speedTrendCard
            bikeGarageCard
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
                        Image(systemName: "figure.outdoor.cycle")
                            .font(.system(size: 24))
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cycling")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("\(cyclingVM.thisWeekRides.count) ride\(cyclingVM.thisWeekRides.count == 1 ? "" : "s") this week · \(String(format: "%.1f", cyclingVM.thisWeekMiles)) mi")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        cyclingVM.showCyclingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(PepTheme.elevated.opacity(0.6))
                            .clipShape(Circle())
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    quickStat(value: String(format: "%.0f", cyclingVM.totalMilesAllTime), label: "Total Mi", icon: "road.lanes")
                    quickStat(value: "\(cyclingVM.totalRidesAllTime)", label: "Rides", icon: "list.bullet")
                    quickStat(value: String(format: "%.1f", cyclingVM.averageSpeedAllTime), label: "Avg MPH", icon: "speedometer")
                    quickStat(value: String(format: "%.0f", cyclingVM.totalElevationAllTime), label: "Elev ft", icon: "mountain.2.fill")
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
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Start Ride Card

    private var startRideCard: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([RideType.casualRide, .endurance, .tempo, .hillClimb, .interval, .gravel], id: \.id) { type in
                        Button {
                            cyclingVM.selectedRideType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 8, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(cyclingVM.selectedRideType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 68)
                            .padding(.vertical, 10)
                            .background(cyclingVM.selectedRideType == type ? type.color : PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)

            HStack(spacing: 10) {
                Toggle(isOn: $cyclingVM.isIndoorMode) {
                    Label("Indoor", systemImage: "figure.indoor.cycle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(accentColor)

                Spacer()

                if !cyclingVM.bikes.filter({ !$0.isRetired }).isEmpty {
                    Menu {
                        Button("No Bike") {
                            cyclingVM.selectedBikeId = nil
                        }
                        ForEach(cyclingVM.bikes.filter { !$0.isRetired }) { bike in
                            Button("\(bike.name) (\(bike.type))") {
                                cyclingVM.selectedBikeId = bike.id
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bicycle")
                                .font(.system(size: 10))
                            Text(cyclingVM.selectedBikeId.flatMap { id in cyclingVM.bikes.first { $0.id == id }?.name } ?? "Select Bike")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(Capsule())
                    }
                }
            }

            Button {
                onStartRide()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                    Text("Start Ride")
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
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.15), PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Weekly Distance Chart

    private var weeklyDistanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Weekly Distance")
                Spacer()
                Text("\(String(format: "%.1f", cyclingVM.thisWeekMiles)) mi this week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor)
            }

            let distData = cyclingVM.weeklyDistanceHistory
            let maxMiles = max(distData.map(\.totalMiles).max() ?? 1, 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(distData) { week in
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", week.totalMiles))
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(week.totalMiles > 0 ? accentColor : PepTheme.textSecondary.opacity(0.4))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    week.totalMiles > 0 ?
                                    LinearGradient(colors: [accentColor, accentColor.opacity(0.5)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [PepTheme.elevated, PepTheme.elevated], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 24, height: max(CGFloat(week.totalMiles / maxMiles) * 80, 4))

                            Text(weekLabel(week.weekStart))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                .frame(height: 110)
            }
            .contentMargins(.horizontal, 4)

            HStack(spacing: 16) {
                weekSummaryPill(icon: "mountain.2.fill", value: String(format: "%.0f ft", cyclingVM.thisWeekElevation), label: "Elevation")
                weekSummaryPill(icon: "speedometer", value: String(format: "%.1f mph", cyclingVM.thisWeekRides.isEmpty ? 0 : cyclingVM.thisWeekRides.reduce(0) { $0 + $1.averageSpeed } / Double(cyclingVM.thisWeekRides.count)), label: "Avg Speed")
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func weekSummaryPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(accentColor.opacity(0.7))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(Capsule())
    }

    // MARK: - Recent Rides

    private var recentRidesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Recent Rides")
                Spacer()
                Text("\(cyclingVM.completedRides.count) total")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if cyclingVM.completedRides.isEmpty {
                noDataPlaceholder("No rides logged yet")
            } else {
                ForEach(cyclingVM.completedRides.prefix(5)) { ride in
                    Button {
                        cyclingVM.selectedRide = ride
                        cyclingVM.showRideDetail = true
                    } label: {
                        recentRideRow(ride)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func recentRideRow(_ ride: CompletedRide) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ride.rideType.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: ride.rideType.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(ride.rideType.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ride.rideType.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if ride.isIndoor {
                        Text("INDOOR")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(PepTheme.violet)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(PepTheme.violet.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if let cat = ride.climbCategory {
                        Text(cat.rawValue)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(cat.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(cat.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(ride.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.1f mi", ride.distanceMiles))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                Text(String(format: "%.1f mph", ride.averageSpeed))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Elevation Profile Card

    private var elevationProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mountain.2.fill")
                    .foregroundStyle(.green)
                HeadlineText(text: "Climbing Summary")
                Spacer()
            }

            let recentRides = cyclingVM.completedRides.prefix(10)
            if recentRides.isEmpty {
                noDataPlaceholder("Ride to track elevation")
            } else {
                let totalElev = recentRides.reduce(0) { $0 + $1.totalElevationGain }
                let maxElev = recentRides.map(\.totalElevationGain).max() ?? 0
                let avgElev = Double(totalElev) / Double(recentRides.count)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    elevStat(value: String(format: "%.0f", totalElev), label: "Total ft", color: .green)
                    elevStat(value: String(format: "%.0f", maxElev), label: "Max Climb", color: .orange)
                    elevStat(value: String(format: "%.0f", avgElev), label: "Avg/Ride", color: accentColor)
                }

                let climbRides = recentRides.filter { $0.climbCategory != nil }
                if !climbRides.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(climbRides.prefix(3)), id: \.id) { ride in
                            if let cat = ride.climbCategory {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(cat.color)
                                        .frame(width: 6, height: 6)
                                    Text(cat.rawValue)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(cat.color)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(cat.color.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func elevStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Speed Trend Card

    private var speedTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Speed Trend")
                Spacer()
            }

            let data = cyclingVM.speedOverTimeData
            if data.count < 2 {
                noDataPlaceholder("Need 2+ rides to show trend")
            } else {
                let minSpeed = (data.map(\.speed).min() ?? 10) - 2
                let maxSpeed = (data.map(\.speed).max() ?? 25) + 2
                let range = maxSpeed - minSpeed

                GeometryReader { geo in
                    let width = geo.size.width
                    let height: CGFloat = 100
                    let stepX = width / CGFloat(max(data.count - 1, 1))

                    ZStack(alignment: .topLeading) {
                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat((point.speed - minSpeed) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat((point.speed - minSpeed) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
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
                    Text("↑ Higher = Faster")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    if let first = data.first, let last = data.last {
                        let diff = last.speed - first.speed
                        HStack(spacing: 3) {
                            Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9))
                            Text(String(format: "%+.1f mph", diff))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(diff > 0 ? .green : .orange)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Bike Garage

    private var bikeGarageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bicycle")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Bike Garage")
                Spacer()
                Button {
                    cyclingVM.showBikeManager = true
                } label: {
                    Text("Manage")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }

            let activeBikes = cyclingVM.bikes.filter { !$0.isRetired }
            if activeBikes.isEmpty {
                noDataPlaceholder("Add bikes to track mileage")
            } else {
                ForEach(activeBikes) { bike in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(bike.maintenanceStatusColor.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "bicycle")
                                .font(.system(size: 14))
                                .foregroundStyle(bike.maintenanceStatusColor)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(bike.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(bike.type)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(accentColor)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(PepTheme.elevated)
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(bike.maintenanceStatusColor)
                                        .frame(width: geo.size.width * bike.maintenanceProgress, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.0f mi", bike.totalMiles))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(bike.maintenanceStatusColor)
                            Text(String(format: "%.0f mi to service", bike.maintenanceIntervalMiles - bike.milesSinceLastMaintenance))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Personal Records

    private var personalRecordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(PepTheme.amber)
                HeadlineText(text: "Personal Records")
                Spacer()
            }

            if cyclingVM.completedRides.isEmpty {
                noDataPlaceholder("Start riding to set records")
            } else {
                let fastest = cyclingVM.completedRides.max(by: { $0.maxSpeed < $1.maxSpeed })
                let longest = cyclingVM.completedRides.max(by: { $0.distanceMiles < $1.distanceMiles })
                let mostClimbing = cyclingVM.completedRides.max(by: { $0.totalElevationGain < $1.totalElevationGain })
                let highestPower = cyclingVM.completedRides.max(by: { $0.maxPower < $1.maxPower })

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    if let ride = fastest {
                        prCell(icon: "bolt.fill", label: "Top Speed", value: String(format: "%.1f mph", ride.maxSpeed), color: .green)
                    }
                    if let ride = longest {
                        prCell(icon: "road.lanes", label: "Longest Ride", value: String(format: "%.1f mi", ride.distanceMiles), color: accentColor)
                    }
                    if let ride = mostClimbing {
                        prCell(icon: "mountain.2.fill", label: "Most Climbing", value: String(format: "%.0f ft", ride.totalElevationGain), color: .orange)
                    }
                    if let ride = highestPower {
                        prCell(icon: "bolt.heart.fill", label: "Max Power", value: "\(ride.maxPower) W", color: .red)
                    }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
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
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Helpers

    private var workoutBuilderButton: some View {
        Button {
            cyclingVM.showWorkoutBuilder = true
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
                    Text("Create Ride Workout")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Build interval, sweet spot & power workouts")
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(16)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(cardBorder())
        }
        .buttonStyle(.scale)
    }

    private func noDataPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.vertical, 16)
            Spacer()
        }
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }

    private func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
