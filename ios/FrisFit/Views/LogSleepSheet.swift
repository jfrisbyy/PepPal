import SwiftUI

struct LogSleepSheet: View {
    /// If provided, edits an existing log instead of creating a new one for last night.
    var existing: ManualSleepLog?
    var onSaved: ((ManualSleepLog) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var sleepVM = SleepLogViewModel.shared

    @State private var bedtime: Date = Self.defaultBedtime()
    @State private var wakeTime: Date = Self.defaultWakeTime()
    @State private var quality: Double = 7
    @State private var notes: String = ""
    @State private var hoursOverride: Double? = nil
    @State private var didLoad: Bool = false
    @FocusState private var notesFocused: Bool

    private var computedHours: Double {
        if let h = hoursOverride { return h }
        let interval = wakeTime.timeIntervalSince(bedtime)
        let h = interval / 3600.0
        return max(0, min(h, 16))
    }

    private var qualityInt: Int { Int(quality.rounded()) }

    private var qualityLabel: String {
        switch qualityInt {
        case ...2: return "Restless"
        case 3...4: return "Poor"
        case 5...6: return "OK"
        case 7...8: return "Good"
        default: return "Excellent"
        }
    }

    private var qualityColor: Color {
        switch qualityInt {
        case ...3: return .red
        case 4...5: return PepTheme.amber
        case 6...7: return PepTheme.teal
        default: return .green
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hoursHero
                    timesCard
                    qualityCard
                    notesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
            .appBackground(accent: PepTheme.violet)
            .navigationTitle(existing == nil ? "Log Sleep" : "Edit Night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveBar
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                if let existing {
                    bedtime = existing.bedtime ?? Self.defaultBedtime()
                    wakeTime = existing.wakeTime ?? Self.defaultWakeTime()
                    quality = Double(existing.quality ?? 7)
                    notes = existing.notes ?? ""
                    if existing.bedtime == nil && existing.wakeTime == nil {
                        hoursOverride = existing.hours
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var hoursHero: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatHours(computedHours))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: computedHours)
            }
            Text("hours of sleep")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            ZStack {
                LinearGradient(
                    colors: [PepTheme.violet.opacity(0.18), PepTheme.violet.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(PepTheme.violet.opacity(0.08))
                    .offset(x: 110, y: -30)
            }
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.violet.opacity(0.25), lineWidth: 0.6)
        )
    }

    private var timesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "bed.double.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.violet)
                    Text("Bedtime & Wake")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    if hoursOverride != nil {
                        Button {
                            hoursOverride = nil
                        } label: {
                            Text("Reset")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PepTheme.teal)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Label("Bedtime", systemImage: "moon.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    DatePicker("", selection: $bedtime, displayedComponents: [.hourAndMinute, .date])
                        .labelsHidden()
                        .onChange(of: bedtime) { _, _ in hoursOverride = nil }
                }

                Divider().background(PepTheme.glassBorderTop)

                HStack {
                    Label("Wake", systemImage: "sunrise.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    DatePicker("", selection: $wakeTime, displayedComponents: [.hourAndMinute, .date])
                        .labelsHidden()
                        .onChange(of: wakeTime) { _, _ in hoursOverride = nil }
                }
            }
        }
    }

    private var qualityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(qualityColor)
                    Text("Quality")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(qualityInt)/10")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("· \(qualityLabel)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(qualityColor)
                    }
                }

                Slider(value: $quality, in: 1...10, step: 1)
                    .tint(qualityColor)
                    .sensoryFeedback(.selection, trigger: qualityInt)

                HStack {
                    Text("Restless")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text("Excellent")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var notesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    Text("Notes")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text("Optional")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                TextField("How did you feel?", text: $notes, axis: .vertical)
                    .focused($notesFocused)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PepTheme.glassBorderTop.opacity(0.3))
                .frame(height: 0.5)
            Button {
                save()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(existing == nil ? "Log Sleep" : "Save")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [PepTheme.violet, PepTheme.violet.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: PepTheme.violet.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.success, trigger: didSaveTrigger)
            .disabled(computedHours <= 0)
            .opacity(computedHours <= 0 ? 0.5 : 1)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    @State private var didSaveTrigger: Bool = false

    private func save() {
        let nightDate: Date = {
            // Anchor to the wake date — that's the day "of" sleep.
            let cal = Calendar.current
            return cal.startOfDay(for: wakeTime)
        }()

        let log = ManualSleepLog(
            id: existing?.id ?? UUID(),
            night: nightDate,
            bedtime: bedtime,
            wakeTime: wakeTime,
            hours: computedHours,
            quality: qualityInt,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            supabaseId: existing?.supabaseId
        )
        let saved = sleepVM.save(log)
        didSaveTrigger.toggle()
        onSaved?(saved)
        dismiss()
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private static func defaultBedtime() -> Date {
        let cal = Calendar.current
        let now = Date()
        // Default to 11pm last night
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = 23
        comps.minute = 0
        let today11pm = cal.date(from: comps) ?? now
        return cal.date(byAdding: .day, value: -1, to: today11pm) ?? now
    }

    private static func defaultWakeTime() -> Date {
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = 7
        comps.minute = 0
        return cal.date(from: comps) ?? now
    }
}
