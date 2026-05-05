import SwiftUI

/// Zoom level + pan state for the Journey Map. Drives a continuous
/// pixels-per-day value that lane renderers consume. Zoom-level buttons,
/// pinch-to-zoom, and pan-with-momentum all funnel through this single store
/// so the map stays a single source of truth.
@Observable
final class JourneyZoomState {
    enum Level: Int, CaseIterable, Identifiable {
        case month, sixMonths, year, allTime
        var id: Int { rawValue }
        var pixelsPerDay: CGFloat {
            switch self {
            case .month: return 28
            case .sixMonths: return 8
            case .year: return 4
            case .allTime: return 1.4
            }
        }
        var label: String {
            switch self {
            case .month: return "1M"
            case .sixMonths: return "6M"
            case .year: return "1Y"
            case .allTime: return "All"
            }
        }
        var months: Int {
            switch self {
            case .month: return 1
            case .sixMonths: return 6
            case .year: return 12
            case .allTime: return 60
            }
        }
    }

    /// Continuous, gesture-driven pixels-per-day. Snaps to a level only when
    /// the user taps a level button.
    var pixelsPerDay: CGFloat = Level.sixMonths.pixelsPerDay

    /// Pan offset in points from the timeline origin (rangeStart at x=0).
    /// Lane content is offset by `-panOffset * parallaxFactor`.
    var panOffset: CGFloat = 0

    /// True while the user is actively dragging or pinching. Drives the
    /// floating date indicator opacity.
    var isInteracting: Bool = false
    /// Last time the user finished interacting — used to fade the indicator
    /// 1.5s after release.
    var lastInteractionEnd: Date = .distantPast

    // Pinch state
    private var pinchStartPpd: CGFloat?
    private var pinchAnchorX: CGFloat?

    // Drag state
    private var dragStartOffset: CGFloat?

    /// Closest discrete level for the level pill UI.
    var nearestLevel: Level {
        Level.allCases.min { abs($0.pixelsPerDay - pixelsPerDay) < abs($1.pixelsPerDay - pixelsPerDay) } ?? .sixMonths
    }

    // MARK: - Pan with momentum

    func beginDrag() {
        if dragStartOffset == nil { dragStartOffset = panOffset }
        isInteracting = true
    }

    func updateDrag(translation: CGFloat, contentWidth: CGFloat, viewportWidth: CGFloat) {
        guard let start = dragStartOffset else { return }
        let raw = start - translation
        panOffset = rubberBand(raw, min: 0, max: max(0, contentWidth - viewportWidth), distance: 80)
    }

    func endDrag(predictedTranslation: CGFloat, contentWidth: CGFloat, viewportWidth: CGFloat) {
        guard let start = dragStartOffset else { return }
        let predicted = start - predictedTranslation
        let clamped = min(max(0, contentWidth - viewportWidth), max(0, predicted))
        withAnimation(.interpolatingSpring(stiffness: 30, damping: 12)) {
            panOffset = clamped
        }
        dragStartOffset = nil
        isInteracting = false
        lastInteractionEnd = Date()
    }

    // MARK: - Pinch

    func beginPinch(anchorX: CGFloat) {
        pinchStartPpd = pixelsPerDay
        pinchAnchorX = anchorX
        isInteracting = true
    }

    func updatePinch(scale: CGFloat) {
        guard let startPpd = pinchStartPpd, let anchor = pinchAnchorX else { return }
        let target = startPpd * scale
        let minPpd = Level.allTime.pixelsPerDay * 0.6
        let maxPpd = Level.month.pixelsPerDay * 1.6
        let clamped = min(max(target, minPpd), maxPpd)
        // Keep the day under the anchor pinned in place.
        let anchorDay = (panOffset + anchor) / max(0.001, pixelsPerDay)
        pixelsPerDay = clamped
        panOffset = anchorDay * pixelsPerDay - anchor
    }

    func endPinch() {
        pinchStartPpd = nil
        pinchAnchorX = nil
        isInteracting = false
        lastInteractionEnd = Date()
    }

    // MARK: - Programmatic moves

    /// Animate to a discrete zoom level while keeping the visible center fixed.
    func setLevel(_ level: Level, viewportWidth: CGFloat) {
        let oldPpd = pixelsPerDay
        let centerX = panOffset + viewportWidth / 2
        let centerDay = oldPpd > 0 ? centerX / oldPpd : 0
        let newPpd = level.pixelsPerDay
        let newOffset = centerDay * newPpd - viewportWidth / 2
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            pixelsPerDay = newPpd
            panOffset = max(0, newOffset)
        }
    }

    /// Smoothly recenter the timeline on a specific date.
    func center(on date: Date, rangeStart: Date, viewportWidth: CGFloat, contentWidth: CGFloat, animation: Animation = .spring(response: 0.55, dampingFraction: 0.85)) {
        let day = Calendar.current.dateComponents([.day], from: rangeStart, to: date).day ?? 0
        let x = CGFloat(day) * pixelsPerDay
        let target = max(0, min(max(0, contentWidth - viewportWidth), x - viewportWidth / 2))
        withAnimation(animation) {
            panOffset = target
        }
    }

    /// Zoom in on a cluster's date range with the celebratory spring so the
    /// expansion feels rewarding.
    func expandCluster(centerDay: Int, viewportWidth: CGFloat, contentWidth: () -> CGFloat) {
        let targetPpd: CGFloat = Level.month.pixelsPerDay
        let newCenterX = CGFloat(centerDay) * targetPpd
        let newWidth = contentWidth()
        _ = newWidth
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            pixelsPerDay = targetPpd
            panOffset = max(0, newCenterX - viewportWidth / 2)
        }
    }

    // MARK: - Helpers

    func centerDate(rangeStart: Date, viewportWidth: CGFloat) -> Date {
        let centerX = panOffset + viewportWidth / 2
        let day = pixelsPerDay > 0 ? centerX / pixelsPerDay : 0
        return Calendar.current.date(byAdding: .day, value: Int(day.rounded()), to: rangeStart) ?? rangeStart
    }

    private func rubberBand(_ x: CGFloat, min lo: CGFloat, max hi: CGFloat, distance d: CGFloat) -> CGFloat {
        if x < lo {
            let over = lo - x
            return lo - d * (1 - d / (d + over))
        }
        if x > hi {
            let over = x - hi
            return hi + d * (1 - d / (d + over))
        }
        return x
    }
}

