import SwiftUI

/// Tabular, count-up numeric label — luxe-watch typography.
///
/// Animates from 0 (or `from`) up to the target on appear.
///
/// ```swift
/// AnimatedNumber(value: 1247, suffix: " kcal")
///     .font(.system(.largeTitle, design: .serif, weight: .semibold))
/// ```
struct AnimatedNumber: View {
    let value: Double
    var from: Double = 0
    var suffix: String = ""
    var fractionDigits: Int = 0
    var duration: Double = 0.9

    @State private var displayed: Double = 0
    @State private var hasAnimated: Bool = false

    var body: some View {
        Text(formatted)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                displayed = from
                withAnimation(.easeOut(duration: duration)) {
                    displayed = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: duration * 0.7)) {
                    displayed = newValue
                }
            }
    }

    private var formatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        let n = f.string(from: NSNumber(value: displayed)) ?? "\(displayed)"
        return n + suffix
    }
}
