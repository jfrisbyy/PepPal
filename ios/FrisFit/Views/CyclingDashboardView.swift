import SwiftUI

struct CyclingDashboardView: View {
    @Bindable var cyclingVM: CyclingViewModel
    let accentColor: Color
    let onStartRide: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            heroCard
            startRideCard
            maintenanceAlertCard
            weeklyMileageCard
            rideMixCard
            SportCoachCard(sport: .cycling, accent: accentColor)
            recentRidesCard
            climbingSummaryCard
            speedTrendCard
            bikeGarageCard
            personalRecordsCard
            workoutBuilderButton
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("CYCLING")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accentColor.opacity(0.9))
                    Spacer()
                    Button {
                        cyclingVM.showCyclingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(PepTheme.elevated.opacity(0.5), in: Circle())
                    }
                }

                Text(heroTitle)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)

                Text(heroLine)
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
                    heroStat(value: String(format: "%.0f", cyclingVM.totalMilesAllTime), label: "MILES")
                    statDivider
                    heroStat(value: "\(cyclingVM.totalRidesAllTime)", label: "RIDES")
                    statDivider
                    heroStat(value: String(format: "%.1f", cyclingVM.averageSpeedAllTime), label: "AVG MPH")
                    statDivider
                    heroStat(value: String(format: "%.0f", cyclingVM.totalElevationAllTime), label: "FT CLIMB")
                }
            }
        }
    }

    private var heroTitle: String {
        if cyclingVM.thisWeekRides.isEmpty {
            return "In the saddle."
        }
        return "On a roll."
    }

    private var heroLine: String {
        let rides = cyclingVM.thisWeekRides.count
        let miles = cyclingVM.thisWeekMiles
        let elev = cyclingVM.thisWeekElevation
        if rides == 0 {
            return "No rides this week — a short spin counts. Pick a route and roll out."
        }
        if rides == 1 {
            return String(format: "One ride down — %.1f mi already in the legs.", miles)
        }
        if elev >= 3000 {
            return String(format: "%d rides, %.0f mi, %.0f ft of climbing — the climbing legs are showing up.", rides, miles, elev)
        }
        return String(format: "%d rides this week · %.1f mi rolled · %.0f ft up.", rides, miles, elev)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 28)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Start Ride Card

    private var startRideCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "01 — Today",
                title: "Roll Out",
                accent: accentColor,
                trailing: AnyView(
                    Text(cyclingVM.selectedRideType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(cyclingVM.selectedRideType.color)
                )
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([RideType.casualRide, .endurance, .tempo, .hillClimb, .interval, .gravel, .commute], id: \.id) { type in
                        Button {
                            cyclingVM.selectedRideType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(cyclingVM.selectedRideType == type ? .black : PepTheme.textSecondary)
                            .frame(width: 70)
                            .padding(.vertical, 10)
                            .background(cyclingVM.selectedRideType == type ? type.color : PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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

            EditorialPrimaryButton("Begin Ride", icon: "play.fill", accent: accentColor) {
                onStartRide()
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Maintenance Alert

    @ViewBuilder
    private var maintenanceAlertCard: some View {
        let overdue = cyclingVM.bikes.filter { !$0.isRetired && $0.maintenanceProgress >= 0.85 }
        if !overdue.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                EditorialSectionHeading(
                    kicker: "Maintenance",
                    title: overdue.count == 1 ? "Service Due" : "Bikes Need Service",
                    accent: .orange,
                    trailing: AnyView(
                        Button {
                            cyclingVM.showBikeManager = true
                        } label: {
                            Text("OPEN")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    )
                )

                ForEach(overdue) { bike in
                    HStack(spacing: 10) {
                        Image(systemName: "wrench.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(bike.maintenanceStatusColor)
                            .frame(width: 28, height: 28)
                            .background(bike.maintenanceStatusColor.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bike.name)
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            let due = max(0, bike.maintenanceIntervalMiles - bike.milesSinceLastMaintenance)
                            Text(due <= 0
                                 ? String(format: "Overdue by %.0f mi", -bike.maintenanceIntervalMiles + bike.milesSinceLastMaintenance)
                                 : String(format: "%.0f mi until service", due))
                                .font(.system(size: 11, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            cyclingVM.markMaintenance(bike.id)
                        } label: {
                            Text("MARK SERVICED")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .editorialCard(accent: .orange)
        }
    }

    // MARK: - Weekly Mileage

    private var weeklyMileageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "02 — This Week",
                title: "Mileage",
                accent: accentColor,
                trailing: AnyView(
                    Text(String(format: "%.1f MI", cyclingVM.thisWeekMiles))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(accentColor)
                )
            )

            let distData = cyclingVM.weeklyDistanceHistory
            let maxMiles = max(distData.map(\.totalMiles).max() ?? 1, 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(distData) { week in
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", week.totalMiles))
                                .font(.system(size: 9, weight: .semibold, design: .serif))
                                .foregroundStyle(week.totalMiles > 0 ? accentColor : PepTheme.textSecondary.opacity(0.4))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    week.totalMiles > 0 ?
                                    LinearGradient(colors: [accentColor, accentColor.opacity(0.45)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [PepTheme.elevated, PepTheme.elevated], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 22, height: max(CGFloat(week.totalMiles / maxMiles) * 80, 4))

                            Text(weekLabel(week.weekStart))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                .frame(height: 110)
            }
            .contentMargins(.horizontal, 0)

            HStack(spacing: 8) {
                weekSummaryPill(icon: "mountain.2.fill", value: String(format: "%.0f ft", cyclingVM.thisWeekElevation), label: "Climb", color: .green)
                weekSummaryPill(icon: "speedometer", value: String(format: "%.1f mph", weekAvgSpeed), label: "Avg Speed", color: .blue)
                weekSummaryPill(icon: "flame.fill", value: "\(weekCalories)", label: "Cal", color: .orange)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private var weekAvgSpeed: Double {
        let rides = cyclingVM.thisWeekRides
        guard !rides.isEmpty else { return 0 }
        return rides.reduce(0) { $0 + $1.averageSpeed } / Double(rides.count)
    }

    private var weekCalories: Int {
        cyclingVM.thisWeekRides.reduce(0) { $0 + $1.caloriesBurned }
    }

    private func weekSummaryPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Ride Mix

    private var rideMixCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "03 — Last 30 Days",
                title: "Ride Mix",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(recentRides.count) RIDES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if recentRides.isEmpty {
                emptyMessage("Ride and we'll show your mix.")
            } else {
                let mix = rideMixBreakdown
                let total = max(mix.reduce(0) { $0 + $1.miles }, 0.0001)

                // Stacked bar
                HStack(spacing: 2) {
                    ForEach(Array(mix.enumerated()), id: \.offset) { _, slice in
                        Rectangle()
                            .fill(slice.type.color)
                            .frame(height: 10)
                            .frame(maxWidth: .infinity)
                            .layoutPriority(slice.miles)
                    }
                }
                .clipShape(.rect(cornerRadius: 5))
                .frame(height: 10)

                VStack(spacing: 6) {
                    ForEach(Array(mix.enumerated()), id: \.offset) { _, slice in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(slice.type.color)
                                .frame(width: 8, height: 8)
                            Text(slice.type.rawValue)
                                .font(.system(size: 12, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Text(String(format: "%.0f mi", slice.miles))
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(String(format: "%.0f%%", slice.miles / total * 100))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(slice.type.color)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }

                let indoorMiles = recentRides.filter(\.isIndoor).reduce(0) { $0 + $1.distanceMiles }
                let outdoorMiles = recentRides.filter { !$0.isIndoor }.reduce(0) { $0 + $1.distanceMiles }
                if indoorMiles + outdoorMiles > 0 {
                    LinearGradient(
                        colors: [PepTheme.textPrimary.opacity(0.10), PepTheme.textPrimary.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(height: 0.5)

                    HStack(spacing: 8) {
                        indoorOutdoorChip(label: "OUTDOOR", miles: outdoorMiles, total: indoorMiles + outdoorMiles, color: accentColor, icon: "figure.outdoor.cycle")
                        indoorOutdoorChip(label: "INDOOR", miles: indoorMiles, total: indoorMiles + outdoorMiles, color: PepTheme.violet, icon: "figure.indoor.cycle")
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private struct RideSlice {
        let type: RideType
        let miles: Double
    }

    private var recentRides: [CompletedRide] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return cyclingVM.completedRides.filter { $0.date >= cutoff }
    }

    private var rideMixBreakdown: [RideSlice] {
        var dict: [RideType: Double] = [:]
        for ride in recentRides {
            dict[ride.rideType, default: 0] += ride.distanceMiles
        }
        return dict
            .map { RideSlice(type: $0.key, miles: $0.value) }
            .sorted { $0.miles > $1.miles }
    }

    private func indoorOutdoorChip(label: String, miles: Double, total: Double, color: Color, icon: String) -> some View {
        let pct = total > 0 ? miles / total : 0
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                Text(String(format: "%.0f mi · %.0f%%", miles, pct * 100))
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recent Rides

    private var recentRidesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "04 — Recent",
                title: "Rides",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(cyclingVM.completedRides.count) TOTAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                )
            )

            if cyclingVM.completedRides.isEmpty {
                emptyMessage("Begin your first ride and your story starts here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(cyclingVM.completedRides.prefix(5).enumerated()), id: \.element.id) { idx, ride in
                        Button {
                            cyclingVM.selectedRide = ride
                            cyclingVM.showRideDetail = true
                        } label: {
                            recentRideRow(ride)
                        }
                        .buttonStyle(.plain)

                        if idx < min(cyclingVM.completedRides.count, 5) - 1 {
                            Rectangle()
                                .fill(PepTheme.glassBorderTop.opacity(0.5))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
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
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    if ride.isIndoor {
                        Text("INDOOR")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(PepTheme.violet)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(PepTheme.violet.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if let cat = ride.climbCategory {
                        Text(cat.rawValue)
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(cat.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(cat.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(ride.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.1f mi", ride.distanceMiles))
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(accentColor)
                Text(String(format: "%.1f mph", ride.averageSpeed))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 10)
    }

    // MARK: - Climbing Summary

    private var climbingSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "05 — Vertical",
                title: "Climbing",
                accent: .green
            )

            let recent = cyclingVM.completedRides.prefix(10)
            if recent.isEmpty {
                emptyMessage("Ride to track elevation.")
            } else {
                let totalElev = recent.reduce(0) { $0 + $1.totalElevationGain }
                let maxElev = recent.map(\.totalElevationGain).max() ?? 0
                let avgElev = Double(totalElev) / Double(recent.count)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    elevStat(value: String(format: "%.0f", totalElev), label: "TOTAL FT", color: .green)
                    elevStat(value: String(format: "%.0f", maxElev), label: "MAX CLIMB", color: .orange)
                    elevStat(value: String(format: "%.0f", avgElev), label: "AVG / RIDE", color: accentColor)
                }

                let climbRides = recent.filter { $0.climbCategory != nil }
                if !climbRides.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(climbRides.prefix(4)), id: \.id) { ride in
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
                                .background(cat.color.opacity(0.10))
                                .clipShape(Capsule())
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .editorialCard(accent: .green)
    }

    private func elevStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Speed Trend

    private var speedTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "06 — Trend",
                title: "Speed",
                accent: accentColor
            )

            let data = cyclingVM.speedOverTimeData
            if data.count < 2 {
                emptyMessage("Need 2+ rides to surface a trend.")
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
                            if let last = data.indices.last {
                                path.addLine(to: CGPoint(x: CGFloat(last) * stepX, y: height))
                                path.addLine(to: CGPoint(x: 0, y: height))
                                path.closeSubpath()
                            }
                        }
                        .fill(
                            LinearGradient(colors: [accentColor.opacity(0.22), accentColor.opacity(0)], startPoint: .top, endPoint: .bottom)
                        )

                        Path { path in
                            for (i, point) in data.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = height - CGFloat((point.speed - minSpeed) / range) * height
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    .frame(height: height)
                }
                .frame(height: 100)

                HStack {
                    Text("HIGHER = FASTER")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    if let first = data.first, let last = data.last {
                        let diff = last.speed - first.speed
                        HStack(spacing: 3) {
                            Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9))
                            Text(String(format: "%+.1f mph", diff))
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                        }
                        .foregroundStyle(diff > 0 ? .green : .orange)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Bike Garage

    private var bikeGarageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "07 — Garage",
                title: "Bikes",
                accent: accentColor,
                trailing: AnyView(
                    Button {
                        cyclingVM.showBikeManager = true
                    } label: {
                        Text("MANAGE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(accentColor)
                    }
                )
            )

            let activeBikes = cyclingVM.bikes.filter { !$0.isRetired }
            if activeBikes.isEmpty {
                emptyMessage("Add a bike to track mileage.")
            } else {
                VStack(spacing: 12) {
                    ForEach(activeBikes) { bike in
                        bikeRow(bike)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func bikeRow(_ bike: Bike) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(bike.maintenanceStatusColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "bicycle")
                    .font(.system(size: 15))
                    .foregroundStyle(bike.maintenanceStatusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(bike.name)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(bike.type.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.10))
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
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(bike.maintenanceStatusColor)
                Text(String(format: "%.0f to service", max(0, bike.maintenanceIntervalMiles - bike.milesSinceLastMaintenance)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    // MARK: - Personal Records

    private var personalRecordsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "08 — On Record",
                title: "Personal Bests",
                accent: PepTheme.amber
            )

            if cyclingVM.completedRides.isEmpty {
                emptyMessage("Start riding to set records.")
            } else {
                let fastest = cyclingVM.completedRides.max(by: { $0.maxSpeed < $1.maxSpeed })
                let longest = cyclingVM.completedRides.max(by: { $0.distanceMiles < $1.distanceMiles })
                let mostClimbing = cyclingVM.completedRides.max(by: { $0.totalElevationGain < $1.totalElevationGain })
                let highestPower = cyclingVM.completedRides.max(by: { $0.maxPower < $1.maxPower })

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    if let ride = fastest {
                        prCell(icon: "bolt.fill", label: "TOP SPEED", value: String(format: "%.1f mph", ride.maxSpeed), color: .green)
                    }
                    if let ride = longest {
                        prCell(icon: "road.lanes", label: "LONGEST RIDE", value: String(format: "%.1f mi", ride.distanceMiles), color: accentColor)
                    }
                    if let ride = mostClimbing {
                        prCell(icon: "mountain.2.fill", label: "MOST CLIMBING", value: String(format: "%.0f ft", ride.totalElevationGain), color: .orange)
                    }
                    if let ride = highestPower, ride.maxPower > 0 {
                        prCell(icon: "bolt.heart.fill", label: "MAX POWER", value: "\(ride.maxPower) W", color: .red)
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func prCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.body, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Workout Builder Button

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
                    Text("Build a Ride Workout")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Intervals, sweet spot, threshold — set the blocks, then ride them.")
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .editorialCard(accent: accentColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func emptyMessage(_ text: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "bicycle")
                    .font(.system(size: 22))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                Text(text)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 14)
            Spacer()
        }
    }

    private func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
