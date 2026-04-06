import SwiftUI

struct BasketballShotChartInputView: View {
    @Bindable var bbVM: BasketballViewModel
    let accentColor: Color

    @State private var selectedZone: ShotZone? = nil

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 220

                ZStack {
                    courtLines(width: w, height: h)

                    ForEach(ShotZone.allCases) { zone in
                        let pos = zone.position
                        let isSelected = selectedZone == zone

                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedZone = zone
                            }
                        } label: {
                            Circle()
                                .fill(isSelected ? accentColor : PepTheme.elevated.opacity(0.8))
                                .frame(width: isSelected ? 32 : 26, height: isSelected ? 32 : 26)
                                .overlay(
                                    Text(zoneAbbreviation(zone))
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                                )
                                .shadow(color: isSelected ? accentColor.opacity(0.4) : .clear, radius: 6)
                        }
                        .position(x: w * pos.x, y: h * pos.y)
                    }

                    ForEach(bbVM.shotChartEntries) { entry in
                        let pos = entry.zone.position
                        let offset = CGPoint(
                            x: CGFloat.random(in: -8...8),
                            y: CGFloat.random(in: -8...8)
                        )
                        Circle()
                            .fill(entry.made ? .green.opacity(0.6) : .red.opacity(0.5))
                            .frame(width: 5, height: 5)
                            .position(x: w * pos.x + offset.x, y: h * pos.y + offset.y)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: h)
            }
            .frame(height: 220)

            if let zone = selectedZone {
                HStack(spacing: 12) {
                    Text(zone.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Spacer()

                    Button {
                        bbVM.addShotEntry(zone: zone, made: false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Miss")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.8))
                        .clipShape(.rect(cornerRadius: 10))
                    }

                    Button {
                        bbVM.addShotEntry(zone: zone, made: true)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Made")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.green)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
                .padding(12)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private func courtLines(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(PepTheme.elevated.opacity(0.6), lineWidth: 1)
                .frame(width: width, height: height)

            RoundedRectangle(cornerRadius: 2)
                .stroke(PepTheme.elevated.opacity(0.5), lineWidth: 1)
                .frame(width: width * 0.32, height: height * 0.35)
                .offset(y: height * 0.325)

            Circle()
                .stroke(PepTheme.elevated.opacity(0.4), lineWidth: 1)
                .frame(width: width * 0.22, height: width * 0.22)
                .offset(y: height * 0.15)

            Path { path in
                let centerX = width / 2
                let radius = width * 0.42
                let startAngle = Angle(degrees: 160)
                let endAngle = Angle(degrees: 20)
                path.addArc(center: CGPoint(x: centerX, y: height), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            }
            .stroke(PepTheme.elevated.opacity(0.4), lineWidth: 1)

            Rectangle()
                .fill(PepTheme.elevated.opacity(0.08))
                .frame(width: width * 0.32, height: height * 0.35)
                .offset(y: height * 0.325)
        }
    }

    private func zoneAbbreviation(_ zone: ShotZone) -> String {
        switch zone {
        case .paint: "PT"
        case .midRangeLeft: "ML"
        case .midRangeRight: "MR"
        case .freeThrow: "FT"
        case .leftElbow: "LE"
        case .rightElbow: "RE"
        case .leftBaseline: "LB"
        case .rightBaseline: "RB"
        case .topOfKey: "TK"
        case .leftWing3: "L3"
        case .rightWing3: "R3"
        case .leftCorner3: "LC"
        case .rightCorner3: "RC"
        case .topArc3: "T3"
        }
    }
}
