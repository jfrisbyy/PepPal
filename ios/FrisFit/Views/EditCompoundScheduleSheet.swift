import SwiftUI

struct EditCompoundScheduleSheet: View {
    let protocolData: PeptideProtocol
    let compound: ProtocolCompound
    let onSave: (Double, String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var doseText: String = ""
    @State private var doseUnit: CompoundUnit = .mcg
    @State private var frequency: String = "1x daily"
    @State private var showDeleteConfirm: Bool = false

    private let frequencyOptions: [String] = [
        "1x daily", "2x daily", "3x daily",
        "1x weekly", "2x weekly", "3x weekly",
        "EOD", "As needed"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    card {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Dose")
                            HStack {
                                TextField("Dose", text: $doseText)
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .keyboardType(.decimalPad)
                                Text(doseUnit.rawValue)
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .padding(12)
                            .background(PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Frequency")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(frequencyOptions, id: \.self) { option in
                                    let selected = frequency == option
                                    Button {
                                        frequency = option
                                    } label: {
                                        Text(option)
                                            .font(.system(.subheadline, weight: .semibold))
                                            .foregroundStyle(selected ? .white : PepTheme.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(selected ? protocolData.goal.color : PepTheme.elevated.opacity(0.5))
                                            .clipShape(.rect(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                    .sensoryFeedback(.selection, trigger: frequency)
                                }
                            }
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Details")
                            detailRow(label: "Route", value: compound.injectionRoute.rawValue, icon: "arrow.down.to.line")
                            Divider().overlay(PepTheme.separatorColor)
                            detailRow(label: "Logged Doses", value: "\(loggedCount) total", icon: "list.bullet")
                            if let last = lastLogged {
                                Divider().overlay(PepTheme.separatorColor)
                                detailRow(label: "Last Logged", value: last, icon: "clock")
                            }
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                            Text("Remove Compound")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(Color.red)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(PepTheme.teal)
                    .disabled(Double(doseText) == nil)
                }
            }
            .alert("Remove Compound?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("This removes \(compound.compoundName) from \(protocolData.name). Dose history is preserved.")
            }
            .onAppear(perform: loadCurrentValues)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(protocolData.goal.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: compound.injectionRoute == .oral ? "pill.fill" : (compound.injectionRoute == .nasal ? "nose.fill" : "syringe.fill"))
                    .font(.title3)
                    .foregroundStyle(protocolData.goal.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(compound.compoundName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(protocolData.name)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(PepTheme.textSecondary)
            .tracking(0.5)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderBottom.opacity(0.5), lineWidth: 0.5)
            )
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 20)
            Text(label)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private var loggedCount: Int {
        protocolData.doseLog.filter { $0.compoundName == compound.compoundName }.count
    }

    private var lastLogged: String? {
        guard let last = protocolData.doseLog
            .filter({ $0.compoundName == compound.compoundName })
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first else { return nil }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: last.timestamp, relativeTo: Date())
    }

    private func loadCurrentValues() {
        doseUnit = CompoundUnitHelper.unit(for: compound.compoundName)
        let displayVal = CompoundUnitHelper.fromMcg(compound.doseMcg, for: compound.compoundName)
        doseText = displayVal == displayVal.rounded() && displayVal >= 1
            ? String(Int(displayVal))
            : String(format: "%.2g", displayVal)
        frequency = compound.frequency
    }

    private func save() {
        guard let value = Double(doseText) else { return }
        let mcg = CompoundUnitHelper.toMcg(value, for: compound.compoundName)
        onSave(mcg, frequency)
        dismiss()
    }
}
