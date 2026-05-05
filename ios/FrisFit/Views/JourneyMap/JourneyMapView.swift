import SwiftUI

/// Cinematic Journey Map. Five stacked lanes over a layered, time-shifting
/// background with crystalline milestones, glowing today rule, parallax depth,
/// continuous pinch-zoom, and pan-with-momentum scrubbing.
struct JourneyMapView: View {
    @State private var service = JourneyEventService.shared
    @State private var zoom = JourneyZoomState()
    @State private var collapsedLanes: Set<JourneyLane> = []
    @State private var selectedEvent: JourneyEvent?
    @State private var captureLane: JourneyLane?
    @State private var laneLabelsVisible: Bool = false
    @State private var dateIndicatorVisible: Bool = false
    @State private var pinchInProgress: Bool = false
    @State private var showStoryMode: Bool = false
    @State private var expandedAnnotation: JourneyEvent?
    @State private var tellMeMoreAnnotation: JourneyEvent?
    @State private var liveBursts: [LiveBurst] = []
    @State private var milestone: JourneyMilestone?
    @State private var milestoneVisible: Bool = false
    @State private var milestoneFiredThisSession: Bool = false

    private struct LiveBurst: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let color: Color
    }

    private let laneHeight: CGFloat = 92
    private let collapsedLaneHeight: CGFloat = 36
    private let laneLabelWidth: CGFloat = 92
    private let axisHeight: CGFloat = 28
    private let dateFadeDelay: TimeInterval = 1.5
    private let recenterThreshold: CGFloat = 80
    /// Buffer around the viewport (in points) within which off-screen pins are
    /// still rendered. Anything past the buffer is virtualized away.
    private let virtualizationBuffer: CGFloat = 240

    var body: some View {
        ZStack {
            JourneyBackground()
            VStack(spacing: 14) {
                header
                rangePicker
                timeline
            }
            .padding(.top, 8)
        }
        .task {
            // Initial pull is the visible window only — wider zooms fetch
            // additional ranges in the background as the user explores.
            _ = try? await service.fetch(from: rangeStart, to: rangeEnd)
            withAnimation(JourneyMotion.gentle) { laneLabelsVisible = true }
            checkForMilestone()
        }
        .onChange(of: zoom.nearestLevel) { _, level in
            Task {
                if level == .allTime {
                    await service.ensureAllTimeLoaded()
                } else {
                    await service.ensureRangeLoaded(from: rangeStart, to: rangeEnd)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .journeyEventsChanged)) { note in
            handleEventsChanged(note: note)
        }
        .overlay(alignment: .top) {
            if let m = milestone, milestoneVisible {
                JourneyMilestoneCard(milestone: m) {
                    dismissMilestone()
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $selectedEvent) { event in
            JourneyEventDetailSheet(event: event)
        }
        .sheet(item: $captureLane) { lane in
            JourneyEventCaptureSheet(initialLane: lane)
        }
        .sheet(item: $tellMeMoreAnnotation) { ann in
            PepChatView(planContext: agentChatContext(for: ann))
        }
        .fullScreenCover(isPresented: $showStoryMode) {
            StoryModeView()
        }
    }

    private func agentChatContext(for ann: JourneyEvent) -> String {
        var parts: [String] = []
        parts.append("Agent annotation on the user's Journey Map: \(ann.title).")
        if let body = ann.description, !body.isEmpty {
            parts.append("Reasoning: \(body)")
        }
        if let kind = ann.payload?.annotationKind {
            parts.append("Annotation kind: \(kind).")
        }
        parts.append("Detected on \(ann.timestamp.formatted(date: .abbreviated, time: .omitted)). Investigate further with the user's most relevant data and answer their follow-up questions.")
        return parts.joined(separator: " ")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Journey")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.75)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .tracking(-0.2)
                Text("\(service.events.count) pins · \(zoom.nearestLevel.label)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText())
            }
            Spacer()
            Button {
                JourneyHaptics.medium()
                showStoryMode = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .heavy))
                    Text("Watch your story")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [PepTheme.violet, PepTheme.teal.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.6))
                .shadow(color: PepTheme.violet.opacity(0.45), radius: 10, y: 2)
            }
            Menu {
                ForEach(JourneyLane.visibleLanes) { lane in
                    Button {
                        JourneyHaptics.light()
                        captureLane = lane
                    } label: {
                        Label(lane.title, systemImage: lane.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .heavy))
                    Text("Pin")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [PepTheme.teal, PepTheme.teal.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(
                    Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.6)
                )
                .shadow(color: PepTheme.teal.opacity(0.45), radius: 10, y: 2)
            }
        }
        .padding(.horizontal, 18)
    }

    private var rangePicker: some View {
        GeometryReader { geo in
            HStack(spacing: 6) {
                ForEach(JourneyZoomState.Level.allCases) { level in
                    let active = zoom.nearestLevel == level
                    Button {
                        JourneyHaptics.soft()
                        zoom.setLevel(level, viewportWidth: max(1, geo.size.width))
                    } label: {
                        Text(level.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(active ? .white : .white.opacity(0.55))
                            .frame(width: 44, height: 26)
                            .background(
                                Capsule()
                                    .fill(active
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [PepTheme.teal.opacity(0.85), PepTheme.teal.opacity(0.55)],
                                            startPoint: .top, endPoint: .bottom))
                                        : AnyShapeStyle(Color.white.opacity(0.06)))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 32)
    }

    // MARK: - Timeline (custom pan/zoom)

    private var timeline: some View {
        GeometryReader { proxy in
            let viewportWidth = max(1, proxy.size.width - laneLabelWidth)
            let totalWidth = max(viewportWidth, contentWidth)

            HStack(alignment: .top, spacing: 0) {
                laneLabelColumn
                    .frame(width: laneLabelWidth)

                ZStack(alignment: .topLeading) {
                    // Date axis (foreground — full pan)
                    dateAxis(totalWidth: totalWidth)
                        .frame(width: viewportWidth, height: axisHeight, alignment: .leading)
                        .clipped()

                    // Edge shimmer band while a background range fetch is
                    // in flight (e.g. zoom → All time). Subtle, non-blocking.
                    if service.isLoadingRange {
                        JourneyEdgeShimmer()
                            .frame(width: viewportWidth, height: 1)
                            .offset(y: axisHeight - 1)
                            .allowsHitTesting(false)
                    }

                    // Lanes — each with its own parallax-clipped viewport
                    VStack(alignment: .leading, spacing: 8) {
                        Color.clear.frame(height: axisHeight)
                        ForEach(JourneyLane.visibleLanes) { lane in
                            laneRow(lane, totalWidth: totalWidth, viewportWidth: viewportWidth)
                                .id(lane.rawValue)
                        }
                    }

                    // Floating date indicator
                    JourneyFloatingDate(
                        date: zoom.centerDate(rangeStart: rangeStart, viewportWidth: viewportWidth),
                        visible: dateIndicatorVisible
                    )
                    .position(x: viewportWidth / 2, y: axisHeight + 18)
                    .allowsHitTesting(false)

                    // Today recenter button
                    JourneyTodayButton(visible: shouldShowTodayButton(viewportWidth: viewportWidth)) {
                        JourneyHaptics.light()
                        zoom.center(on: Date(), rangeStart: rangeStart, viewportWidth: viewportWidth, contentWidth: totalWidth)
                    }
                    .position(x: viewportWidth - 50, y: axisHeight + 18)

                    // Agent annotation badges + expand card
                    agentAnnotationLayer(viewportWidth: viewportWidth)

                    // Live pin-add bursts
                    ForEach(liveBursts) { burst in
                        JourneyLivePinBurst(color: burst.color)
                            .position(x: burst.x - zoom.panOffset, y: burst.y)
                    }

                    // Milestone particle burst at the relevant pin
                    if let m = milestone, milestoneVisible {
                        let x = xPosition(for: m.anchorDate) - zoom.panOffset
                        if x >= -40, x <= viewportWidth + 40 {
                            JourneyMilestoneParticleBurst(color: m.targetLane.color)
                                .position(x: x, y: axisHeight + 60)
                        }
                    }
                }
                .frame(width: viewportWidth, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(panGesture(viewportWidth: viewportWidth, contentWidth: totalWidth))
                .simultaneousGesture(pinchGesture(viewportWidth: viewportWidth))
                .onChange(of: zoom.isInteracting) { _, interacting in
                    if interacting {
                        withAnimation(JourneyMotion.standard) { dateIndicatorVisible = true }
                    } else {
                        scheduleDateFade()
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Gestures

    private func panGesture(viewportWidth: CGFloat, contentWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                if !zoom.isInteracting {
                    JourneyHaptics.soft()
                    zoom.beginDrag()
                }
                zoom.updateDrag(translation: v.translation.width, contentWidth: contentWidth, viewportWidth: viewportWidth)
            }
            .onEnded { v in
                zoom.endDrag(predictedTranslation: v.predictedEndTranslation.width, contentWidth: contentWidth, viewportWidth: viewportWidth)
            }
    }

    private func pinchGesture(viewportWidth: CGFloat) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.005)
            .onChanged { v in
                if !pinchInProgress {
                    pinchInProgress = true
                    let anchor = v.startLocation.x
                    zoom.beginPinch(anchorX: max(0, min(viewportWidth, anchor)))
                }
                zoom.updatePinch(scale: v.magnification)
            }
            .onEnded { _ in
                pinchInProgress = false
                zoom.endPinch()
            }
    }

    // MARK: - Lane row (clipped viewport with parallax)

    private func laneRow(_ lane: JourneyLane, totalWidth: CGFloat, viewportWidth: CGFloat) -> some View {
        let collapsed = collapsedLanes.contains(lane)
        let height = collapsed ? collapsedLaneHeight : laneHeight
        let parallax = lane.parallaxFactor
        let offset = -zoom.panOffset * parallax
        let allEvents = service.events(in: lane).filter { rangeContains($0.timestamp) }
        let cluster = JourneyClustering.cluster(events: allEvents, rangeStart: rangeStart, pixelsPerDay: zoom.pixelsPerDay)
        // Virtualize: only events whose pin would render within the visible
        // viewport (plus a buffer) are passed to the lane renderer. This
        // keeps scrub at 60fps even with hundreds of pins.
        let parallaxOffset = zoom.panOffset * parallax
        let leftEdge = parallaxOffset - virtualizationBuffer
        let rightEdge = parallaxOffset + viewportWidth + virtualizationBuffer
        let visibleEvents = allEvents.filter { e in
            if cluster.excluded.contains(e.id) { return false }
            let x = xPosition(for: e.timestamp)
            let span = CGFloat(max(0, e.durationDays ?? 0)) * zoom.pixelsPerDay
            return (x + span) >= leftEdge && x <= rightEdge
        }
        let visibleClusters = cluster.clusters.filter { c in
            c.centerX >= leftEdge && c.centerX <= rightEdge
        }

        return ZStack(alignment: .leading) {
            // Translucent surface (viewport-sized, no parallax)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.07), .white.opacity(0.0)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.6
                        )
                )
                .frame(width: viewportWidth, height: height)

            // Lane content layer — full content width, drawn out of viewport
            // and offset by panOffset * parallax. Virtualized only by clipping.
            ZStack(alignment: .topLeading) {
                if !collapsed {
                    laneContent(lane: lane, events: visibleEvents, totalWidth: totalWidth, height: height)
                        .frame(width: totalWidth, height: height, alignment: .leading)

                    // Cluster pills overlay (virtualized to viewport)
                    ForEach(visibleClusters) { cl in
                        JourneyClusterPill(cluster: cl) {
                            JourneyHaptics.medium()
                            zoom.expandCluster(centerDay: cl.centerDay, viewportWidth: viewportWidth) { contentWidth }
                        }
                        .position(x: cl.centerX, y: height / 2)
                    }
                } else {
                    collapsedDensity(for: allEvents, totalWidth: totalWidth)
                        .frame(width: totalWidth, height: height)
                }
            }
            .frame(width: totalWidth, height: height, alignment: .leading)
            .offset(x: offset)
        }
        .frame(width: viewportWidth, height: height, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func laneContent(lane: JourneyLane, events: [JourneyEvent], totalWidth: CGFloat, height: CGFloat) -> some View {
        switch lane {
        case .body:
            BodyLaneRenderer(
                events: events,
                totalWidth: totalWidth,
                height: height,
                xPosition: { xPosition(for: $0) },
                onTap: { selectedEvent = $0 }
            )
        case .compounds:
            CompoundsLaneRenderer(
                events: events,
                totalWidth: totalWidth,
                height: height,
                xPosition: { xPosition(for: $0) },
                pixelsPerDay: zoom.pixelsPerDay,
                onTap: { selectedEvent = $0 }
            )
        case .training:
            TrainingLaneRenderer(
                events: events,
                totalWidth: totalWidth,
                height: height,
                xPosition: { xPosition(for: $0) },
                pixelsPerDay: zoom.pixelsPerDay,
                onTap: { selectedEvent = $0 }
            )
        case .bloodwork:
            BloodworkLaneRenderer(
                events: events,
                totalWidth: totalWidth,
                height: height,
                xPosition: { xPosition(for: $0) },
                onTap: { selectedEvent = $0 }
            )
        case .life:
            LifeLaneRenderer(
                events: events,
                totalWidth: totalWidth,
                height: height,
                xPosition: { xPosition(for: $0) },
                onTap: { selectedEvent = $0 }
            )
        case .agentAnnotation:
            EmptyView()
        }
    }

    private func collapsedDensity(for events: [JourneyEvent], totalWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ForEach(events) { e in
                Circle()
                    .fill(e.lane.color.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .offset(x: xPosition(for: e.timestamp) - 2)
            }
        }
    }

    // MARK: - Lane labels

    private var laneLabelColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.frame(height: axisHeight)
            ForEach(JourneyLane.visibleLanes) { lane in
                laneLabel(lane,
                          collapsed: collapsedLanes.contains(lane),
                          count: service.events(in: lane).filter { rangeContains($0.timestamp) }.count)
                    .frame(height: collapsedLanes.contains(lane) ? collapsedLaneHeight : laneHeight)
                    .opacity(laneLabelsVisible ? 1 : 0)
                    .offset(y: laneLabelsVisible ? 0 : 8)
            }
        }
        .padding(.leading, 14)
    }

    private func laneLabel(_ lane: JourneyLane, collapsed: Bool, count: Int) -> some View {
        Button {
            JourneyHaptics.soft()
            withAnimation(JourneyMotion.standard) {
                if collapsed { collapsedLanes.remove(lane) } else { collapsedLanes.insert(lane) }
            }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(lane.color.opacity(0.16))
                        .frame(width: 26, height: 26)
                    Image(systemName: lane.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(lane.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(lane.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date axis

    private func dateAxis(totalWidth: CGFloat) -> some View {
        let cal = Calendar.current
        let streak = StreakManager.shared.streakData.currentStreak
        let streakStartX: CGFloat = {
            guard streak > 1 else { return 0 }
            let start = cal.date(byAdding: .day, value: -(streak - 1), to: Date()) ?? Date()
            return xPosition(for: max(start, rangeStart))
        }()
        let todayX = xPosition(for: Date())
        return ZStack(alignment: .topLeading) {
            // Glowing route-line axis
            LinearGradient(
                colors: [
                    .white.opacity(0.0),
                    .white.opacity(0.18),
                    .white.opacity(0.0)
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: totalWidth, height: 1)
            .offset(y: 22)
            .shadow(color: PepTheme.teal.opacity(0.25), radius: 4)

            ForEach(monthMarkers, id: \.self) { date in
                let day = cal.dateComponents([.day], from: rangeStart, to: date).day ?? 0
                VStack(alignment: .leading, spacing: 3) {
                    Text(monthLabel(for: date))
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(0.4)
                    Rectangle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 0.5, height: 6)
                }
                .offset(x: CGFloat(day) * zoom.pixelsPerDay)
            }

            if streak >= 2 {
                JourneyStreakBand(startX: streakStartX, endX: todayX, streakDays: streak)
                    .frame(width: totalWidth, height: 12)
                    .offset(y: 26)
            }

            TodayPulseMarker(height: axisHeight)
                .offset(x: CGFloat(cal.dateComponents([.day], from: rangeStart, to: Date()).day ?? 0) * zoom.pixelsPerDay - 5)
        }
        .frame(width: totalWidth, height: axisHeight, alignment: .topLeading)
        .offset(x: -zoom.panOffset)
    }

    private func monthLabel(for date: Date) -> String {
        // Show full month + year at zoomed-out scales, abbreviated at finer.
        let format: Date.FormatStyle = zoom.pixelsPerDay >= 14
            ? .dateTime.month(.wide).year()
            : .dateTime.month(.abbreviated)
        return date.formatted(format)
    }

    // MARK: - Range math

    private var rangeStart: Date {
        let cal = Calendar.current
        // Generous range so all four zoom levels can pan freely.
        return cal.date(byAdding: .month, value: -JourneyZoomState.Level.allTime.months, to: Date()) ?? Date()
    }

    private var rangeEnd: Date {
        Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    }

    private var totalDaysInRange: Int {
        max(1, Calendar.current.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 1)
    }

    private var contentWidth: CGFloat {
        CGFloat(totalDaysInRange) * zoom.pixelsPerDay
    }

    private func rangeContains(_ date: Date) -> Bool {
        date >= rangeStart && date <= rangeEnd
    }

    private func xPosition(for date: Date) -> CGFloat {
        let day = Calendar.current.dateComponents([.day], from: rangeStart, to: date).day ?? 0
        return CGFloat(day) * zoom.pixelsPerDay
    }

    private var monthMarkers: [Date] {
        var markers: [Date] = []
        let cal = Calendar.current
        var cursor = cal.date(from: cal.dateComponents([.year, .month], from: rangeStart)) ?? rangeStart
        // Stride increases at finer zooms to avoid label crowding.
        let strideMonths: Int = {
            switch zoom.pixelsPerDay {
            case 0..<2: return 6
            case 2..<5: return 3
            case 5..<12: return 1
            default: return 1
            }
        }()
        while cursor <= rangeEnd {
            markers.append(cursor)
            cursor = cal.date(byAdding: .month, value: strideMonths, to: cursor) ?? rangeEnd
        }
        return markers
    }

    // MARK: - Today button visibility

    private func shouldShowTodayButton(viewportWidth: CGFloat) -> Bool {
        let todayX = xPosition(for: Date())
        let centerX = zoom.panOffset + viewportWidth / 2
        return abs(todayX - centerX) > recenterThreshold
    }

    // MARK: - Agent annotation layer

    @ViewBuilder
    private func agentAnnotationLayer(viewportWidth: CGFloat) -> some View {
        let annotations = service.events(in: .agentAnnotation).filter { rangeContains($0.timestamp) }
        ZStack(alignment: .topLeading) {
            ForEach(annotations) { ann in
                let x = xPosition(for: ann.timestamp) - zoom.panOffset
                if x >= -20, x <= viewportWidth + 20 {
                    JourneyAgentBadge(event: ann) {
                        JourneyHaptics.light()
                        withAnimation(JourneyMotion.standard) {
                            expandedAnnotation = (expandedAnnotation?.id == ann.id) ? nil : ann
                        }
                    }
                    .position(x: x, y: 4)
                }
            }
            if let exp = expandedAnnotation {
                let rawX = xPosition(for: exp.timestamp) - zoom.panOffset
                let cardWidth: CGFloat = min(320, viewportWidth - 24)
                let cardX = max(cardWidth / 2 + 12, min(viewportWidth - cardWidth / 2 - 12, rawX))
                JourneyAgentExpandedCard(
                    event: exp,
                    onDismiss: {
                        withAnimation(JourneyMotion.standard) { expandedAnnotation = nil }
                    },
                    onTellMeMore: {
                        let toOpen = exp
                        withAnimation(JourneyMotion.standard) { expandedAnnotation = nil }
                        tellMeMoreAnnotation = toOpen
                    }
                )
                .frame(width: cardWidth)
                .position(x: cardX, y: axisHeight + 90)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .frame(width: viewportWidth, alignment: .topLeading)
    }

    // MARK: - Live updates

    private func handleEventsChanged(note: Notification) {
        guard let idStr = note.userInfo?["insertedId"] as? String,
              let id = UUID(uuidString: idStr),
              let event = service.events.first(where: { $0.id == id }),
              event.lane != .agentAnnotation else { return }
        JourneyHaptics.soft()
        let x = xPosition(for: event.timestamp)
        let y = laneCenterY(for: event.lane)
        let burst = LiveBurst(x: x, y: y, color: event.lane.color)
        liveBursts.append(burst)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            liveBursts.removeAll { $0.id == burst.id }
        }
    }

    private func laneCenterY(for lane: JourneyLane) -> CGFloat {
        let visible = JourneyLane.visibleLanes
        guard let index = visible.firstIndex(of: lane) else { return axisHeight + laneHeight / 2 }
        var y: CGFloat = axisHeight + 8
        for i in 0..<index {
            let l = visible[i]
            y += (collapsedLanes.contains(l) ? collapsedLaneHeight : laneHeight) + 8
        }
        let h = collapsedLanes.contains(lane) ? collapsedLaneHeight : laneHeight
        return y + h / 2
    }

    // MARK: - Milestones

    private func checkForMilestone() {
        guard !milestoneFiredThisSession else { return }
        let tracker = JourneyMilestoneTracker.shared
        guard let next = tracker.nextUnfired() else { return }
        milestoneFiredThisSession = true
        milestone = next
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(JourneyMotion.celebratory) { milestoneVisible = true }
            JourneyHaptics.success()
            tracker.markFired(next.id)
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run {
                if milestoneVisible { dismissMilestone() }
            }
        }
    }

    private func dismissMilestone() {
        withAnimation(JourneyMotion.standard) {
            milestoneVisible = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            milestone = nil
        }
    }

    // MARK: - Date indicator fade

    private func scheduleDateFade() {
        let endedAt = zoom.lastInteractionEnd
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(dateFadeDelay))
            // Bail if user touched again in the meantime.
            guard zoom.lastInteractionEnd == endedAt, !zoom.isInteracting else { return }
            withAnimation(JourneyMotion.standard) { dateIndicatorVisible = false }
        }
    }
}
