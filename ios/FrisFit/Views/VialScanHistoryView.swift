import SwiftUI

struct VialScanHistoryView: View {
    @State private var history = VialScanHistoryStore.shared
    @State private var selectedEntry: VialScanHistoryEntry? = nil
    let onAction: (ScannedVialLabel, VialScanAction) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            if history.entries.isEmpty {
                emptyState
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(history.entries) { entry in
                        Button { selectedEntry = entry } label: {
                            card(for: entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                history.remove(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Scan History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !history.entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            history.clear()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(PepTheme.teal)
                    }
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            historyDetailSheet(entry)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text("No scans yet")
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Scanned vial labels will appear here so you can re-use them later.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func card(for entry: VialScanHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            thumb(for: entry)
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.scan.compoundName.isEmpty ? "Unknown" : entry.scan.compoundName)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    if entry.scan.isDiluent {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(PepTheme.blue)
                    }
                }
                if let mg = entry.scan.vialSizeMg, mg > 0 {
                    Text("\(formatMg(mg)) mg")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                } else if let ml = entry.scan.diluentVolumeMl, ml > 0 {
                    Text("\(formatMg(ml)) mL")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Text(entry.scannedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
            }
            .padding(10)
        }
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func thumb(for entry: VialScanHistoryEntry) -> some View {
        if let name = entry.labelImageFilename, let img = VialLabelImageStore.shared.load(name) {
            Color(.secondarySystemBackground).overlay {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if !entry.extraImageFilenames.isEmpty {
                    Text("+\(entry.extraImageFilenames.count)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.65), in: .capsule)
                        .padding(6)
                }
            }
        } else {
            Color(.secondarySystemBackground).overlay {
                Image(systemName: "testtube.2")
                    .font(.system(size: 28))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
        }
    }

    private func historyDetailSheet(_ entry: VialScanHistoryEntry) -> some View {
        // Uses the review sheet, but here we don't need to update state.
        // Wrap in a helper that handles the binding.
        HistoryDetailWrapper(entry: entry, onAction: { scan, action in
            selectedEntry = nil
            onAction(scan, action)
        })
    }

    private func formatMg(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2g", d)
    }
}

private struct HistoryDetailWrapper: View {
    let entry: VialScanHistoryEntry
    let onAction: (ScannedVialLabel, VialScanAction) -> Void

    @State private var editable: ScannedVialLabel

    init(entry: VialScanHistoryEntry, onAction: @escaping (ScannedVialLabel, VialScanAction) -> Void) {
        self.entry = entry
        self.onAction = onAction
        _editable = State(initialValue: entry.scan)
    }

    var body: some View {
        let images = entry.allImageFilenames.compactMap { VialLabelImageStore.shared.load($0) }
        VialScanReviewSheet(
            scan: $editable,
            capturedImages: images,
            onChoose: { action in
                onAction(editable, action)
            }
        )
    }
}