// MARK: - Lane parallax

extension JourneyLane {
    /// Foreground (Body/Compounds/Training) tracks the finger. Back lanes
    /// (Bloodwork/Life) move slightly slower so users feel depth without
    /// noticing it.
    var parallaxFactor: CGFloat {
        switch self {
        case .body, .compounds, .training: return 1.0
        case .bloodwork: return 0.92
        case .life: return 0.85
        case .agentAnnotation: return 1.0
        }
    }
}

// MARK: - Clustering

nonisolated struct JourneyCluster: Identifiable {
    let id = UUID()
    let lane: JourneyLane
    let events: [JourneyEvent]
    let centerX: CGFloat
    let centerDay: Int

    var count: Int { events.count }
}

@MainActor
enum JourneyClustering {
    /// Cluster point events (no duration) along the x-axis whenever they sit
    /// closer than `threshold` points apart. Returns the cluster pills to
    /// render and the set of event IDs that should be hidden by lane
    /// renderers (so we don't double-draw).
    static func cluster(
        events: [JourneyEvent],
        rangeStart: Date,
        pixelsPerDay: CGFloat,
        threshold: CGFloat = 26
    ) -> (clusters: [JourneyCluster], excluded: Set<UUID>) {
        let cal = Calendar.current
        let pointEvents = events
            .filter { ($0.durationDays ?? 0) == 0 }
            .sorted { $0.timestamp < $1.timestamp }
        guard !pointEvents.isEmpty else { return ([], []) }

        var groups: [[JourneyEvent]] = []
        var lastX: CGFloat = -.greatestFiniteMagnitude
        for e in pointEvents {
            let day = cal.dateComponents([.day], from: rangeStart, to: e.timestamp).day ?? 0
            let x = CGFloat(day) * pixelsPerDay
            if x - lastX < threshold, !groups.isEmpty {
                groups[groups.count - 1].append(e)
            } else {
                groups.append([e])
            }
            lastX = x
        }

        var clusters: [JourneyCluster] = []
        var excluded: Set<UUID> = []
        for grp in groups where grp.count > 1 {
            let days = grp.map { cal.dateComponents([.day], from: rangeStart, to: $0.timestamp).day ?? 0 }
            let avgDay = Int(Double(days.reduce(0, +)) / Double(days.count))
            let centerX = CGFloat(avgDay) * pixelsPerDay
            clusters.append(JourneyCluster(lane: grp[0].lane, events: grp, centerX: centerX, centerDay: avgDay))
            excluded.formUnion(grp.map(\.id))
        }
        return (clusters, excluded)
    }
}

// MARK: - Cluster pill view

struct JourneyClusterPill: View {
    let cluster: JourneyCluster
    let onTap: () -> Void
    @State private var pop: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: cluster.lane.icon)
                    .font(.system(size: 9, weight: .heavy))
                Text("+\(cluster.count)")
                    .font(.system(size: 11, weight: .heavy))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [cluster.lane.color.opacity(0.85), cluster.lane.color.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.6))
            .shadow(color: cluster.lane.color.opacity(0.45), radius: 6, y: 1)
            .scaleEffect(pop ? 1.0 : 0.85)
            .opacity(pop ? 1 : 0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(JourneyMotion.celebratory) { pop = true }
        }
    }
}

// MARK: - Floating date indicator

struct JourneyFloatingDate: View {
    let date: Date
    let visible: Bool

    var body: some View {
        Text(date, format: .dateTime.month(.wide).day().year())
            .font(.system(size: 12, weight: .heavy))
            .tracking(0.3)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.92)
            .animation(JourneyMotion.standard, value: visible)
    }
}

// MARK: - Today recenter button

struct JourneyTodayButton: View {
    let visible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(PepTheme.teal)
                    .frame(width: 6, height: 6)
                    .shadow(color: PepTheme.teal.opacity(0.8), radius: 4)
                Text("Today")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.3)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(PepTheme.teal.opacity(0.45), lineWidth: 0.6))
            .shadow(color: PepTheme.teal.opacity(0.35), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.85)
        .animation(JourneyMotion.standard, value: visible)
        .allowsHitTesting(visible)
    }
}
