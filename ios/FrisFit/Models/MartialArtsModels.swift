import Foundation
import SwiftUI

// MARK: - Discipline

nonisolated enum MartialArtsDiscipline: String, CaseIterable, Identifiable, Sendable, Codable {
    case bjj = "BJJ"
    case muayThai = "Muay Thai"
    case boxing = "Boxing"
    case mma = "MMA"
    case kickboxing = "Kickboxing"
    case karate = "Karate"
    case judo = "Judo"
    case taekwondo = "Taekwondo"
    case wrestling = "Wrestling"
    case kravMaga = "Krav Maga"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bjj: "figure.wrestling"
        case .muayThai: "figure.kickboxing"
        case .boxing: "figure.boxing"
        case .mma: "figure.martial.arts"
        case .kickboxing: "figure.kickboxing"
        case .karate: "figure.martial.arts"
        case .judo: "figure.wrestling"
        case .taekwondo: "figure.kickboxing"
        case .wrestling: "figure.wrestling"
        case .kravMaga: "figure.martial.arts"
        }
    }

    var color: Color {
        switch self {
        case .bjj: Color(red: 0.20, green: 0.50, blue: 0.95)
        case .muayThai: Color(red: 0.95, green: 0.35, blue: 0.10)
        case .boxing: Color(red: 0.95, green: 0.20, blue: 0.20)
        case .mma: Color(red: 0.85, green: 0.18, blue: 0.22)
        case .kickboxing: Color(red: 0.95, green: 0.50, blue: 0.18)
        case .karate: Color(red: 0.95, green: 0.85, blue: 0.20)
        case .judo: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .taekwondo: Color(red: 0.20, green: 0.78, blue: 0.55)
        case .wrestling: Color(red: 0.85, green: 0.50, blue: 0.20)
        case .kravMaga: Color(red: 0.40, green: 0.40, blue: 0.45)
        }
    }

    var tagline: String {
        switch self {
        case .bjj: "The gentle art."
        case .muayThai: "Eight limbs, all weapons."
        case .boxing: "The sweet science."
        case .mma: "Everything goes."
        case .kickboxing: "Fists and shins."
        case .karate: "Karate ni sente nashi."
        case .judo: "Maximum efficiency, mutual benefit."
        case .taekwondo: "Way of the foot and fist."
        case .wrestling: "Earn the takedown."
        case .kravMaga: "Defend, attack, escape."
        }
    }

    var primaryFocus: MartialArtsFocus {
        switch self {
        case .bjj, .judo, .wrestling: .grappling
        case .boxing: .striking
        case .muayThai, .kickboxing, .karate, .taekwondo: .striking
        case .mma, .kravMaga: .hybrid
        }
    }

    /// Belt / rank progression.
    var ranks: [String] {
        switch self {
        case .bjj: ["White", "Blue", "Purple", "Brown", "Black"]
        case .judo, .karate, .taekwondo, .kravMaga:
            ["White", "Yellow", "Orange", "Green", "Blue", "Purple", "Brown", "Red", "Black"]
        case .boxing, .muayThai, .kickboxing, .mma, .wrestling:
            ["Beginner", "Amateur", "Intermediate", "Advanced", "Pro"]
        }
    }
}

nonisolated enum MartialArtsFocus: String, Sendable, Codable {
    case striking
    case grappling
    case hybrid
}

// MARK: - Session type

nonisolated enum MartialArtsSessionType: String, CaseIterable, Identifiable, Sendable {
    case classSession = "Class"
    case sparring = "Sparring"
    case rolling = "Rolling"
    case drilling = "Drilling"
    case padwork = "Pads"
    case bagwork = "Bag"
    case shadowwork = "Shadow"
    case strengthCond = "S&C"
    case competition = "Competition"
    case openMat = "Open Mat"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .classSession: "graduationcap.fill"
        case .sparring: "figure.boxing"
        case .rolling: "figure.wrestling"
        case .drilling: "scope"
        case .padwork: "hand.raised.fill"
        case .bagwork: "bolt.fill"
        case .shadowwork: "figure.mind.and.body"
        case .strengthCond: "dumbbell.fill"
        case .competition: "trophy.fill"
        case .openMat: "person.3.fill"
        }
    }

    var isLive: Bool {
        switch self {
        case .sparring, .rolling, .competition: true
        default: false
        }
    }

    var isCompetitive: Bool {
        self == .competition
    }
}

