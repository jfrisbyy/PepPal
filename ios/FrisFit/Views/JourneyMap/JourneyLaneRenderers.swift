import SwiftUI

// MARK: - Body lane — flowing area chart + crystalline milestones

struct BodyLaneRenderer: View {
    let events: [JourneyEvent]
    let totalWidth: CGFloat
    let height: CGFloat
    let xPosition: (Date) -> CGFloat
    let onTap: (JourneyEvent) -> Void

    @State private var strokeProgress: CGFloat = 0

    private var weightPoints: [(x: CGFloat, y: CGFloat, event: JourneyEvent)] {
        let withWeight = events
            .compactMap { e -> (Date, Double, JourneyEvent)? in
                guard let w = e.payload?.weightLbs, w > 0 else { return nil }
                return (e.timestamp, w, e)
            }
            .sorted { $0.0 < $1.0 }
        guard !withWeight.isEmpty else { return [] }
        let weights = withWeight.map { $0.1 }
        let minW = (weights.min() ?? 0) - 2
        let maxW = (weights.max() ?? 0) + 2
        let span = max(1, maxW - minW)
        let topInset: CGFloat = 14
        let bottomInset: CGFloat = 18
        let usable = max(1, height - topInset - bottomInset)
        return withWeight.map { (date, w, e) in
            let x = xPosition(date)
            let y = topInset + CGFloat(1 - (w - minW) / span) * usable
            return (x, y, e)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            let pts = weightPoints
            if pts.count >= 2 {
                // Translucent gradient fill underneath
                areaPath(points: pts)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 76/255, green: 217/255, blue: 100/255).opacity(0.35),
                                Color(red: 76/255, green: 217/255, blue: 100/255).opacity(0.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .opacity(strokeProgress)
                // Stroke
                linePath(points: pts)
                    .trim(from: 0, to: strokeProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 120/255, green: 230/255, blue: 150/255),
                                Color(red: 76/255, green: 217/255, blue: 100/255)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color(red: 76/255, green: 217/255, blue: 100/255).opacity(0.5), radius: 4)
            }

            ForEach(pts, id: \.event.id) { pt in
                Button { onTap(pt.event) } label: {
                    CrystallineMilestoneNode(
                        color: Color(red: 76/255, green: 217/255, blue: 100/255),
                        size: 18,
                        icon: "scalemass"
                    )
                }
                .buttonStyle(.plain)
                .position(x: pt.x, y: pt.y)
                .opacity(strokeProgress)
            }

            // Body events without weight (e.g. body fat only) — small crystalline node on lane mid
            ForEach(events.filter { $0.payload?.weightLbs == nil }) { e in
                Button { onTap(e) } label: {
                    CrystallineMilestoneNode(
                        color: Color(red: 76/255, green: 217/255, blue: 100/255).opacity(0.85),
                        size: 14,
                        icon: nil
                    )
                }
                .buttonStyle(.plain)
                .position(x: xPosition(e.timestamp), y: height / 2)
            }
        }
        .frame(width: totalWidth, height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { strokeProgress = 1 }
        }
    }

    private func linePath(points: [(x: CGFloat, y: CGFloat, event: JourneyEvent)]) -> Path {
        Path { p in
            guard let first = points.first else { return }
            p.move(to: CGPoint(x: first.x, y: first.y))
            for pt in points.dropFirst() {
                p.addLine(to: CGPoint(x: pt.x, y: pt.y))
            }
        }
    }

    private func areaPath(points: [(x: CGFloat, y: CGFloat, event: JourneyEvent)]) -> Path {
        Path { p in
            guard let first = points.first, let last = points.last else { return }
            p.move(to: CGPoint(x: first.x, y: height - 4))
            p.addLine(to: CGPoint(x: first.x, y: first.y))
            for pt in points.dropFirst() {
                p.addLine(to: CGPoint(x: pt.x, y: pt.y))
            }
            p.addLine(to: CGPoint(x: last.x, y: height - 4))
            p.closeSubpath()
        }
    }
}

// MARK: - Compounds lane — gradient bars per class

