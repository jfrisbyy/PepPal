import SwiftUI

nonisolated struct VialRecallEntry: Identifiable, Sendable, Hashable {
    let id: UUID
    let compoundName: String
    let lotPattern: String
    let manufacturer: String
    let severity: Severity
    let reason: String
    let action: String
    let issuedOn: Date

    enum Severity: String, Sendable, Hashable {
        case classI = "Class I"
        case classII = "Class II"
        case advisory = "Advisory"

        var color: Color {
            switch self {
            case .classI: return .red
            case .classII: return .orange
            case .advisory: return PepTheme.amber
            }
        }

        var icon: String {
            switch self {
            case .classI: return "exclamationmark.octagon.fill"
            case .classII: return "exclamationmark.triangle.fill"
            case .advisory: return "info.circle.fill"
            }
        }
    }

    init(compoundName: String, lotPattern: String, manufacturer: String = "", severity: Severity, reason: String, action: String, issuedOn: Date) {
        self.id = UUID()
        self.compoundName = compoundName
        self.lotPattern = lotPattern
        self.manufacturer = manufacturer
        self.severity = severity
        self.reason = reason
        self.action = action
        self.issuedOn = issuedOn
    }
}

nonisolated enum VialRecallDatabase: Sendable {
    /// Curated educational-only list of reported recalls / alerts.
    /// These are illustrative entries — the lot patterns are regex-style prefixes users can match against.
    static let all: [VialRecallEntry] = [
        VialRecallEntry(
            compoundName: "Semaglutide",
            lotPattern: "SG23",
            manufacturer: "Generic compounded",
            severity: .classII,
            reason: "Potential potency deviation reported in early 2024 batches.",
            action: "Discontinue use and contact your compounding pharmacy for replacement.",
            issuedOn: Date(timeIntervalSince1970: 1_706_400_000)
        ),
        VialRecallEntry(
            compoundName: "Tirzepatide",
            lotPattern: "TZ22",
            manufacturer: "Generic compounded",
            severity: .advisory,
            reason: "Advisory: some 10 mg vials underfilled by ~5%.",
            action: "Verify total volume before reconstitution; adjust draw if underfilled.",
            issuedOn: Date(timeIntervalSince1970: 1_709_000_000)
        ),
        VialRecallEntry(
            compoundName: "BPC-157",
            lotPattern: "BPC-A1",
            manufacturer: "",
            severity: .classI,
            reason: "Sterility concern flagged in third-party testing for select lots.",
            action: "Do NOT inject. Return to vendor and request replacement.",
            issuedOn: Date(timeIntervalSince1970: 1_711_000_000)
        )
    ]

    static func matches(compoundName: String, lotNumber: String) -> [VialRecallEntry] {
        let compound = compoundName.trimmingCharacters(in: .whitespaces).lowercased()
        let lot = lotNumber.trimmingCharacters(in: .whitespaces).uppercased()
        guard !compound.isEmpty, !lot.isEmpty else { return [] }
        return all.filter { entry in
            entry.compoundName.lowercased() == compound && lot.hasPrefix(entry.lotPattern.uppercased())
        }
    }

    static func anyMatches(for vials: [Vial]) -> [(Vial, VialRecallEntry)] {
        var pairs: [(Vial, VialRecallEntry)] = []
        for v in vials {
            for entry in matches(compoundName: v.compoundName, lotNumber: v.lotNumber) {
                pairs.append((v, entry))
            }
        }
        return pairs
    }
}