// MARK: - Outcome

nonisolated enum MartialArtsOutcome: String, CaseIterable, Identifiable, Sendable, Codable {
    case win = "W"
    case loss = "L"
    case draw = "D"
    case noContest = "NC"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .win: "Win"
        case .loss: "Loss"
        case .draw: "Draw"
        case .noContest: "No Contest"
        }
    }

    var color: Color {
        switch self {
        case .win: .green
        case .loss: .red
        case .draw: .orange
        case .noContest: .gray
        }
    }
}

// MARK: - Session stats

nonisolated struct MartialArtsSessionStats: Sendable {
    // Striking
    var jabs: Int = 0
    var crosses: Int = 0
    var hooks: Int = 0
    var uppercuts: Int = 0
    var lowKicks: Int = 0
    var bodyKicks: Int = 0
    var headKicks: Int = 0
    var knees: Int = 0
    var elbows: Int = 0
    // Grappling
    var takedownsAttempted: Int = 0
    var takedownsLanded: Int = 0
    var sweepsLanded: Int = 0
    var passesLanded: Int = 0
    var submissionsAttempted: Int = 0
    var submissionsLanded: Int = 0
    var submissionsDefended: Int = 0
    var tapsGiven: Int = 0
    var tapsReceived: Int = 0
    // Live
    var roundsCompleted: Int = 0
    var roundDurationSeconds: Int = 180

    var totalStrikes: Int {
        jabs + crosses + hooks + uppercuts + lowKicks + bodyKicks + headKicks + knees + elbows
    }

    var takedownPercentage: Double {
        guard takedownsAttempted > 0 else { return 0 }
        return Double(takedownsLanded) / Double(takedownsAttempted)
    }

    var submissionRatio: Double {
        let net = submissionsLanded - tapsReceived
        return Double(net)
    }
}

// MARK: - Session record

nonisolated struct MartialArtsSession: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let discipline: MartialArtsDiscipline
    let sessionType: MartialArtsSessionType
    let durationMinutes: Int
    let stats: MartialArtsSessionStats
    let outcome: MartialArtsOutcome?
    let opponentName: String
    let coachName: String
    let gymName: String
    let energyRating: Int
    let techniqueRating: Int
    let cardioRating: Int
    let intensity: Int
    let techniquesWorked: [String]
    let notes: String

    init(
        date: Date = Date(),
        discipline: MartialArtsDiscipline = .bjj,
        sessionType: MartialArtsSessionType = .classSession,
        durationMinutes: Int = 60,
        stats: MartialArtsSessionStats = MartialArtsSessionStats(),
        outcome: MartialArtsOutcome? = nil,
        opponentName: String = "",
        coachName: String = "",
        gymName: String = "",
        energyRating: Int = 5,
        techniqueRating: Int = 5,
        cardioRating: Int = 5,
        intensity: Int = 6,
        techniquesWorked: [String] = [],
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.discipline = discipline
        self.sessionType = sessionType
        self.durationMinutes = durationMinutes
        self.stats = stats
        self.outcome = outcome
        self.opponentName = opponentName
        self.coachName = coachName
        self.gymName = gymName
        self.energyRating = energyRating
        self.techniqueRating = techniqueRating
        self.cardioRating = cardioRating
        self.intensity = intensity
        self.techniquesWorked = techniquesWorked
        self.notes = notes
    }
}

// MARK: - Drill library

