import SwiftUI

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDone: () -> Void

    @State private var displayedFP: Int = 0
    @State private var showStats: Bool = false
    @State private var showPRs: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(FrisTheme.cyan)
                        .symbolEffect(.bounce, value: showStats)

                    Text("Workout Complete")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(FrisTheme.textPrimary)

                    Text(summary.workoutName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                }

                VStack(spacing: 6) {
                    Text("\(displayedFP)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(FrisTheme.cyan)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text("FIT POINTS EARNED")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(FrisTheme.cyan.opacity(0.7))
                }

                if showStats {
                    statsGrid
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if showPRs && !summary.personalRecords.isEmpty {
                    prSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 8)

                VStack(spacing: 12) {
                    Button {
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                            Text("Share Workout")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(FrisTheme.cyan)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(FrisTheme.cyan.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(FrisTheme.cyan.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.scale)

                    Button(action: onDone) {
                        Text("Done")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(FrisTheme.cyan)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.scalePrimary)
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(FrisTheme.background.ignoresSafeArea())
        .onAppear {
            animateIn()
            WorkoutState.shared.isWorkoutActive = false
            WorkoutState.shared.workoutProgress = 0
        }
        .sensoryFeedback(.success, trigger: showStats)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(icon: "clock.fill", label: "Duration", value: formattedDuration)
            statCard(icon: "scalemass.fill", label: "Volume", value: formattedVolume)
            statCard(icon: "checkmark.circle.fill", label: "Sets", value: "\(summary.totalSets)")
            statCard(icon: "flame.fill", label: "Exercises", value: "\(summary.totalSets > 0 ? summary.totalSets / 3 : 0)")
        }
        .padding(.horizontal, 4)
    }

    private func statCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(FrisTheme.cyan.opacity(0.8))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(FrisTheme.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(FrisTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(FrisTheme.amber)
                Text("Personal Records")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(FrisTheme.textPrimary)
            }

            ForEach(summary.personalRecords) { pr in
                HStack(spacing: 14) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(FrisTheme.amber)
                        .frame(width: 32, height: 32)
                        .background(FrisTheme.amber.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pr.exerciseName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Text("\(pr.recordType) — \(pr.value)")
                            .font(.caption)
                            .foregroundStyle(FrisTheme.amber)
                    }

                    Spacer()
                }
                .padding(12)
                .background(FrisTheme.amber.opacity(0.06))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(FrisTheme.amber.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
        .padding(.horizontal, 4)
    }

    private var formattedDuration: String {
        let mins = Int(summary.duration) / 60
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins)m"
    }

    private var formattedVolume: String {
        if summary.totalVolume >= 1000 {
            return String(format: "%.1fk", summary.totalVolume / 1000)
        }
        return "\(Int(summary.totalVolume))"
    }

    private func animateIn() {
        let target = summary.fpEarned
        let steps = 40
        let interval = 0.03

        for i in 0...steps {
            let delay = interval * Double(i)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.05)) {
                    displayedFP = Int(Double(target) * Double(i) / Double(steps))
                }
            }
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
            showStats = true
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7)) {
            showPRs = true
        }
    }
}
