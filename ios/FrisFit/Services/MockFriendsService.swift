import SwiftUI

@MainActor
final class MockFriendsService {
    static let shared = MockFriendsService()
    private init() {}

    struct MockProtocol: Sendable, Identifiable {
        var id: String { name }
        let name: String
        let dosage: String
        let frequency: String
        let week: Int
        let totalWeeks: Int
    }

    struct MockSet: Sendable {
        let reps: Int
        let weightKg: Int
        let rpe: Double?
    }

    struct MockExerciseLog: Sendable {
        let name: String
        let sets: [MockSet]
    }

    struct MockWorkout: Sendable {
        let name: String
        let date: Date
        let durationMin: Int
        let volumeKg: Int
        let calories: Int
        let sport: String
        let exercises: [MockExerciseLog]
    }

    struct MockMeal: Sendable {
        let mealTime: String
        let name: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let time: Date
    }

    struct MockActivityLogEntry: Sendable, Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let time: Date
    }

    struct MockTodaySnapshot: Sendable {
        let stepsSoFar: Int
        let stepsGoal: Int
        let caloriesBurned: Int
        let waterMl: Int
        let waterGoalMl: Int
        let meals: [MockMeal]
        let recentActivity: [MockActivityLogEntry]
    }

    struct MockFriendProfile: Sendable {
        let user: SocialUser
        let bio: String
        let goal: String
        let weeklyWorkouts: Int
        let totalWorkouts: Int
        let weeklyVolumeKg: Int
        let weeklySteps: Int
        let weeklyCalories: Int
        let weeklyWaterMl: Int
        let latestPR: String
        let activeProtocols: [MockProtocol]
        let recentWorkouts: [MockWorkout]
        let today: MockTodaySnapshot
    }

    private static func t(_ hoursAgo: Double) -> Date {
        Date().addingTimeInterval(-hoursAgo * 3600)
    }

    let profiles: [MockFriendProfile] = [
        MockFriendProfile(
            user: SocialUser(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Marcus Chen",
                username: "marcus",
                avatarInitial: "M",
                avatarColor: PepTheme.teal,
                activeProgramName: "PPL 6-Day",
                streak: 24,
                totalFP: 18420
            ),
            bio: "Recomp arc, 12 weeks in. Powerlifting roots, hybrid now.",
            goal: "Cut to 12% BF, hold 405 squat",
            weeklyWorkouts: 6,
            totalWorkouts: 142,
            weeklyVolumeKg: 28400,
            weeklySteps: 78420,
            weeklyCalories: 4820,
            weeklyWaterMl: 24500,
            latestPR: "Squat 405×3",
            activeProtocols: [
                MockProtocol(name: "BPC-157", dosage: "500mcg", frequency: "2x daily SubQ", week: 6, totalWeeks: 8),
                MockProtocol(name: "TB-500", dosage: "2.5mg", frequency: "Weekly", week: 3, totalWeeks: 6)
            ],
            recentWorkouts: [
                MockWorkout(name: "Push Day — Bench Focus", date: t(5), durationMin: 72, volumeKg: 5840, calories: 612, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Barbell Bench Press", sets: [
                        MockSet(reps: 8, weightKg: 100, rpe: 7),
                        MockSet(reps: 8, weightKg: 100, rpe: 8),
                        MockSet(reps: 7, weightKg: 100, rpe: 9),
                        MockSet(reps: 6, weightKg: 100, rpe: 9.5)
                    ]),
                    MockExerciseLog(name: "Overhead Press", sets: [
                        MockSet(reps: 6, weightKg: 70, rpe: 8),
                        MockSet(reps: 6, weightKg: 70, rpe: 8.5),
                        MockSet(reps: 5, weightKg: 70, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Incline DB Press", sets: [
                        MockSet(reps: 10, weightKg: 32, rpe: 7),
                        MockSet(reps: 10, weightKg: 32, rpe: 8),
                        MockSet(reps: 8, weightKg: 32, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Tricep Pushdown", sets: [
                        MockSet(reps: 12, weightKg: 45, rpe: 7),
                        MockSet(reps: 12, weightKg: 45, rpe: 8),
                        MockSet(reps: 10, weightKg: 45, rpe: 9)
                    ])
                ]),
                MockWorkout(name: "Pull Day — Heavy Rows", date: t(26), durationMin: 68, volumeKg: 5210, calories: 580, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Barbell Row", sets: [
                        MockSet(reps: 8, weightKg: 110, rpe: 7),
                        MockSet(reps: 8, weightKg: 110, rpe: 8),
                        MockSet(reps: 7, weightKg: 110, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Weighted Pull-up", sets: [
                        MockSet(reps: 6, weightKg: 20, rpe: 8),
                        MockSet(reps: 6, weightKg: 20, rpe: 8.5),
                        MockSet(reps: 5, weightKg: 20, rpe: 9.5)
                    ]),
                    MockExerciseLog(name: "Face Pull", sets: [
                        MockSet(reps: 15, weightKg: 30, rpe: 7),
                        MockSet(reps: 15, weightKg: 30, rpe: 7),
                        MockSet(reps: 12, weightKg: 30, rpe: 8)
                    ])
                ]),
                MockWorkout(name: "Leg Day — Squat 405×3", date: t(50), durationMin: 84, volumeKg: 7120, calories: 720, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Back Squat", sets: [
                        MockSet(reps: 5, weightKg: 160, rpe: 7),
                        MockSet(reps: 3, weightKg: 184, rpe: 9),
                        MockSet(reps: 3, weightKg: 184, rpe: 9.5),
                        MockSet(reps: 3, weightKg: 184, rpe: 10)
                    ]),
                    MockExerciseLog(name: "Romanian Deadlift", sets: [
                        MockSet(reps: 8, weightKg: 140, rpe: 8),
                        MockSet(reps: 8, weightKg: 140, rpe: 8),
                        MockSet(reps: 6, weightKg: 140, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Leg Press", sets: [
                        MockSet(reps: 12, weightKg: 200, rpe: 8),
                        MockSet(reps: 10, weightKg: 200, rpe: 9)
                    ])
                ])
            ],
            today: MockTodaySnapshot(
                stepsSoFar: 6420,
                stepsGoal: 10000,
                caloriesBurned: 612,
                waterMl: 1800,
                waterGoalMl: 3500,
                meals: [
                    MockMeal(mealTime: "Breakfast", name: "Oats + whey + blueberries", calories: 520, protein: 42, carbs: 68, fat: 9, time: t(7)),
                    MockMeal(mealTime: "Lunch", name: "Chicken rice bowl", calories: 720, protein: 58, carbs: 84, fat: 14, time: t(2.5))
                ],
                recentActivity: [
                    MockActivityLogEntry(icon: "syringe.fill", title: "Logged BPC-157 morning dose", time: t(8)),
                    MockActivityLogEntry(icon: "dumbbell.fill", title: "Completed Push Day — Bench Focus", time: t(5)),
                    MockActivityLogEntry(icon: "fork.knife", title: "Logged lunch (720 cal)", time: t(2.5))
                ]
            )
        ),
        MockFriendProfile(
            user: SocialUser(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "Finn O'Brien",
                username: "finn",
                avatarInitial: "F",
                avatarColor: PepTheme.violet,
                activeProgramName: "5/3/1 BBB",
                streak: 51,
                totalFP: 32110
            ),
            bio: "51-day streak. 5/3/1 forever. Coffee + barbell.",
            goal: "Add 20kg total to big 3 in 6 months",
            weeklyWorkouts: 4,
            totalWorkouts: 287,
            weeklyVolumeKg: 22100,
            weeklySteps: 54200,
            weeklyCalories: 3210,
            weeklyWaterMl: 21000,
            latestPR: "Deadlift 220kg×1",
            activeProtocols: [
                MockProtocol(name: "Creatine Mono", dosage: "5g", frequency: "Daily", week: 12, totalWeeks: 52),
                MockProtocol(name: "Ipamorelin", dosage: "300mcg", frequency: "Pre-bed", week: 8, totalWeeks: 12)
            ],
            recentWorkouts: [
                MockWorkout(name: "5/3/1 Deadlift Day", date: t(18), durationMin: 65, volumeKg: 4920, calories: 540, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Deadlift", sets: [
                        MockSet(reps: 5, weightKg: 160, rpe: 7),
                        MockSet(reps: 3, weightKg: 180, rpe: 8),
                        MockSet(reps: 1, weightKg: 220, rpe: 10)
                    ]),
                    MockExerciseLog(name: "BBB Deadlift", sets: [
                        MockSet(reps: 10, weightKg: 110, rpe: 7),
                        MockSet(reps: 10, weightKg: 110, rpe: 8),
                        MockSet(reps: 10, weightKg: 110, rpe: 8.5),
                        MockSet(reps: 8, weightKg: 110, rpe: 9),
                        MockSet(reps: 8, weightKg: 110, rpe: 9.5)
                    ]),
                    MockExerciseLog(name: "Pull-up", sets: [
                        MockSet(reps: 8, weightKg: 0, rpe: nil),
                        MockSet(reps: 8, weightKg: 0, rpe: nil),
                        MockSet(reps: 6, weightKg: 0, rpe: nil)
                    ])
                ]),
                MockWorkout(name: "BBB Bench Volume", date: t(51), durationMin: 72, volumeKg: 5400, calories: 590, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Bench Press", sets: [
                        MockSet(reps: 5, weightKg: 90, rpe: 7),
                        MockSet(reps: 3, weightKg: 105, rpe: 8),
                        MockSet(reps: 1, weightKg: 130, rpe: 9.5)
                    ]),
                    MockExerciseLog(name: "BBB Bench", sets: [
                        MockSet(reps: 10, weightKg: 65, rpe: 7),
                        MockSet(reps: 10, weightKg: 65, rpe: 7.5),
                        MockSet(reps: 10, weightKg: 65, rpe: 8),
                        MockSet(reps: 10, weightKg: 65, rpe: 8.5),
                        MockSet(reps: 10, weightKg: 65, rpe: 9)
                    ])
                ])
            ],
            today: MockTodaySnapshot(
                stepsSoFar: 4820,
                stepsGoal: 8000,
                caloriesBurned: 410,
                waterMl: 1400,
                waterGoalMl: 3000,
                meals: [
                    MockMeal(mealTime: "Breakfast", name: "Eggs, toast, coffee", calories: 480, protein: 32, carbs: 38, fat: 22, time: t(6))
                ],
                recentActivity: [
                    MockActivityLogEntry(icon: "syringe.fill", title: "Creatine logged", time: t(6)),
                    MockActivityLogEntry(icon: "flame.fill", title: "51-day streak — keep going", time: t(5))
                ]
            )
        ),
        MockFriendProfile(
            user: SocialUser(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                name: "Sara Patel",
                username: "sarap",
                avatarInitial: "S",
                avatarColor: PepTheme.amber,
                activeProgramName: "Hybrid Athlete",
                streak: 12,
                totalFP: 9840
            ),
            bio: "Hybrid: lift + run. Marathon in 14 weeks.",
            goal: "Sub-3:30 marathon while holding strength",
            weeklyWorkouts: 7,
            totalWorkouts: 96,
            weeklyVolumeKg: 14200,
            weeklySteps: 112000,
            weeklyCalories: 5840,
            weeklyWaterMl: 28000,
            latestPR: "10K 41:22",
            activeProtocols: [
                MockProtocol(name: "MOTS-c", dosage: "10mg", frequency: "3x weekly", week: 4, totalWeeks: 8),
                MockProtocol(name: "Vitamin D3", dosage: "5000 IU", frequency: "Daily", week: 20, totalWeeks: 52)
            ],
            recentWorkouts: [
                MockWorkout(name: "Tempo Run 8mi", date: t(8), durationMin: 56, volumeKg: 0, calories: 720, sport: "Run", exercises: []),
                MockWorkout(name: "Upper Body Strength", date: t(27), durationMin: 48, volumeKg: 3200, calories: 380, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Pull-up", sets: [
                        MockSet(reps: 8, weightKg: 0, rpe: 7),
                        MockSet(reps: 8, weightKg: 0, rpe: 8),
                        MockSet(reps: 6, weightKg: 0, rpe: 9)
                    ]),
                    MockExerciseLog(name: "DB Bench Press", sets: [
                        MockSet(reps: 10, weightKg: 22, rpe: 7),
                        MockSet(reps: 10, weightKg: 22, rpe: 8),
                        MockSet(reps: 8, weightKg: 22, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Cable Row", sets: [
                        MockSet(reps: 12, weightKg: 50, rpe: 7),
                        MockSet(reps: 12, weightKg: 50, rpe: 8)
                    ])
                ]),
                MockWorkout(name: "Long Run 14mi", date: t(74), durationMin: 122, volumeKg: 0, calories: 1340, sport: "Run", exercises: [])
            ],
            today: MockTodaySnapshot(
                stepsSoFar: 12480,
                stepsGoal: 12000,
                caloriesBurned: 920,
                waterMl: 2400,
                waterGoalMl: 3500,
                meals: [
                    MockMeal(mealTime: "Pre-run", name: "Banana + coffee", calories: 140, protein: 2, carbs: 32, fat: 0, time: t(9)),
                    MockMeal(mealTime: "Breakfast", name: "Greek yogurt bowl", calories: 420, protein: 38, carbs: 48, fat: 8, time: t(7)),
                    MockMeal(mealTime: "Lunch", name: "Salmon + sweet potato", calories: 640, protein: 44, carbs: 62, fat: 22, time: t(2))
                ],
                recentActivity: [
                    MockActivityLogEntry(icon: "figure.run", title: "Completed Tempo Run 8mi", time: t(8)),
                    MockActivityLogEntry(icon: "figure.walk", title: "Hit 10k steps", time: t(4)),
                    MockActivityLogEntry(icon: "fork.knife", title: "Logged lunch (640 cal)", time: t(2))
                ]
            )
        ),
        MockFriendProfile(
            user: SocialUser(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                name: "Diego Rivera",
                username: "diegor",
                avatarInitial: "D",
                avatarColor: PepTheme.teal,
                activeProgramName: "Full Body 3x",
                streak: 7,
                totalFP: 5210
            ),
            bio: "Just getting back. Week 2 back in the gym.",
            goal: "Drop 10kg, rebuild base",
            weeklyWorkouts: 3,
            totalWorkouts: 18,
            weeklyVolumeKg: 8400,
            weeklySteps: 42000,
            weeklyCalories: 2200,
            weeklyWaterMl: 18000,
            latestPR: "Bench 80kg×5",
            activeProtocols: [
                MockProtocol(name: "Semaglutide", dosage: "0.5mg", frequency: "Weekly", week: 5, totalWeeks: 16)
            ],
            recentWorkouts: [
                MockWorkout(name: "Full Body A", date: t(26), durationMin: 52, volumeKg: 3100, calories: 410, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Goblet Squat", sets: [
                        MockSet(reps: 10, weightKg: 24, rpe: 6),
                        MockSet(reps: 10, weightKg: 24, rpe: 7),
                        MockSet(reps: 10, weightKg: 24, rpe: 7.5)
                    ]),
                    MockExerciseLog(name: "Bench Press", sets: [
                        MockSet(reps: 5, weightKg: 80, rpe: 8),
                        MockSet(reps: 5, weightKg: 80, rpe: 9),
                        MockSet(reps: 5, weightKg: 75, rpe: 8)
                    ]),
                    MockExerciseLog(name: "Lat Pulldown", sets: [
                        MockSet(reps: 12, weightKg: 50, rpe: 7),
                        MockSet(reps: 12, weightKg: 50, rpe: 8)
                    ])
                ]),
                MockWorkout(name: "Zone 2 Bike", date: t(50), durationMin: 45, volumeKg: 0, calories: 380, sport: "Cycle", exercises: [])
            ],
            today: MockTodaySnapshot(
                stepsSoFar: 3120,
                stepsGoal: 8000,
                caloriesBurned: 280,
                waterMl: 1200,
                waterGoalMl: 3000,
                meals: [
                    MockMeal(mealTime: "Breakfast", name: "Egg whites + toast", calories: 320, protein: 28, carbs: 32, fat: 6, time: t(5))
                ],
                recentActivity: [
                    MockActivityLogEntry(icon: "syringe.fill", title: "Semaglutide injection logged", time: t(20)),
                    MockActivityLogEntry(icon: "fork.knife", title: "Logged breakfast", time: t(5))
                ]
            )
        ),
        MockFriendProfile(
            user: SocialUser(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                name: "Avery Kim",
                username: "averyk",
                avatarInitial: "A",
                avatarColor: PepTheme.violet,
                activeProgramName: "Cut Phase",
                streak: 33,
                totalFP: 21450
            ),
            bio: "8 weeks into a cut. Holding strength surprisingly well.",
            goal: "Reach 18% BF for summer, no muscle loss",
            weeklyWorkouts: 5,
            totalWorkouts: 168,
            weeklyVolumeKg: 19800,
            weeklySteps: 92400,
            weeklyCalories: 3680,
            weeklyWaterMl: 26000,
            latestPR: "Pull-up +20kg×6",
            activeProtocols: [
                MockProtocol(name: "Tirzepatide", dosage: "5mg", frequency: "Weekly", week: 8, totalWeeks: 12),
                MockProtocol(name: "L-Carnitine", dosage: "2g", frequency: "Pre-cardio", week: 8, totalWeeks: 12)
            ],
            recentWorkouts: [
                MockWorkout(name: "Upper Hypertrophy", date: t(4), durationMin: 64, volumeKg: 4280, calories: 510, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Weighted Pull-up", sets: [
                        MockSet(reps: 6, weightKg: 20, rpe: 8),
                        MockSet(reps: 6, weightKg: 20, rpe: 9),
                        MockSet(reps: 5, weightKg: 20, rpe: 9.5)
                    ]),
                    MockExerciseLog(name: "Incline DB Press", sets: [
                        MockSet(reps: 10, weightKg: 24, rpe: 7),
                        MockSet(reps: 10, weightKg: 24, rpe: 8),
                        MockSet(reps: 8, weightKg: 24, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Cable Row", sets: [
                        MockSet(reps: 12, weightKg: 55, rpe: 8),
                        MockSet(reps: 12, weightKg: 55, rpe: 8.5),
                        MockSet(reps: 10, weightKg: 55, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Lateral Raise", sets: [
                        MockSet(reps: 15, weightKg: 8, rpe: 7),
                        MockSet(reps: 15, weightKg: 8, rpe: 8),
                        MockSet(reps: 12, weightKg: 8, rpe: 9)
                    ])
                ]),
                MockWorkout(name: "HIIT 20min", date: t(25), durationMin: 22, volumeKg: 0, calories: 290, sport: "HIIT", exercises: []),
                MockWorkout(name: "Lower Hypertrophy", date: t(50), durationMin: 71, volumeKg: 6100, calories: 640, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Front Squat", sets: [
                        MockSet(reps: 8, weightKg: 80, rpe: 7),
                        MockSet(reps: 8, weightKg: 80, rpe: 8),
                        MockSet(reps: 6, weightKg: 80, rpe: 9)
                    ]),
                    MockExerciseLog(name: "RDL", sets: [
                        MockSet(reps: 10, weightKg: 100, rpe: 8),
                        MockSet(reps: 10, weightKg: 100, rpe: 8.5),
                        MockSet(reps: 8, weightKg: 100, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Walking Lunge", sets: [
                        MockSet(reps: 12, weightKg: 20, rpe: 7),
                        MockSet(reps: 12, weightKg: 20, rpe: 8)
                    ])
                ])
            ],
            today: MockTodaySnapshot(
                stepsSoFar: 9240,
                stepsGoal: 12000,
                caloriesBurned: 580,
                waterMl: 2800,
                waterGoalMl: 3500,
                meals: [
                    MockMeal(mealTime: "Breakfast", name: "Egg white scramble", calories: 360, protein: 38, carbs: 22, fat: 12, time: t(7)),
                    MockMeal(mealTime: "Lunch", name: "Tuna salad + greens", calories: 480, protein: 46, carbs: 24, fat: 18, time: t(3))
                ],
                recentActivity: [
                    MockActivityLogEntry(icon: "syringe.fill", title: "Tirzepatide injection logged", time: t(10)),
                    MockActivityLogEntry(icon: "dumbbell.fill", title: "Completed Upper Hypertrophy", time: t(4)),
                    MockActivityLogEntry(icon: "fork.knife", title: "Logged lunch (480 cal)", time: t(3))
                ]
            )
        ),
        MockFriendProfile(
            user: SocialUser(
                id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                name: "Jordan Blake",
                username: "jblake",
                avatarInitial: "J",
                avatarColor: PepTheme.amber,
                activeProgramName: "Bulk + GLP-1",
                streak: 18,
                totalFP: 14780
            ),
            bio: "Lean bulk while microdosing GLP-1 for appetite control.",
            goal: "Add 4kg lean mass, keep BF under 16%",
            weeklyWorkouts: 5,
            totalWorkouts: 211,
            weeklyVolumeKg: 24600,
            weeklySteps: 64200,
            weeklyCalories: 3020,
            weeklyWaterMl: 22000,
            latestPR: "OHP 100kg×3",
            activeProtocols: [
                MockProtocol(name: "Retatrutide", dosage: "1mg", frequency: "Weekly", week: 4, totalWeeks: 16),
                MockProtocol(name: "CJC-1295/Ipamorelin", dosage: "100/100mcg", frequency: "Pre-bed", week: 6, totalWeeks: 12)
            ],
            recentWorkouts: [
                MockWorkout(name: "Push — OHP PR Day", date: t(10), durationMin: 78, volumeKg: 5640, calories: 620, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Overhead Press", sets: [
                        MockSet(reps: 5, weightKg: 80, rpe: 7),
                        MockSet(reps: 3, weightKg: 90, rpe: 8.5),
                        MockSet(reps: 3, weightKg: 100, rpe: 9.5)
                    ]),
                    MockExerciseLog(name: "Bench Press", sets: [
                        MockSet(reps: 8, weightKg: 100, rpe: 7),
                        MockSet(reps: 8, weightKg: 100, rpe: 8),
                        MockSet(reps: 6, weightKg: 100, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Tricep Extension", sets: [
                        MockSet(reps: 12, weightKg: 30, rpe: 7),
                        MockSet(reps: 12, weightKg: 30, rpe: 8)
                    ])
                ]),
                MockWorkout(name: "Pull — Back Width", date: t(29), durationMin: 66, volumeKg: 4920, calories: 540, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Pull-up", sets: [
                        MockSet(reps: 10, weightKg: 0, rpe: 7),
                        MockSet(reps: 10, weightKg: 0, rpe: 8),
                        MockSet(reps: 8, weightKg: 0, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Barbell Row", sets: [
                        MockSet(reps: 8, weightKg: 100, rpe: 7),
                        MockSet(reps: 8, weightKg: 100, rpe: 8),
                        MockSet(reps: 6, weightKg: 100, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Bicep Curl", sets: [
                        MockSet(reps: 12, weightKg: 18, rpe: 7),
                        MockSet(reps: 10, weightKg: 18, rpe: 8)
                    ])
                ])
            ],
            today: MockTodaySnapshot(
                stepsSoFar: 7820,
                stepsGoal: 10000,
                caloriesBurned: 540,
                waterMl: 2200,
                waterGoalMl: 3500,
                meals: [
                    MockMeal(mealTime: "Breakfast", name: "Protein oats + nut butter", calories: 620, protein: 48, carbs: 72, fat: 18, time: t(6)),
                    MockMeal(mealTime: "Lunch", name: "Steak + rice + veg", calories: 820, protein: 62, carbs: 78, fat: 26, time: t(2)),
                    MockMeal(mealTime: "Snack", name: "Greek yogurt + berries", calories: 240, protein: 22, carbs: 28, fat: 4, time: t(0.5))
                ],
                recentActivity: [
                    MockActivityLogEntry(icon: "dumbbell.fill", title: "Completed Push — OHP PR Day", time: t(10)),
                    MockActivityLogEntry(icon: "fork.knife", title: "Logged lunch (820 cal)", time: t(2))
                ]
            )
        ),
        MockFriendProfile(
            user: SocialUser(
                id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                name: "Riley Tan",
                username: "rileyt",
                avatarInitial: "R",
                avatarColor: PepTheme.teal,
                activeProgramName: "Recomp + Sleep Stack",
                streak: 41,
                totalFP: 26340
            ),
            bio: "Sleep optimization arc. Tracking HRV, REM, recovery.",
            goal: "85+ recovery score 5/7 days, recomp on the side",
            weeklyWorkouts: 4,
            totalWorkouts: 198,
            weeklyVolumeKg: 17800,
            weeklySteps: 71200,
            weeklyCalories: 2940,
            weeklyWaterMl: 23000,
            latestPR: "Front Squat 140kg×3",
            activeProtocols: [
                MockProtocol(name: "Magnesium Glycinate", dosage: "400mg", frequency: "Pre-bed", week: 18, totalWeeks: 52),
                MockProtocol(name: "DSIP", dosage: "100mcg", frequency: "Pre-bed", week: 5, totalWeeks: 8),
                MockProtocol(name: "Apigenin", dosage: "50mg", frequency: "Pre-bed", week: 6, totalWeeks: 12)
            ],
            recentWorkouts: [
                MockWorkout(name: "Lower Strength", date: t(12), durationMin: 70, volumeKg: 5100, calories: 580, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Front Squat", sets: [
                        MockSet(reps: 5, weightKg: 120, rpe: 7),
                        MockSet(reps: 3, weightKg: 130, rpe: 8.5),
                        MockSet(reps: 3, weightKg: 140, rpe: 9.5)
                    ]),
                    MockExerciseLog(name: "Romanian Deadlift", sets: [
                        MockSet(reps: 8, weightKg: 120, rpe: 7),
                        MockSet(reps: 8, weightKg: 120, rpe: 8),
                        MockSet(reps: 6, weightKg: 120, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Bulgarian Split Squat", sets: [
                        MockSet(reps: 10, weightKg: 20, rpe: 8),
                        MockSet(reps: 10, weightKg: 20, rpe: 8.5)
                    ])
                ]),
                MockWorkout(name: "Easy Zone 2", date: t(51), durationMin: 50, volumeKg: 0, calories: 410, sport: "Run", exercises: [])
            ],
            today: MockTodaySnapshot(
                stepsSoFar: 8420,
                stepsGoal: 10000,
                caloriesBurned: 480,
                waterMl: 2600,
                waterGoalMl: 3500,
                meals: [
                    MockMeal(mealTime: "Breakfast", name: "Avocado toast + eggs", calories: 540, protein: 28, carbs: 42, fat: 28, time: t(5))
                ],
                recentActivity: [
                    MockActivityLogEntry(icon: "moon.fill", title: "Recovery score: 88", time: t(11)),
                    MockActivityLogEntry(icon: "syringe.fill", title: "Magnesium + Apigenin logged", time: t(11))
                ]
            )
        ),
        MockFriendProfile(
            user: SocialUser(
                id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
                name: "Nadia Brooks",
                username: "nadiab",
                avatarInitial: "N",
                avatarColor: PepTheme.amber,
                activeProgramName: "Postpartum Rebuild",
                streak: 15,
                totalFP: 7820
            ),
            bio: "8 months postpartum. Slow rebuild. Form > weight.",
            goal: "Restore core stability, hit pre-preg lifts by month 12",
            weeklyWorkouts: 4,
            totalWorkouts: 47,
            weeklyVolumeKg: 9200,
            weeklySteps: 58400,
            weeklyCalories: 2480,
            weeklyWaterMl: 25000,
            latestPR: "RDL 100kg×5",
            activeProtocols: [
                MockProtocol(name: "Collagen Peptides", dosage: "20g", frequency: "Daily", week: 8, totalWeeks: 24),
                MockProtocol(name: "Iron Bisglycinate", dosage: "25mg", frequency: "Daily", week: 32, totalWeeks: 52)
            ],
            recentWorkouts: [
                MockWorkout(name: "Core + Posterior Chain", date: t(28), durationMin: 45, volumeKg: 2800, calories: 320, sport: "Strength", exercises: [
                    MockExerciseLog(name: "Romanian Deadlift", sets: [
                        MockSet(reps: 5, weightKg: 100, rpe: 8),
                        MockSet(reps: 5, weightKg: 100, rpe: 8.5),
                        MockSet(reps: 5, weightKg: 100, rpe: 9)
                    ]),
                    MockExerciseLog(name: "Glute Bridge", sets: [
                        MockSet(reps: 12, weightKg: 60, rpe: 7),
                        MockSet(reps: 12, weightKg: 60, rpe: 8)
                    ]),
                    MockExerciseLog(name: "Dead Bug", sets: [
                        MockSet(reps: 12, weightKg: 0, rpe: nil),
                        MockSet(reps: 12, weightKg: 0, rpe: nil),
                        MockSet(reps: 10, weightKg: 0, rpe: nil)
                    ])
                ]),
                MockWorkout(name: "Stroller Walk 5K", date: t(30), durationMin: 52, volumeKg: 0, calories: 280, sport: "Walk", exercises: [])
            ],
            today: MockTodaySnapshot(
                stepsSoFar: 5640,
                stepsGoal: 8000,
                caloriesBurned: 320,
                waterMl: 2800,
                waterGoalMl: 3000,
                meals: [
                    MockMeal(mealTime: "Breakfast", name: "Oatmeal + collagen", calories: 380, protein: 24, carbs: 52, fat: 8, time: t(6))
                ],
                recentActivity: [
                    MockActivityLogEntry(icon: "drop.fill", title: "Hit water goal early", time: t(2)),
                    MockActivityLogEntry(icon: "syringe.fill", title: "Collagen + Iron logged", time: t(6))
                ]
            )
        )
    ]

    var friends: [SocialUser] { profiles.map { $0.user } }
    var ids: [String] { profiles.map { $0.user.id.uuidString } }
    var count: Int { profiles.count }

    func friend(byId id: String) -> SocialUser? {
        let target = id.lowercased()
        return profiles.first { $0.user.id.uuidString.lowercased() == target }?.user
    }

    func profile(byId id: String) -> MockFriendProfile? {
        let target = id.lowercased()
        return profiles.first { $0.user.id.uuidString.lowercased() == target }
    }

    func contains(id: String) -> Bool {
        friend(byId: id) != nil
    }

    func snapshots() -> [FriendStatSnapshot] {
        profiles.map { p in
            let activeProtocol = p.activeProtocols.first.map { "\($0.name) · wk \($0.week)/\($0.totalWeeks)" }
            let (lastTitle, lastAt) = mostRecentLog(for: p)
            return FriendStatSnapshot(
                id: p.user.id,
                user: p.user,
                isSharing: true,
                streak: p.user.streak,
                weeklyWorkouts: p.weeklyWorkouts,
                totalWorkouts: p.totalWorkouts,
                weeklyVolume: p.weeklyVolumeKg,
                weeklySteps: p.weeklySteps,
                weeklyCalories: p.weeklyCalories,
                weeklyWaterMl: p.weeklyWaterMl,
                latestPR: p.latestPR,
                activeProgram: p.user.activeProgramName,
                activeProtocol: activeProtocol,
                sharedCategories: Set(StatShareCategory.allCases),
                lastActivityTitle: lastTitle,
                lastActivityAt: lastAt,
                phase: FriendStatSnapshot.derivePhase(programName: p.user.activeProgramName, goalText: p.goal)
            )
        }
    }

    /// Most recent log of ANY kind — workout, meal, protocol dose, or other recent activity entry.
    private func mostRecentLog(for p: MockFriendProfile) -> (title: String?, at: Date?) {
        var candidates: [(String, Date)] = []
        if let w = p.recentWorkouts.first {
            candidates.append((w.name, w.date))
        }
        if let m = p.today.meals.max(by: { $0.time < $1.time }) {
            candidates.append(("\(m.mealTime) — \(m.name)", m.time))
        }
        if let entry = p.today.recentActivity.max(by: { $0.time < $1.time }) {
            candidates.append((entry.title, entry.time))
        }
        guard let best = candidates.max(by: { $0.1 < $1.1 }) else { return (nil, nil) }
        return (best.0, best.1)
    }

    func activityEvents() -> [FriendActivityEvent] {
        var events: [FriendActivityEvent] = []
        for p in profiles {
            for w in p.recentWorkouts {
                events.append(FriendActivityEvent(
                    id: UUID(),
                    user: p.user,
                    type: .workout,
                    title: "\(p.user.name) completed \(w.name)",
                    subtitle: "\(w.durationMin) min · \(w.calories) cal" + (w.volumeKg > 0 ? " · \(w.volumeKg)kg volume" : ""),
                    timestamp: w.date
                ))
            }
            if !p.latestPR.isEmpty {
                events.append(FriendActivityEvent(
                    id: UUID(),
                    user: p.user,
                    type: .pr,
                    title: "\(p.user.name) hit a PR: \(p.latestPR)",
                    subtitle: nil,
                    timestamp: Date().addingTimeInterval(-Double.random(in: 3600...86400 * 3))
                ))
            }
            if p.user.streak > 0 && p.user.streak % 7 == 0 {
                events.append(FriendActivityEvent(
                    id: UUID(),
                    user: p.user,
                    type: .streakMilestone,
                    title: "\(p.user.name) hit a \(p.user.streak)-day streak",
                    subtitle: "Keep it going!",
                    timestamp: Date().addingTimeInterval(-Double.random(in: 0...86400))
                ))
            }
            if let proto = p.activeProtocols.first {
                events.append(FriendActivityEvent(
                    id: UUID(),
                    user: p.user,
                    type: .protocolStart,
                    title: "\(p.user.name) is on \(proto.name)",
                    subtitle: "Week \(proto.week) of \(proto.totalWeeks) · \(proto.dosage) \(proto.frequency)",
                    timestamp: Date().addingTimeInterval(-Double.random(in: 86400...86400 * 5))
                ))
            }
            if let program = p.user.activeProgramName {
                events.append(FriendActivityEvent(
                    id: UUID(),
                    user: p.user,
                    type: .programStart,
                    title: "\(p.user.name) is running \(program)",
                    subtitle: nil,
                    timestamp: Date().addingTimeInterval(-Double.random(in: 86400 * 2...86400 * 7))
                ))
            }
        }
        return events.sorted { $0.timestamp > $1.timestamp }
    }
}
