import SwiftUI

struct TennisLiveScorerView: View {
    @Bindable var tennisVM: TennisViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEndMatchConfirm: Bool = false
    @State private var matchStartTime: Date = Date()
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer? = nil

    private let accentColor = Color(red: 0.85, green: 0.9, blue: 0.15)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scoreboard
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                if tennisVM.liveScore.matchOver {
                    matchOverView
                } else {
                    servingIndicator
                        .padding(.bottom, 16)
                    pointButtons
                        .padding(.horizontal, 24)
                }

                Spacer()

                bottomBar
            }
            .appBackground()
            .navigationTitle("Live Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End") {
                        showEndMatchConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .alert("End Match?", isPresented: $showEndMatchConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("End & Save", role: .destructive) {
                    stopTimer()
                    tennisVM.matchDuration = max(elapsedSeconds / 60, 1)
                    tennisVM.logFromLiveScore()
                    dismiss()
                }
                Button("End & Discard", role: .destructive) {
                    stopTimer()
                    tennisVM.resetLiveScore()
                    dismiss()
                }
            }
            .onAppear {
                matchStartTime = Date()
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }

    private var scoreboard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(formatTime(elapsedSeconds))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text(tennisVM.liveScore.format.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("YOU")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)

                ForEach(Array(tennisVM.liveScore.sets.enumerated()), id: \.offset) { index, set in
                    VStack(spacing: 4) {
                        Text("S\(index + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .tracking(0.5)
                    }
                    .frame(width: 36)
                }

                VStack(spacing: 4) {
                    Text("PTS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.5)
                }
                .frame(width: 50)
            }

            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    if tennisVM.liveScore.isPlayerServing {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)
                    }
                    Text("You")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(tennisVM.liveScore.sets.enumerated()), id: \.offset) { _, set in
                    Text("\(set.playerGames)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(set.playerWon ? accentColor : PepTheme.textPrimary)
                        .frame(width: 36)
                }

                Text(tennisVM.liveScore.playerPointDisplay)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(accentColor)
                    .frame(width: 50)
                    .contentTransition(.numericText())
            }

            Rectangle()
                .fill(PepTheme.elevated)
                .frame(height: 1)

            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    if !tennisVM.liveScore.isPlayerServing {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                    }
                    Text(tennisVM.opponentName.isEmpty ? "OPP" : tennisVM.opponentName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(tennisVM.liveScore.sets.enumerated()), id: \.offset) { _, set in
                    Text("\(set.opponentGames)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(!set.playerWon && (set.playerGames + set.opponentGames > 0) ? .red : PepTheme.textPrimary)
                        .frame(width: 36)
                }

                Text(tennisVM.liveScore.opponentPointDisplay)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .frame(width: 50)
                    .contentTransition(.numericText())
            }
        }
        .padding(20)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.15), PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var servingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(tennisVM.liveScore.isPlayerServing ? accentColor : .red)
            Text(tennisVM.liveScore.isPlayerServing ? "Your Serve" : "Opponent's Serve")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            if tennisVM.liveScore.isTiebreak {
                Text("TIEBREAK")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.amber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(PepTheme.amber.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private var pointButtons: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    tennisVM.liveScore.playerWonPoint()
                }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 28))
                    Text("Won Point")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(accentColor)
                .clipShape(.rect(cornerRadius: 20))
            }
            .buttonStyle(.scalePrimary)
            .sensoryFeedback(.impact(weight: .medium), trigger: tennisVM.liveScore.playerPoints)

            Button {
                withAnimation(.spring(duration: 0.2)) {
                    tennisVM.liveScore.opponentWonPoint()
                }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 28))
                    Text("Lost Point")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.red.opacity(0.8))
                .clipShape(.rect(cornerRadius: 20))
            }
            .buttonStyle(.scalePrimary)
            .sensoryFeedback(.impact(weight: .light), trigger: tennisVM.liveScore.opponentPoints)
        }
    }

    private var matchOverView: some View {
        VStack(spacing: 20) {
            let playerWon = tennisVM.liveScore.computedPlayerSetsWon > tennisVM.liveScore.computedOpponentSetsWon
            Image(systemName: playerWon ? "trophy.fill" : "flag.fill")
                .font(.system(size: 48))
                .foregroundStyle(playerWon ? PepTheme.amber : PepTheme.textSecondary)

            Text(playerWon ? "Match Won!" : "Match Lost")
                .font(.title.weight(.bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text(tennisVM.liveScore.sets.map(\.display).joined(separator: "  "))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)

            Button {
                stopTimer()
                tennisVM.matchDuration = max(elapsedSeconds / 60, 1)
                tennisVM.logFromLiveScore()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Match")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accentColor)
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.scalePrimary)
            .padding(.horizontal, 24)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 20) {
            statCounter(label: "Aces", value: $tennisVM.currentStats.aces, color: accentColor)
            statCounter(label: "Double Faults", value: $tennisVM.currentStats.doubleFaults, color: .red)
            statCounter(label: "Winners", value: $tennisVM.currentStats.winners, color: .green)
            statCounter(label: "UE", value: $tennisVM.currentStats.unforcedErrors, color: .orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            PepTheme.cardSurface
                .shadow(color: .black.opacity(0.5), radius: 20, y: -8)
                .ignoresSafeArea()
        )
    }

    private func statCounter(label: String, value: Binding<Int>, color: Color) -> some View {
        VStack(spacing: 4) {
            Button { value.wrappedValue += 1 } label: {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds = Int(Date().timeIntervalSince(matchStartTime))
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
