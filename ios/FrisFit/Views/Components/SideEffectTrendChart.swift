import SwiftUI
import Charts

struct SideEffectTrendChart: View {
    let points: [ProtocolDetailViewModel.SideEffectTrendPoint]

    var body: some View {
        Chart {
            ForEach(points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Severity", p.severity)
                )
                .foregroundStyle(by: .value("Effect", p.effect))
                .interpolationMethod(.catmullRom)
                .symbol(.circle)
            }
        }
        .chartYScale(domain: 0...4)
        .chartYAxis {
            AxisMarks(values: [1, 2, 3, 4]) { v in
                AxisGridLine().foregroundStyle(PepTheme.elevated)
                AxisValueLabel {
                    if let i = v.as(Int.self) {
                        Text(label(for: i))
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: false)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .chartLegend(position: .bottom, spacing: 8)
    }

    private func label(for i: Int) -> String {
        switch i {
        case 1: return "Mild"
        case 2: return "Mod"
        case 3: return "Sig"
        case 4: return "Sev"
        default: return ""
        }
    }
}
