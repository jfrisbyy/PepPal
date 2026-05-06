import SwiftUI
import Charts

struct SleepRecoveryView: View {
    @State private var service = SleepRecoveryService.shared
    @State private var sleepVM = SleepLogViewModel.shared
    @State private var hasRequested: Bool = false
    @State private var showLogSheet: Bool = false
    @State private var editingLog: ManualSleepLog? = nil

    private var hasAnyData: Bool {
        !service.recentNights.isEmpty || !sleepVM.manualByNight.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if service.isLoading && !hasAnyData {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if !hasAnyData {
                    emptyState
                } else {
                    summary
                    if let correlation = service.correlation {
                        correlationCard(correlation)
                    }
                    sleepChart
                    stagesBreakdown
                    manualEntriesCard
                    if !service.recoveryReadings.isEmpty {
                        recoveryCard
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Sleep & Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingLog = nil
                    showLogSheet = true
                } label: {
                    Label("Log", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                }
            }
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

    private var manualEntriesCard: some View {
        let logs = sleepVM.recentManualLogs.prefix(7)
        return Group {
            if !logs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Your Logged Nights")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text("\(logs.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PepTheme.elevated)
                            .clipShape(.capsule)
                    }

                    VStack(spacing: 8) {
                        ForEach(Array(logs)) { log in
                            manualLogRow(log)
                        }
                    }
                }
                .padding(14)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 12))
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if let q = log.qualityLabel, let n = log.quality {
                        Text("\(q) · \(n)/10")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    } else {
                        Text("Manual entry")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                Spacer()
                Text(formatHours(log.hours))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.violet)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
            }
            .padding(10)
            .background(PepTheme.elevated.opacity(0.6))
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
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 44))
                .foregroundStyle(PepTheme.violet.opacity(0.7))
            Text("No Sleep Data Yet")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Connect Apple Health for automatic syncing, or log a night yourself to start your sleep history.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
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
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: [PepTheme.violet, PepTheme.violet.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(.capsule)
            }
            .buttonStyle(.scale)
            .padding(.top, 4)
        }
        .padding(.top, 50)
    }

    private var summary: some View {
        HStack(spacing: 10) {
            stat(value: String(format: "%.1fh", service.averageSleep7d), label: "7d Avg Sleep", color: PepTheme.violet)
            if let hrv = service.averageHRV7d {
                stat(value: String(format: "%.0fms", hrv), label: "7d Avg HRV", color: PepTheme.teal)
            }
            if let lastRhr = service.recoveryReadings.compactMap(\.restingHR).first {
                stat(value: "\(Int(lastRhr))", label: "Resting HR", color: PepTheme.blue)
            }
        }
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var sleepChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep Hours")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Chart {
                ForEach(service.recentNights.prefix(14).reversed()) { night in
                    BarMark(
                        x: .value("Date", night.date, unit: .day),
                        y: .value("Hours", night.totalHours)
                    )
                    .foregroundStyle(LinearGradient(colors: [PepTheme.violet, PepTheme.violet.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Goal", 8))
                    .foregroundStyle(PepTheme.teal.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 160)
            .chartYScale(domain: 0...10)
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var stagesBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last Night Stages")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            if let last = service.recentNights.first {
                VStack(spacing: 6) {
                    stageRow("Deep", hours: last.deepHours, color: PepTheme.violet)
                    stageRow("REM", hours: last.remHours, color: PepTheme.blue)
                    stageRow("Core", hours: last.coreHours, color: PepTheme.teal)
                    if last.awakeHours > 0 {
                        stageRow("Awake", hours: last.awakeHours, color: PepTheme.amber)
                    }
                }
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func stageRow(_ label: String, hours: Double, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Text(formatHours(hours))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HRV Trend")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Chart {
                ForEach(service.recoveryReadings.prefix(14).reversed()) { reading in
                    if let hrv = reading.hrv {
                        LineMark(
                            x: .value("Date", reading.date, unit: .day),
                            y: .value("HRV", hrv)
                        )
                        .foregroundStyle(PepTheme.teal)
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Date", reading.date, unit: .day),
                            y: .value("HRV", hrv)
                        )
                        .foregroundStyle(PepTheme.teal)
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func correlationCard(_ c: TrainingSleepCorrelation) -> some View {
        let color: Color = {
            switch c.severity {
            case .good: return .green
            case .watch: return PepTheme.amber
            case .warn: return .red
            }
        }()
        let icon: String = {
            switch c.severity {
            case .good: return "checkmark.seal.fill"
            case .watch: return "exclamationmark.circle.fill"
            case .warn: return "exclamationmark.triangle.fill"
            }
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                Text("Training vs Recovery")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }
            HStack(spacing: 12) {
                miniStat(value: "\(c.weeklySessions)", label: "Sessions / 7d")
                miniStat(value: formatVolume(c.weeklyVolume), label: "Volume")
                miniStat(value: String(format: "%.1fh", c.averageSleepHours), label: "Avg Sleep")
            }
            Text(c.insight)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 12))
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 8))
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
}
