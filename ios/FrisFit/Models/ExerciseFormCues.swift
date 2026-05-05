import Foundation

/// Curated, short form cues per exercise id. Used by `Exercise.formCues` when no
/// custom cues are provided on the exercise itself.
nonisolated enum ExerciseFormCues {
    static func cues(for exerciseId: String) -> [String] {
        dictionary[exerciseId] ?? []
    }

    private static let dictionary: [String: [String]] = [
        "barbell-bench-press": [
            "Retract and depress your shoulder blades before unracking",
            "Touch the bar to your mid-chest, nipple line",
            "Elbows tucked around 60–75° from the torso",
            "Drive your feet hard into the floor",
            "Lock out with a straight, vertical bar path"
        ],
        "dumbbell-bench-press": [
            "Kick the dumbbells up one at a time from your thighs",
            "Lower until elbows are just below bench height",
            "Keep wrists stacked over elbows",
            "Press up and slightly in — don't bang them together"
        ],
        "incline-barbell-press": [
            "Use a 30° incline, not steeper",
            "Touch the upper chest, just below the collarbone",
            "Keep elbows at ~60° from torso",
            "Drive the bar back over your upper chest at lockout"
        ],
        "incline-dumbbell-press": [
            "Set bench to 30°",
            "Stretch to just below shoulder level",
            "Elbows stacked under wrists",
            "Squeeze chest at the top without clanking dumbbells"
        ],
        "dumbbell-flyes": [
            "Maintain a soft, fixed elbow bend the whole set",
            "Lower in a wide arc until you feel the chest stretch",
            "Think 'hug a tree' to bring them together",
            "Stop just shy of weights touching to keep tension"
        ],
        "cable-crossover": [
            "Slight forward lean with a staggered stance",
            "Soft elbow bend locked in",
            "Bring hands together in front of your hips",
            "Squeeze 1 second at the bottom"
        ],
        "chest-dips": [
            "Lean torso ~30° forward throughout",
            "Lower until shoulders drop below elbows",
            "Keep elbows flared slightly, not behind you",
            "Drive through the palms, squeeze chest at the top"
        ],
        "machine-chest-press": [
            "Seat height: handles line up with mid-chest",
            "Retract shoulder blades before starting",
            "Press out, don't shrug up",
            "Stop just shy of full elbow lockout"
        ],
        "push-ups": [
            "Hands under shoulders, slightly wider",
            "Brace abs and glutes — plank from head to heels",
            "Lower chest to the floor, elbows at 45°",
            "Push the floor away to lock out"
        ],
        "barbell-deadlift": [
            "Bar over mid-foot before the pull",
            "Shoulders just in front of the bar at setup",
            "Take the slack out — wedge and brace",
            "Push the floor away, bar stays on the body",
            "Lock out by squeezing glutes — don't hyperextend"
        ],
        "barbell-row": [
            "Hinge to ~45° with a flat back",
            "Pull the bar to your lower chest/upper abdomen",
            "Lead with the elbows",
            "Squeeze shoulder blades at the top for a beat"
        ],
        "pull-ups": [
            "Start from a dead hang with shoulders engaged",
            "Drive elbows down and back",
            "Chest up, chin clears the bar",
            "Control the descent to full extension"
        ],
        "lat-pulldown": [
            "Slight backward lean — no rocking",
            "Pull to upper chest, elbows down and back",
            "Squeeze lats at the bottom",
            "Let the bar travel fully overhead on the return"
        ],
        "seated-cable-row": [
            "Chest up, torso stationary",
            "Pull the handle to your lower chest",
            "Drive elbows straight back",
            "Control the stretch on the return"
        ],
        "dumbbell-row": [
            "Flat back, brace the non-working side on a bench",
            "Pull to the hip, not the armpit",
            "Elbow travels close to the body",
            "Don't rotate the torso to help"
        ],
        "overhead-press": [
            "Bar rests on the front delts at the start",
            "Brace hard — glutes, abs, lats",
            "Press bar in a straight vertical line",
            "Tuck your head through at lockout"
        ],
        "dumbbell-shoulder-press": [
            "Start at ear level with wrists stacked",
            "Press up and slightly in",
            "Don't bang the dumbbells at the top",
            "Lower under control to a full stretch"
        ],
        "lateral-raises": [
            "Slight forward lean to target side delts",
            "Lead with the elbows, not the hands",
            "Raise to shoulder height — no higher",
            "Pause and lower slowly (2-second negative)"
        ],
        "arnold-press": [
            "Start with palms facing you, dumbbells in front",
            "Rotate smoothly as you press",
            "Full overhead lockout, no elbow flare",
            "Reverse the rotation on the way down"
        ],
        "barbell-curl": [
            "Elbows pinned to your sides the whole rep",
            "Start with a full stretch at the bottom",
            "Curl without using the hips",
            "Squeeze hard at the top — don't rest"
        ],
        "dumbbell-curl": [
            "Supinate (rotate pinky up) as you curl",
            "Keep elbows still and torso upright",
            "Full stretch at the bottom, full squeeze at top",
            "Alternate or do both — just don't swing"
        ],
        "hammer-curl": [
            "Neutral grip — palms face each other",
            "Elbows locked at your sides",
            "Curl with the same bicep isolation cues",
            "Great for brachialis and forearm mass"
        ],
        "tricep-pushdown": [
            "Elbows pinned tight to your ribs",
            "Only the forearms move",
            "Lock out without leaning over the bar",
            "Control the eccentric back to 90°"
        ],
        "skull-crushers": [
            "Keep upper arms perpendicular to the floor",
            "Lower to forehead or just past",
            "Elbows stay in — no flaring",
            "Extend fully without locking out aggressively"
        ],
        "close-grip-bench": [
            "Grip is shoulder-width — no narrower",
            "Tuck elbows close to the torso",
            "Bar touches lower chest/upper abdomen",
            "Drive through the triceps to lock out"
        ],
        "barbell-squat": [
            "Bar racked on upper traps or rear delts",
            "Feet shoulder-width, toes slightly out",
            "Brace like you're taking a punch, then break at hips and knees together",
            "Knees track over toes, chest stays proud",
            "Drive through the whole foot to stand"
        ],
        "front-squat": [
            "High elbows throughout — fingertip rack is fine",
            "Torso stays very upright",
            "Break at knees and hips together",
            "Drive up through the heels"
        ],
        "leg-press": [
            "Feet shoulder-width on the platform",
            "Lower until knees reach ~90°",
            "Don't let the lower back round off the pad",
            "Don't lock out knees hard at the top"
        ],
        "leg-extension": [
            "Pad just above your ankles",
            "Full extension, one-second squeeze",
            "Lower slowly — control the negative",
            "Don't slam the weight stack"
        ],
        "goblet-squat": [
            "Dumbbell held vertically at the chest",
            "Elbows tuck inside the knees",
            "Squat to full depth — hips below knees",
            "Drive up with chest tall"
        ],
        "bulgarian-split-squat": [
            "Rear foot on the bench, front foot far enough forward",
            "Front shin roughly vertical at the bottom",
            "Lower straight down — don't lunge forward",
            "Drive through the front heel to stand"
        ],
        "romanian-deadlift": [
            "Soft knee bend — not a squat",
            "Push the hips back, bar close to the legs",
            "Lower until you feel the hamstrings stretch",
            "Drive hips forward to lock out, squeeze glutes"
        ],
        "lying-leg-curl": [
            "Pad sits just above the heels",
            "Hips pressed down into the pad",
            "Curl fully — squeeze hamstrings at the top",
            "Lower slowly to a full stretch"
        ],
        "stiff-leg-deadlift": [
            "Slight knee bend — stays fixed",
            "Push hips back, chest proud",
            "Lower until you feel the stretch, don't force it",
            "Drive hips forward to stand"
        ],
        "hip-thrust": [
            "Shoulder blades on the bench, feet flat",
            "Chin tucked, ribs down",
            "Drive through the heels — hips to lockout",
            "Squeeze glutes 1 second at the top"
        ],
        "glute-bridge": [
            "Feet flat, knees bent ~90°",
            "Drive through the heels",
            "Full lockout — squeeze glutes hard",
            "Don't hyperextend the lower back"
        ],
        "walking-lunges": [
            "Step long enough that the front shin is vertical at the bottom",
            "Lower under control — no bouncing",
            "Drive through the front heel",
            "Torso stays upright"
        ],
        "standing-calf-raise": [
            "Full stretch at the bottom — heels drop low",
            "Up to the highest point on the balls of your feet",
            "1-second squeeze at the top",
            "Lower slowly, no bouncing"
        ],
        "seated-calf-raise": [
            "Full stretch at the bottom",
            "Squeeze hard at the top",
            "Pause at both ends of the range",
            "Great for soleus — use higher reps"
        ],
        "plank": [
            "Forearms under shoulders",
            "Brace abs, squeeze glutes",
            "Straight line from head to heels",
            "Breathe — don't hold your breath"
        ],
        "hanging-leg-raise": [
            "Pack shoulders — don't hang loose",
            "Raise legs to at least 90°",
            "No swinging or kipping",
            "Lower slowly to a dead hang"
        ],
        "russian-twist": [
            "Lean back ~45° with a flat back",
            "Rotate from the torso, not just the arms",
            "Count both sides as one rep",
            "Add weight once form is solid"
        ],
        "ab-wheel-rollout": [
            "Brace the core before moving",
            "Roll out as far as you can control",
            "Keep the lower back flat — no sagging",
            "Pull back with the abs, not the hips"
        ],
        "farmers-carry": [
            "Stand tall, shoulders packed and down",
            "Short, quick steps",
            "Brace abs — don't lean side to side",
            "Grip hard; let go only when done"
        ],
        "kettlebell-swing": [
            "Hinge, don't squat",
            "Power comes from the hip snap",
            "Arms are ropes — don't lift with them",
            "Bell floats to chest height at lockout"
        ],
        "burpees": [
            "Chest to the floor on each rep",
            "Jump feet forward close to the hands",
            "Explode straight up with arms overhead",
            "Keep a steady rhythm — don't flail"
        ],
        "thrusters": [
            "Front rack with high elbows",
            "Hit depth in the squat",
            "Use the leg drive to start the press",
            "Lock out overhead before descending"
        ],
        "jump-rope": [
            "Rotate from the wrists, not the arms",
            "Jump just 1–2 inches off the floor",
            "Land softly on the balls of the feet",
            "Keep elbows close to the body"
        ]
    ]
}
