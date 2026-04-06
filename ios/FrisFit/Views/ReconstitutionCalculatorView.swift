import SwiftUI

struct ReconstitutionCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var peptideAmountMg: String = ""
    @State private var waterVolumeMl: String = ""
    @State private var desiredDoseMcg: String = ""

    private var peptideMg: Double? { Double(peptideAmountMg) }
    private var waterMl: Double? { Double(waterVolumeMl) }
    private var doseMcg: Double? { Double(desiredDoseMcg) }

    private var concentrationMcgPerMl: Double? {
        guard let mg = peptideMg, let ml = waterMl, mg > 0, ml > 0 else { return nil }
        return (mg * 1000) / ml
    }

    private var unitsToInject: Double? {
        guard let conc = concentrationMcgPerMl, let dose = doseMcg, conc > 0, dose > 0 else { return nil }
        return (dose / conc) * 100
    }

    private var mlToInject: Double? {
        guard let conc = concentrationMcgPerMl, let dose = doseMcg, conc > 0, dose > 0 else { return nil }
        return dose / conc
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard

                    inputSection

                    if concentrationMcgPerMl != nil {
                        resultSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if let units = unitsToInject {
                        syringeVisual(units: units)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    disclaimerBanner
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: concentrationMcgPerMl != nil)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Reconstitution Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(colors: [PepTheme.teal, PepTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: "function")
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Dose Calculator")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Enter your vial info to calculate exact dosing")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            calcInput(
                label: "Peptide Amount",
                placeholder: "5",
                unit: "mg",
                text: $peptideAmountMg,
                icon: "pill.fill",
                color: PepTheme.teal
            )

            calcInput(
                label: "BAC Water Volume",
                placeholder: "2",
                unit: "mL",
                text: $waterVolumeMl,
                icon: "drop.fill",
                color: PepTheme.blue
            )

            calcInput(
                label: "Desired Dose",
                placeholder: "250",
                unit: "mcg",
                text: $desiredDoseMcg,
                icon: "syringe.fill",
                color: .orange
            )
        }
    }

    private func calcInput(label: String, placeholder: String, unit: String, text: Binding<String>, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            HStack(spacing: 8) {
                TextField(placeholder, text: text)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .keyboardType(.decimalPad)

                Text(unit)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var resultSection: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Results")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                }

                if let conc = concentrationMcgPerMl {
                    resultRow(label: "Concentration", value: String(format: "%.0f mcg/mL", conc), icon: "flask.fill", color: PepTheme.teal)
                }

                if let units = unitsToInject {
                    resultRow(label: "Units to Draw", value: String(format: "%.1f units", units), icon: "syringe.fill", color: .orange)
                }

                if let ml = mlToInject {
                    resultRow(label: "Volume to Inject", value: String(format: "%.3f mL", ml), icon: "drop.fill", color: PepTheme.blue)
                }

                if let conc = concentrationMcgPerMl, let mg = peptideMg, let dose = doseMcg, dose > 0 {
                    let totalDoses = (mg * 1000) / dose
                    resultRow(label: "Doses per Vial", value: String(format: "%.0f doses", totalDoses), icon: "number", color: PepTheme.violet)
                }
            }
        }
    }

    private func resultRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.vertical, 2)
    }

    private func syringeVisual(units: Double) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "syringe.fill")
                        .foregroundStyle(.orange)
                    Text("Insulin Syringe (100 units)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(PepTheme.elevated)
                        .frame(height: 32)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(colors: [PepTheme.teal, PepTheme.blue], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(4, CGFloat(min(units / 100.0, 1.0)) * (UIScreen.main.bounds.width - 96)), height: 32)

                    HStack {
                        ForEach([0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100], id: \.self) { tick in
                            if tick == 0 {
                                Rectangle()
                                    .fill(PepTheme.textSecondary.opacity(0.3))
                                    .frame(width: 1, height: tick % 50 == 0 ? 32 : 16)
                            }
                            Spacer()
                            if tick < 100 {
                                Rectangle()
                                    .fill(PepTheme.textSecondary.opacity(0.3))
                                    .frame(width: 1, height: (tick + 10) % 50 == 0 ? 32 : 16)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                HStack {
                    Text("0")
                    Spacer()
                    Text("50")
                    Spacer()
                    Text("100")
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PepTheme.textSecondary)

                Text("Draw to the \(String(format: "%.1f", min(units, 100))) unit mark")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var disclaimerBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title3)
                .foregroundStyle(PepTheme.amber)

            Text("This calculator is for educational purposes only. Always verify dosing with a qualified healthcare professional.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
        }
        .padding(12)
        .background(PepTheme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }
}
