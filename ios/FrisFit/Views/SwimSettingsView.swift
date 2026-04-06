import SwiftUI

struct SwimSettingsView: View {
    @Bindable var swimVM: SwimmingViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.2, green: 0.6, blue: 1.0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    poolConfigSection
                    preferencesSection
                    cssTestSection
                    cssHistorySection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(FrisTheme.background.ignoresSafeArea())
            .navigationTitle("Swim Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
        }
    }

    private var poolConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ruler")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Pool Configuration")
                Spacer()
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Pool Length")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Spacer()
                    Picker("", selection: $swimVM.settings.poolLength) {
                        ForEach(PoolLength.allCases) { length in
                            Text(length.rawValue).tag(length)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                }

                if swimVM.settings.poolLength == .custom {
                    HStack {
                        Text("Custom Length (meters)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Spacer()
                        TextField("25", value: $swimVM.settings.customPoolLengthMeters, format: .number)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("m")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FrisTheme.textSecondary)
                    }
                }

                HStack {
                    Text("Pace Unit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Spacer()
                    Picker("", selection: $swimVM.settings.paceUnit) {
                        ForEach(SwimPaceUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Preferences")
                Spacer()
            }

            VStack(spacing: 10) {
                Toggle(isOn: $swimVM.settings.autoDetectStrokes) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 13))
                            .foregroundStyle(accentColor.opacity(0.7))
                        Text("Auto-Detect Strokes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FrisTheme.textPrimary)
                    }
                }
                .tint(accentColor)

                Toggle(isOn: $swimVM.settings.lapAlerts) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(accentColor.opacity(0.7))
                        Text("Lap Alerts")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FrisTheme.textPrimary)
                    }
                }
                .tint(accentColor)

                HStack {
                    Image(systemName: "target")
                        .font(.system(size: 13))
                        .foregroundStyle(accentColor.opacity(0.7))
                    Text("Session Lap Goal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FrisTheme.textPrimary)
                    Spacer()
                    Stepper("\(swimVM.settings.targetLapsPerSession)", value: $swimVM.settings.targetLapsPerSession, in: 10...200, step: 5)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private var cssTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundStyle(FrisTheme.amber)
                HeadlineText(text: "Critical Swim Speed Test")
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("How it works:")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FrisTheme.textPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    stepRow(number: 1, text: "Warm up with 200-400m easy swimming")
                    stepRow(number: 2, text: "Swim 400m all-out, record your time")
                    stepRow(number: 3, text: "Rest 2-3 minutes")
                    stepRow(number: 4, text: "Swim 200m all-out, record your time")
                    stepRow(number: 5, text: "Enter both times below to calculate CSS")
                }

                Text("CSS = (T400 - T200) / (D400 - D200) × 100")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(FrisTheme.textSecondary)
                    .padding(.top, 4)
            }

            CSSInputForm(swimVM: swimVM)
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FrisTheme.textSecondary)
        }
    }

    private var cssHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "CSS History")
                Spacer()
            }

            if swimVM.cssHistory.isEmpty {
                HStack {
                    Spacer()
                    Text("No CSS tests recorded yet")
                        .font(.caption)
                        .foregroundStyle(FrisTheme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(swimVM.cssHistory.sorted(by: { $0.date > $1.date }), id: \.date) { result in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.cssFormatted + " /100m")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)
                            Text(result.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("400m: \(SwimFormatters.formatDuration(result.time400m))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                            Text("200m: \(SwimFormatters.formatDuration(result.time200m))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(FrisTheme.cardSurface.overlay(FrisTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [FrisTheme.glassBorderTop, FrisTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}

struct CSSInputForm: View {
    @Bindable var swimVM: SwimmingViewModel

    @State private var minutes400: Int = 6
    @State private var seconds400: Int = 0
    @State private var minutes200: Int = 2
    @State private var seconds200: Int = 45

    private let accentColor = Color(red: 0.2, green: 0.6, blue: 1.0)

    private var time400: TimeInterval {
        Double(minutes400 * 60 + seconds400)
    }

    private var time200: TimeInterval {
        Double(minutes200 * 60 + seconds200)
    }

    private var calculatedCSS: Double {
        CSSResult.calculate(time400m: time400, time200m: time200)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("400m Time")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FrisTheme.textSecondary)
                    HStack(spacing: 4) {
                        Picker("", selection: $minutes400) {
                            ForEach(0..<20, id: \.self) { m in Text("\(m)").tag(m) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 80)
                        .clipped()
                        Text(":")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Picker("", selection: $seconds400) {
                            ForEach(0..<60, id: \.self) { s in Text(String(format: "%02d", s)).tag(s) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 80)
                        .clipped()
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("200m Time")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FrisTheme.textSecondary)
                    HStack(spacing: 4) {
                        Picker("", selection: $minutes200) {
                            ForEach(0..<20, id: \.self) { m in Text("\(m)").tag(m) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 80)
                        .clipped()
                        Text(":")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(FrisTheme.textPrimary)
                        Picker("", selection: $seconds200) {
                            ForEach(0..<60, id: \.self) { s in Text(String(format: "%02d", s)).tag(s) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 80)
                        .clipped()
                    }
                }
            }

            if calculatedCSS > 0 {
                HStack(spacing: 8) {
                    Text("Calculated CSS:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FrisTheme.textSecondary)
                    Text(SwimFormatters.formatPace(calculatedCSS) + " /100m")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                }
                .padding(.vertical, 6)
            }

            Button {
                guard calculatedCSS > 0 else { return }
                swimVM.addCSSResult(time400m: time400, time200m: time200)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Save CSS Result")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(FrisTheme.amber)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.scalePrimary)
            .opacity(calculatedCSS > 0 ? 1 : 0.5)
            .disabled(calculatedCSS <= 0)
        }
    }
}
