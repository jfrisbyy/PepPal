import SwiftUI

/// Tiny inline medication-level sparkline used inside compact compound rows.
struct CompoundLevelSparkline: View {
    let proto: PeptideProtocol
    let compound: ProtocolCompound
    let color: Color

    var body: some View {
        let profile = PeptidePharmacology.profile(for: compound.compoundName)
        let doses = PKSampleBuilder.dosesFromLog(proto.doseLog, compoundName: compound.compoundName)
        let samples = PKSampleBuilder.samples(doses: doses, profile: profile, range: .sevenDay)

        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxMg = max(0.0001, samples.map(\.mg).max() ?? 0.0001)
            let pastSamples = samples
            let firstT = pastSamples.first?.time ?? Date()
            let lastT = pastSamples.last?.time ?? Date()
            let span = max(1, lastT.timeIntervalSince(firstT))

            ZStack(alignment: .leading) {
                if doses.isEmpty {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(PepTheme.elevated.opacity(0.6))
                        .frame(height: 2)
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    Path { p in
                        for (i, s) in pastSamples.enumerated() {
                            let x = w * CGFloat(s.time.timeIntervalSince(firstT) / span)
                            let y = h - h * CGFloat(s.mg / maxMg)
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h))
                        for s in pastSamples {
                            let x = w * CGFloat(s.time.timeIntervalSince(firstT) / span)
                            let y = h - h * CGFloat(s.mg / maxMg)
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.25), color.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
            }
        }
    }
}
