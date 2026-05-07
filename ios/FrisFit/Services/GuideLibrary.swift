import Foundation

/// Destination an in-app guide / tool row should open.
nonisolated enum GuideDestination: String, Codable, Sendable {
    case beginnersGuideBasics
    case beginnersGuideReconstitution
    case beginnersGuideInjection
    case beginnersGuideStorage
    case beginnersGuideCOA
    case reconstitutionCalculator
}

nonisolated struct GuideEntry: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let destination: GuideDestination
    let icon: String
    /// Extra phrases the ranker should consider (synonyms, how-to phrasings).
    let keywords: [String]

    var rankableStrings: [String] {
        [title, subtitle] + keywords
    }
}

nonisolated enum GuideLibrary: Sendable {
    static let all: [GuideEntry] = [
        GuideEntry(
            id: "guide.basics",
            title: "What Are Peptides",
            subtitle: "Beginner's Guide · Chapter 01",
            destination: .beginnersGuideBasics,
            icon: "book.pages.fill",
            keywords: [
                "peptide basics", "intro to peptides", "what is a peptide",
                "fundamentals", "research peptides", "how peptides work"
            ]
        ),
        GuideEntry(
            id: "guide.reconstitution",
            title: "Reconstitution",
            subtitle: "Beginner's Guide · Chapter 02 · mixing peptides with BAC water",
            destination: .beginnersGuideReconstitution,
            icon: "drop.fill",
            keywords: [
                "how do i reconstitute", "how to reconstitute", "reconstitute peptide",
                "mix peptide", "mixing peptides", "bacteriostatic water", "bac water",
                "diluent", "reconstitution math", "mix vial", "rehydrate peptide"
            ]
        ),
        GuideEntry(
            id: "guide.injection",
            title: "Injection Technique",
            subtitle: "Beginner's Guide · Chapter 03 · safe administration & site rotation",
            destination: .beginnersGuideInjection,
            icon: "syringe.fill",
            keywords: [
                "how to inject", "injection technique", "subq injection",
                "subcutaneous injection", "im injection", "intramuscular",
                "site rotation", "where to inject", "needle technique",
                "injecting peptides", "first injection"
            ]
        ),
        GuideEntry(
            id: "guide.storage",
            title: "Storage & Handling",
            subtitle: "Beginner's Guide · Chapter 04 · keep peptides potent",
            destination: .beginnersGuideStorage,
            icon: "thermometer.snowflake",
            keywords: [
                "how to store peptides", "storing peptides", "peptide storage",
                "refrigerate peptides", "freeze peptides", "peptide shelf life",
                "expiration", "stability", "lyophilized storage", "reconstituted storage"
            ]
        ),
        GuideEntry(
            id: "guide.coa",
            title: "Reading COAs",
            subtitle: "Beginner's Guide · Chapter 05 · verify quality & purity",
            destination: .beginnersGuideCOA,
            icon: "doc.text.magnifyingglass",
            keywords: [
                "certificate of analysis", "coa", "read coa", "reading a coa",
                "verify peptide", "purity test", "hplc", "mass spec",
                "third party testing", "quality check"
            ]
        ),
        GuideEntry(
            id: "tool.reconCalc",
            title: "Reconstitution Calculator",
            subtitle: "Tool · vial size, diluent volume & units per dose",
            destination: .reconstitutionCalculator,
            icon: "function",
            keywords: [
                "reconstitution calculator", "dose calculator", "units per dose",
                "how many units", "calculate reconstitution", "peptide calculator",
                "vial calculator", "bac water calculator"
            ]
        ),
    ]
}
