import SwiftUI
import Charts

struct BiomarkerTrackingView: View {
    @State private var store = BiomarkerStore.shared
    @State private var showAdd: Bool = false
    @State private var selectedKind: BiomarkerKind = .weight

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                kindPicker
                chartCard
                historyCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(PepTheme.teal)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddBiomarkerSheet(defaultKind: selectedKind) { entry in
                store.add(entry)
            }
            .presentationDetents([.medium])
        }
    }

    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BiomarkerKind.allCases) { kind in
                    let isOn = selectedKind == kind
                    Button {
                        withAnimation { selectedKind = kind }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: kind.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(kind.rawValue)
                                .font(.system(.caption, weight: .semibold))
                        }
                        .foregroundStyle(isOn ? PepTheme.invertedText : PepTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isOn ? kind.color : PepTheme.elevated)
                        .clipShape(.capsule)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    private var series: [BiomarkerEntry] { store.series(selectedKind, within: 365) }

    private var chartCard: some View {
        GlassCard(accent: selectedKind.color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedKind.rawValue)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    if let latest = store.latest(selectedKind) {
                        Text("\(formatVal(latest.value)) \(selectedKind.unit)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(selectedKind.color)
                    }
                }

                if let delta = store.delta(selectedKind, windowDays: 30) {
                    HStack(spacing: 6) {
                        Image(systemName: delta.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(delta.change >= 0 ? "+" : "")\(String(format: "%.1f", delta.change)) \(selectedKind.unit) · 30d")
                            .font(.system(.caption, weight: .bold))
                    }
                    .foregroundStyle(deltaColor(delta.change))
                }

                if series.isEmpty {
                    emptyChart
                } else {
                    Chart(series) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("Value", pt.value))
                            .foregroundStyle(selectedKind.color)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", pt.date), y: .value("Value", pt.value))
                            .foregroundStyle(selectedKind.color)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 180)
                }
            }
        }
    }

    private var emptyChart: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedKind.icon)
                .font(.system(size: 32))
                .foregroundStyle(selectedKind.color.opacity(0.5))
            Text("No entries yet")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Text("Tap + to log your first \(selectedKind.rawValue.lowercased()) reading.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    private var historyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("HISTORY")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                if series.isEmpty {
                    Text("No history yet.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                } else {
                    ForEach(series.reversed()) { entry in
                        HStack {
                            Text(entry.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                            Spacer()
                            Text("\(formatVal(entry.value)) \(selectedKind.unit)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Button {
                                store.remove(entry)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                            }
                        }
                        if entry.id != series.first?.id {
                            Rectangle().fill(PepTheme.separatorColor).frame(height: 0.5)
                        }
                    }
                }
            }
        }
    }

    private func formatVal(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }

    private func deltaColor(_ change: Double) -> Color {
        let desiredDown = selectedKind.betterDirection == .down
        let isImproving = desiredDown ? change < 0 : change > 0
        return isImproving ? .green : (change == 0 ? PepTheme.textSecondary : PepTheme.amber)
    }
}

struct AddBiomarkerSheet: View {
    let defaultKind: BiomarkerKind
    let onSave: (BiomarkerEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var kind: BiomarkerKind
    @State private var valueText: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""

    init(defaultKind: BiomarkerKind, onSave: @escaping (BiomarkerEntry) -> Void) {
        self.defaultKind = defaultKind
        self.onSave = onSave
        _kind = State(initialValue: defaultKind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Metric") {
                    Picker("Metric", selection: $kind) {
                        ForEach(BiomarkerKind.allCases) { k in
                            Label(k.rawValue, systemImage: k.icon).tag(k)
                        }
                    }
                }
                Section("Value") {
                    HStack {
                        TextField("0", text: $valueText)
                            .keyboardType(.decimalPad)
                        Text(kind.unit).foregroundStyle(PepTheme.textSecondary)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }
                Section("Notes") {
                    TextField("Optional", text: $note, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Log Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let v = Double(valueText) else { return }
                        onSave(BiomarkerEntry(kind: kind, value: v, date: date, note: note))
                        dismiss()
                    }
                    .disabled(Double(valueText) == nil)
                    .bold()
                }
            }
        }
    }
}
