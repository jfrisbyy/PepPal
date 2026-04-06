import SwiftUI

struct MarketLinkPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    let onSelect: (MarketProgram) -> Void

    private let samplePrograms: [MarketProgram] = [
        MarketProgram(
            title: "Push Pull Legs Pro",
            creatorName: "Alex Martinez",
            creatorId: UUID(),
            rating: 4.8,
            reviewCount: 234,
            itemType: .workoutSplit,
            difficulty: .intermediate,
            durationWeeks: 12,
            daysPerWeek: 6,
            equipment: "Full Gym",
            totalFP: 4200,
            overview: "A complete PPL program for intermediate lifters",
            gradientColors: [GradientColor(0, 0.9, 1), GradientColor(0.1, 0.5, 0.9)],
            iconName: "dumbbell.fill"
        ),
        MarketProgram(
            title: "GZCLP Beginner",
            creatorName: "Jordan Kim",
            creatorId: UUID(),
            rating: 4.9,
            reviewCount: 512,
            itemType: .workoutSplit,
            difficulty: .beginner,
            durationWeeks: 16,
            daysPerWeek: 4,
            equipment: "Barbell + Rack",
            totalFP: 3800,
            overview: "The best beginner linear progression program",
            gradientColors: [GradientColor(0.9, 0.4, 0.3), GradientColor(0.9, 0.6, 0.2)],
            iconName: "figure.strengthtraining.traditional"
        ),
        MarketProgram(
            title: "Shred 8-Week Cut",
            creatorName: "Sam Taylor",
            creatorId: UUID(),
            rating: 4.6,
            reviewCount: 189,
            itemType: .timedProgram,
            difficulty: .intermediate,
            durationWeeks: 8,
            daysPerWeek: 5,
            equipment: "Full Gym",
            totalFP: 2800,
            overview: "8 weeks to a leaner physique with progressive overload",
            gradientColors: [GradientColor(0.55, 0.36, 0.96), GradientColor(0.9, 0.3, 0.5)],
            iconName: "flame.fill"
        ),
        MarketProgram(
            title: "Clean Bulk Nutrition",
            creatorName: "Riley Chen",
            creatorId: UUID(),
            rating: 4.7,
            reviewCount: 97,
            itemType: .nutritionPlan,
            difficulty: .beginner,
            durationWeeks: 12,
            daysPerWeek: 7,
            equipment: "Kitchen",
            totalFP: 1500,
            overview: "Structured meal plan for lean mass gain",
            gradientColors: [GradientColor(0.2, 0.8, 0.4), GradientColor(0.1, 0.6, 0.5)],
            iconName: "fork.knife"
        ),
    ]

    private var filteredPrograms: [MarketProgram] {
        if searchText.isEmpty { return samplePrograms }
        return samplePrograms.filter { $0.title.localizedStandardContains(searchText) || $0.creatorName.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredPrograms) { program in
                        Button {
                            onSelect(program)
                            dismiss()
                        } label: {
                            marketRow(program)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(PepTheme.background)
            .navigationTitle("Link Market Item")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search programs...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private func marketRow(_ program: MarketProgram) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: program.gradientColors.map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: program.iconName)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)

                HStack(spacing: 6) {
                    Text(program.creatorName)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary)

                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(PepTheme.amber)
                        Text(String(format: "%.1f", program.rating))
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(PepTheme.teal)
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
    }
}
