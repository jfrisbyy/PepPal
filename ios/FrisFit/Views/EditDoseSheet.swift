import SwiftUI

struct EditDoseSheet: View {
    @Bindable var viewModel: ProtocolDetailViewModel
    let dose: DoseLogEntry
    @Environment(\.dismiss) private var dismiss

    @State private var doseText: String
    @State private var site: InjectionSite
    @State private var notes: String
    @State private var timestamp: Date
    @State private var showDeleteConfirm: Bool = false

    init(viewModel: ProtocolDetailViewModel, dose: DoseLogEntry) {
        self.viewModel = viewModel
        self.dose = dose
        let display = CompoundUnitHelper.fromMcg(dose.doseMcg, for: dose.compoundName)
        let initial = display == display.rounded() && display >= 1
            ? String(Int(display))
            : String(format: "%.2g", display)
        _doseText = State(initialValue: initial)
        _site = State(initialValue: dose.injectionSite)
        _notes = State(initialValue: dose.notes)
        _timestamp = State(initialValue: dose.timestamp)
    }

    private var doseMcg: Double {
        let display = Double(doseText) ?? 0
        return CompoundUnitHelper.toMcg(display, for: dose.compoundName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard
                    doseField
                    timeField
                    sitePicker
                    notesField
                    actionButtons
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Edit Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.updateDose(dose, doseMcg: doseMcg, site: site, notes: notes, timestamp: timestamp)
                        dismiss()
                    }
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                    .disabled(doseText.isEmpty || doseMcg <= 0)
                }
            }
            .confirmationDialog("Delete this dose log?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteDose(dose)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PepTheme.teal.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "syringe.fill")
                        .foregroundStyle(PepTheme.teal)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(dose.compoundName)
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(dose.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var doseField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dose")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            HStack {
                TextField("Dose", text: $doseText)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .keyboardType(.decimalPad)
                Text(CompoundUnitHelper.unit(for: dose.compoundName).rawValue)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var timeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("When")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            DatePicker("", selection: $timestamp, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var sitePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Injection Site")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(InjectionSite.allCases) { s in
                    let isSel = site == s
                    Button {
                        site = s
                    } label: {
                        Text(s.shortName)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(isSel ? PepTheme.invertedText : PepTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSel ? PepTheme.teal : PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            TextField("Add notes...", text: $notes, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(3...6)
                .padding(12)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                viewModel.logSideEffect(linkedTo: dose)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Log side effect for this dose")
                }
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(PepTheme.amber, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("Delete log")
                }
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1), in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}
