import SwiftUI

struct VialBatchReviewSheet: View {
    @Binding var items: [VialScannerView.BatchScanItem]
    let onDone: ([VialScannerView.BatchScanItem]) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editingIndex: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header

                    if items.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                            batchRow(item: item, index: idx)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Batch Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDone(items)
                    } label: {
                        Text("Save All (\(saveableCount))")
                            .font(.system(.subheadline, weight: .bold))
                    }
                    .disabled(saveableCount == 0)
                }
            }
            .sheet(item: Binding(get: {
                if let idx = editingIndex, idx < items.count {
                    return EditingWrapper(id: items[idx].id, index: idx)
                }
                return nil
            }, set: { wrap in
                editingIndex = wrap?.index
            })) { wrap in
                if wrap.index < items.count {
                    let images = items[wrap.index].imageFilenames.compactMap { VialLabelImageStore.shared.load($0) }
                    VialScanReviewSheet(
                        scan: Binding(
                            get: { items[wrap.index].scan },
                            set: { items[wrap.index].scan = $0 }
                        ),
                        capturedImages: images,
                        onChoose: { _ in editingIndex = nil }
                    )
                }
            }
        }
    }

    private struct EditingWrapper: Identifiable {
        let id: UUID
        let index: Int
    }

    private var saveableCount: Int {
        items.filter { !$0.scan.compoundName.isEmpty && ($0.scan.vialSizeMg ?? 0) > 0 && !$0.scan.isDiluent }.count
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(items.count) vial\(items.count == 1 ? "" : "s") scanned")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Tap any row to edit. Diluents are kept for reference but skipped when saving to inventory.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 40))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text("No scans yet")
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(.top, 60)
    }

    private func batchRow(item: VialScannerView.BatchScanItem, index: Int) -> some View {
        Button {
            editingIndex = index
        } label: {
            HStack(spacing: 12) {
                thumb(for: item)
                    .frame(width: 62, height: 62)
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.scan.compoundName.isEmpty ? "Unknown" : item.scan.compoundName)
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        if item.scan.isDiluent {
                            Text("DILUENT")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(PepTheme.blue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(PepTheme.blue.opacity(0.15), in: .capsule)
                        }
                    }
                    HStack(spacing: 8) {
                        if let mg = item.scan.vialSizeMg, mg > 0 {
                            subChip("\(formatMg(mg)) mg", "syringe")
                        } else if let ml = item.scan.diluentVolumeMl, ml > 0 {
                            subChip("\(formatMg(ml)) mL", "drop")
                        } else {
                            subChip("No strength", "exclamationmark.triangle")
                        }
                        if !item.scan.lotNumber.isEmpty {
                            subChip("Lot \(item.scan.lotNumber)", "number")
                        }
                    }
                    if let exp = item.scan.expirationDate {
                        Text("Exp \(exp.formatted(.dateTime.month().day().year()))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(10)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                removeItem(at: index)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func subChip(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(PepTheme.textSecondary)
    }

    @ViewBuilder
    private func thumb(for item: VialScannerView.BatchScanItem) -> some View {
        if let name = item.primaryFilename, let img = VialLabelImageStore.shared.load(name) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                .overlay(alignment: .bottomTrailing) {
                    if item.imageFilenames.count > 1 {
                        Text("+\(item.imageFilenames.count - 1)")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.black.opacity(0.7), in: .capsule)
                            .padding(3)
                    }
                }
        } else {
            Color(.secondarySystemBackground).overlay(
                Image(systemName: "testtube.2")
                    .foregroundStyle(PepTheme.textSecondary)
            )
        }
    }

    private func removeItem(at index: Int) {
        guard index < items.count else { return }
        let item = items[index]
        for name in item.imageFilenames { VialLabelImageStore.shared.delete(name) }
        withAnimation { items.remove(at: index) }
    }

    private func formatMg(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2g", d)
    }
}
