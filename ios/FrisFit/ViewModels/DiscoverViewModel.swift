import SwiftUI

@Observable
final class DiscoverViewModel {
    var searchText: String = ""
    var selectedCategory: PeptideCategory = .all
    var selectedSegment: DiscoverSegment = .compounds
    var compounds: [CompoundProfile] = CompoundDatabase.all
    var vendors: [Vendor] = CompoundDatabase.vendors
    var liveStats: [String: CompoundUsageStat] = [:]

    init() {
        // Apply any cached stats immediately for snappier first paint.
        liveStats = CompoundStatsService.shared.stats
        Task { await refreshLiveStats() }
    }

    // MARK: - Persona fabrication
    //
    // When the operator is impersonating a fake persona (i.e. screenshot /
    // demo mode), the trending rail's live numbers can look anemic against
    // the seeded community data. We swap in a curated set of headline
    // numbers so screenshots and walkthroughs land with a believable scale.
    // Outside impersonation we always fall through to real Supabase stats.

    private var personaFabricationActive: Bool {
        FakeAccountService.shared.isImpersonating
    }

    private struct FabricatedStat {
        let users: Int
        let newStarts: Int
        let rank: Int
    }

    private static let fabricatedTrending: [String: FabricatedStat] = [
        "retatrutide": .init(users: 3_400, newStarts: 318, rank: 1),
        "tirzepatide": .init(users: 1_800, newStarts: 56,  rank: 2),
        "ghk-cu":      .init(users: 1_600, newStarts: 61,  rank: 3),
        "tesamorelin": .init(users: 1_100, newStarts: 44,  rank: 4),
    ]

    private func fabricatedStat(for compound: CompoundProfile) -> FabricatedStat? {
        guard personaFabricationActive else { return nil }
        return DiscoverViewModel.fabricatedTrending[compound.name.lowercased()]
    }

    enum DiscoverSegment: String, CaseIterable {
        case compounds = "Compounds"
        case vendors = "Vendors"
    }

    // MARK: - Live counts

    /// Real Supabase user count for a compound. Returns 0 when no live data
    /// is available — we intentionally do NOT fall back to the mock
    /// `communityUsers` placeholder on Discover so social stats reflect the
    /// actual community.
    func liveUserCount(for compound: CompoundProfile) -> Int {
        if let fab = fabricatedStat(for: compound) { return fab.users }
        return max(liveStats[compound.name.lowercased()]?.recent_users ?? 0, 0)
    }

    func newStarts(for compound: CompoundProfile) -> Int {
        if let fab = fabricatedStat(for: compound) { return fab.newStarts }
        return liveStats[compound.name.lowercased()]?.new_starts_7d ?? 0
    }

    func trendingScore(for compound: CompoundProfile) -> Int {
        if let fab = fabricatedStat(for: compound) {
            // Higher rank should win — invert so rank 1 has the highest score.
            return 1_000_000 - fab.rank
        }
        // Order purely by live signal. Compounds with no real users score 0.
        return (liveStats[compound.name.lowercased()]?.trending_score ?? 0)
    }

    func refreshLiveStats() async {
        await CompoundStatsService.shared.loadIfNeeded()
        liveStats = CompoundStatsService.shared.stats
    }

    func forceRefreshLiveStats() async {
        await CompoundStatsService.shared.refresh()
        liveStats = CompoundStatsService.shared.stats
    }

    // MARK: - Sections

    var featuredCompounds: [CompoundProfile] {
        Array(compounds.sorted { liveUserCount(for: $0) > liveUserCount(for: $1) }.prefix(5))
    }

    var trendingCompounds: [CompoundProfile] {
        Array(compounds.sorted { trendingScore(for: $0) > trendingScore(for: $1) }.prefix(5))
    }

    var filteredCompounds: [CompoundProfile] {
        var result = selectedCategory == .all ? compounds : compounds.filter { $0.categories.contains(selectedCategory) }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedStandardContains(searchText) || $0.peptideType.localizedStandardContains(searchText) }
        }
        return result
    }

    var filteredVendors: [Vendor] {
        if searchText.isEmpty { return vendors }
        return vendors.filter { $0.name.localizedStandardContains(searchText) }
    }

    func vendors(for compoundName: String) -> [Vendor] {
        CompoundDatabase.vendors(for: compoundName)
    }
}
