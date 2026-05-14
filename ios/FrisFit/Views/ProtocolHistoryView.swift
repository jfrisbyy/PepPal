import SwiftUI

@Observable
final class ProtocolHistoryViewModel {
    var protocols: [PeptideProtocol] = []
    var isLoading: Bool = true
    var errorMessage: String?
    var selectedFilter: ProtocolFilter = .all
    var compareMode: Bool = false
    var selectedForCompare: Set<UUID> = []

    enum ProtocolFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case past = "Past"
    }

    var filteredProtocols: [PeptideProtocol] {
        switch selectedFilter {
        case .all: return protocols
        case .active: return protocols.filter { $0.isActive }
        case .past: return protocols.filter { !$0.isActive }
        }
    }

    func loadProtocols() async {
        isLoading = true
        defer { isLoading = false }
        do {
            protocols = try await ProtocolService.shared.fetchProtocols()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteProtocol(_ proto: PeptideProtocol) async {
        guard let sid = proto.supabaseId else { return }
        do {
            try await ProtocolService.shared.deleteProtocol(id: sid)
            protocols.removeAll { $0.id == proto.id }
        } catch {}
    }

    func toggleActive(_ proto: PeptideProtocol) async {
        guard let sid = proto.supabaseId else { return }
        let newActive = !proto.isActive
        do {
            try await ProtocolService.shared.updateProtocolStatus(id: sid, isActive: newActive)
            if let idx = protocols.firstIndex(where: { $0.id == proto.id }) {
                protocols[idx].isActive = newActive
            }
        } catch {}
    }
}

struct ProtocolHistoryView: View {
    @State private var viewModel = ProtocolHistoryViewModel()

    var body: some View {
        if PeptideAccessManager.shared.shouldShowTrackAEmptyState {
            TrackAEmptyStateView(
                surface: .protocolHistory,
                icon: "calendar.badge.clock",
                title: "Past cycles, all in one place",
                blurb: "A protocol is a structured plan for using a peptide — what, how much, how often, how long. Tracking it lets you see what worked, what didn't, and how your body responded over time."
            )
            .navigationTitle("Protocol History")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            historyBody
        }
    }

    @ViewBuilder
    private var historyBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                topBar

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.filteredProtocols.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredProtocols) { proto in
                            cardRow(proto: proto)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Protocol History")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadProtocols() }
        .refreshable { await viewModel.loadProtocols() }
        .navigationDestination(for: PeptideProtocol.self) { proto in
            ProtocolDetailView(protocolData: proto)
        }
        .navigationDestination(for: CompareCyclesPayload.self) { payload in
            CycleComparisonView(cycles: payload.cycles)
        }
        .overlay(alignment: .bottom) {
            compareCTA
        }
    }

    @ViewBuilder
    private func cardRow(proto: PeptideProtocol) -> some View {
        if viewModel.compareMode {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    if viewModel.selectedForCompare.contains(proto.id) {
                        viewModel.selectedForCompare.remove(proto.id)
                    } else {
                        viewModel.selectedForCompare.insert(proto.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(PepTheme.glassBorderTop, lineWidth: 1)
                            .frame(width: 22, height: 22)
                        if viewModel.selectedForCompare.contains(proto.id) {
                            Circle()
                                .fill(PepTheme.teal)
                                .frame(width: 16, height: 16)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    ProtocolHistoryCard(proto: proto) {
                        Task { await viewModel.toggleActive(proto) }
                    } onDelete: {
                        Task { await viewModel.deleteProtocol(proto) }
                    }
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: viewModel.selectedForCompare.contains(proto.id))
        } else {
            NavigationLink(value: proto) {
                ProtocolHistoryCard(proto: proto) {
                    Task { await viewModel.toggleActive(proto) }
                } onDelete: {
                    Task { await viewModel.deleteProtocol(proto) }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            filterPicker
            Spacer(minLength: 4)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    viewModel.compareMode.toggle()
                    if !viewModel.compareMode { viewModel.selectedForCompare.removeAll() }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.compareMode ? "xmark" : "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10, weight: .bold))
                    Text(viewModel.compareMode ? "Cancel" : "Compare")
                        .font(.system(.caption, weight: .bold))
                }
                .foregroundStyle(viewModel.compareMode ? PepTheme.textPrimary : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(viewModel.compareMode ? PepTheme.elevated : PepTheme.teal, in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var compareCTA: some View {
        if viewModel.compareMode {
            let selected = viewModel.protocols.filter { viewModel.selectedForCompare.contains($0.id) }
            let enabled = selected.count >= 2
            NavigationLink(value: CompareCyclesPayload(cycles: selected)) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .bold))
                    Text(enabled ? "Compare \(selected.count) cycles" : "Select at least 2 cycles")
                        .font(.system(.subheadline, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(enabled ? PepTheme.teal : PepTheme.textSecondary.opacity(0.45))
                        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)
                )
            }
            .disabled(!enabled)
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var filterPicker: some View {
        HStack(spacing: 8) {
            ForEach(ProtocolHistoryViewModel.ProtocolFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filter.rawValue)
                            .font(.system(.caption, weight: .semibold))
                        if filter != .all {
                            let count = filter == .active
                                ? viewModel.protocols.filter(\.isActive).count
                                : viewModel.protocols.filter({ !$0.isActive }).count
                            Text("\(count)")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                        }
                    }
                    .foregroundStyle(viewModel.selectedFilter == filter ? .white : PepTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(viewModel.selectedFilter == filter ? PepTheme.teal : PepTheme.elevated)
                    .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: viewModel.selectedFilter)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pill.fill")
                .font(.system(size: 48))
                .foregroundStyle(PepTheme.violet.opacity(0.5))
            Text("No Protocols Found")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Your peptide protocols will appear here once you create one from the home screen.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

private struct ProtocolHistoryCard: View {
    let proto: PeptideProtocol
    let onToggleActive: () -> Void
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
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(proto.name)
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(1)

                            if proto.isActive {
                                Text("ACTIVE")
                                    .font(.system(.caption2, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(PepTheme.teal)
                                    .clipShape(.capsule)
                            } else {
                                Text("ENDED")
                                    .font(.system(.caption2, weight: .heavy))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(PepTheme.elevated)
                                    .clipShape(.capsule)
                            }
                        }

                        HStack(spacing: 6) {
                            Image(systemName: proto.goal.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(proto.goal.color)
                            Text(proto.goal.rawValue)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Menu {
                        Button {
                            onToggleActive()
                        } label: {
                            Label(proto.isActive ? "Mark as Ended" : "Reactivate", systemImage: proto.isActive ? "pause.circle" : "play.circle")
                        }
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

                HStack(spacing: 16) {
                    statPill(icon: "calendar", value: dateFormatter.string(from: proto.startDate))
                    statPill(icon: "clock", value: proto.totalWeeks != nil ? "\(proto.totalWeeks!) weeks" : "Ongoing")
                    statPill(icon: "flask.fill", value: "\(proto.compounds.count) compounds")
                }

                if !proto.compounds.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(proto.compounds.prefix(3)) { compound in
                            Text(compound.compoundName)
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PepTheme.elevated)
                                .clipShape(.capsule)
                        }
                        if proto.compounds.count > 3 {
                            Text("+\(proto.compounds.count - 3)")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PepTheme.elevated)
                                .clipShape(.capsule)
                        }
                    }
                }

                if proto.isActive {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Day \(proto.currentDay)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(proto.currentPhase.rawValue)
                                .font(.caption2)
                                .foregroundStyle(proto.currentPhase.color)
                        }

                        Spacer()

                        let progress = min(1.0, Double(proto.currentDay) / Double((proto.totalWeeks ?? proto.effectiveTotalWeeks) * 7))
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(PepTheme.elevated)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(colors: [PepTheme.teal, PepTheme.blue], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(4, CGFloat(progress) * 120), height: 6)
                        }
                        .frame(width: 120)

                        Text("\(Int(progress * 100))%")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "syringe.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.teal)
                        Text("\(proto.doseLog.count) doses")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("\(proto.sideEffectLog.count) side effects")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
        }
        .alert("Delete Protocol?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This will permanently remove this protocol and all associated data.")
        }
    }

    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
        }
    }
}

nonisolated struct CompareCyclesPayload: Hashable, Sendable {
    let cycleIds: [UUID]
    let cycles: [PeptideProtocol]

    init(cycles: [PeptideProtocol]) {
        self.cycles = cycles
        self.cycleIds = cycles.map(\.id)
    }

    static func == (lhs: CompareCyclesPayload, rhs: CompareCyclesPayload) -> Bool {
        lhs.cycleIds == rhs.cycleIds
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(cycleIds)
    }
}

extension PeptideProtocol: @retroactive Hashable {
    nonisolated static func == (lhs: PeptideProtocol, rhs: PeptideProtocol) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
