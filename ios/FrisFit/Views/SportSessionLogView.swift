import SwiftUI

struct SportSessionLogView: View {
    @State private var viewModel: SportSessionViewModel
    let onComplete: (SportSession) -> Void

    @Environment(\.dismiss) private var dismiss

    init(sport: Sport, onComplete: @escaping (SportSession) -> Void) {
        let vm = SportSessionViewModel()
        vm.selectedSport = sport
        _viewModel = State(initialValue: vm)
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    sportHeader
                    sessionTypeSection
                    durationSection
                    intensitySection
                    sportSpecificSection
                    fpPreview
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Log Session")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let session = viewModel.createSession()
                    onComplete(session)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        Text("Log Session")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.selectedSport.color)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(
                    PepTheme.background
                        .shadow(color: .black.opacity(0.5), radius: 20, y: -8)
                        .ignoresSafeArea()
                )
            }
        }
    }

    private var sportHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(viewModel.selectedSport.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: viewModel.selectedSport.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(viewModel.selectedSport.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                if viewModel.selectedSport == .custom {
                    TextField("Sport name", text: $viewModel.customSportName)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .tint(viewModel.selectedSport.color)
                } else {
                    Text(viewModel.selectedSport.rawValue)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Text("Enter your session details")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [viewModel.selectedSport.color.opacity(0.25), PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private var sessionTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "SESSION TYPE")

            HStack(spacing: 10) {
                ForEach(SportSessionType.allCases) { type in
                    let isSelected = viewModel.sessionType == type
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            viewModel.sessionType = type
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18))
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelected ? viewModel.selectedSport.color : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? viewModel.selectedSport.color.opacity(0.5) : PepTheme.glassBorderTop, lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "DURATION")

            HStack(spacing: 12) {
                Button { viewModel.durationMinutes = max(5, viewModel.durationMinutes - 5) } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }

                VStack(spacing: 2) {
                    Text("\(viewModel.durationMinutes)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("minutes")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Button { viewModel.durationMinutes = min(300, viewModel.durationMinutes + 5) } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(PepTheme.elevated)
                        .clipShape(Circle())
                }
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                viewModel.durationMinutes = mins
                            }
                        } label: {
                            Text("\(mins)m")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(viewModel.durationMinutes == mins ? .black : PepTheme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(viewModel.durationMinutes == mins ? viewModel.selectedSport.color : PepTheme.elevated)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "INTENSITY")
                Spacer()
                Text("\(viewModel.intensity)/10")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(intensityColor)
            }

            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    ForEach(1...10, id: \.self) { level in
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                viewModel.intensity = level
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(level <= viewModel.intensity ? intensityColor : PepTheme.elevated)
                                .frame(height: 32 + CGFloat(level) * 2)
                        }
                        if level < 10 {
                            Spacer().frame(width: 4)
                        }
                    }
                }

                HStack {
                    Text("Light")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text(intensityLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(intensityColor)
                    Spacer()
                    Text("Max")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    private var intensityColor: Color {
        switch viewModel.intensity {
        case 1...3: .green
        case 4...6: .yellow
        case 7...8: .orange
        default: .red
        }
    }

    private var intensityLabel: String {
        switch viewModel.intensity {
        case 1...2: "Recovery"
        case 3...4: "Light"
        case 5...6: "Moderate"
        case 7...8: "Hard"
        case 9...10: "All-Out"
        default: "Moderate"
        }
    }

    @ViewBuilder
    private var sportSpecificSection: some View {
        switch viewModel.selectedSport {
        case .basketball:
            basketballSection
        case .running:
            runningSection
        case .swimming:
            swimmingSection
        default:
            EmptyView()
        }
    }

    private var basketballSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "GAME STATS")

            VStack(spacing: 12) {
                SportStatRow(label: "Points", value: $viewModel.basketballStats.points, icon: "target", color: .orange)
                Divider().overlay(PepTheme.glassBorderTop)
                SportStatRow(label: "Assists", value: $viewModel.basketballStats.assists, icon: "arrow.turn.up.right", color: .blue)
                Divider().overlay(PepTheme.glassBorderTop)
                SportStatRow(label: "Rebounds", value: $viewModel.basketballStats.rebounds, icon: "arrow.up.and.down", color: .green)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    private var runningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "RUN STATS")

            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 14))
                            .foregroundStyle(.cyan)
                            .frame(width: 28)
                        Text("Distance (mi)")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    TextField("0.0", value: $viewModel.runningStats.distanceMiles, format: .number.precision(.fractionLength(1)))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                }

                Divider().overlay(PepTheme.glassBorderTop)

                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                            .frame(width: 28)
                        Text("Pace (min/mi)")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    TextField("0.0", value: $viewModel.runningStats.paceMinutesPerMile, format: .number.precision(.fractionLength(1)))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                }
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    private var swimmingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "SWIM STATS")

            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        Text("Laps")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button { viewModel.swimmingStats.laps = max(0, viewModel.swimmingStats.laps - 1) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Text("\(viewModel.swimmingStats.laps)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .frame(width: 40)
                        Button { viewModel.swimmingStats.laps += 1 } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Divider().overlay(PepTheme.glassBorderTop)

                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.pool.swim")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        Text("Stroke")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    Picker("Stroke", selection: $viewModel.swimmingStats.stroke) {
                        ForEach(SwimmingStroke.allCases) { stroke in
                            Text(stroke.rawValue).tag(stroke)
                        }
                    }
                    .tint(PepTheme.textPrimary)
                }
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    private var fpPreview: some View {
        EmptyView()
    }
}

private struct SportStatRow: View {
    let label: String
    @Binding var value: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            HStack(spacing: 12) {
                Button { value = max(0, value - 1) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Text("\(value)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 40)
                    .contentTransition(.numericText())
                Button { value += 1 } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
        }
    }
}

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(PepTheme.textSecondary)
            .tracking(1)
    }
}
