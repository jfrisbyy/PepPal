import SwiftUI

struct VialInventoryView: View {
    @State private var inventory = VialInventoryStore.shared
    @State private var showAdd: Bool = false
    @State private var filter: InventoryFilter = .all
    @State private var editingVial: Vial? = nil
    @State private var showScanner: Bool = false
    @State private var scannedPrefill: Vial? = nil
    @State private var scanHandoff: VialScanHandoff? = nil
    @State private var showHistory: Bool = false
    @State private var showIntegrityCheck: Bool = false
    @State private var showStackBuilder: Bool = false

    enum InventoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case low = "Low / Expiring"
        case archive = "Archive"
        var id: String { rawValue }
    }

    private var filteredVials: [Vial] {
        switch filter {
        case .all: return inventory.vials
        case .active: return inventory.vials.filter { !$0.isExpired && !$0.isEmpty }
        case .low: return inventory.vials.filter { $0.isLowStock || (($0.daysUntilBUD ?? 999) <= 7 && !$0.isEmpty) }
        case .archive: return inventory.vials.filter { $0.isExpired || $0.isEmpty }
        }
    }

    var body: some View {
        Group {
            if PeptideAccessManager.shared.shouldShowTrackAEmptyState {
                TrackAEmptyStateView(
                    surface: .inventory,
                    icon: "tray.full.fill",
                    title: "Your vial inventory, organized",
                    blurb: "EPTI keeps every vial in one place — compound, lot, expiration, BUD, and remaining supply. Activate peptide tracking to start your inventory."
                )
                .navigationTitle("Vial Inventory")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                inventoryBody
            }
        }
    }

    @ViewBuilder
    private var inventoryBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                MedicalDisclaimerBanner(compact: true)
                    .padding(.horizontal)

                recallBanner

                quickActionsStrip
                    .padding(.horizontal)

                filterBar
                    .padding(.horizontal)

                if filteredVials.isEmpty {
                    emptyState
                        .padding(.top, 48)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(filteredVials) { vial in
                            Button {
                                editingVial = vial
                            } label: {
                                VialCard(vial: vial)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AuroraBackground(accent: PepTheme.teal))
        .navigationTitle("Vial Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(PepTheme.teal)
                    }
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "viewfinder")
                            .foregroundStyle(PepTheme.teal)
                    }
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(PepTheme.teal)
                    }
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                VialScanHistoryView { scan, action in
                    showHistory = false
                    handleScan(scan, action: action)
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            VialScannerView { scan, action in
                handleScan(scan, action: action)
            }
        }
        .sheet(isPresented: $showIntegrityCheck) {
            VialIntegrityCheckView()
        }
        .sheet(isPresented: $showStackBuilder) {
            PeptideStackBuilderView()
        }
        .sheet(item: $scanHandoff) { handoff in
            switch handoff.kind {
            case .inventory:
                AddEditVialSheet(prefill: handoff.prefill) { new in
                    inventory.add(new)
                }
            case .reconstitute:
                ReconstitutionCalculatorView(
                    initialCompound: handoff.prefill.compoundName,
                    initialVialSizeMg: handoff.prefill.vialSizeMg
                )
            case .protocolSetup:
                ProtocolSetupWizardView(initialCompound: handoff.prefill.compoundName) { _ in }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditVialSheet(vial: nil) { new in
                inventory.add(new)
                VialBUDNotificationService.shared.scheduleBUDReminder(for: new)
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
    }

    private var recallBanner: some View {
        Group {
            let matches = VialRecallDatabase.anyMatches(for: inventory.vials)
            if !matches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(matches.prefix(3).enumerated()), id: \.offset) { _, pair in
                        let entry = pair.1
                        HStack(spacing: 10) {
                            Image(systemName: entry.severity.icon)
                                .foregroundStyle(entry.severity.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recall alert — \(pair.0.compoundName)")
                                    .font(.system(.caption, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(entry.reason)
                                    .font(.caption2)
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text(entry.severity.rawValue)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(entry.severity.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(entry.severity.color.opacity(0.15), in: .capsule)
                        }
                        .padding(12)
                        .background(entry.severity.color.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(entry.severity.color.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var quickActionsStrip: some View {
        HStack(spacing: 10) {
            quickAction(title: "Integrity", icon: "checkmark.seal.fill", color: .green) {
                showIntegrityCheck = true
            }
            quickAction(title: "Stack", icon: "square.stack.3d.up.fill", color: PepTheme.violet) {
                showStackBuilder = true
            }
            quickAction(title: "Scan", icon: "viewfinder", color: PepTheme.teal) {
                showScanner = true
            }
        }
    }

    private func quickAction(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleScan(_ scan: ScannedVialLabel, action: VialScanAction) {
        let prefill = VialScanPrefill(scan: scan)
        switch action {
        case .addToInventory:
            scanHandoff = VialScanHandoff(kind: .inventory, prefill: prefill)
        case .reconstitute:
            scanHandoff = VialScanHandoff(kind: .reconstitute, prefill: prefill)
        case .createProtocol:
            scanHandoff = VialScanHandoff(kind: .protocolSetup, prefill: prefill)
        }
    }

    private var filterBar: some View {
        HStack {
            GlassPill(selection: $filter, options: InventoryFilter.allCases) { f in
                Text(f.rawValue)
            }
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "testtube.2")
                .font(.system(size: 44))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text("No vials yet")
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Add a vial to track its contents, BUD countdown, and doses remaining.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showAdd = true
            } label: {
                Label("Add Vial", systemImage: "plus")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.invertedText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(PepTheme.teal, in: .capsule)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Vial Card

struct VialCard: View {
    let vial: Vial

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                if let name = vial.labelImageFilename, let img = VialLabelImageStore.shared.load(name) {
                    Color(.secondarySystemBackground)
                        .frame(width: 44, height: 56)
                        .overlay {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 6))
                } else {
                    vialGraphic
                }
                Spacer()
                statusBadge
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vial.compoundName)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text("\(formatNum(vial.vialSizeMg)) mg vial")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.system(size: 9))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("\(vial.dosesRemaining) doses left")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            if let forecast = VialBurnRate.forecast(for: vial) {
                SupplyChip(forecast: forecast, compact: true)
            }

            if let days = vial.daysUntilBUD {
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9))
                        .foregroundStyle(vial.statusColor)
                    Text(days < 0 ? "Past BUD" : "BUD in \(days)d")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(vial.statusColor)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(vial.statusColor.opacity(0.35), lineWidth: 0.8)
        )
    }

    private var vialGraphic: some View {
        ZStack {
            // Outline
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(PepTheme.textSecondary.opacity(0.4), lineWidth: 1)
                .frame(width: 26, height: 50)

            // Fluid
            GeometryReader { geo in
                let h = geo.size.height
                let fillH = h * CGFloat(vial.fillFraction)
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(colors: [vial.statusColor.opacity(0.8), vial.statusColor.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(height: fillH)
                        .padding(.horizontal, 2)
                }
            }
            .frame(width: 26, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Cap
            RoundedRectangle(cornerRadius: 2)
                .fill(PepTheme.textSecondary.opacity(0.7))
                .frame(width: 14, height: 6)
                .offset(y: -28)
        }
        .frame(width: 30, height: 56)
    }

    private var statusBadge: some View {
        Text(vial.statusLabel)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(vial.statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(vial.statusColor.opacity(0.15))
            .clipShape(.capsule)
    }

    private func formatNum(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2g", d)
    }
}

// MARK: - Add/Edit Sheet

struct AddEditVialSheet: View {
    let existing: Vial?
    let prefill: VialScanPrefill?
    let onSave: (Vial) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var compoundName: String = ""
    @State private var vialSizeText: String = ""
    @State private var diluentText: String = ""
    @State private var doseText: String = ""
    @State private var reconDate: Date = Date()
    @State private var isReconstituted: Bool = true
    @State private var storage: VialStorageLocation = .fridge
    @State private var lotNumber: String = ""
    @State private var vialNumber: String = ""
    @State private var hasExpiration: Bool = false
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var budDays: Int = 30
    @State private var showCompoundPicker: Bool = false
    @State private var showDeleteConfirm: Bool = false

    init(vial: Vial?, onSave: @escaping (Vial) -> Void, onDelete: (() -> Void)? = nil) {
        self.existing = vial
        self.prefill = nil
        self.onSave = onSave
        self.onDelete = onDelete
    }

    init(prefill: VialScanPrefill, onSave: @escaping (Vial) -> Void) {
        self.existing = nil
        self.prefill = prefill
        self.onSave = onSave
        self.onDelete = nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Compound") {
                    Button {
                        showCompoundPicker = true
                    } label: {
                        HStack {
                            Text(compoundName.isEmpty ? "Select compound" : compoundName)
                                .foregroundStyle(compoundName.isEmpty ? PepTheme.textSecondary : PepTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                    TextField("Or type custom name", text: $compoundName)
                }

                Section("Vial") {
                    HStack {
                        TextField("5", text: $vialSizeText)
                            .keyboardType(.decimalPad)
                        Text("mg").foregroundStyle(PepTheme.textSecondary)
                    }
                    HStack {
                        TextField("250", text: $doseText)
                            .keyboardType(.decimalPad)
                        Text("mcg per dose").foregroundStyle(PepTheme.textSecondary)
                    }
                }

                Section("Reconstitution") {
                    Toggle("Reconstituted", isOn: $isReconstituted)
                    if isReconstituted {
                        HStack {
                            TextField("2", text: $diluentText)
                                .keyboardType(.decimalPad)
                            Text("mL BAC water").foregroundStyle(PepTheme.textSecondary)
                        }
                        DatePicker("Mixed on", selection: $reconDate, displayedComponents: .date)
                        Stepper("BUD: \(budDays) days", value: $budDays, in: 3...120)
                    }
                }

                Section("Storage") {
                    Picker("Location", selection: $storage) {
                        ForEach(VialStorageLocation.allCases) { loc in
                            Label(loc.rawValue, systemImage: loc.icon).tag(loc)
                        }
                    }
                    TextField("Lot number (optional)", text: $lotNumber)
                    TextField("Vial # / serial (optional)", text: $vialNumber)
                    Toggle("Has expiration date", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expires", selection: $expirationDate, displayedComponents: .date)
                    }
                }

                if existing != nil, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Vial & Protocol", systemImage: "trash")
                        }
                    } footer: {
                        Text("Removes this vial and any linked protocol in one step.")
                            .font(.caption2)
                    }
                    .confirmationDialog(
                        "Delete this vial and its protocol?",
                        isPresented: $showDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Delete vial & protocol", role: .destructive) {
                            // Ask any owners of protocol state to remove protocols by compound.
                            if !compoundName.isEmpty {
                                NotificationCenter.default.post(
                                    name: .protocolShouldDeleteByCompound,
                                    object: nil,
                                    userInfo: ["compoundName": compoundName]
                                )
                            }
                            onDelete()
                            dismiss()
                        }
                        Button("Delete vial only") {
                            onDelete()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This permanently removes the vial. The linked protocol and its titration plan will also be removed.")
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add Vial" : "Edit Vial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(compoundName.isEmpty || Double(vialSizeText) == nil || Double(doseText) == nil)
                        .bold()
                }
            }
            .sheet(isPresented: $showCompoundPicker) {
                CompoundPickerSheet { profile in
                    compoundName = profile.name
                    if let mg = ReconHelper.parseFirstNumber(profile.reconstitutionGuide.typicalVialSize) {
                        vialSizeText = String(Int(mg))
                    }
                    budDays = ReconHelper.defaultBUDDays(for: profile.name)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        if let p = prefill, existing == nil {
            compoundName = p.compoundName
            if p.vialSizeMg > 0 {
                vialSizeText = p.vialSizeMg == p.vialSizeMg.rounded() ? String(Int(p.vialSizeMg)) : String(format: "%.2f", p.vialSizeMg)
            }
            lotNumber = p.lotNumber
            vialNumber = p.vialNumber
            if let exp = p.expirationDate {
                hasExpiration = true
                expirationDate = exp
            }
            budDays = ReconHelper.defaultBUDDays(for: p.compoundName)
            isReconstituted = false
            // Default dose from compound profile
            if let profile = CompoundDatabase.all.first(where: { $0.name == p.compoundName }),
               let tiered = profile.tieredDosing.first(where: { $0.tier == "Intermediate" }) ?? profile.tieredDosing.first,
               let doseNum = tiered.dose.matches(of: /\d+(?:\.\d+)?/).first.flatMap({ Double($0.output) }) {
                let isMg = tiered.dose.lowercased().contains("mg") && !tiered.dose.lowercased().contains("mcg")
                let mcg = isMg ? doseNum * 1000 : doseNum
                doseText = String(Int(mcg))
            }
            return
        }
        guard let v = existing else { return }
        compoundName = v.compoundName
        vialSizeText = String(v.vialSizeMg == v.vialSizeMg.rounded() ? Int(v.vialSizeMg).description : String(v.vialSizeMg))
        diluentText = v.diluentMl.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
        doseText = String(Int(v.typicalDoseMcg))
        isReconstituted = v.isReconstituted
        reconDate = v.reconstitutedOn ?? Date()
        storage = v.storage
        lotNumber = v.lotNumber
        vialNumber = v.vialNumber
        if let exp = v.expirationDate {
            hasExpiration = true
            expirationDate = exp
        }
        budDays = v.budDays
    }

    private func save() {
        guard let vialSize = Double(vialSizeText), let dose = Double(doseText) else { return }
        let vial = Vial(
            id: existing?.id ?? UUID(),
            compoundName: compoundName,
            vialSizeMg: vialSize,
            diluentMl: Double(diluentText),
            reconstitutedOn: isReconstituted ? reconDate : nil,
            storage: storage,
            lotNumber: lotNumber,
            vialNumber: vialNumber,
            expirationDate: hasExpiration ? expirationDate : nil,
            typicalDoseMcg: dose,
            mcgUsed: existing?.mcgUsed ?? 0,
            budDays: budDays,
            createdAt: existing?.createdAt ?? Date()
        )
        onSave(vial)
        dismiss()
    }
}

// MARK: - Compound Picker

struct CompoundPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    let onSelect: (CompoundProfile) -> Void

    private var filtered: [CompoundProfile] {
        if search.isEmpty { return CompoundDatabase.all }
        return CompoundDatabase.all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { profile in
                Button {
                    onSelect(profile)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: profile.iconName)
                            .foregroundStyle(PepTheme.teal)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(profile.peptideType)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Select Compound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
