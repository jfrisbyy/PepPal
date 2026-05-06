import SwiftUI

struct HomeSleepCard: View {
    let healthKit: HealthKitService

    @State private var sleepVM = SleepLogViewModel.shared
    @State private var sleepService = SleepRecoveryService.shared
    @State private var showLogSheet: Bool = false
    @State private var showDetail: Bool = false
    @State private var showWakeSheet: Bool = false

    @AppStorage("sleep.goal.hours") private var goalHours: Double = 8.0
    @AppStorage("sleep.window.start") private var windowStart: Double = 0

    @State private var hookIndex: Int = 0
    @State private var insightIndex: Int = 0
    @State private var now: Date = Date()
    @State private var goalDialog: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var reading: SleepLogViewModel.LastNightReading {
        sleepVM.lastNightReading(healthHours: healthKit.sleepHours)
    }

    private var weekPoints: [SleepLogViewModel.NightPoint] {
        var hkMap: [Date: Double] = [:]
        let cal = Calendar.current
        for n in sleepService.recentNights {
            hkMap[cal.startOfDay(for: n.date)] = n.totalHours
        }
        return sleepVM.recent7Nights(healthByDate: hkMap)
    }

    private var isSleeping: Bool { windowStart > 0 }
    private var hasData: Bool { reading.source != .none || weekPoints.contains(where: { $0.hours > 0 }) }

    private var elapsedSleepHours: Double {
        guard isSleeping else { return 0 }
        return max(0, now.timeIntervalSince1970 - windowStart) / 3600.0
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            cardContent
        }
        .buttonStyle(.scale)
        .navigationDestination(isPresented: $showDetail) {
            SleepRecoveryView()
        }
        .sheet(isPresented: $showLogSheet) {
            LogSleepSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWakeSheet) {
            WakeUpSheet(elapsedHours: elapsedSleepHours) { quality, hours in
                saveWakeLog(hours: hours, quality: quality)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Sleep goal", isPresented: $goalDialog, titleVisibility: .visible) {
            ForEach([6.0, 7.0, 7.5, 8.0, 8.5, 9.0, 10.0], id: \.self) { v in
                Button(formatGoal(v)) { goalHours = v }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await sleepVM.loadIfNeeded()
            if sleepService.recentNights.isEmpty {
                await sleepService.loadRecent(days: 7)
            }
        }
        .task(id: isSleeping) {
            // tick once per minute while sleeping
            while !Task.isCancelled && isSleeping {
                now = Date()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .task(id: hasData) {
            // rotate hook (empty state) or insight (data state) every ~5s
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if reduceMotion { continue }
                if isSleeping { continue }
                withAnimation(.easeInOut(duration: 0.45)) {
                    if hasData {
                        insightIndex = (insightIndex + 1) % max(1, insightItems.count)
                    } else {
                        hookIndex = (hookIndex + 1) % 3
                    }
                }
            }
        }
    }

    // MARK: - Card shell

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                NightSkyScene(
                    moonY: moonYAnchor,
                    starDimmed: isSleeping,
                    reduceMotion: reduceMotion
                )
                .frame(height: heroHeight)
                .clipShape(.rect(cornerRadius: 14))

                heroOverlay
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: heroHeight)

            if isSleeping {
                sleepingControls
            } else if hasData {
                weekStrip
                insightFooter
            } else {
                emptyControls
            }
        }
        .padding(14)
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

    private var heroHeight: CGFloat {
        if isSleeping { return 150 }
        if hasData { return 130 }
        return 158
    }

    /// 0 = bottom (low / no data), 1 = top (goal achieved)
    private var moonYAnchor: CGFloat {
        if isSleeping {
            // climbs slowly across the night, capped
            let t = min(1.0, elapsedSleepHours / max(goalHours, 6))
            return 0.35 + 0.45 * CGFloat(t)
        }
        if hasData, reading.hours > 0 {
            return CGFloat(min(1.0, max(0.15, reading.hours / max(goalHours, 6))))
        }
        return 0.78 // empty state — tucked up to the right
    }

    // MARK: - Hero overlay (text on top of sky)

    @ViewBuilder
    private var heroOverlay: some View {
        if isSleeping {
            sleepingHero
        } else if hasData {
            dataHero
        } else {
            emptyHero
        }
    }

    // MARK: - States: Has data hero

