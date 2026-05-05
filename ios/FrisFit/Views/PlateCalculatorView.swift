import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetWeight: Double
    @State private var barWeight: Double
    @State private var inKg: Bool

    init(initialWeight: Double = 135, inKg: Bool = false) {
        let useKg = inKg || (UserDefaults.standard.string(forKey: "weightUnitPref") == "kg")
        self._inKg = State(initialValue: useKg)
        self._barWeight = State(initialValue: useKg ? 20 : 45)
        self._targetWeight = State(initialValue: initialWeight > 0 ? initialWeight : (useKg ? 60 : 135))
    }

    private var plates: [Double] {
        StrengthCalculators.platesPerSide(target: targetWeight, barWeight: barWeight, inKg: inKg)
    }

    private var loadedTotal: Double {
        plates.reduce(0) { $0 + $1 } * 2 + barWeight
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    targetCard
                    barVisualization
                    plateList
                }
                .padding()
            }
            .appBackground()
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var targetCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Picker("Unit", selection: $inKg) {
                    Text("lbs").tag(false)
                    Text("kg").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .onChange(of: inKg) { _, newValue in
                    barWeight = newValue ? 20 : 45
                }
            }

            Text("\(formatWeight(targetWeight)) \(inKg ? "kg" : "lbs")")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
                .contentTransition(.numericText())

            Slider(value: $targetWeight, in: barWeight...(inKg ? 300 : 700), step: inKg ? 1.25 : 2.5)
                .tint(PepTheme.teal)

            HStack {
                Text("Bar")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Picker("Bar", selection: $barWeight) {
                    if inKg {
                        Text("20 kg").tag(20.0)
                        Text("15 kg").tag(15.0)
                        Text("10 kg").tag(10.0)
                    } else {
                        Text("45 lbs").tag(45.0)
                        Text("35 lbs").tag(35.0)
                        Text("15 lbs").tag(15.0)
                    }
                }
                .pickerStyle(.menu)
                .tint(PepTheme.teal)
            }
        }
        .padding(20)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var barVisualization: some View {
        VStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(plates.reversed().indices, id: \.self) { i in
                    plateShape(plates.reversed()[i])
                }
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 80, height: 6)
                ForEach(plates.indices, id: \.self) { i in
                    plateShape(plates[i])
                }
            }
            .frame(height: 100)

            Text("Loaded: \(formatWeight(loadedTotal)) \(inKg ? "kg" : "lbs")")
                .font(.caption.weight(.medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private func plateShape(_ weight: Double) -> some View {
        let color: Color = {
            switch weight {
            case 45, 20: return .red
            case 35, 15: return .blue
            case 25, 10: return .green
            case 10, 5: return .white
            case 5, 2.5: return .orange
            default: return .gray
            }
        }()
        let height: CGFloat = {
            switch weight {
            case 45, 20: return 90
            case 35, 15: return 75
            case 25, 10: return 60
            case 10, 5: return 45
            default: return 30
            }
        }()
        return RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(0.85))
            .frame(width: 12, height: height)
            .overlay {
                Text(formatWeight(weight))
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(.white)
            }
    }

    private var plateList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Per Side")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PepTheme.textSecondary)
            if plates.isEmpty {
                Text("Bar only")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            } else {
                let grouped = Dictionary(grouping: plates, by: { $0 })
                    .sorted { $0.key > $1.key }
                ForEach(grouped, id: \.key) { entry in
                    HStack {
                        Text("\(entry.value.count)×")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.teal)
                            .frame(width: 40, alignment: .leading)
                        Text("\(formatWeight(entry.key)) \(inKg ? "kg" : "lbs") plate")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }
}
