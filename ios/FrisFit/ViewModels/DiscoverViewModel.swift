import SwiftUI

@Observable
final class DiscoverViewModel {
    var searchText: String = ""
    var selectedCategory: PeptideCategory = .all
    var selectedSegment: DiscoverSegment = .compounds
    var compounds: [CompoundProfile] = CompoundDatabase.all
    var vendors: [Vendor] = CompoundDatabase.vendors

    enum DiscoverSegment: String, CaseIterable {
        case compounds = "Compounds"
        case vendors = "Vendors"
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