    private var dataHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                Text("Last Night")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                if let q = reading.quality {
                    qualityChip(q)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(hoursWhole)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(hoursMinutes)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Text("h")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.leading, 2)
                Spacer(minLength: 0)
            }

            goalProgressBar
        }
    }

    private var goalProgressBar: some View {
        let value = max(0, min(reading.hours, goalHours * 1.25))
        let frac = goalHours > 0 ? CGFloat(value / (goalHours * 1.25)) : 0
        let goalMark: CGFloat = goalHours > 0 ? CGFloat(goalHours / (goalHours * 1.25)) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [PepTheme.violet, PepTheme.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geo.size.width * frac))
                Rectangle()
                    .fill(.white.opacity(0.7))
                    .frame(width: 1.5, height: 10)
                    .offset(x: geo.size.width * goalMark - 0.75, y: 0)
            }
        }
        .frame(height: 6)
        .overlay(alignment: .trailing) {
            Button {
                goalDialog = true
            } label: {
                Text("Goal \(formatGoal(goalHours))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.10), in: .capsule)
            }
            .buttonStyle(.plain)
            .offset(y: 16)
        }
    }

    private var hoursWhole: String { "\(Int(reading.hours))" }
    private var hoursMinutes: String {
        let mins = Int((reading.hours - Double(Int(reading.hours))) * 60)
        if mins == 0 { return "" }
        return String(format: ":%02d", mins)
    }

    private func qualityChip(_ quality: Int) -> some View {
        let label: String
        let color: Color
        switch quality {
        case ...3: label = "Restless"; color = PepTheme.coral
        case 4...5: label = "Poor"; color = PepTheme.amber
        case 6...7: label = "OK"; color = PepTheme.teal
        case 8: label = "Good"; color = PepTheme.teal
        default: label = "Excellent"; color = PepTheme.success
        }
        return HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text("\(label) · \(quality)/10")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.25), in: .capsule)
        .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 0.6))
    }

    // MARK: - States: Empty hero (rotating hook)

    private var emptyHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                Text("Sleep")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                hookDots
            }

            ZStack(alignment: .leading) {
                ForEach(0..<3, id: \.self) { i in
                    hookCard(for: i)
                        .opacity(i == hookIndex ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hookDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { hookIndex = i }
                } label: {
                    Circle()
                        .fill(i == hookIndex ? PepTheme.violet : .white.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func hookCard(for i: Int) -> some View {
        switch i {
        case 0:
            hookContent(
                icon: "pills.fill",
                accent: PepTheme.violet,
                title: "Sleep fuels your peptides",
                body: "Growth peptides peak in deep sleep. Track nights to see the impact on recovery."
            )
        case 1:
            hookContent(
                icon: "heart.text.square.fill",
                accent: PepTheme.coral,
                title: healthKit.isAuthorized ? "Apple Health connected" : "Connect Apple Health",
                body: healthKit.isAuthorized ? "Last night will sync automatically as you sleep." : "Import last night automatically — no logging required.",
                actionLabel: healthKit.isAuthorized ? nil : "Connect",
                action: { Task { _ = await healthKit.requestAuthorizationInteractively() } }
            )
        default:
            hookContent(
                icon: "target",
                accent: PepTheme.teal,
                title: "Set your sleep goal",
                body: "Currently \(formatGoal(goalHours)). Tap to adjust your target.",
                actionLabel: "Adjust",
                action: { goalDialog = true }
            )
        }
    }

    private func hookContent(icon: String, accent: Color, title: String, body: String, actionLabel: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.18), in: .circle)
                .overlay(Circle().strokeBorder(accent.opacity(0.35), lineWidth: 0.6))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(body)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionLabel, let action {
                    Button {
                        action()
                    } label: {
                        Text(actionLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.18), in: .capsule)
                            .overlay(Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - States: Sleeping hero

    private var sleepingHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(PepTheme.violet)
                    .frame(width: 7, height: 7)
                    .opacity(reduceMotion ? 1 : 0.6)
                    .overlay(
                        Circle()
                            .stroke(PepTheme.violet.opacity(0.4), lineWidth: 1)
                            .scaleEffect(reduceMotion ? 1 : 2)
                            .opacity(reduceMotion ? 0 : 0)
                    )
                Text("SLEEPING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            Spacer(minLength: 0)
            Text(elapsedDisplay)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text("Started at \(startedAtDisplay) · tap Wake when you're up")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var elapsedDisplay: String {
        let total = max(0, now.timeIntervalSince1970 - windowStart)
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private var startedAtDisplay: String {
        let d = Date(timeIntervalSince1970: windowStart)
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    // MARK: - Sleeping controls (below hero)

    private var sleepingControls: some View {
        HStack(spacing: 8) {
            Button {
                cancelSleepWindow()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Cancel")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(PepTheme.elevated, in: .capsule)
            }
            .buttonStyle(.scale)

            Button {
                showWakeSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Wake & Log")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [PepTheme.violet, PepTheme.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .capsule
                )
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.success, trigger: showWakeSheet)
        }
    }

    // MARK: - Empty controls (below hero)

    private var emptyControls: some View {
        HStack(spacing: 8) {
            Button {
                startSleepWindow()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Going to Bed")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [PepTheme.violet, PepTheme.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .capsule
                )
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.selection, trigger: windowStart)

            Button {
                showLogSheet = true
            } label: {
                Text("Log past night")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(PepTheme.violet.opacity(0.14), in: .capsule)
                    .overlay(Capsule().strokeBorder(PepTheme.violet.opacity(0.3), lineWidth: 0.6))
            }
            .buttonStyle(.scale)
        }
    }

    // MARK: - Week strip with goal line + sleep debt

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let points = weekPoints
                let chartMax = max(goalHours + 1.5, points.map(\.hours).max() ?? 0, 9)
                let goalY: CGFloat = goalHours > 0 ? CGFloat(1 - goalHours / chartMax) * geo.size.height : 0
                let barWidth = (geo.size.width - 6 * 6) / 7
                ZStack(alignment: .topLeading) {
                    // goal line
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: goalY))
                        p.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                    .foregroundStyle(.white.opacity(0.18))

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(points) { p in
                            let isLast = p.id == points.last?.id
                            let ratio = chartMax > 0 ? p.hours / chartMax : 0
                            let height = max(p.hours > 0 ? 4 : 2, geo.size.height * ratio)
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: barColors(isLast: isLast, isManual: p.isManual, hasValue: p.hours > 0, metGoal: p.hours >= goalHours),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: barWidth, height: height)
                                    .opacity(p.hours > 0 ? 1 : 0.35)
                                    .scaleEffect(isLast && !reduceMotion ? barPulse : 1, anchor: .bottom)
                            }
                            .frame(height: geo.size.height, alignment: .bottom)
                        }
                    }
                }
            }
            .frame(height: 38)

            HStack(spacing: 8) {
                debtBadge
                Spacer()
                Text(weekdayLabels)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textTertiary)
                    .tracking(2)
            }
        }
    }

    @State private var barPulse: CGFloat = 1.0

    private var weekdayLabels: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        var parts: [String] = []
        for offset in (0..<7).reversed() {
            if let d = cal.date(byAdding: .day, value: -offset, to: today) {
                parts.append(f.string(from: d).uppercased())
            }
        }
        return parts.joined(separator: " ")
    }

    private func barColors(isLast: Bool, isManual: Bool, hasValue: Bool, metGoal: Bool) -> [Color] {
        if !hasValue { return [PepTheme.elevated, PepTheme.elevated] }
        if isLast {
            return metGoal
                ? [PepTheme.success, PepTheme.teal.opacity(0.7)]
                : [PepTheme.violet, PepTheme.violet.opacity(0.55)]
        }
        let base = isManual ? PepTheme.teal : PepTheme.violet
        return [base.opacity(0.6), base.opacity(0.25)]
    }

    private var debtBadge: some View {
        let logged = weekPoints.filter { $0.hours > 0 }
        let totalActual = logged.reduce(0.0) { $0 + $1.hours }
        let target = goalHours * Double(max(1, logged.count))
        let debt = totalActual - target  // negative = behind
        let label: String
        let color: Color
        let icon: String
        if logged.isEmpty {
            label = "No nights yet"; color = PepTheme.textTertiary; icon = "circle.dotted"
        } else if debt >= -0.4 {
            label = "On track"; color = PepTheme.success; icon = "checkmark.circle.fill"
        } else {
            label = String(format: "%.1fh debt this week", debt)
            color = PepTheme.coral; icon = "arrow.down.right.circle.fill"
        }
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: .capsule)
    }

    // MARK: - Insight rotator + footer

    private var insightFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                ForEach(Array(insightItems.enumerated()), id: \.offset) { idx, item in
                    insightLine(item)
                        .opacity(idx == insightIndex % max(1, insightItems.count) ? 1 : 0)
                }
            }
            .frame(minHeight: 30)
        }
    }

    private func insightLine(_ item: InsightItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(item.accent)
                .frame(width: 22, height: 22)
                .background(item.accent.opacity(0.14), in: .circle)
            Text(item.text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textTertiary)
        }
    }

    // MARK: - Insight items

    private struct InsightItem: Identifiable {
        let id = UUID()
        let icon: String
        let accent: Color
        let text: String
    }

    private var insightItems: [InsightItem] {
        var items: [InsightItem] = []
        let logged = weekPoints.filter { $0.hours > 0 }

        // Peptide tie-in
        if reading.hours > 0 {
            let h = reading.hours
            let msg: String
            if h >= 7.5 {
                msg = String(format: "GH peaks in deep sleep — your %.1fh last night supports recovery.", h)
            } else if h >= 6 {
                msg = String(format: "Peptides recover best with 7+ hrs — last night was %.1fh.", h)
            } else {
                msg = String(format: "Short night (%.1fh) — peptide-driven recovery may lag today.", h)
            }
            items.append(InsightItem(icon: "pills.fill", accent: PepTheme.violet, text: msg))
        }

        // Sleep debt
        if !logged.isEmpty {
            let total = logged.reduce(0.0) { $0 + $1.hours }
            let target = goalHours * Double(logged.count)
            let debt = total - target
            if debt < -0.5 {
                items.append(InsightItem(
                    icon: "arrow.down.right.circle.fill",
                    accent: PepTheme.coral,
                    text: String(format: "You're %.1fh short this week — aim for %@ tonight.", -debt, formatGoal(goalHours))
                ))
            } else if debt >= -0.5 && logged.count >= 3 {
                items.append(InsightItem(
                    icon: "checkmark.seal.fill",
                    accent: PepTheme.success,
                    text: String(format: "On track — averaging %.1fh vs %@ goal.", total / Double(logged.count), formatGoal(goalHours))
                ))
            }
        }

        // Streak
        let streak = currentStreak()
        if streak >= 2 {
            items.append(InsightItem(
                icon: "flame.fill",
                accent: PepTheme.amber,
                text: "\(streak) nights logged in a row — keep the streak alive."
            ))
        }

        // Training correlation teaser
        if let corr = sleepService.correlation {
            let icon: String
            let accent: Color
            switch corr.severity {
            case .good: icon = "figure.strengthtraining.traditional"; accent = PepTheme.teal
            case .watch: icon = "exclamationmark.circle.fill"; accent = PepTheme.amber
            case .warn: icon = "exclamationmark.triangle.fill"; accent = PepTheme.coral
            }
            items.append(InsightItem(icon: icon, accent: accent, text: corr.insight))
        }

        if items.isEmpty {
            items.append(InsightItem(
                icon: "moon.stars.fill",
                accent: PepTheme.violet,
                text: "Log a few nights to unlock recovery & peptide insights."
            ))
        }
        return items
    }

    private func currentStreak() -> Int {
        // Count consecutive nights from most recent backwards with hours > 0
        let pts = weekPoints.reversed() // newest first
        var count = 0
        for p in pts {
            if p.hours > 0 { count += 1 } else { break }
        }
        return count
    }

    // MARK: - Actions

    private func startSleepWindow() {
        windowStart = Date().timeIntervalSince1970
        now = Date()
    }

    private func cancelSleepWindow() {
        windowStart = 0
    }

    private func saveWakeLog(hours: Double, quality: Int) {
        let start = Date(timeIntervalSince1970: windowStart)
        let log = ManualSleepLog(
            night: Date(),
            bedtime: start,
            wakeTime: Date(),
            hours: hours,
            quality: quality
        )
        sleepVM.save(log)
        windowStart = 0
        showWakeSheet = false
    }

    private func formatGoal(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(v))h"
        }
        return String(format: "%.1fh", v)
    }
}

