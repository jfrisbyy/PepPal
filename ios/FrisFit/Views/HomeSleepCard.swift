import SwiftUI

struct HomeSleepCard: View {
    let healthKit: HealthKitService

    @State private var sleepVM = SleepLogViewModel.shared
    @State private var sleepService = SleepRecoveryService.shared
    @State private var showLogSheet: Bool = false
    @State private var showDetail: Bool = false

    private var reading: SleepLogViewModel.LastNightReading {
        sleepVM.lastNightReading(healthHours: healthKit.sleepHours)
    }

    private var weekPoints: [SleepLogViewModel.NightPoint] {
        // Build map from HealthKit recent nights (capped at last 7)
        var hkMap: [Date: Double] = [:]
        let cal = Calendar.current
        for n in sleepService.recentNights {
            hkMap[cal.startOfDay(for: n.date)] = n.totalHours
        }
        return sleepVM.recent7Nights(healthByDate: hkMap)
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
        .task {
            await sleepVM.loadIfNeeded()
            if sleepService.recentNights.isEmpty {
                await sleepService.loadRecent(days: 7)
            }
        }
    }

    // MARK: - Card

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if reading.source == .none {
                emptyState
            } else {
                hoursRow
                miniBarChart
                footerRow
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

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.violet)
                Text("Sleep")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            Button {
                showLogSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Log")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(PepTheme.violet)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PepTheme.violet.opacity(0.14))
                .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: showLogSheet)
        }
    }

    private var hoursRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(hoursWhole)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(hoursMinutes)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("h")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.leading, 2)
            }

            if let quality = reading.quality {
                qualityChip(quality)
            }

            Spacer()
        }
    }

    private var hoursWhole: String {
        let h = Int(reading.hours)
        return "\(h)"
    }

    private var hoursMinutes: String {
        let mins = Int((reading.hours - Double(Int(reading.hours))) * 60)
        if mins == 0 { return "" }
        return String(format: ":%02d", mins)
    }

    private func qualityChip(_ quality: Int) -> some View {
        let label: String
        let color: Color
        switch quality {
        case ...3: label = "Restless"; color = .red
        case 4...5: label = "Poor"; color = PepTheme.amber
        case 6...7: label = "OK"; color = PepTheme.teal
        case 8: label = "Good"; color = PepTheme.teal
        default: label = "Excellent"; color = .green
        }
        return HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text("\(label) · \(quality)/10")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.14))
        .clipShape(.capsule)
    }

    private var miniBarChart: some View {
        GeometryReader { geo in
            let points = weekPoints
            let maxHours: Double = max(8.0, points.map(\.hours).max() ?? 8)
            let barWidth = (geo.size.width - 6 * 6) / 7
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(points) { p in
                    let isLast = p.id == points.last?.id
                    let ratio = maxHours > 0 ? p.hours / maxHours : 0
                    let height = max(4, geo.size.height * ratio)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: barColors(isLast: isLast, isManual: p.isManual, hasValue: p.hours > 0),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: height)
                        .opacity(p.hours > 0 ? 1 : 0.35)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 36)
    }

    private func barColors(isLast: Bool, isManual: Bool, hasValue: Bool) -> [Color] {
        if !hasValue { return [PepTheme.elevated, PepTheme.elevated] }
        if isLast {
            return [PepTheme.violet, PepTheme.violet.opacity(0.6)]
        }
        let base = isManual ? PepTheme.teal : PepTheme.violet
        return [base.opacity(0.55), base.opacity(0.25)]
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            sourceBadge
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        switch reading.source {
        case .appleHealth:
            HStack(spacing: 4) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Apple Health")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(PepTheme.textSecondary)
        case .manual:
            HStack(spacing: 4) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 10, weight: .semibold))
                Text("Logged")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(PepTheme.textSecondary)
        case .none:
            EmptyView()
        }
    }

    private var emptyState: some View {
        Button {
            showLogSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(PepTheme.violet)
                    .frame(width: 36, height: 36)
                    .background(PepTheme.violet.opacity(0.14))
                    .clipShape(.circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Log last night's sleep")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Hours, quality, and notes")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(PepTheme.violet)
            }
            .padding(12)
            .background(PepTheme.violet.opacity(0.06))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(PepTheme.violet.opacity(0.2), lineWidth: 0.6)
            )
        }
        .buttonStyle(.scale)
    }
}
