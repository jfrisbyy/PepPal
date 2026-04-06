import SwiftUI

struct MiniBarChart: View {
    let data: [DailyDataPoint]
    var barColor: Color = PepTheme.teal
    var height: CGFloat = 100

    private var maxValue: Double {
        data.map(\.value).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(data) { point in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [barColor, barColor.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(4, height * (point.value / maxValue)))

                    Text(point.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height + 18)
    }
}

struct MiniLineChart: View {
    let data: [DailyDataPoint]
    var lineColor: Color = PepTheme.teal
    var height: CGFloat = 80

    private var minValue: Double {
        (data.map(\.value).min() ?? 0) - 1
    }

    private var maxValue: Double {
        (data.map(\.value).max() ?? 1) + 1
    }

    private var range: Double {
        let r = maxValue - minValue
        return r > 0 ? r : 1
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    Path { path in
                        guard data.count > 1 else { return }
                        for (index, point) in data.enumerated() {
                            let x = w * CGFloat(index) / CGFloat(data.count - 1)
                            let y = h - h * CGFloat((point.value - minValue) / range)
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    Path { path in
                        guard data.count > 1 else { return }
                        for (index, point) in data.enumerated() {
                            let x = w * CGFloat(index) / CGFloat(data.count - 1)
                            let y = h - h * CGFloat((point.value - minValue) / range)
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        let lastX = w
                        path.addLine(to: CGPoint(x: lastX, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [lineColor.opacity(0.25), lineColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                        let x = w * CGFloat(index) / CGFloat(data.count - 1)
                        let y = h - h * CGFloat((point.value - minValue) / range)
                        Circle()
                            .fill(lineColor)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: height)

            HStack {
                ForEach(data) { point in
                    Text(point.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
            }
        }
    }
}