nonisolated enum MartialArtsDrillCategory: String, CaseIterable, Identifiable, Sendable {
    case strikingTechnique = "Striking"
    case combos = "Combos"
    case footwork = "Footwork"
    case defense = "Defense"
    case clinch = "Clinch"
    case takedowns = "Takedowns"
    case guardWork = "Guard"
    case submissions = "Submissions"
    case escapes = "Escapes"
    case conditioning = "Conditioning"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .strikingTechnique: "bolt.fill"
        case .combos: "arrow.triangle.merge"
        case .footwork: "figure.run.circle"
        case .defense: "shield.lefthalf.filled"
        case .clinch: "person.2.fill"
        case .takedowns: "arrow.down.to.line"
        case .guardWork: "figure.wrestling"
        case .submissions: "hand.raised.fill"
        case .escapes: "arrow.uturn.up"
        case .conditioning: "bolt.heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .strikingTechnique: Color(red: 0.95, green: 0.30, blue: 0.20)
        case .combos: Color(red: 0.95, green: 0.55, blue: 0.10)
        case .footwork: Color(red: 0.85, green: 0.85, blue: 0.20)
        case .defense: Color(red: 0.20, green: 0.60, blue: 1.00)
        case .clinch: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .takedowns: Color(red: 0.85, green: 0.50, blue: 0.20)
        case .guardWork: Color(red: 0.20, green: 0.50, blue: 0.95)
        case .submissions: Color(red: 0.85, green: 0.18, blue: 0.22)
        case .escapes: Color(red: 0.20, green: 0.78, blue: 0.55)
        case .conditioning: Color(red: 0.95, green: 0.30, blue: 0.55)
        }
    }
}

nonisolated enum MartialArtsDrillDifficulty: String, CaseIterable, Identifiable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .beginner: .green
        case .intermediate: .orange
        case .advanced: .red
        }
    }
}

nonisolated struct MartialArtsDrill: Identifiable, Sendable {
    let id: UUID
    let name: String
    let discipline: MartialArtsDiscipline
    let category: MartialArtsDrillCategory
    let difficulty: MartialArtsDrillDifficulty
    let durationMinutes: Int
    let description: String
    let purpose: String
    let equipment: String
    let steps: [String]
    let cues: [String]
    let setsReps: String?

    init(
        name: String,
        discipline: MartialArtsDiscipline,
        category: MartialArtsDrillCategory,
        difficulty: MartialArtsDrillDifficulty,
        durationMinutes: Int,
        description: String,
        purpose: String,
        equipment: String = "Mat / Open space",
        steps: [String] = [],
        cues: [String] = [],
        setsReps: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.discipline = discipline
        self.category = category
        self.difficulty = difficulty
        self.durationMinutes = durationMinutes
        self.description = description
        self.purpose = purpose
        self.equipment = equipment
        self.steps = steps
        self.cues = cues
        self.setsReps = setsReps
    }
}

