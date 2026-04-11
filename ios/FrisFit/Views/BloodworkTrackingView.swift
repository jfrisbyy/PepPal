import SwiftUI

@Observable
final class BloodworkTrackingViewModel {
    var entries: [BloodworkEntry] = []
    var isLoading: Bool = true
    var showAddEntry: Bool = false
    var errorMessage: String?

    private let service = BloodworkService.shared

    func loadEntries() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let userId = try AuthService.shared.currentUserId()
            let supaEntries = try await service.fetchEntries(userId: userId)
            var loaded: [BloodworkEntry] = []
            for entry in supaEntries {
                guard let entryId = entry.id else { continue }
                let results = try await service.fetchBiomarkerResults(entryId: entryId)
                loaded.append(service.toBloodworkEntry(entry, results: results))
            }
            entries = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: BloodworkEntry) async {
        let idStr = entry.id.uuidString.lowercased()
        do {
            try await service.deleteEntry(entryId: idStr)
            entries.removeAll { $0.id == entry.id }
        } catch {}
    }

    func addEntry(date: Date, notes: String, results: [BiomarkerResult]) async {
        do {
            let userId = try AuthService.shared.currentUserId()
            let created = try await service.createEntry(userId: userId, date: date, notes: notes, photoUrl: nil)
            guard let entryId = created.id else { return }
            try await service.addBiomarkerResults(entryId: entryId, results: results)
            await loadEntries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BloodworkTrackingView: View {
    @State private var viewModel = BloodworkTrackingViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if viewModel.entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.entries) { entry in
                        BloodworkEntryCard(entry: entry) {
                            Task { await viewModel.deleteEntry(entry) }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Bloodwork Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { viewModel.showAddEntry = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .task { await viewModel.loadEntries() }
        .refreshable { await viewModel.loadEntries() }
        .sheet(isPresented: $viewModel.showAddEntry) {
            AddBloodworkEntrySheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "drop.fill")
                .font(.system(size: 48))
                .foregroundStyle(PepTheme.teal.opacity(0.5))
            Text("No Bloodwork Entries")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Tap + to log your first lab results and track biomarkers over time.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                viewModel.showAddEntry = true
            } label: {
                Text("Add Lab Results")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(PepTheme.teal)
                    .clipShape(.capsule)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

private struct BloodworkEntryCard: View {
    let entry: BloodworkEntry
    let onDelete: () -> Void
    @State private var showDeleteConfirm: Bool = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateFormatter.string(from: entry.date))
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("\(entry.results.count) biomarkers logged")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    statusBadge
                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundStyle(PepTheme.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                }

                if !entry.results.isEmpty {
                    let grouped = Dictionary(grouping: entry.results) { $0.biomarker.category }
                    ForEach(BiomarkerCategory.allCases, id: \.self) { category in
                        if let results = grouped[category], !results.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 10))
                                        .foregroundStyle(category.color)
                                    Text(category.rawValue)
                                        .font(.system(.caption2, weight: .semibold))
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                ForEach(results) { result in
                                    HStack {
                                        Text(result.biomarker.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(PepTheme.textPrimary)
                                        Spacer()
                                        Text("\(result.value, specifier: "%.1f") \(result.biomarker.unit)")
                                            .font(.system(.caption, design: .rounded, weight: .semibold))
                                            .foregroundStyle(result.status.color)
                                    }
                                }
                            }
                        }
                    }
                }

                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This will permanently remove this bloodwork entry.")
        }
    }

    private var statusBadge: some View {
        let outOfRange = entry.results.filter { !$0.isInRange }.count
        return Group {
            if outOfRange > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("\(outOfRange) flagged")
                        .font(.system(.caption2, weight: .semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.12))
                .clipShape(.capsule)
            } else if !entry.results.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("All normal")
                        .font(.system(.caption2, weight: .semibold))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.green.opacity(0.12))
                .clipShape(.capsule)
            }
        }
    }
}

private struct AddBloodworkEntrySheet: View {
    let viewModel: BloodworkTrackingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var selectedBiomarkers: Set<Biomarker> = []
    @State private var values: [Biomarker: String] = [:]
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Entry Date")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Biomarkers")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)

                            ForEach(BiomarkerCategory.allCases, id: \.self) { category in
                                let markers = Biomarker.allCases.filter { $0.category == category }
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 12))
                                            .foregroundStyle(category.color)
                                        Text(category.rawValue)
                                            .font(.system(.caption, weight: .bold))
                                            .foregroundStyle(PepTheme.textSecondary)
                                    }
                                    .padding(.top, 4)

                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 8) {
                                        ForEach(markers) { marker in
                                            Button {
                                                if selectedBiomarkers.contains(marker) {
                                                    selectedBiomarkers.remove(marker)
                                                } else {
                                                    selectedBiomarkers.insert(marker)
                                                }
                                            } label: {
                                                Text(marker.rawValue)
                                                    .font(.system(.caption, weight: .medium))
                                                    .foregroundStyle(selectedBiomarkers.contains(marker) ? .white : PepTheme.textPrimary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .frame(maxWidth: .infinity)
                                                    .background(selectedBiomarkers.contains(marker) ? category.color : PepTheme.elevated)
                                                    .clipShape(.rect(cornerRadius: 8))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !selectedBiomarkers.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Enter Values")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)

                                ForEach(Array(selectedBiomarkers).sorted(by: { $0.rawValue < $1.rawValue })) { marker in
                                    HStack(spacing: 12) {
                                        Text(marker.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(PepTheme.textPrimary)
                                            .frame(width: 110, alignment: .leading)

                                        TextField("0.0", text: Binding(
                                            get: { values[marker] ?? "" },
                                            set: { values[marker] = $0 }
                                        ))
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(PepTheme.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(PepTheme.elevated)
                                        .clipShape(.rect(cornerRadius: 8))

                                        Text(marker.unit)
                                            .font(.caption2)
                                            .foregroundStyle(PepTheme.textSecondary)
                                            .frame(width: 50, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            TextField("Fasting, lab name, etc.", text: $notes)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary)
                                .padding(12)
                                .background(PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Add Lab Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundStyle(selectedBiomarkers.isEmpty ? PepTheme.textSecondary : PepTheme.teal)
                        }
                    }
                    .disabled(selectedBiomarkers.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let results: [BiomarkerResult] = selectedBiomarkers.compactMap { marker in
            guard let valStr = values[marker], let val = Double(valStr), val > 0 else { return nil }
            return BiomarkerResult(biomarker: marker, value: val)
        }
        guard !results.isEmpty else { return }
        await viewModel.addEntry(date: date, notes: notes, results: results)
        dismiss()
    }
}
