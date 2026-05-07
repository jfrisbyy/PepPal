import SwiftUI
import Charts

struct SleepRecoveryView: View {
    @State private var service = SleepRecoveryService.shared
    @State private var sleepVM = SleepLogViewModel.shared
    @State private var hasRequested: Bool = false
    @State private var showLogSheet: Bool = false
    @State private var editingLog: ManualSleepLog? = nil
    @State private var range: TimeRange = .week
    @State private var insightIndex: Int = 0
    @AppStorage("sleep.goal.hours") private var goalHours: Double = 8.0
    @Environment(\.dismiss) private var dismiss

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "7D"
        case fortnight = "14D"
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 14 }
    }

    private var hasAnyData: Bool {
        !service.recentNights.isEmpty || !sleepVM.manualByNight.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if service.isLoading && !hasAnyData {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if !hasAnyData {
                    emptyState
                } else {
                    heroCard
                    insightsCard
                    trendsCard
                    if let correlation = service.correlation {
                        correlationCard(correlation)
                    }
                    suggestionsCard
                    stagesCard
                    if !service.recoveryReadings.isEmpty {
                        recoveryCard
                    }
                    manualEntriesCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 52)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .floatingTopBar {
            FloatingNavButton(systemImage: "chevron.left") { dismiss() }
        } trailing: {
            FloatingNavButton(systemImage: "plus", action: {
                editingLog = nil
                showLogSheet = true
            }, tint: PepTheme.violet)
        }
        .sheet(isPresented: $showLogSheet) {
            LogSleepSheet(existing: editingLog)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task {
            if !hasRequested {
                hasRequested = true
                _ = await service.authorize()
                await service.loadRecent()
            } else {
                await service.loadRecent()
            }
            await sleepVM.loadIfNeeded()
        }
        .refreshable {
            await service.loadRecent()
            await sleepVM.load()
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SLEEP & RECOVERY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.violet.opacity(0.9))
                Spacer()
                Text(rangeSubtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(headlineForAvg)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(editorialSubline)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LinearGradient(
                colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.5)

            HStack(spacing: 0) {
                heroStat(value: String(format: "%.1f", service.averageSleep7d), unit: "h", label: "7D AVG")
                statDivider
                heroStat(value: hrvDisplay, unit: hrvUnit, label: "HRV")
                statDivider
                heroStat(value: rhrDisplay, unit: rhrUnit, label: "RESTING HR")
            }
        }
        .padding(18)
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
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 30)
    }

    private func heroStat(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var headlineForAvg: String {
        let avg = service.averageSleep7d
        if avg <= 0 { return "Building your sleep story." }
        let h = Int(avg)
        let m = Int((avg - Double(h)) * 60)
        let timeStr = m > 0 ? "\(h)h \(m)m" : "\(h)h"
        if avg >= goalHours { return "\(timeStr) — on rhythm." }
        if avg >= goalHours - 0.75 { return "\(timeStr) — close to your goal." }
        return "\(timeStr) — running a deficit."
    }

    private var editorialSubline: String {
        let avg = service.averageSleep7d
        if avg <= 0 { return "Log a few nights to surface trends, debt, and recovery insights." }
        let goalDelta = avg - goalHours
        if goalDelta >= 0 { return "Above your \(formatGoal(goalHours)) goal — keep the routine consistent." }
        return String(format: "%.1fh below your %@ target — bank an early night this week.", -goalDelta, formatGoal(goalHours))
    }

    private var rangeSubtitle: String { "TRAILING 7 NIGHTS" }

    private var hrvDisplay: String {
        guard let h = service.averageHRV7d else { return "—" }
        return "\(Int(h))"
    }
    private var hrvUnit: String { service.averageHRV7d == nil ? "" : "ms" }

    private var rhrDisplay: String {
        guard let r = service.recoveryReadings.compactMap(\.restingHR).first else { return "—" }
        return "\(Int(r))"
    }
    private var rhrUnit: String { service.recoveryReadings.compactMap(\.restingHR).first == nil ? "" : "bpm" }

    private func streakNights() -> Int {
        let cal = Calendar.current
        var count = 0
        var day = cal.startOfDay(for: Date())
        let nightsByDay = Dictionary(uniqueKeysWithValues: service.recentNights.map { (cal.startOfDay(for: $0.date), $0.totalHours) })
        for _ in 0..<14 {
            let manual = sleepVM.manualByNight[Self.nightKey(for: day)]?.hours ?? 0
            let hk = nightsByDay[day] ?? 0
            if max(manual, hk) > 0 { count += 1 } else { break }
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    private static func nightKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Insights (rotating)

    private var insightsCard: some View {
        let items = insightItems
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PepTheme.violet)
                Text("INSIGHTS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if items.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<items.count, id: \.self) { i in
                            Circle()
                                .fill(i == insightIndex % items.count ? PepTheme.violet : PepTheme.textTertiary.opacity(0.3))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }

            ZStack(alignment: .leading) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    insightLine(item)
                        .opacity(idx == insightIndex % max(1, items.count) ? 1 : 0)
                }
            }
            .frame(minHeight: 64)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.35)) {
                insightIndex = (insightIndex + 1) % max(1, items.count)
            }
        }
        .task(id: hasAnyData) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                withAnimation(.easeInOut(duration: 0.45)) {
                    insightIndex = (insightIndex + 1) % max(1, insightItems.count)
                }
            }
        }
    }

    private func insightLine(_ item: InsightItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.accent)
                .frame(width: 30, height: 30)
                .background(item.accent.opacity(0.14), in: .circle)
                .overlay(Circle().strokeBorder(item.accent.opacity(0.3), lineWidth: 0.6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(item.body)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private struct InsightItem: Identifiable {
        let id = UUID()
        let icon: String
        let accent: Color
        let title: String
        let body: String
    }

    private var insightItems: [InsightItem] {
        var items: [InsightItem] = []
        let nights = service.recentNights.prefix(7)
        let totalHours = nights.reduce(0.0) { $0 + $1.totalHours }
        let avg = service.averageSleep7d

        // Last night vs avg
        if let last = service.recentNights.first {
            let delta = last.totalHours - avg
            if avg > 0 {
                if delta >= 0.5 {
                    items.append(.init(
                        icon: "arrow.up.right.circle.fill",
                        accent: PepTheme.success,
                        title: String(format: "%.1fh above your average", delta),
                        body: "Last night ran longer than your 7-day mean. Expect sharper cognition today."
                    ))
                } else if delta <= -0.75 {
                    items.append(.init(
                        icon: "arrow.down.right.circle.fill",
                        accent: PepTheme.coral,
                        title: String(format: "%.1fh under your average", -delta),
                        body: "Short night. Front-load hydration and consider lighter cognitive load this morning."
                    ))
                }
            }
        }

        // Deep sleep ratio
        if let last = service.recentNights.first, last.totalHours > 0 {
            let deepRatio = last.deepHours / last.totalHours
            if deepRatio >= 0.18 {
                items.append(.init(
                    icon: "waveform.path.ecg",
                    accent: PepTheme.violet,
                    title: "Deep sleep was strong",
                    body: String(format: "%.0f%% in deep — growth peptides peak here. Recovery window earned.", deepRatio * 100)
                ))
            } else if deepRatio < 0.10 && last.totalHours >= 5 {
                items.append(.init(
                    icon: "exclamationmark.circle.fill",
                    accent: PepTheme.amber,
                    title: "Light on deep sleep",
                    body: String(format: "Only %.0f%% in deep. Cooler room, no late alcohol, and earlier dinner help.", deepRatio * 100)
                ))
            }
        }

        // Consistency
        if nights.count >= 5 {
            let mean = totalHours / Double(nights.count)
            let variance = nights.reduce(0.0) { $0 + pow($1.totalHours - mean, 2) } / Double(nights.count)
            let stdev = sqrt(variance)
            if stdev <= 0.6 {
                items.append(.init(
                    icon: "checkmark.seal.fill",
                    accent: PepTheme.teal,
                    title: "Rhythm is locked in",
                    body: String(format: "Variance under %.1fh — consistent timing is one of the highest-leverage recovery levers.", stdev)
                ))
            } else if stdev > 1.2 {
                items.append(.init(
                    icon: "waveform",
                    accent: PepTheme.amber,
                    title: "Sleep timing is volatile",
                    body: String(format: "Nights swing by %.1fh on average — anchor a fixed wake time for two weeks.", stdev)
                ))
            }
        }

        // Debt
        let logged = nights.filter { $0.totalHours > 0 }
        if !logged.isEmpty {
            let target = goalHours * Double(logged.count)
            let debt = totalHours - target
            if debt < -1.5 {
                items.append(.init(
                    icon: "arrow.down.right.circle.fill",
                    accent: PepTheme.coral,
                    title: String(format: "%.1fh debt this week", -debt),
                    body: "Recovery, mood, and lift performance trail when debt compounds. Bank an early night."
                ))
            } else if debt >= -0.5 && logged.count >= 4 {
                items.append(.init(
                    icon: "checkmark.seal.fill",
                    accent: PepTheme.success,
                    title: "On pace with your goal",
                    body: String(format: "Averaging %.1fh against a %@ target. Hold the line.", totalHours / Double(logged.count), formatGoal(goalHours))
                ))
            }
        }

        // HRV trend
        if let avgHrv = service.averageHRV7d {
            if avgHrv < 30 {
                items.append(.init(
                    icon: "heart.text.square.fill",
                    accent: PepTheme.coral,
                    title: "HRV is trending low",
                    body: String(format: "%.0fms avg suggests autonomic strain. Lighter session or extra sleep tonight.", avgHrv)
                ))
            } else if avgHrv >= 60 {
                items.append(.init(
                    icon: "bolt.heart.fill",
                    accent: PepTheme.success,
                    title: "HRV is thriving",
                    body: String(format: "%.0fms avg — a green light for harder training blocks.", avgHrv)
                ))
            }
        }

        if items.isEmpty {
            items.append(.init(
                icon: "moon.stars.fill",
                accent: PepTheme.violet,
                title: "Building your story",
                body: "A few more nights and we'll surface deep-sleep, debt, and recovery patterns tailored to you."
            ))
        }
        return items
    }

    // MARK: - Trends chart

    private var trendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRENDS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("Hours per night")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(TimeRange.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            Chart {
                ForEach(chartNights) { night in
                    BarMark(
                        x: .value("Date", night.date, unit: .day),
                        y: .value("Hours", night.totalHours)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: night.totalHours >= goalHours
                                ? [PepTheme.success, PepTheme.teal.opacity(0.6)]
                                : [PepTheme.violet, PepTheme.violet.opacity(0.5)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Goal", goalHours))
                    .foregroundStyle(PepTheme.amber.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text("Goal \(formatGoal(goalHours))")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PepTheme.amber)
                    }
            }
            .frame(height: 170)
            .chartYScale(domain: 0...max(10, goalHours + 1.5))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 2)) { value in
                    AxisValueLabel(format: .dateTime.day(.defaultDigits), centered: true)
                        .foregroundStyle(PepTheme.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, Int(goalHours), 10]) {
                    AxisValueLabel().foregroundStyle(PepTheme.textTertiary)
                    AxisGridLine().foregroundStyle(PepTheme.shimmerHighlight)
                }
            }

            HStack(spacing: 14) {
                miniLegend(color: PepTheme.violet, label: "Below goal")
                miniLegend(color: PepTheme.success, label: "At or above")
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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

    private var chartNights: [SleepNight] {
        Array(service.recentNights.prefix(range.days).reversed())
    }

    private func miniLegend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    // MARK: - Suggestions

    private var suggestionsCard: some View {
        let suggestions = computedSuggestions
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PepTheme.amber)
                Text("SUGGESTIONS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, s in
                    suggestionRow(s)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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

    private func suggestionRow(_ s: Suggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(s.numeral)
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundStyle(s.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(s.body)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private struct Suggestion {
        let numeral: String
        let accent: Color
        let title: String
        let body: String
    }

    private var computedSuggestions: [Suggestion] {
        var out: [Suggestion] = []
        let avg = service.averageSleep7d
        let last = service.recentNights.first

        if avg > 0 && avg < goalHours - 0.5 {
            let delta = goalHours - avg
            out.append(.init(
                numeral: "I",
                accent: PepTheme.violet,
                title: "Move bedtime \(Int(delta * 60)) min earlier",
                body: "Closing the gap to your \(formatGoal(goalHours)) target compounds across recovery, mood, and training output."
            ))
        }
        if let last, last.totalHours > 0 {
            let deepRatio = last.deepHours / last.totalHours
            if deepRatio < 0.13 {
                out.append(.init(
                    numeral: "II",
                    accent: PepTheme.teal,
                    title: "Cool the room to 65°F",
                    body: "Deep sleep doubles in cooler ambient temperatures. Skip late alcohol and caffeine after 2pm."
                ))
            }
        }
        if let avgHrv = service.averageHRV7d, avgHrv < 35 {
            out.append(.init(
                numeral: out.count == 0 ? "I" : romanNumeral(out.count + 1),
                accent: PepTheme.coral,
                title: "Pull back training intensity",
                body: "HRV under 35ms signals autonomic strain. A deload day or zone-2 session lets the nervous system reset."
            ))
        }
        // Consistency
        let nights = service.recentNights.prefix(7)
        if nights.count >= 4 {
            let mean = nights.reduce(0.0) { $0 + $1.totalHours } / Double(nights.count)
            let stdev = sqrt(nights.reduce(0.0) { $0 + pow($1.totalHours - mean, 2) } / Double(nights.count))
            if stdev > 1.0 {
                out.append(.init(
                    numeral: romanNumeral(out.count + 1),
                    accent: PepTheme.amber,
                    title: "Anchor a fixed wake time",
                    body: "Same wake every day — even weekends — is the single most studied lever for sleep architecture."
                ))
            }
        }
        if out.isEmpty {
            out.append(.init(
                numeral: "I",
                accent: PepTheme.success,
                title: "Hold the routine",
                body: "Your numbers are clean. Protect bedtime, sun in the morning, and screens off in the final hour."
            ))
        }
        return Array(out.prefix(3))
    }

    private func romanNumeral(_ n: Int) -> String {
        switch n {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        case 4: return "IV"
        default: return "\(n)"
        }
    }

    // MARK: - Stages

    private var stagesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ARCHITECTURE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("Last night's stages")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Spacer()
            }

            if let last = service.recentNights.first {
                stageBar(last)
                VStack(spacing: 8) {
                    stageRow("Deep", hours: last.deepHours, total: last.totalHours, color: PepTheme.violet, hint: "Physical recovery")
                    stageRow("REM", hours: last.remHours, total: last.totalHours, color: PepTheme.blue, hint: "Memory & mood")
                    stageRow("Core", hours: last.coreHours, total: last.totalHours, color: PepTheme.teal, hint: "Light sleep")
                    if last.awakeHours > 0 {
                        stageRow("Awake", hours: last.awakeHours, total: last.totalHours, color: PepTheme.amber, hint: "Brief wake-ups")
                    }
                }
            } else {
                Text("Stage data appears once Apple Health syncs a tracked night.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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

    private func stageBar(_ night: SleepNight) -> some View {
        let total = max(0.0001, night.deepHours + night.remHours + night.coreHours + night.awakeHours)
        return GeometryReader { geo in
            HStack(spacing: 1) {
                stageSegment(width: geo.size.width * (night.deepHours / total), color: PepTheme.violet)
                stageSegment(width: geo.size.width * (night.remHours / total), color: PepTheme.blue)
                stageSegment(width: geo.size.width * (night.coreHours / total), color: PepTheme.teal)
                stageSegment(width: geo.size.width * (night.awakeHours / total), color: PepTheme.amber)
            }
            .clipShape(.rect(cornerRadius: 4))
        }
        .frame(height: 10)
    }

    private func stageSegment(width: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            .frame(width: max(0, width))
    }

    private func stageRow(_ label: String, hours: Double, total: Double, color: Color, hint: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textTertiary)
            }
            Spacer()
            Text(formatHours(hours))
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(color)
            if total > 0 {
                Text(String(format: "%.0f%%", (hours / total) * 100))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textTertiary)
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    // MARK: - Recovery / HRV

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AUTONOMIC")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("HRV trend")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Spacer()
                if let avgHrv = service.averageHRV7d {
                    Text("\(Int(avgHrv))ms avg")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PepTheme.teal.opacity(0.12), in: .capsule)
                }
            }

            Chart {
                ForEach(service.recoveryReadings.prefix(14).reversed()) { reading in
                    if let hrv = reading.hrv {
                        AreaMark(
                            x: .value("Date", reading.date, unit: .day),
                            y: .value("HRV", hrv)
                        )
                        .foregroundStyle(LinearGradient(colors: [PepTheme.teal.opacity(0.3), PepTheme.teal.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                        LineMark(
                            x: .value("Date", reading.date, unit: .day),
                            y: .value("HRV", hrv)
                        )
                        .foregroundStyle(PepTheme.teal)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .frame(height: 130)
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisValueLabel().foregroundStyle(PepTheme.textTertiary)
                    AxisGridLine().foregroundStyle(PepTheme.shimmerHighlight)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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

    // MARK: - Manual entries

    private var manualEntriesCard: some View {
        let logs = sleepVM.recentManualLogs.prefix(7)
        return Group {
            if !logs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("YOUR JOURNAL")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2.0)
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Text("\(logs.count) NIGHT\(logs.count == 1 ? "" : "S")")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(PepTheme.textTertiary)
                    }
                    VStack(spacing: 8) {
                        ForEach(Array(logs)) { log in
                            manualLogRow(log)
                        }
                    }
                }
                .padding(16)
                .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
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

    private func manualLogRow(_ log: ManualSleepLog) -> some View {
        Button {
            editingLog = log
            showLogSheet = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatNight(log.night))
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    if let q = log.qualityLabel, let n = log.quality {
                        Text("\(q) · \(n)/10")
                            .font(.system(size: 11, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    } else {
                        Text("Manual entry")
                            .font(.system(size: 11, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                Spacer()
                Text(formatHours(log.hours))
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.violet)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textTertiary)
            }
            .padding(12)
            .background(PepTheme.elevated.opacity(0.5))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                sleepVM.remove(log)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatNight(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Last night" }
        if cal.isDateInYesterday(date) { return "Two nights ago" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SLEEP & RECOVERY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.violet)
                Text("Your night, in print.")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Connect Apple Health for automatic syncing, or log a night yourself to begin building your sleep story — trends, debt, recovery, and a stage-by-stage breakdown of how you actually rest.")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                emptyFeatureRow(icon: "chart.bar.fill", title: "Trends", body: "7- and 14-night charts with goal benchmarks.")
                emptyFeatureRow(icon: "sparkles", title: "Insights", body: "Deep-sleep ratio, debt, HRV, training overlap.")
                emptyFeatureRow(icon: "lightbulb.fill", title: "Suggestions", body: "Personal levers — bedtime shift, room temp, training load.")
            }

            Button {
                editingLog = nil
                showLogSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Log a night")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(colors: [PepTheme.violet, PepTheme.blue], startPoint: .leading, endPoint: .trailing),
                    in: .capsule
                )
            }
            .buttonStyle(.scale)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    private func emptyFeatureRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.violet)
                .frame(width: 28, height: 28)
                .background(PepTheme.violet.opacity(0.14), in: .circle)
                .overlay(Circle().strokeBorder(PepTheme.violet.opacity(0.3), lineWidth: 0.6))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(body)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Correlation card

    private func correlationCard(_ c: TrainingSleepCorrelation) -> some View {
        let color: Color = {
            switch c.severity {
            case .good: return PepTheme.success
            case .watch: return PepTheme.amber
            case .warn: return PepTheme.coral
            }
        }()
        let icon: String = {
            switch c.severity {
            case .good: return "checkmark.seal.fill"
            case .watch: return "exclamationmark.circle.fill"
            case .warn: return "exclamationmark.triangle.fill"
            }
        }()
        let label: String = {
            switch c.severity {
            case .good: return "BALANCED"
            case .watch: return "MONITOR"
            case .warn: return "ELEVATED RISK"
            }
        }()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(color)
                Spacer()
                Text("TRAINING × SLEEP")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textTertiary)
            }

            HStack(spacing: 0) {
                miniStat(value: "\(c.weeklySessions)", label: "SESSIONS")
                statDivider
                miniStat(value: formatVolume(c.weeklyVolume), label: "VOLUME")
                statDivider
                miniStat(value: String(format: "%.1fh", c.averageSleepHours), label: "AVG SLEEP")
            }

            Text(c.insight)
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(color.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.35), lineWidth: 0.6)
        )
        .clipShape(.rect(cornerRadius: 14))
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVolume(_ v: Int) -> String {
        if v >= 1000 { return String(format: "%.1fk", Double(v) / 1000.0) }
        return "\(v)"
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func formatGoal(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(v))h" }
        return String(format: "%.1fh", v)
    }
}
