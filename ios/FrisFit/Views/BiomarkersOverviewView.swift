import SwiftUI
import Charts
import Supabase
import Auth

/// Editorial overview of every tracked biomarker. Reads from
/// `InsightsDataStore.bloodwork` so it works for both real users (HomeView
/// hydrates the store from Supabase) and demo personas (DemoDataInjector
/// hydrates it from the persona bundle).
struct BiomarkersOverviewView: View {
    @State private var store = InsightsDataStore.shared
    @State private var selectedCategory: BiomarkerCategory? = nil
    @State private var userAge: Int? = nil
    @State private var userSex: BiologicalSex? = nil
    @State private var didLoadContext: Bool = false
    @State private var appeared: Bool = false

    private var entries: [BloodworkEntry] {
        store.bloodwork.sorted { $0.date < $1.date }
    }

    private var latestEntry: BloodworkEntry? {
        entries.last
    }

    /// Latest reading per marker across all panels.
    private var latestReadings: [(biomarker: Biomarker, value: Double, date: Date)] {
        var byMarker: [Biomarker: (Double, Date)] = [:]
        for entry in entries {
            for r in entry.results {
                if let existing = byMarker[r.biomarker] {
                    if entry.date > existing.1 {
                        byMarker[r.biomarker] = (r.value, entry.date)
                    }
                } else {
                    byMarker[r.biomarker] = (r.value, entry.date)
                }
            }
        }
        return byMarker
            .map { (biomarker: $0.key, value: $0.value.0, date: $0.value.1) }
            .sorted { lhs, rhs in
                if lhs.biomarker.category != rhs.biomarker.category {
                    let order = BiomarkerCategory.allCases
                    return (order.firstIndex(of: lhs.biomarker.category) ?? 0) <
                           (order.firstIndex(of: rhs.biomarker.category) ?? 0)
                }
                return lhs.biomarker.rawValue < rhs.biomarker.rawValue
            }
    }

    private var filteredReadings: [(biomarker: Biomarker, value: Double, date: Date)] {
        guard let cat = selectedCategory else { return latestReadings }
        return latestReadings.filter { $0.biomarker.category == cat }
    }

    private var visibleCategories: [BiomarkerCategory] {
        let present = Set(latestReadings.map { $0.biomarker.category })
        return BiomarkerCategory.allCases.filter { present.contains($0) }
    }

    private func range(for b: Biomarker) -> PersonalizedRange {
        BloodworkRangeService.range(for: b, age: userAge, sex: userSex)
    }

    private func series(for b: Biomarker) -> [(date: Date, value: Double)] {
        entries.compactMap { e in
            guard let r = e.results.first(where: { $0.biomarker == b }) else { return nil }
            return (e.date, r.value)
        }
    }

    private var flaggedCount: Int {
        latestReadings.filter {
            BloodworkRangeService.status($0.value, range: range(for: $0.biomarker)) != .normal
        }.count
    }

