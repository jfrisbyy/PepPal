import SwiftUI

/// Editorial scroll-ruler input for weights and reps.
/// A horizontal ticker snaps to whole values (or 2.5lb increments for weight).
/// Quick increment chips remain for fine adjustments. The active value is
/// rendered in serif display type to match the rest of the app's premium feel.
struct NumberInputView: View {
    @Binding var value: String
    let isWeight: Bool
    let onDone: () -> Void
    let onIncrement: (Double) -> Void

    @State private var selectedTick: Int? = nil
    @State private var rulerWidth: CGFloat = 0
    /// True while we're updating `selectedTick` from an external `value` change,
    /// so the scroll-driven `onChange` doesn't write the same value back and
    /// fight the user's gesture.
    @State private var isSyncingFromValue: Bool = false

    private var step: Double { isWeight ? 2.5 : 1 }
    /// Reps go in single-rep ticks but extend well past the typical 60 cap so
    /// high-rep work (cardio, calisthenics, AMRAPs) still snaps cleanly.
    private var maxValue: Double { isWeight ? 600 : 200 }
    private var tickCount: Int { Int(maxValue / step) + 1 }

    private var currentValue: Double {
        Double(value) ?? 0
    }

    private var unitLabel: String {
        isWeight ? "LBS" : "REPS"
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(PepTheme.textSecondary.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)

            valueDisplay
                .padding(.top, 14)
                .padding(.bottom, 8)

            scrollRuler
                .frame(height: 64)
                .padding(.bottom, 14)

            Divider()
                .background(PepTheme.elevated)
                .padding(.horizontal, 20)

            quickAdjustRow
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)

            doneButton
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(PepTheme.cardSurface)
        .onAppear { syncTickFromValue() }
        .onChange(of: selectedTick) { _, newTick in
            // Ignore changes that we initiated from `value` syncing back into the ruler.
            guard !isSyncingFromValue, let newTick else { return }
            let v = Double(newTick) * step
            let formatted = formatted(v)
            if formatted != value {
                value = formatted
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    // MARK: - Value display

    private var valueDisplay: some View {
        VStack(spacing: 6) {
            Text(unitLabel)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))

            Text(displayedValueString)
                .font(.system(size: 56, weight: .semibold, design: .serif))
                .kerning(-0.5)
                .foregroundStyle(PepTheme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: displayedValueString)
        }
        .frame(maxWidth: .infinity)
    }

    private var displayedValueString: String {
        if value.isEmpty { return "0" }
        return value
    }

    // MARK: - Scroll ruler

    private var scrollRuler: some View {
        GeometryReader { geo in
            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { i in
                            tickMark(index: i)
                                .frame(width: tickSpacing, height: 64)
                                .id(i)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, max(0, geo.size.width / 2 - tickSpacing / 2))
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $selectedTick, anchor: .center)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

                // Center indicator
                Rectangle()
                    .fill(PepTheme.teal)
                    .frame(width: 2, height: 36)
                    .shadow(color: PepTheme.teal.opacity(0.4), radius: 4)
                    .allowsHitTesting(false)
            }
        }
    }

    private var tickSpacing: CGFloat { 12 }

    private func tickMark(index i: Int) -> some View {
        let v = Double(i) * step
        let isMajor: Bool = isWeight ? (i % 4 == 0) : (i % 5 == 0)
        let isMid: Bool = isWeight ? (i % 2 == 0) : false
        return VStack(spacing: 6) {
            Rectangle()
                .fill(PepTheme.textSecondary.opacity(isMajor ? 0.85 : (isMid ? 0.5 : 0.25)))
                .frame(width: 1, height: isMajor ? 26 : (isMid ? 16 : 10))
            if isMajor {
                Text(majorLabel(v))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
            } else {
                Spacer().frame(height: 12)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func majorLabel(_ v: Double) -> String {
        if isWeight { return "\(Int(v))" }
        return "\(Int(v))"
    }

    // MARK: - Quick adjust + done

    private var quickAdjustRow: some View {
        HStack(spacing: 10) {
            incrementButton(label: isWeight ? "−10" : "−5", amount: isWeight ? -10 : -5)
            incrementButton(label: isWeight ? "−5" : "−1", amount: isWeight ? -5 : -1)
            Spacer(minLength: 4)
            incrementButton(label: isWeight ? "+5" : "+1", amount: isWeight ? 5 : 1, accent: true)
            incrementButton(label: isWeight ? "+10" : "+5", amount: isWeight ? 10 : 5, accent: true)
        }
    }

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.system(size: 14, weight: .semibold))
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: false)
    }

    private func incrementButton(label: String, amount: Double, accent: Bool = false) -> some View {
        Button {
            onIncrement(amount)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(accent ? PepTheme.teal : PepTheme.textSecondary)
                .frame(minWidth: 56)
                .frame(height: 36)
                .padding(.horizontal, 6)
                .background(
                    Capsule()
                        .strokeBorder(
                            accent ? PepTheme.teal.opacity(0.45) : PepTheme.textSecondary.opacity(0.25),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func syncTickFromValue() {
        let v = currentValue
        let tick = Int((v / step).rounded())
        let clamped = max(0, min(tickCount - 1, tick))
        if selectedTick != clamped {
            isSyncingFromValue = true
            selectedTick = clamped
            // Re-enable scroll-driven updates on the next runloop tick, after
            // SwiftUI has propagated the new scrollPosition.
            DispatchQueue.main.async {
                isSyncingFromValue = false
            }
        }
    }

    private func formatted(_ v: Double) -> String {
        if isWeight {
            return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
        }
        return "\(Int(v))"
    }
}