// MARK: - Night Sky Scene

private struct NightSkyScene: View {
    let moonY: CGFloat // 0 (bottom) -> 1 (top)
    let starDimmed: Bool
    let reduceMotion: Bool

    @State private var pulse: CGFloat = 1.0
    @State private var twinkle: Double = 0

    private let stars: [StarSpec] = (0..<14).map { i in
        let seed = Double(i) * 17.31
        return StarSpec(
            x: CGFloat((seed * 0.61803).truncatingRemainder(dividingBy: 1.0)),
            y: CGFloat((seed * 0.38197).truncatingRemainder(dividingBy: 1.0)) * 0.85,
            size: 1.2 + CGFloat((seed * 0.271).truncatingRemainder(dividingBy: 1.6)),
            phase: (seed * 0.13).truncatingRemainder(dividingBy: 6.28)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Sky gradient
                LinearGradient(
                    colors: [
                        Color(red: 16/255, green: 12/255, blue: 38/255),
                        Color(red: 38/255, green: 22/255, blue: 70/255),
                        Color(red: 68/255, green: 30/255, blue: 90/255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Subtle horizon glow
                RadialGradient(
                    colors: [PepTheme.violet.opacity(0.35), .clear],
                    center: UnitPoint(x: 0.85, y: 1.05),
                    startRadius: 5,
                    endRadius: geo.size.width * 0.9
                )
                .blendMode(.screen)

                // Stars
                ForEach(Array(stars.enumerated()), id: \.offset) { idx, s in
                    let baseOpacity: Double = starDimmed ? 0.18 : 0.55
                    let twinkleAmt: Double = reduceMotion ? 0 : (sin(twinkle + s.phase) * 0.25 + 0.25)
                    Circle()
                        .fill(.white)
                        .frame(width: s.size, height: s.size)
                        .blur(radius: 0.3)
                        .opacity(baseOpacity + twinkleAmt * (starDimmed ? 0.15 : 0.4))
                        .position(x: s.x * geo.size.width, y: s.y * geo.size.height)
                }

                // Moon
                let moonPos = CGPoint(
                    x: geo.size.width * 0.78,
                    y: geo.size.height * (1.0 - max(0.1, min(0.92, moonY))) * 0.95 + geo.size.height * 0.05
                )
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: 36
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: 6)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 250/255, green: 245/255, blue: 235/255),
                                    Color(red: 220/255, green: 210/255, blue: 240/255)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            // crescent shadow
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 30/255, green: 22/255, blue: 60/255).opacity(0.0),
                                                 Color(red: 30/255, green: 22/255, blue: 60/255).opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .offset(x: 12)
                                .mask(Circle().frame(width: 38, height: 38))
                        )
                        .scaleEffect(reduceMotion ? 1 : pulse)
                }
                .position(moonPos)