nonisolated enum MartialArtsDrillLibrary {
    static let all: [MartialArtsDrill] = [
        // BOXING
        MartialArtsDrill(
            name: "Jab–Cross Tempo",
            discipline: .boxing,
            category: .strikingTechnique,
            difficulty: .beginner,
            durationMinutes: 8,
            description: "Throw straight 1-2s on a metronome to lock in mechanics and rhythm.",
            purpose: "Cement clean fundamentals — the foundation of every boxing combo.",
            equipment: "Mirror or shadow space",
            steps: [
                "Stand in stance, hands at the chin.",
                "Snap a jab — exhale, return on the same line.",
                "Cross — rotate the back hip, full extension.",
                "Reset, repeat at a steady tempo for the round."
            ],
            cues: [
                "Chin tucked, elbows in.",
                "Snap, don't push.",
                "Eyes through the target."
            ],
            setsReps: "3 × 3 min rounds"
        ),
        MartialArtsDrill(
            name: "Slip-Counter Drill",
            discipline: .boxing,
            category: .defense,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Partner throws a jab; slip to the outside and return a 2-3 counter.",
            purpose: "Train head movement and immediate offense out of defense.",
            equipment: "Partner, gloves",
            steps: [
                "Partner throws a slow jab.",
                "Slip outside — chin behind shoulder.",
                "Return with a cross-hook combo.",
                "Reset to stance, repeat."
            ],
            cues: [
                "Slip an inch, not a foot.",
                "Counter from the slip, not after.",
                "Stay tall, bend at the knees."
            ],
            setsReps: "4 × 2 min rounds"
        ),
        MartialArtsDrill(
            name: "6-Punch Power Combo",
            discipline: .boxing,
            category: .combos,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "1-2-3-2-3-2 on the heavy bag with full hip rotation on every shot.",
            purpose: "Build cardio, output, and the ability to finish under fatigue.",
            equipment: "Heavy bag, gloves",
            steps: [
                "Throw 1-2 clean.",
                "Lead hook (3) — pivot foot.",
                "Cross (2) over the top.",
                "Lead hook (3), cross (2)."
            ],
            cues: [
                "Drive from the floor.",
                "Hands back home every shot.",
                "Don't muscle it — turn through it."
            ],
            setsReps: "5 × 3 min rounds"
        ),

        // MUAY THAI
        MartialArtsDrill(
            name: "Teep Recovery",
            discipline: .muayThai,
            category: .strikingTechnique,
            difficulty: .beginner,
            durationMinutes: 8,
            description: "Long teep, push-kick recovery, return to stance — control the distance.",
            purpose: "Own the kicking range and break opponent rhythm.",
            equipment: "Mirror or partner with kick shield",
            steps: [
                "Step in stance, weight on rear foot.",
                "Fire teep — toes pulled back, hip drive.",
                "Pull leg sharp back to stance.",
                "Reset distance and repeat."
            ],
            cues: [
                "Knee up first, then extend.",
                "Land with shoulders back.",
                "Back foot owns the power."
            ],
            setsReps: "4 × 2 min rounds"
        ),
        MartialArtsDrill(
            name: "Leg-Kick Tempo",
            discipline: .muayThai,
            category: .strikingTechnique,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Switch-kick low on rhythm — keep the shin connecting on the same line.",
            purpose: "Develop the low kick that dictates the fight.",
            equipment: "Heavy bag or pads",
            steps: [
                "Switch step — load the rear leg.",
                "Hip rotate, shin sweeps through.",
                "Return same path, hands up.",
                "Alternate sides each round."
            ],
            cues: [
                "Hip turns the kick, not the foot.",
                "Step to the side, don't kick across.",
                "Connect with shin, not foot."
            ],
            setsReps: "5 × 3 min rounds"
        ),
        MartialArtsDrill(
            name: "Clinch Knees & Sweeps",
            discipline: .muayThai,
            category: .clinch,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "Plum clinch — knees, off-balance, throw or kick to break.",
            purpose: "Win the clinch range — uniquely Thai, uniquely brutal.",
            equipment: "Partner, mouthpiece",
            steps: [
                "Establish double collar tie.",
                "Drive knees alternately to the body.",
                "Pivot to off-balance partner.",
                "Push and disengage with a kick."
            ],
            cues: [
                "Elbows in, head down.",
                "Move the partner — don't stand still.",
                "Knee through, not at."
            ],
            setsReps: "4 × 3 min rounds"
        ),

        // BJJ
        MartialArtsDrill(
            name: "Hip Escape Ladder",
            discipline: .bjj,
            category: .footwork,
            difficulty: .beginner,
            durationMinutes: 6,
            description: "Shrimp the length of the mat — both sides.",
            purpose: "Build the foundational movement of BJJ — hip escape is everything.",
            equipment: "Mat",
            steps: [
                "Lie on back, feet planted.",
                "Post foot, lift hips, slide on shoulder.",
                "Reset, alternate sides.",
                "Cross the mat 4 times."
            ],
            cues: [
                "Hips first, head last.",
                "Don't bridge — slide.",
                "Stay on the side, not flat."
            ],
            setsReps: "3 rounds, 2 lengths each"
        ),
        MartialArtsDrill(
            name: "Guard Retention Flow",
            discipline: .bjj,
            category: .guardWork,
            difficulty: .intermediate,
            durationMinutes: 12,
            description: "Partner tries to pass; hip escape, frame, recover guard repeatedly.",
            purpose: "Make recovery automatic so you never lose top control.",
            equipment: "Partner, gi or no-gi",
            steps: [
                "Partner starts in your guard, posts to pass.",
                "Hip escape, frame the cross-face.",
                "Pummel a knee or insert butterfly hook.",
                "Recover full guard, reset."
            ],
            cues: [
                "Frames before hips.",
                "Sit on the side, never flat.",
                "Move first, breathe second."
            ],
            setsReps: "5 × 2 min rounds"
        ),
        MartialArtsDrill(
            name: "Triangle from Closed Guard",
            discipline: .bjj,
            category: .submissions,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "Lock a triangle off the cross-grip break — angle, lock, finish.",
            purpose: "High-percentage closed guard finish for any belt level.",
            equipment: "Partner, gi or no-gi",
            steps: [
                "Cross-grip the wrist, post other hand.",
                "Hip-out 45°, climb leg over the shoulder.",
                "Lock the triangle, pull head down.",
                "Squeeze knees and arch hips for the tap."
            ],
            cues: [
                "Get the angle before the lock.",
                "Cut the angle, don't sit square.",
                "Pull the head — don't just squeeze."
            ],
            setsReps: "10 reps each side"
        ),

        // WRESTLING
        MartialArtsDrill(
            name: "Penetration Step Reps",
            discipline: .wrestling,
            category: .takedowns,
            difficulty: .beginner,
            durationMinutes: 8,
            description: "Drive forward into a clean shot — no partner, perfect mechanics.",
            purpose: "Burn in the lead-leg drive that finishes every wrestling takedown.",
            equipment: "Mat",
            steps: [
                "Stance — knees bent, hips back.",
                "Drop level, lead foot drives in.",
                "Rear knee touches the mat, head up.",
                "Stand up, reset."
            ],
            cues: [
                "Level change first, then step.",
                "Toes forward, knee aligned.",
                "Hands up to the chest."
            ],
            setsReps: "5 sets of 10 each leg"
        ),
        MartialArtsDrill(
            name: "Single-Leg Finish Series",
            discipline: .wrestling,
            category: .takedowns,
            difficulty: .intermediate,
            durationMinutes: 12,
            description: "Run-the-pipe, dump, and high crotch finishes from a clean single.",
            purpose: "Three reliable finishes when the partner sprawls or reacts.",
            equipment: "Partner, mat",
            steps: [
                "Hit a clean single, head inside.",
                "Run-the-pipe — circle and trip.",
                "Reset; partner sprawls — pivot to the dump.",
                "Reset; switch to high crotch and lift."
            ],
            cues: [
                "Head pressure first.",
                "Move the partner before finishing.",
                "Squeeze the leg into your chest."
            ],
            setsReps: "3 × 8 reps each finish"
        ),

        // MMA
        MartialArtsDrill(
            name: "Cage Stance & Switch",
            discipline: .mma,
            category: .footwork,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Move the cage with pivots, level changes, and stance switches.",
            purpose: "Avoid getting pinned — own the angle.",
            equipment: "Cage / wall",
            steps: [
                "Start with back to cage.",
                "Pivot to either side — circle off.",
                "Mid-pivot, throw a 1-2 to clear.",
                "Reset. 30 seconds, recover."
            ],
            cues: [
                "Don't square up.",
                "Pivot off the back foot.",
                "Frame the partner before you move."
            ],
            setsReps: "5 × 1 min rounds"
        ),
        MartialArtsDrill(
            name: "Strike-to-Takedown Chain",
            discipline: .mma,
            category: .combos,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "Set up a level change behind a 1-2 and finish a double leg.",
            purpose: "The signature MMA chain — sell the strike, take the legs.",
            equipment: "Partner, mat",
            steps: [
                "Throw a clean 1-2 to the head.",
                "Drop level off the cross.",
                "Drive forward, double leg shot.",
                "Lift, finish to side."
            ],
            cues: [
                "Sell the punch — full extension.",
                "Don't telegraph the level change.",
                "Pop the hips, don't just push."
            ],
            setsReps: "4 × 8 reps"
        ),

        // KICKBOXING
        MartialArtsDrill(
            name: "Round Kick Triple",
            discipline: .kickboxing,
            category: .combos,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Low–body–head kick on the same side without resetting stance.",
            purpose: "Train the trick of climbing the body with your shin.",
            equipment: "Heavy bag",
            steps: [
                "Throw a leg kick, return to stance.",
                "Body kick on the same side.",
                "Head kick on the same side.",
                "Reset, switch sides next round."
            ],
            cues: [
                "Same hip rotation each time.",
                "Don't fall away — stay over the post leg.",
                "Hands up after each kick."
            ],
            setsReps: "4 × 3 min rounds"
        ),

        // KARATE
        MartialArtsDrill(
            name: "Reverse Punch Lunge",
            discipline: .karate,
            category: .strikingTechnique,
            difficulty: .beginner,
            durationMinutes: 8,
            description: "Step-in reverse punch with full hip drive — kihon staple.",
            purpose: "Build the snap and timing of the karate gyaku-zuki.",
            equipment: "Mirror or pad",
            steps: [
                "Front stance, hand on hip.",
                "Step forward, drive opposite hand.",
                "Snap punch with hip rotation.",
                "Hikite back to hip, reset."
            ],
            cues: [
                "Pull the rear hand — that's the power.",
                "Rotate hip into the punch.",
                "Sharp, quick, decisive."
            ],
            setsReps: "5 × 10 reps each side"
        ),

        // JUDO
        MartialArtsDrill(
            name: "Uchi-Komi Triple",
            discipline: .judo,
            category: .takedowns,
            difficulty: .beginner,
            durationMinutes: 10,
            description: "Three-rep uchi-komi — load, off-balance, throw position without finishing.",
            purpose: "Burn in the throw entry until it's automatic.",
            equipment: "Partner, gi",
            steps: [
                "Establish kumi-kata grip.",
                "Pull and step in for the throw.",
                "Three quick entries, no finish.",
                "Switch — partner's turn."
            ],
            cues: [
                "Off-balance first, then enter.",
                "Drop the hips, not the head.",
                "Speed first, power later."
            ],
            setsReps: "3 sets of 30 reps"
        ),
        MartialArtsDrill(
            name: "Seoi-Nage Finish",
            discipline: .judo,
            category: .takedowns,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "Full ippon seoi-nage with a partner taking ukemi.",
            purpose: "Master the shoulder throw — Olympic finish on demand.",
            equipment: "Partner, gi, crash mat",
            steps: [
                "Grip sleeve and lapel.",
                "Pull, drop, turn under.",
                "Load on the back, lift with legs.",
                "Throw, control, score."
            ],
            cues: [
                "Drop your level under their armpit.",
                "Stand up tall before the throw.",
                "Drive the head down on the finish."
            ],
            setsReps: "4 × 5 throws each side"
        ),

        // TAEKWONDO
        MartialArtsDrill(
            name: "Roundhouse Pivot Drill",
            discipline: .taekwondo,
            category: .strikingTechnique,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Pivot back foot 180°, snap roundhouse, reset clean.",
            purpose: "Sharpen the iconic taekwondo back-leg roundhouse.",
            equipment: "Pad or bag",
            steps: [
                "Stand in fighting stance.",
                "Pivot the back foot — knee chambers high.",
                "Snap kick, return same path.",
                "Land back to stance balanced."
            ],
            cues: [
                "Hip rotates the kick.",
                "Pivot all the way through.",
                "Whip from the hip, snap with the knee."
            ],
            setsReps: "5 × 20 reps each side"
        ),
        MartialArtsDrill(
            name: "Spinning Hook Kick",
            discipline: .taekwondo,
            category: .strikingTechnique,
            difficulty: .advanced,
            durationMinutes: 12,
            description: "Full spin, eyes on target, hook the heel through the line.",
            purpose: "Develop the highlight-reel finish — taekwondo's calling card.",
            equipment: "Partner with target or pad",
            steps: [
                "Stance, look over rear shoulder.",
                "Pivot front foot, spin.",
                "Kick swings horizontally — heel leads.",
                "Land balanced and reset."
            ],
            cues: [
                "Eyes find target before the leg.",
                "Heel through the line, not at it.",
                "Stay tall — don't lean."
            ],
            setsReps: "4 × 10 reps each side"
        ),

        // KRAV MAGA
        MartialArtsDrill(
            name: "360° Defense + Counter",
            discipline: .kravMaga,
            category: .defense,
            difficulty: .intermediate,
            durationMinutes: 10,
            description: "Block any incoming arc — same-side counter immediately after.",
            purpose: "Krav's signature defense — fast, repeatable, brutal.",
            equipment: "Partner with focus mitts",
            steps: [
                "Partner throws a hook from any angle.",
                "Block with same-side bone — arm vertical.",
                "Counter the throat / face on the same beat.",
                "Reset — partner picks new angle."
            ],
            cues: [
                "Don't block, attack the strike.",
                "Counter on the block.",
                "Aggression beats precision."
            ],
            setsReps: "4 × 2 min rounds"
        ),

        // CONDITIONING (any discipline)
        MartialArtsDrill(
            name: "Burnout Bag Round",
            discipline: .mma,
            category: .conditioning,
            difficulty: .advanced,
            durationMinutes: 6,
            description: "5 minutes max output on the heavy bag — punches, knees, kicks.",
            purpose: "Build fight-finish cardio — the last round mentality.",
            equipment: "Heavy bag, gloves",
            steps: [
                "First minute: jab-cross only.",
                "Minute 2: add hooks and uppercuts.",
                "Minute 3: add kicks.",
                "Minutes 4–5: throw everything, no rest."
            ],
            cues: [
                "Breathe through the work.",
                "Form first, output second.",
                "Don't die in the last 30 seconds."
            ],
            setsReps: "3 × 5 min rounds, 1 min rest"
        ),
        MartialArtsDrill(
            name: "Shrimp + Stand-Up Burpee",
            discipline: .bjj,
            category: .conditioning,
            difficulty: .intermediate,
            durationMinutes: 8,
            description: "Shrimp, technical stand-up, burpee, repeat for time.",
            purpose: "BJJ-specific cardio — exit, stand, reset.",
            equipment: "Mat",
            steps: [
                "Shrimp 2x off your back.",
                "Technical stand-up to base.",
                "Drop and burpee.",
                "Drop back, repeat."
            ],
            cues: [
                "Don't rush form for speed.",
                "Drive the hand for the stand-up.",
                "Stay aware — visualize a partner."
            ],
            setsReps: "5 × 1 min rounds"
        ),
    ]

    static func filtered(discipline: MartialArtsDiscipline?) -> [MartialArtsDrill] {
        guard let discipline else { return all }
        return all.filter { $0.discipline == discipline }
    }
}

// MARK: - Drill items / saved sessions

nonisolated struct MartialArtsDrillItem: Identifiable, Sendable {
    let id: UUID
    var drillName: String
    var durationMinutes: Int
    var notes: String

    init(drillName: String, durationMinutes: Int, notes: String = "") {
        self.id = UUID()
        self.drillName = drillName
        self.durationMinutes = durationMinutes
        self.notes = notes
    }
}

nonisolated struct CustomMartialArtsSession: Identifiable, Sendable {
    let id: UUID
    var name: String
    var discipline: MartialArtsDiscipline
    var drills: [MartialArtsDrillItem]
    let dateCreated: Date

    init(name: String, discipline: MartialArtsDiscipline = .bjj, drills: [MartialArtsDrillItem] = [], dateCreated: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.discipline = discipline
        self.drills = drills
        self.dateCreated = dateCreated
    }

    var totalDuration: Int { drills.reduce(0) { $0 + $1.durationMinutes } }
}
