import SwiftUI

struct OneRMCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double = 185
    @State private var reps: Int = 5

    private var oneRM: Double {
        StrengthCalculators.estimated1RM(weight: weight, reps: reps)
    }

    private let percentRows: [(pct: Double, label: String)] = [
        (100, "1RM"), (95, "2 reps"), (90, "4 reps"),
        (85, "6 reps"), (80, "8 reps"), (75, "10 reps"),
        (70, "12 reps"), (65, "15 reps"), (60, "20 reps")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    inputCard
                    resultCard
                    percentTable
                }
                .padding()
            }
            .appBackground()
            .navigationTitle("1RM Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var inputCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weight")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text("\(Int(weight)) lbs")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Slider(value: $weight, in: 45...600, step: 5)
                    .tint(PepTheme.teal)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Reps")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    Text("\(reps)")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Slider(value: Binding(get: { Double(reps) }, set: { reps = Int($0) }), in: 1...15, step: 1)
                    .tint(PepTheme.teal)
            }
        }
        .padding(20)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var resultCard: some View {
        VStack(spacing: 6) {
            Text("ESTIMATED 1RM")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(PepTheme.teal)
            Text("\(Int(oneRM)) lbs")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textPrimary)
                .contentTransition(.numericText())
            Text("Avg of Epley & Brzycki formulas")
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(PepTheme.teal.opacity(0.08))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var percentTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("% OF 1RM").frame(maxWidth: .infinity, alignment: .leading)
                Text("WEIGHT").frame(width: 90, alignment: .trailing)
                Text("TARGET").frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold))
            .tracking(1)
            .foregroundStyle(PepTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ForEach(percentRows, id: \.pct) { row in
                HStack {
                    Text("\(Int(row.pct))%")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int(StrengthCalculators.percentOf1RM(oneRM, percent: row.pct))) lbs")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 90, alignment: .trailing)
                    Text(row.label)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Divider()
            }
        }
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
    }
}