                // soft cloud line near bottom
                Capsule()
                    .fill(.white.opacity(0.04))
                    .frame(width: geo.size.width * 0.55, height: 6)
                    .blur(radius: 4)
                    .position(x: geo.size.width * 0.3, y: geo.size.height * 0.92)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                pulse = 1.06
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                twinkle = .pi * 2
            }
        }
    }

    private struct StarSpec {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let phase: Double
    }
}

// MARK: - Wake Up sheet (one-tap quality)

private struct WakeUpSheet: View {
    let elapsedHours: Double
    let onSave: (_ quality: Int, _ hours: Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quality: Int = 7
    @State private var hours: Double

    init(elapsedHours: Double, onSave: @escaping (Int, Double) -> Void) {
        self.elapsedHours = elapsedHours
        self.onSave = onSave
        self._hours = State(initialValue: max(3, min(elapsedHours, 14)))
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(PepTheme.amber)
                Text("Good morning")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(String(format: "You slept about %.1fh", hours))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("How did you sleep?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(qualities, id: \.value) { q in
                        Button {
                            quality = q.value
                        } label: {
                            VStack(spacing: 4) {
                                Text(q.emoji).font(.system(size: 26))
                                Text(q.label)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(quality == q.value ? PepTheme.violet : PepTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                quality == q.value ? PepTheme.violet.opacity(0.15) : PepTheme.elevated,
                                in: .rect(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(quality == q.value ? PepTheme.violet.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.scale)
                    }
                }
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Hours slept")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%.1fh", hours))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Slider(value: $hours, in: 3...14, step: 0.25)
                    .tint(PepTheme.violet)
            }
            .padding(.horizontal, 16)

            Spacer()

            Button {
                onSave(quality, hours)
                dismiss()
            } label: {
                Text("Save")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [PepTheme.violet, PepTheme.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: .capsule
                    )
            }
            .buttonStyle(.scale)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .sensoryFeedback(.success, trigger: false)
        }
    }

    private struct QOption {
        let value: Int
        let emoji: String
        let label: String
    }

    private let qualities: [QOption] = [
        .init(value: 2, emoji: "😴", label: "Restless"),
        .init(value: 4, emoji: "😟", label: "Poor"),
        .init(value: 6, emoji: "😐", label: "OK"),
        .init(value: 8, emoji: "🙂", label: "Good"),
        .init(value: 10, emoji: "🤩", label: "Great")
    ]
}
