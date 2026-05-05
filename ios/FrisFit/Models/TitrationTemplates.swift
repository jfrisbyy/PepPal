import SwiftUI

nonisolated struct TitrationTemplate: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let compound: String
    let steps: [Step]
    let notes: String

    nonisolated struct Step: Sendable, Hashable {
        let week: Int
        let doseMcg: Double
        let label: String
    }
}

nonisolated enum TitrationTemplateLibrary: Sendable {
    static let all: [TitrationTemplate] = [
        TitrationTemplate(
            name: "Retatrutide Standard Titration",
            compound: "Retatrutide",
            steps: [
                .init(week: 1, doseMcg: 2000, label: "Start"),
                .init(week: 5, doseMcg: 4000, label: "Bump 1"),
                .init(week: 9, doseMcg: 6000, label: "Bump 2"),
                .init(week: 13, doseMcg: 8000, label: "Target"),
            ],
            notes: "Hold each dose for 4 weeks. If GI side effects are severe, stay at current dose an extra 2 weeks."
        ),
        TitrationTemplate(
            name: "Tirzepatide Clinical Ladder",
            compound: "Tirzepatide",
            steps: [
                .init(week: 1, doseMcg: 2500, label: "Start"),
                .init(week: 5, doseMcg: 5000, label: "Bump 1"),
                .init(week: 9, doseMcg: 7500, label: "Bump 2"),
                .init(week: 13, doseMcg: 10000, label: "Bump 3"),
                .init(week: 17, doseMcg: 12500, label: "Bump 4"),
                .init(week: 21, doseMcg: 15000, label: "Target"),
            ],
            notes: "Mirrors the Mounjaro/Zepbound approved titration. 4-week dose holds."
        ),
        TitrationTemplate(
            name: "Semaglutide Slow Escalation",
            compound: "Semaglutide",
            steps: [
                .init(week: 1, doseMcg: 250, label: "Start"),
                .init(week: 5, doseMcg: 500, label: "Bump 1"),
                .init(week: 9, doseMcg: 1000, label: "Bump 2"),
                .init(week: 13, doseMcg: 1700, label: "Bump 3"),
                .init(week: 17, doseMcg: 2400, label: "Target"),
            ],
            notes: "Once weekly. Hold each dose 4 weeks. Stop escalating at the first tolerable effective dose."
        ),
    ]

    static func templates(for compound: String) -> [TitrationTemplate] {
        all.filter { $0.compound.lowercased() == compound.lowercased() }
    }
}
