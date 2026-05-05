import SwiftUI

struct CostTrackingSheet: View {
    let protocolData: PeptideProtocol
    @Environment(\.dismiss) private var dismiss

    @State private var costs: [CompoundCost] = []
    @State private var editingCompound: String?
    @State private var priceInput: String = ""
    @State private var vialInput: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView().padding(.top, 40)
                    } else {
                        summaryCard
                        ForEach(protocolData.compounds) { compound in
                            compoundRow(compound)
                        }
                        disclaimer
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Cost Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                        .fontWeight(.semibold)
                }
            }
            .task { await loadCosts() }
        }
    }

    private var totalMonthlySpend: Double {
        protocolData.compounds.reduce(0.0) { total, compound in
            guard let cost = costs.first(where: { $0.compoundName == compound.compoundName }) else { return total }
            let freq = dosesPerWeek(compound.frequency)
            return total + CostTrackingService.monthlySpend(cost: cost, doseMcg: compound.doseMcg, dosesPerWeek: freq)
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 8) {
            Text("Estimated Monthly Spend")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Text(formatCurrency(totalMonthlySpend))
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.teal)
            Text("Based on logged vial pricing and current dose frequencies.")
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
    }

    @ViewBuilder
    private func compoundRow(_ compound: ProtocolCompound) -> some View {
        let cost = costs.first { $0.compoundName == compound.compoundName }
        let freq = dosesPerWeek(compound.frequency)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(compound.compoundName)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Button {
                    editingCompound = compound.compoundName
                    priceInput = cost.map { String(format: "%g", $0.pricePerVial) } ?? ""
                    vialInput = cost.map { String(format: "%g", $0.vialSizeMg) } ?? compound.vialSizeMg.map { String(format: "%g", $0) } ?? ""
                } label: {
                    Text(cost == nil ? "Set Price" : "Edit")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
            }

            if let cost {
                let perDose = CostTrackingService.costPerDose(cost: cost, doseMcg: compound.doseMcg)
                let monthly = CostTrackingService.monthlySpend(cost: cost, doseMcg: compound.doseMcg, dosesPerWeek: freq)

                HStack(spacing: 8) {
                    costStat(label: "Vial", value: formatCurrency(cost.pricePerVial))
                    costStat(label: "Per Dose", value: formatCurrency(perDose))
                    costStat(label: "Monthly", value: formatCurrency(monthly))
                }
            } else {
                Text("No price set — tap Set Price to add vial cost.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
        .sheet(isPresented: Binding(
            get: { editingCompound == compound.compoundName },
            set: { if !$0 { editingCompound = nil } }
        )) {
            priceEditor(for: compound)
                .presentationDetents([.medium])
        }
    }

    private func costStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func priceEditor(for compound: ProtocolCompound) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Price Per Vial (USD)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    TextField("0.00", text: $priceInput)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Vial Size (mg)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    TextField("5", text: $vialInput)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 10))
                }

                Button {
                    Task { await saveCost(for: compound) }
                } label: {
                    Text("Save")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.teal, in: .rect(cornerRadius: 12))
                }
                .disabled(Double(priceInput) == nil || Double(vialInput) == nil)

                Spacer()
            }
            .padding()
            .appBackground()
            .navigationTitle(compound.compoundName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { editingCompound = nil }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("Estimates assume the full vial is used and ignore reconstitution overdraw. Real cost per dose may vary.")
            .font(.caption2)
            .foregroundStyle(PepTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    private func loadCosts() async {
        isLoading = true
        defer { isLoading = false }
        guard let protoId = protocolData.supabaseId else { return }
        do {
            costs = try await CostTrackingService.shared.fetchCosts(protocolId: protoId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveCost(for compound: ProtocolCompound) async {
        guard let price = Double(priceInput), let vial = Double(vialInput), let protoId = protocolData.supabaseId else { return }
        do {
            try await CostTrackingService.shared.upsertCost(
                protocolId: protoId,
                compoundName: compound.compoundName,
                pricePerVial: price,
                vialSizeMg: vial
            )
            await loadCosts()
            editingCompound = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dosesPerWeek(_ freq: String) -> Double {
        let f = freq.lowercased()
        if f.contains("eod") { return 3.5 }
        if f.contains("3x daily") { return 21 }
        if f.contains("2x daily") || f.contains("twice daily") { return 14 }
        if f.contains("3x weekly") { return 3 }
        if f.contains("2x weekly") { return 2 }
        if f.contains("weekly") { return 1 }
        if f.contains("daily") { return 7 }
        return 7
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value < 10 ? 2 : 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
