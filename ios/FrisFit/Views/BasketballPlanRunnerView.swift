import SwiftUI
import Combine

struct BasketballPlanRunnerView: View {
    let plan: PracticePlan
    var bbVM: BasketballViewModel = .shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0
    @State private var completedSlugs: Set<String> = []
    @State private var isResting: Bool = false
    @State private var restRemaining: Int = 30
    @State private var showSummary: Bool = false

    private let accentColor = BasketballPalette.courtOrange

    var body: some View {
        NavigationStack {
            ZStack {
                PepTheme.background.ignoresSafeArea()

                if showSummary {
                    summaryView
                } else if isResting {
                    restView
                } else {
                    drillView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showSummary ? "Done" : "Cancel") { dismiss() }
                        .foregroundStyle(showSummary ? accentColor : PepTheme.textSecondary)
                }
            }
        }
    }

    private var currentDrill: BasketballDrill? {
        guard currentIndex < plan.drills.count else { return nil }
        return plan.drills[currentIndex].drill
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(plan.drills.enumerated()), id: \.element.id) { idx, _ in
                    Capsule()
                        .fill(idx <= currentIndex ? accentColor : PepTheme.elevated)
                        .frame(height: 4)
                }
            }
            HStack {
                Text(plan.name.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(accentColor)
                Spacer()
                Text("\(currentIndex + 1) of \(plan.drills.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private var drillView: some View {
        VStack(spacing: 16) {
            progressBar
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    if let drill = currentDrill {
                        drillHeader(drill)
                        if !drill.steps.isEmpty {
                            stepsCard(drill)
                        }
                        if !drill.cues.isEmpty {
                            cuesCard(drill)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }

            actionBar
        }
    }

    private func drillHeader(_ drill: BasketballDrill) -> some View {
        PepSportCard(accent: drill.category.color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(drill.category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(drill.category.color)
                    Spacer()
                    Text("\(drill.durationMinutes) MIN")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Text(drill.name)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                Text(drill.purpose)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stepsCard(_ drill: BasketballDrill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "How To", title: "Steps", accent: drill.category.color)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(drill.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text(String(format: "%02d", idx + 1))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(drill.category.color)
                            .frame(width: 24, alignment: .leading)
                        Text(step)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .editorialCard(accent: drill.category.color)
    }

    private func cuesCard(_ drill: BasketballDrill) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "Coaching", title: "Cues", accent: BasketballPalette.courtAmber)
            VStack(spacing: 6) {
                ForEach(drill.cues, id: \.self) { cue in
                    HStack(spacing: 10) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 11))
                            .foregroundStyle(BasketballPalette.courtAmber)
                        Text(cue)
                            .font(.system(size: 13, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                    }
                }
            }
        }
        .editorialCard(accent: BasketballPalette.courtAmber)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if currentIndex > 0 {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        currentIndex -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 50, height: 50)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.scale)
            }

            Button {
                completeCurrentDrill()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(currentIndex == plan.drills.count - 1 ? "Finish Plan" : "Mark Complete")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(accentColor)
                .clipShape(.rect(cornerRadius: 14))
                .shadow(color: accentColor.opacity(0.3), radius: 12, y: 6)
            }
            .buttonStyle(.scalePrimary)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func completeCurrentDrill() {
        guard let drill = currentDrill else { return }
        completedSlugs.insert(drill.slug)
        bbVM.recordDrillCompletion(drill)
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        if currentIndex >= plan.drills.count - 1 {
            showSummary = true
        } else {
            withAnimation(.spring(duration: 0.3)) {
                isResting = true
                restRemaining = 30
            }
        }
    }

    // MARK: - Rest

    private var restView: some View {
        VStack(spacing: 24) {
            progressBar
                .padding(.horizontal)
                .padding(.top, 8)

            Spacer()

            Text("REST")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(PepTheme.textSecondary)

            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 8)
                    .frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: 1.0 - Double(restRemaining) / 30.0)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: restRemaining)
                Text("\(restRemaining)")
                    .font(.system(size: 64, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
            }

            if let next = currentIndex + 1 < plan.drills.count ? plan.drills[currentIndex + 1].drill : nil {
                VStack(spacing: 6) {
                    Text("UP NEXT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(next.name)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }

            Spacer()

            Button {
                advanceFromRest()
            } label: {
                Text("Skip Rest")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isResting else { return }
            if restRemaining > 0 {
                restRemaining -= 1
            } else {
                advanceFromRest()
            }
        }
    }

    private func advanceFromRest() {
        withAnimation(.spring(duration: 0.3)) {
            isResting = false
            currentIndex += 1
        }
    }

    // MARK: - Summary

    private var summaryView: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            VStack(spacing: 8) {
                Text("PLAN COMPLETE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(accentColor)
                Text(plan.name)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("\(plan.drills.count) drills · \(plan.totalDuration) min")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }

            VStack(spacing: 6) {
                ForEach(plan.drills) { drillRef in
                    let done = completedSlugs.contains(drillRef.drill.slug)
                    HStack(spacing: 10) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? .green : PepTheme.textSecondary)
                        Text(drillRef.drill.name)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text("\(drillRef.drill.durationMinutes)m")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PepTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 8) {
                EditorialPrimaryButton("Log This as a Run", icon: "basketball.fill", accent: accentColor) {
                    bbVM.selectedSessionType = .skillsPractice
                    bbVM.gameDuration = plan.totalDuration
                    bbVM.drillsCompletedThisSession = Array(completedSlugs)
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        bbVM.showRunLog = true
                    }
                }
                Button { dismiss() } label: {
                    Text("Close")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .onAppear {
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.success)
        }
    }
}
