import SwiftUI

struct GPSSignalBadge: View {
    let signal: GPSSignalQuality

    private var signalColor: Color {
        switch signal {
        case .none: .red
        case .poor: .orange
        case .fair: .yellow
        case .good: .green
        case .excellent: .green
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: signal.iconName)
                .font(.system(size: 9))
                .foregroundStyle(signalColor)

            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(1...4, id: \.self) { bar in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(bar <= signal.barCount ? signalColor : Color.white.opacity(0.25))
                        .frame(width: 3, height: CGFloat(bar) * 3 + 2)
                }
            }

            Text("GPS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.55))
        .clipShape(Capsule())
    }
}
