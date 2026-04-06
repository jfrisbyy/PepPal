import SwiftUI

@Observable
final class MarketViewModel {
    var searchText: String = ""
    var featuredPrograms: [MarketProgram] = []
    var trendingPrograms: [MarketProgram] = []
    var topRatedSplits: [MarketProgram] = []
    var challenges: [MarketProgram] = []
    var nutritionPlans: [MarketProgram] = []
    var bundles: [MarketProgram] = []
    var creators: [MarketCreator] = []
    var heroIndex: Int = 0

    var filteredFeatured: [MarketProgram] {
        guard !searchText.isEmpty else { return featuredPrograms }
        return featuredPrograms.filter { $0.title.localizedStandardContains(searchText) || $0.creatorName.localizedStandardContains(searchText) }
    }

    init() {
        loadSampleData()
    }

    func creatorFor(id: UUID) -> MarketCreator? {
        creators.first { $0.id == id }
    }

    func programsBy(creatorId: UUID) -> [MarketProgram] {
        let all = featuredPrograms + trendingPrograms + topRatedSplits + challenges + nutritionPlans + bundles
        var seen = Set<UUID>()
        return all.filter { $0.creatorId == creatorId && seen.insert($0.id).inserted }
    }

    private func loadSampleData() {
        let creatorAlex = MarketCreator(name: "Alex Chen", followerCount: 24500, programsPublished: 8, averageRating: 4.8, bio: "CSCS-certified strength coach. 10+ years training athletes and lifters of all levels.")
        let creatorSarah = MarketCreator(name: "Sarah Kim", followerCount: 18200, programsPublished: 5, averageRating: 4.7, bio: "Fitness nutritionist and personal trainer specializing in body recomposition.")
        let creatorMarcus = MarketCreator(name: "Marcus Rivera", followerCount: 31000, programsPublished: 12, averageRating: 4.9, bio: "Pro powerlifter turned coach. IPF national qualifier. Building strong humans.")
        let creatorEmma = MarketCreator(name: "Emma Brooks", followerCount: 15600, programsPublished: 6, averageRating: 4.6, bio: "Yoga teacher and functional fitness specialist. Movement is medicine.")
        let creatorJay = MarketCreator(name: "Jay Patel", followerCount: 42000, programsPublished: 15, averageRating: 4.8, bio: "Online coach helping 10,000+ clients transform. Science-based hypertrophy programming.")

        creators = [creatorAlex, creatorSarah, creatorMarcus, creatorEmma, creatorJay]

        let sampleReviews: [MarketReview] = [
            MarketReview(userName: "Mike T.", rating: 5, text: "Best program I've ever run. Saw incredible gains in 12 weeks.", daysAgo: 3),
            MarketReview(userName: "Lisa R.", rating: 4, text: "Great structure but some exercises need equipment I don't have.", daysAgo: 7),
            MarketReview(userName: "Chris D.", rating: 5, text: "The progressive overload scheme is perfectly designed.", daysAgo: 14),
            MarketReview(userName: "Nora K.", rating: 5, text: "Clear instructions, amazing results. Highly recommend!", daysAgo: 21),
        ]

        let pushPullSchedule = [
            ScheduleDay(dayName: "Day 1", focus: "Push — Chest & Shoulders", exerciseCount: 6),
            ScheduleDay(dayName: "Day 2", focus: "Pull — Back & Biceps", exerciseCount: 6),
            ScheduleDay(dayName: "Day 3", focus: "Legs & Core", exerciseCount: 7),
            ScheduleDay(dayName: "Day 4", focus: "Upper Hypertrophy", exerciseCount: 6),
            ScheduleDay(dayName: "Day 5", focus: "Lower Hypertrophy", exerciseCount: 6),
        ]

        featuredPrograms = [
            MarketProgram(title: "Titan Strength Protocol", creatorName: creatorMarcus.name, creatorId: creatorMarcus.id, rating: 4.9, reviewCount: 1284, itemType: .workoutSplit, difficulty: .advanced, durationWeeks: 16, daysPerWeek: 5, equipment: "Full Gym", totalFP: 12800, overview: "A 16-week periodized strength program built for serious lifters. Combines heavy compound movements with intelligent accessory work to drive maximal strength gains. Includes deload weeks and peaking phases.", gradientColors: [GradientColor(0, 0.9, 1), GradientColor(0.1, 0.2, 0.6)], iconName: "figure.strengthtraining.traditional", isFeatured: true, reviews: sampleReviews, scheduleSummary: pushPullSchedule),
            MarketProgram(title: "Lean Machine 90", creatorName: creatorSarah.name, creatorId: creatorSarah.id, rating: 4.7, reviewCount: 892, itemType: .timedProgram, difficulty: .intermediate, durationWeeks: 12, daysPerWeek: 4, equipment: "Dumbbells & Bench", totalFP: 9600, overview: "A complete 90-day body recomposition system. Pairs progressive resistance training with a flexible nutrition framework. Designed to build lean muscle while burning fat.", gradientColors: [GradientColor(1, 0.72, 0), GradientColor(0.8, 0.2, 0.1)], iconName: "flame.fill", isFeatured: true, reviews: sampleReviews),
            MarketProgram(title: "Functional Athlete", creatorName: creatorEmma.name, creatorId: creatorEmma.id, rating: 4.8, reviewCount: 634, itemType: .workoutSplit, difficulty: .intermediate, durationWeeks: 8, daysPerWeek: 5, equipment: "Minimal", totalFP: 6400, overview: "Train like an athlete, look like an athlete. Blends strength, mobility, and conditioning into a cohesive program that builds real-world performance.", gradientColors: [GradientColor(0.55, 0.36, 0.96), GradientColor(0.2, 0.1, 0.5)], iconName: "figure.run", isFeatured: true, reviews: sampleReviews),
            MarketProgram(title: "Hypertrophy Lab", creatorName: creatorJay.name, creatorId: creatorJay.id, rating: 4.9, reviewCount: 2100, itemType: .workoutSplit, difficulty: .intermediate, durationWeeks: 12, daysPerWeek: 6, equipment: "Full Gym", totalFP: 11520, overview: "Science-based muscle building at its finest. Every set, rep, and rest period is optimized for maximum hypertrophy based on the latest research.", gradientColors: [GradientColor(0, 0.8, 0.5), GradientColor(0, 0.3, 0.4)], iconName: "dumbbell.fill", isFeatured: true, reviews: sampleReviews),
        ]

        trendingPrograms = [
            MarketProgram(title: "Push Pull Legs", creatorName: creatorAlex.name, creatorId: creatorAlex.id, rating: 4.8, reviewCount: 1560, itemType: .workoutSplit, difficulty: .intermediate, durationWeeks: 12, daysPerWeek: 6, equipment: "Full Gym", totalFP: 11520, overview: "The classic PPL split optimized for progressive overload.", gradientColors: [GradientColor(0, 0.9, 1), GradientColor(0, 0.4, 0.5)], iconName: "arrow.triangle.2.circlepath", scheduleSummary: pushPullSchedule),
            MarketProgram(title: "Minimalist Muscle", creatorName: creatorJay.name, creatorId: creatorJay.id, rating: 4.6, reviewCount: 723, itemType: .workoutSplit, difficulty: .beginner, durationWeeks: 8, daysPerWeek: 3, equipment: "Dumbbells", totalFP: 3840, overview: "Maximum results with minimum equipment. 3 days a week.", gradientColors: [GradientColor(0.3, 0.7, 1), GradientColor(0.1, 0.2, 0.5)], iconName: "bolt.fill"),
            MarketProgram(title: "Shred Season", creatorName: creatorSarah.name, creatorId: creatorSarah.id, rating: 4.7, reviewCount: 945, itemType: .timedProgram, difficulty: .advanced, durationWeeks: 6, daysPerWeek: 5, equipment: "Full Gym", totalFP: 4800, overview: "6-week aggressive cut program for competition prep.", gradientColors: [GradientColor(1, 0.4, 0.2), GradientColor(0.6, 0.1, 0.1)], iconName: "flame.fill"),
            MarketProgram(title: "Powerbuilder", creatorName: creatorMarcus.name, creatorId: creatorMarcus.id, rating: 4.9, reviewCount: 1890, itemType: .workoutSplit, difficulty: .advanced, durationWeeks: 16, daysPerWeek: 5, equipment: "Full Gym", totalFP: 12800, overview: "The best of both worlds: powerlifting and bodybuilding.", gradientColors: [GradientColor(0.8, 0, 0.2), GradientColor(0.3, 0, 0.1)], iconName: "figure.strengthtraining.traditional"),
            MarketProgram(title: "Home Hero", creatorName: creatorEmma.name, creatorId: creatorEmma.id, rating: 4.5, reviewCount: 412, itemType: .workoutSplit, difficulty: .beginner, durationWeeks: 8, daysPerWeek: 4, equipment: "Bodyweight", totalFP: 5120, overview: "No gym? No problem. Build muscle at home.", gradientColors: [GradientColor(0.2, 0.8, 0.4), GradientColor(0.05, 0.3, 0.15)], iconName: "house.fill"),
        ]

        topRatedSplits = [
            MarketProgram(title: "Upper Lower Classic", creatorName: creatorAlex.name, creatorId: creatorAlex.id, rating: 4.9, reviewCount: 2340, itemType: .workoutSplit, difficulty: .intermediate, durationWeeks: 10, daysPerWeek: 4, equipment: "Full Gym", totalFP: 6400, overview: "Time-tested upper/lower split for balanced development.", gradientColors: [GradientColor(0.1, 0.6, 0.9), GradientColor(0.05, 0.2, 0.4)], iconName: "rectangle.split.2x1.fill"),
            MarketProgram(title: "Bro Split Supreme", creatorName: creatorJay.name, creatorId: creatorJay.id, rating: 4.7, reviewCount: 1120, itemType: .workoutSplit, difficulty: .intermediate, durationWeeks: 12, daysPerWeek: 5, equipment: "Full Gym", totalFP: 9600, overview: "One muscle group per day for maximum volume.", gradientColors: [GradientColor(0.9, 0.5, 0), GradientColor(0.4, 0.2, 0)], iconName: "figure.arms.open"),
            MarketProgram(title: "Full Body 3x", creatorName: creatorEmma.name, creatorId: creatorEmma.id, rating: 4.8, reviewCount: 876, itemType: .workoutSplit, difficulty: .beginner, durationWeeks: 8, daysPerWeek: 3, equipment: "Full Gym", totalFP: 3840, overview: "Hit every muscle 3x per week for rapid beginner gains.", gradientColors: [GradientColor(0, 0.7, 0.6), GradientColor(0, 0.3, 0.3)], iconName: "figure.walk"),
            MarketProgram(title: "Strength Foundation", creatorName: creatorMarcus.name, creatorId: creatorMarcus.id, rating: 4.9, reviewCount: 1650, itemType: .workoutSplit, difficulty: .beginner, durationWeeks: 12, daysPerWeek: 4, equipment: "Barbell & Rack", totalFP: 7680, overview: "Build your base with the big 4 lifts.", gradientColors: [GradientColor(0.4, 0.4, 0.9), GradientColor(0.15, 0.1, 0.4)], iconName: "building.columns.fill"),
        ]

        challenges = [
            MarketProgram(title: "30-Day Squat Challenge", creatorName: creatorMarcus.name, creatorId: creatorMarcus.id, rating: 4.6, reviewCount: 3200, itemType: .timedProgram, difficulty: .beginner, durationWeeks: 4, daysPerWeek: 6, equipment: "Bodyweight", totalFP: 3840, overview: "From 10 to 200 squats in 30 days.", gradientColors: [GradientColor(1, 0.3, 0.5), GradientColor(0.5, 0.1, 0.2)], iconName: "trophy.fill"),
            MarketProgram(title: "Core Crusher 21", creatorName: creatorEmma.name, creatorId: creatorEmma.id, rating: 4.5, reviewCount: 1890, itemType: .timedProgram, difficulty: .intermediate, durationWeeks: 3, daysPerWeek: 5, equipment: "None", totalFP: 2400, overview: "21 days to a stronger, more defined core.", gradientColors: [GradientColor(1, 0.6, 0), GradientColor(0.5, 0.2, 0)], iconName: "bolt.heart.fill"),
            MarketProgram(title: "Pull-Up Progression", creatorName: creatorAlex.name, creatorId: creatorAlex.id, rating: 4.8, reviewCount: 1450, itemType: .timedProgram, difficulty: .beginner, durationWeeks: 8, daysPerWeek: 4, equipment: "Pull-Up Bar", totalFP: 5120, overview: "From zero pull-ups to 10+ unbroken.", gradientColors: [GradientColor(0.6, 0, 1), GradientColor(0.2, 0, 0.4)], iconName: "arrow.up.circle.fill"),
        ]

        nutritionPlans = [
            MarketProgram(title: "Clean Bulk Blueprint", creatorName: creatorSarah.name, creatorId: creatorSarah.id, rating: 4.7, reviewCount: 670, itemType: .nutritionPlan, difficulty: .intermediate, durationWeeks: 12, daysPerWeek: 7, equipment: "N/A", totalFP: 0, overview: "Gain lean mass without the excess fat. Macro-optimized meal plans.", gradientColors: [GradientColor(0.2, 0.8, 0.3), GradientColor(0.05, 0.3, 0.1)], iconName: "leaf.fill"),
            MarketProgram(title: "Shred Diet System", creatorName: creatorSarah.name, creatorId: creatorSarah.id, rating: 4.8, reviewCount: 1240, itemType: .nutritionPlan, difficulty: .advanced, durationWeeks: 8, daysPerWeek: 7, equipment: "N/A", totalFP: 0, overview: "Aggressive but sustainable cutting protocol with refeeds.", gradientColors: [GradientColor(0, 0.7, 0.4), GradientColor(0, 0.25, 0.15)], iconName: "chart.line.downtrend.xyaxis"),
            MarketProgram(title: "Flexible Eating 101", creatorName: creatorJay.name, creatorId: creatorJay.id, rating: 4.6, reviewCount: 890, itemType: .nutritionPlan, difficulty: .beginner, durationWeeks: 4, daysPerWeek: 7, equipment: "N/A", totalFP: 0, overview: "Learn IIFYM the right way. No food restrictions.", gradientColors: [GradientColor(0.3, 0.9, 0.5), GradientColor(0.1, 0.35, 0.15)], iconName: "fork.knife"),
        ]

        bundles = [
            MarketProgram(title: "Total Transformation", creatorName: creatorJay.name, creatorId: creatorJay.id, rating: 4.9, reviewCount: 3400, itemType: .bundle, difficulty: .intermediate, durationWeeks: 16, daysPerWeek: 5, equipment: "Full Gym", totalFP: 12800, overview: "Training + nutrition + mindset. Everything you need for a complete physique transformation.", gradientColors: [GradientColor(0, 0.9, 1), GradientColor(1, 0.72, 0)], iconName: "star.fill"),
            MarketProgram(title: "Beginner's Complete Kit", creatorName: creatorEmma.name, creatorId: creatorEmma.id, rating: 4.8, reviewCount: 2100, itemType: .bundle, difficulty: .beginner, durationWeeks: 12, daysPerWeek: 4, equipment: "Minimal", totalFP: 7680, overview: "Program + nutrition + mobility routines. Your first 12 weeks done right.", gradientColors: [GradientColor(0.55, 0.36, 0.96), GradientColor(0.2, 0.8, 0.4)], iconName: "gift.fill"),
        ]
    }
}