struct CompoundsLaneRenderer: View {
    let events: [JourneyEvent]
    let totalWidth: CGFloat
    let height: CGFloat
    let xPosition: (Date) -> CGFloat
    let pixelsPerDay: CGFloat
    let onTap: (JourneyEvent) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
                let row = idx % 2
                let yMid = height / 2 + (row == 0 ? -14 : 14)
                let span = barSpan(for: event)
                Button { onTap(event) } label: {
                    bar(for: event, width: span.width)
                }
                .buttonStyle(.plain)
                .position(x: span.x + span.width / 2, y: yMid)
            }
        }
        .frame(width: totalWidth, height: height)
    }

    private func barSpan(for event: JourneyEvent) -> (x: CGFloat, width: CGFloat) {
        let startX = xPosition(event.timestamp)
        let days = max(1, event.durationDays ?? 1)
        let width = max(10, CGFloat(days) * pixelsPerDay)
        return (startX, width)
    }

    private func bar(for event: JourneyEvent, width: CGFloat) -> some View {
        let gradient = JourneyCompoundPalette.gradient(for: event.payload?.compoundName)
        let accent = JourneyCompoundPalette.accent(for: event.payload?.compoundName)
        return ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(gradient)
                .frame(width: width, height: 18)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: accent.opacity(0.45), radius: 6, y: 1)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                        .frame(height: 8)
                        .offset(y: -5)
                        .blendMode(.plusLighter)
                )
            if width > 60 {
                Text((event.payload?.compoundName ?? event.title).uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 10)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Training lane — phase bars + heartbeat tick marks

struct TrainingLaneRenderer: View {
    let events: [JourneyEvent]
    let totalWidth: CGFloat
    let height: CGFloat
    let xPosition: (Date) -> CGFloat
    let pixelsPerDay: CGFloat
    let onTap: (JourneyEvent) -> Void

    @State private var ticksIn: CGFloat = 0

    private var phaseEvents: [JourneyEvent] {
        events.filter { ($0.durationDays ?? 0) > 0 }
    }

    private var workoutEvents: [JourneyEvent] {
        events.filter { ($0.durationDays ?? 0) == 0 }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Phase bars (muted, wide)
            ForEach(phaseEvents) { event in
                let startX = xPosition(event.timestamp)
                let width = max(20, CGFloat(max(1, event.durationDays ?? 1)) * pixelsPerDay)
                Button { onTap(event) } label: {
                    phaseBar(event: event, width: width)
                }
                .buttonStyle(.plain)
                .position(x: startX + width / 2, y: height / 2 - 6)
            }

            // Workout heartbeat ticks underneath
            ForEach(Array(workoutEvents.enumerated()), id: \.element.id) { idx, event in
                let intensity = max(0.2, min(1.0, event.confidence))
                let tickHeight: CGFloat = 6 + 10 * intensity
                let stagger = Double(idx % 12) * 0.02
                Button { onTap(event) } label: {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 255/255, green: 165/255, blue: 0).opacity(0.3 + 0.5 * intensity),
                                    Color(red: 255/255, green: 200/255, blue: 80/255).opacity(0.7)
                                ],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .frame(width: 2, height: tickHeight)
                        .shadow(color: Color(red: 255/255, green: 149/255, blue: 0).opacity(0.4), radius: 2)
                }
                .buttonStyle(.plain)
                .position(x: xPosition(event.timestamp), y: height - tickHeight / 2 - 6)
                .opacity(ticksIn)
                .scaleEffect(y: ticksIn, anchor: .bottom)
                .animation(JourneyMotion.gentle.delay(stagger), value: ticksIn)
            }
        }
        .frame(width: totalWidth, height: height)
        .onAppear { ticksIn = 1 }
    }

    private func phaseBar(event: JourneyEvent, width: CGFloat) -> some View {
        let phase = event.payload?.phaseType.flatMap { JourneyTrainingPhase(rawValue: $0) }
        let base = Color(red: 255/255, green: 149/255, blue: 0)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(base.opacity(0.18))
                .frame(width: width, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(base.opacity(0.32), lineWidth: 0.6)
                )
            if width > 50 {
                HStack(spacing: 5) {
                    if let icon = phase?.icon {
                        Image(systemName: icon)
                            .font(.system(size: 9, weight: .heavy))
                    }
                    Text((phase?.label ?? event.title).uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.5)
                }
                .foregroundStyle(base.opacity(0.95))
                .padding(.horizontal, 8)
                .lineLimit(1)
            }
        }
    }
}

// MARK: - Bloodwork lane — connected colored dots

struct BloodworkLaneRenderer: View {
    let events: [JourneyEvent]
    let totalWidth: CGFloat
    let height: CGFloat
    let xPosition: (Date) -> CGFloat
    let onTap: (JourneyEvent) -> Void

    @State private var traceProgress: CGFloat = 0

    private var sorted: [JourneyEvent] {
        events.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Connecting arc
            if sorted.count >= 2 {
                Path { p in
                    let pts = sorted.map { CGPoint(x: xPosition($0.timestamp), y: height / 2) }
                    p.move(to: pts[0])
                    for pt in pts.dropFirst() {
                        p.addLine(to: pt)
                    }
                }
                .trim(from: 0, to: traceProgress)
                .stroke(
                    LinearGradient(
                        colors: [PepTheme.blue.opacity(0.4), PepTheme.blue.opacity(0.7)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3])
                )
            }

            ForEach(sorted) { event in
                let status = bloodworkStatus(for: event)
                Button { onTap(event) } label: {
                    ZStack {
                        Circle()
                            .fill(status.opacity(0.25))
                            .frame(width: 22, height: 22)
                            .blur(radius: 2)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [status, status.opacity(0.6)],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 12
                                )
                            )
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.6))
                            .shadow(color: status.opacity(0.6), radius: 4)
                    }
                }
                .buttonStyle(.plain)
                .position(x: xPosition(event.timestamp), y: height / 2)
                .opacity(traceProgress)
            }
        }
        .frame(width: totalWidth, height: height)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9)) { traceProgress = 1 }
        }
    }

    private func bloodworkStatus(for event: JourneyEvent) -> Color {
        // Green good, amber attention, red flagged. Heuristic: confidence band.
        let c = event.confidence
        if c >= 0.8 { return Color(red: 76/255, green: 217/255, blue: 100/255) }
        if c >= 0.5 { return PepTheme.amber }
        return Color(red: 255/255, green: 80/255, blue: 80/255)
    }
}

// MARK: - Life lane — small subtle icons

struct LifeLaneRenderer: View {
    let events: [JourneyEvent]
    let totalWidth: CGFloat
    let height: CGFloat
    let xPosition: (Date) -> CGFloat
    let onTap: (JourneyEvent) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(events) { event in
                let icon = event.payload?.lifeEventType
                    .flatMap { JourneyLifeEventType(rawValue: $0)?.icon } ?? "calendar"
                Button { onTap(event) } label: {
                    VStack(spacing: 2) {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PepTheme.violet.opacity(0.85))
                            .frame(width: 22, height: 22)
                            .background(
                                Circle().fill(.white.opacity(0.04))
                            )
                            .overlay(
                                Circle().strokeBorder(PepTheme.violet.opacity(0.25), lineWidth: 0.5)
                            )
                    }
                }
                .buttonStyle(.plain)
                .position(x: xPosition(event.timestamp), y: height / 2)
            }
        }
        .frame(width: totalWidth, height: height)
    }
}