    var body: some View {
        ScrollView {
            if entries.isEmpty {
                emptyState
                    .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    if visibleCategories.count > 1 {
                        categoryStrip
                    }

                    statusRibbon
                        .padding(.horizontal, 20)

                    grid
                        .padding(.horizontal, 16)

                    footer
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                .padding(.bottom, 32)
            }
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    BloodworkTrackingView()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .task {
            if !didLoadContext {
                didLoadContext = true
                await loadUserContext()
            }
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BIOMARKERS".uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))

            Text("Your lab story")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .kerning(-0.6)
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let latest = latestEntry {
                let days = Calendar.current.dateComponents([.day], from: latest.date, to: Date()).day ?? 0
                let markerCount = latestReadings.count
                let panelCount = entries.count
                Text("Last draw · \(daysPhrase(days)) · \(markerCount) marker\(markerCount == 1 ? "" : "s") tracked across \(panelCount) panel\(panelCount == 1 ? "" : "s")")
                    .font(.system(.subheadline))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
            }

            LinearGradient(
                colors: [PepTheme.textPrimary.opacity(0.18), PepTheme.textPrimary.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    private func daysPhrase(_ days: Int) -> String {
        if days <= 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 14 { return "\(days) days ago" }
        if days < 60 { return "\(days / 7) weeks ago" }
        return "\(days / 30) months ago"
    }

    // MARK: - Status ribbon

    private var statusRibbon: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(flaggedCount == 0 ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(flaggedCount == 0 ? "All in range" : "\(flaggedCount) out of range")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (flaggedCount == 0 ? Color.green : Color.orange).opacity(0.10),
                in: .capsule
            )

            // Tiny dot row — one per marker, color = status
            HStack(spacing: 4) {
                ForEach(Array(latestReadings.enumerated()), id: \.offset) { _, item in
                    let s = BloodworkRangeService.status(item.value, range: range(for: item.biomarker))
                    Circle()
                        .fill(statusColor(s).opacity(0.85))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Category chips

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", color: PepTheme.teal, isOn: selectedCategory == nil) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        selectedCategory = nil
                    }
                }
                ForEach(visibleCategories, id: \.self) { cat in
                    chip(label: cat.rawValue, color: cat.color, isOn: selectedCategory == cat) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 20)
    }

    private func chip(label: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(isOn ? PepTheme.invertedText : PepTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isOn ? color : PepTheme.elevated, in: .capsule)
                .overlay(
                    Capsule().strokeBorder(
                        isOn ? Color.clear : PepTheme.separatorColor.opacity(0.8),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(Array(filteredReadings.enumerated()), id: \.element.biomarker) { index, item in
                NavigationLink {
                    BiomarkerDetailView(
                        biomarker: item.biomarker,
                        entries: entries,
                        personalizedRange: range(for: item.biomarker)
                    )
                } label: {
                    BiomarkerTile(
                        biomarker: item.biomarker,
                        value: item.value,
                        latestDate: item.date,
                        history: series(for: item.biomarker),
                        range: range(for: item.biomarker)
                    )
                }
                .buttonStyle(BiomarkerTilePressStyle())
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.45).delay(Double(index) * 0.025), value: appeared)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            LinearGradient(
                colors: [PepTheme.textPrimary.opacity(0.12), PepTheme.textPrimary.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)

            HStack {
                Text("All panels are logged in Bloodwork Tracking.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                NavigationLink {
                    BloodworkTrackingView()
                } label: {
                    HStack(spacing: 4) {
                        Text("Log a panel")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("BIOMARKERS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
            Text("Your lab story\nstarts with one panel.")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .kerning(-0.4)
                .multilineTextAlignment(.center)
                .foregroundStyle(PepTheme.textPrimary)
            Text("Upload a lab report or enter values by hand. Trends, status, and personalized ranges appear here as soon as you log them.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            NavigationLink {
                BloodworkTrackingView()
            } label: {
                Text("Add lab results")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(PepTheme.teal, in: .capsule)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func statusColor(_ s: BiomarkerStatus) -> Color {
        switch s {
        case .normal: return .green
        case .high: return .red
        case .low: return PepTheme.blue
        }
    }

    private func loadUserContext() async {
        guard let session = try? await SupabaseService.shared.client.auth.session else { return }
        let userId = session.user.id.uuidString.lowercased()
        if let profile = try? await ProfileService.shared.fetchProfile(userId: userId) {
            if let sexStr = profile.biological_sex {
                userSex = BiologicalSex(rawValue: sexStr)
            }
            if let dobStr = profile.date_of_birth {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                if let dob = f.date(from: dobStr) {
                    userAge = Calendar.current.dateComponents([.year], from: dob, to: Date()).year
                }
            }
        }
    }
}

// MARK: - Tile

private struct BiomarkerTile: View {
    let biomarker: Biomarker
    let value: Double
    let latestDate: Date
    let history: [(date: Date, value: Double)]
    let range: PersonalizedRange

    private var status: BiomarkerStatus {
        BloodworkRangeService.status(value, range: range)
    }

    private var statusTint: Color {
        switch status {
        case .normal: return .green
        case .high: return .red
        case .low: return PepTheme.blue
        }
    }

    private var deltaText: String? {
        let sorted = history.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return nil }
        let prev = sorted[sorted.count - 2].value
        let diff = value - prev
        if abs(diff) < 0.05 { return "→ flat" }
        let arrow = diff > 0 ? "↑" : "↓"
        return "\(arrow) \(formatValue(abs(diff))) vs last"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent strip
            Rectangle()
                .fill(biomarker.category.color.opacity(0.85))
                .frame(height: 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(biomarker.rawValue)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    statusDot
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(value))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(biomarker.unit)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                        .padding(.leading, 1)
                }

                sparkline
                    .frame(height: 28)

                HStack(spacing: 4) {
                    Text(biomarker.category.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(biomarker.category.color.opacity(0.9))
                    Spacer(minLength: 0)
                    if let deltaText {
                        Text(deltaText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            ZStack {
                PepTheme.cardSurface
                biomarker.category.color.opacity(0.04)
            }
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.separatorColor.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: PepTheme.shadowColor.opacity(0.6), radius: 10, x: 0, y: 5)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusTint)
            .frame(width: 6, height: 6)
            .overlay(
                Circle().stroke(statusTint.opacity(0.4), lineWidth: 3).blur(radius: 2)
            )
    }

    @ViewBuilder
    private var sparkline: some View {
        let sorted = history.sorted { $0.date < $1.date }
        if sorted.count >= 2 {
            Chart {
                // Reference band — softly tinted normal zone
                RectangleMark(
                    yStart: .value("Low", range.low),
                    yEnd: .value("High", range.high)
                )
                .foregroundStyle(Color.green.opacity(0.08))

                ForEach(Array(sorted.enumerated()), id: \.offset) { _, pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("Value", pt.value)
                    )
                    .foregroundStyle(biomarker.category.color)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
                if let last = sorted.last {
                    PointMark(
                        x: .value("Date", last.date),
                        y: .value("Value", last.value)
                    )
                    .foregroundStyle(statusTint)
                    .symbolSize(28)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: yDomain(sorted: sorted))
            .chartPlotStyle { $0.background(Color.clear) }
        } else {
            HStack(spacing: 3) {
                ForEach(0..<14, id: \.self) { _ in
                    Capsule()
                        .fill(PepTheme.textSecondary.opacity(0.15))
                        .frame(width: 2, height: CGFloat.random(in: 4...18))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func yDomain(sorted: [(date: Date, value: Double)]) -> ClosedRange<Double> {
        let vals = sorted.map { $0.value }
        let lo = min(vals.min() ?? range.low, range.low) * 0.95
        let hi = max(vals.max() ?? range.high, range.high) * 1.05
        return lo...hi
    }

    private func formatValue(_ v: Double) -> String {
        if v >= 100 || v.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.1f", v)
    }
}

private struct BiomarkerTilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}
