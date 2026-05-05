import SwiftUI

/// Editorial vial section for ProtocolDetailView.
/// Shows all vials tied to this protocol's compounds — active up top, stockpiled
/// reserves below, depleted/expired tucked into a history disclosure.
/// Replaces the standalone VialInventoryView for everything protocol-related.
struct ProtocolVialsSection: View {
    let protocolData: PeptideProtocol

    @State private var inventory = VialInventoryStore.shared
    @State private var addVialPrefill: AddVialPrefill? = nil
    @State private var editingVial: Vial? = nil
    @State private var showScanner: Bool = false
    @State private var showIntegrityCheck: Bool = false
    @State private var scanHandoff: VialScanHandoff? = nil
    @State private var historyExpanded: Bool = false
    @State private var reservesExpanded: Bool = false

    var body: some View {
        CollapsibleEditorialSection(
            eyebrow: "Vials",
            storageKey: "protocol.vials",
            trailingAction: {
                Menu {
                    ForEach(protocolData.compounds, id: \.compoundName) { compound in
                        Button {
                            addVialPrefill = AddVialPrefill(compoundName: compound.compoundName, vialSizeMg: compound.vialSizeMg)
                        } label: {
                            Label("Add \(compound.compoundName) Vial", systemImage: "plus")
                        }
                    }
                    Divider()
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan Vial Label", systemImage: "viewfinder")
                    }
                    Button {
                        showIntegrityCheck = true
                    } label: {
                        Label("Integrity Check", systemImage: "checkmark.seal")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().strokeBorder(PepTheme.textPrimary.opacity(0.25), lineWidth: 0.5)
                        )
                }
            }
        ) {
            content
        }
        .sheet(item: $addVialPrefill) { prefill in
            AddEditVialSheet(vial: nil) { new in
                var v = new
                if v.compoundName.isEmpty { v.compoundName = prefill.compoundName }
                inventory.add(v)
                VialBUDNotificationService.shared.scheduleBUDReminder(for: v)
                Task { await VialBUDNotificationService.shared.requestAuthIfNeeded() }
            }
        }
        .sheet(item: $editingVial) { vial in
            AddEditVialSheet(vial: vial) { updated in
                inventory.update(updated)
            } onDelete: {
                inventory.remove(vial)
            }
        }
        .sheet(isPresented: $showIntegrityCheck) {
            VialIntegrityCheckView()
        }
        .fullScreenCover(isPresented: $showScanner) {
            VialScannerView { scan, action in
                let prefill = VialScanPrefill(scan: scan)
                switch action {
                case .addToInventory:
                    scanHandoff = VialScanHandoff(kind: .inventory, prefill: prefill)
                case .reconstitute:
                    scanHandoff = VialScanHandoff(kind: .reconstitute, prefill: prefill)
                case .createProtocol:
                    scanHandoff = VialScanHandoff(kind: .inventory, prefill: prefill)
                }
            }
        }
        .sheet(item: $scanHandoff) { handoff in
            switch handoff.kind {
            case .inventory, .protocolSetup:
                AddEditVialSheet(prefill: handoff.prefill) { new in
                    inventory.add(new)
                    VialBUDNotificationService.shared.scheduleBUDReminder(for: new)
                }
            case .reconstitute:
                ReconstitutionCalculatorView(
                    initialCompound: handoff.prefill.compoundName,
                    initialVialSizeMg: handoff.prefill.vialSizeMg
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let compoundNames = protocolData.compounds.map(\.compoundName)
        let related = inventory.vials.filter { compoundNames.contains($0.compoundName) }

        if related.isEmpty {
            emptyState
        } else {
            VStack(spacing: 14) {
                ForEach(protocolData.compounds, id: \.compoundName) { compound in
                    compoundBlock(for: compound, in: related)
                }

                let archived = related.filter { $0.isExpired || $0.isEmpty }
                if !archived.isEmpty {
                    historyDisclosure(archived: archived)
                }

                quickActionsStrip
            }
        }
    }

    // MARK: - Compound block

    @ViewBuilder
    private func compoundBlock(for compound: ProtocolCompound, in related: [Vial]) -> some View {
        let vials = related
            .filter { $0.compoundName == compound.compoundName && !$0.isExpired && !$0.isEmpty }
            .sorted { lhs, rhs in
                // active (most recently mixed/used first), then unmixed reserves
                if lhs.isReconstituted != rhs.isReconstituted { return lhs.isReconstituted }
                return lhs.createdAt > rhs.createdAt
            }
        if vials.isEmpty {
            compoundEmptyRow(compound)
        } else {
            VStack(spacing: 10) {
                compoundHeader(compound: compound, count: vials.count)
                if let active = vials.first {
                    activeVialCard(active)
                }
                if vials.count > 1 {
                    let reserves = Array(vials.dropFirst())
                    reservesDisclosure(compound: compound, reserves: reserves)
                }
            }
        }
    }

    private func compoundHeader(compound: ProtocolCompound, count: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(PeptidePharmacology.accentColor(for: compound.compoundName))
                .frame(width: 7, height: 7)
            Text(compound.compoundName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text("\(count) \(count == 1 ? "vial" : "vials")")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
        }
    }

    private func compoundEmptyRow(_ compound: ProtocolCompound) -> some View {
        Button {
            addVialPrefill = AddVialPrefill(compoundName: compound.compoundName, vialSizeMg: compound.vialSizeMg)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(PeptidePharmacology.accentColor(for: compound.compoundName))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add \(compound.compoundName) vial")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Track BUD, doses remaining, batch & lot")
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.elevated.opacity(0.45))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        PeptidePharmacology.accentColor(for: compound.compoundName).opacity(0.18),
                        style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active vial card

    private func activeVialCard(_ vial: Vial) -> some View {
        Button { editingVial = vial } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    bottle(for: vial)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(1.2)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.14))
                                .clipShape(.capsule)
                            Spacer(minLength: 0)
                            statusChip(vial)
                        }
                        Text("\(formatNum(vial.vialSizeMg)) mg vial")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("\(vial.dosesRemaining) doses left · \(Int(round(vial.fillFraction * 100)))% full")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                        if let forecast = VialBurnRate.forecast(for: vial) {
                            SupplyChip(forecast: forecast, compact: true)
                                .padding(.top, 2)
                        }
                    }
                }

                Divider().overlay(PepTheme.separatorColor)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metaItem(label: "Mixed", value: vial.reconstitutedOn.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? (vial.isReconstituted ? "—" : "Unmixed"))
                    if let days = vial.daysUntilBUD {
                        metaItem(label: "BUD", value: days < 0 ? "Past BUD" : "\(days) days", tint: days < 7 ? PepTheme.amber : nil)
                    } else {
                        metaItem(label: "BUD", value: "—")
                    }
                    metaItem(label: "Storage", value: vial.storage.rawValue)
                    if let exp = vial.expirationDate {
                        metaItem(label: "Expires", value: exp.formatted(date: .abbreviated, time: .omitted))
                    } else {
                        metaItem(label: "Expires", value: "—")
                    }
                    if !vial.lotNumber.isEmpty {
                        metaItem(label: "Lot #", value: vial.lotNumber)
                    }
                    if !vial.vialNumber.isEmpty {
                        metaItem(label: "Vial #", value: vial.vialNumber)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.cardSurface.opacity(0.65))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(vial.statusColor.opacity(0.32), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func bottle(for vial: Vial) -> some View {
        let accent = PeptidePharmacology.accentColor(for: vial.compoundName)
        return PeptideBottleView(
            fillFraction: vial.fillFraction,
            liquidColor: accent,
            compactHeight: 72,
            showHighlights: true
        )
        .frame(width: 40, height: 72)
    }

    private func statusChip(_ vial: Vial) -> some View {
        Text(vial.statusLabel)
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.8)
            .foregroundStyle(vial.statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(vial.statusColor.opacity(0.14))
            .clipShape(.capsule)
    }

    private func metaItem(label: String, value: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(tint ?? PepTheme.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Reserves disclosure

    private func reservesDisclosure(compound: ProtocolCompound, reserves: [Vial]) -> some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    reservesExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: reservesExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("\(reserves.count) reserve \(reserves.count == 1 ? "vial" : "vials")")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if reservesExpanded {
                VStack(spacing: 8) {
                    ForEach(reserves) { vial in
                        Button { editingVial = vial } label: {
                            reserveRow(vial)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func reserveRow(_ vial: Vial) -> some View {
        HStack(spacing: 10) {
            bottle(for: vial)
                .scaleEffect(0.7)
                .frame(width: 28, height: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(formatNum(vial.vialSizeMg)) mg \u{2014} \(vial.isReconstituted ? "Mixed" : "Unmixed")")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 6) {
                    Text(vial.statusLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(vial.statusColor)
                    if !vial.lotNumber.isEmpty {
                        Text("· Lot \(vial.lotNumber)")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
        }
        .padding(10)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - History disclosure

    private func historyDisclosure(archived: [Vial]) -> some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    historyExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: historyExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("History")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("\(archived.count) archived")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                    Spacer()
                }
                .padding(.top, 4)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if historyExpanded {
                VStack(spacing: 6) {
                    ForEach(archived.sorted { $0.createdAt > $1.createdAt }) { vial in
                        Button { editingVial = vial } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(vial.statusColor.opacity(0.2))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(vial.compoundName) · \(formatNum(vial.vialSizeMg)) mg")
                                        .font(.system(.caption, weight: .semibold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text(vial.statusLabel)
                                        .font(.system(size: 10))
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                Spacer()
                                Text(vial.createdAt, style: .date)
                                    .font(.system(size: 10))
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(PepTheme.elevated.opacity(0.3))
                            .clipShape(.rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Quick actions

    private var quickActionsStrip: some View {
        HStack(spacing: 8) {
            quickAction(title: "Scan", icon: "viewfinder", color: PepTheme.teal) {
                showScanner = true
            }
            quickAction(title: "Integrity", icon: "checkmark.seal.fill", color: .green) {
                showIntegrityCheck = true
            }
        }
        .padding(.top, 4)
    }

    private func quickAction(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.10))
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(color.opacity(0.22), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "testtube.2")
                .font(.system(size: 28))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text("No vials tracked yet")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Add a vial to track BUD countdown, doses remaining, lot, and storage.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            HStack(spacing: 8) {
                if let first = protocolData.compounds.first {
                    Button {
                        addVialPrefill = AddVialPrefill(compoundName: first.compoundName, vialSizeMg: first.vialSizeMg)
                    } label: {
                        Label("Add Vial", systemImage: "plus")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(PepTheme.teal, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showScanner = true
                } label: {
                    Label("Scan", systemImage: "viewfinder")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PepTheme.teal.opacity(0.12), in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func formatNum(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2g", d)
    }
}

// MARK: - Prefill identifiable

struct AddVialPrefill: Identifiable {
    let id = UUID()
    let compoundName: String
    let vialSizeMg: Double?
}
