import Foundation

enum ExerciseLibrary {
    static let all: [Exercise] = chest + back + shoulders + biceps + triceps + quadriceps + hamstrings + glutes + calves + core + forearms + fullBody + cardioExercises

    static let chest: [Exercise] = [
        Exercise(
            id: "barbell-bench-press", name: "Barbell Bench Press", primaryMuscle: .chest,
            secondaryMuscles: [.triceps, .shoulders], movementPattern: .horizontalPress, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 120,
            instructions: ["Lie flat on the bench with feet firmly on the floor", "Grip the bar slightly wider than shoulder-width", "Unrack the bar and lower it to your mid-chest", "Press the bar up until arms are fully extended", "Keep your shoulder blades retracted throughout"],
            commonMistakes: ["Bouncing the bar off the chest", "Flaring elbows too wide", "Lifting hips off the bench", "Incomplete range of motion"],
            proTips: ["Drive your feet into the floor for leg drive", "Squeeze the bar hard to activate more muscle fibers", "Control the eccentric for 2-3 seconds"]
        ),
        Exercise(
            id: "dumbbell-bench-press", name: "Dumbbell Bench Press", primaryMuscle: .chest,
            secondaryMuscles: [.triceps, .shoulders], movementPattern: .horizontalPress, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Sit on the bench with dumbbells on your thighs", "Lie back and press the dumbbells to arm's length", "Lower the dumbbells to chest level with elbows at 45°", "Press back up, squeezing your chest at the top"],
            commonMistakes: ["Using momentum to swing the weights", "Not going deep enough on the stretch", "Uneven pressing"],
            proTips: ["Rotate your pinkies slightly inward at the top for peak contraction", "Use a spotter for heavy sets"]
        ),
        Exercise(
            id: "incline-barbell-press", name: "Incline Barbell Press", primaryMuscle: .chest,
            secondaryMuscles: [.shoulders, .triceps], movementPattern: .horizontalPress, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 120,
            instructions: ["Set the bench to a 30-45° incline", "Grip the bar slightly wider than shoulder-width", "Lower the bar to your upper chest", "Press up to full lockout"],
            commonMistakes: ["Setting the incline too steep", "Flaring the elbows excessively", "Using too much weight and losing control"],
            proTips: ["A 30° incline targets upper chest best without overloading shoulders", "Focus on squeezing the chest, not pushing with shoulders"]
        ),
        Exercise(
            id: "incline-dumbbell-press", name: "Incline Dumbbell Press", primaryMuscle: .chest,
            secondaryMuscles: [.shoulders, .triceps], movementPattern: .horizontalPress, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Set bench to 30-45° incline", "Press dumbbells from shoulder level to arm's length", "Lower with control, feeling the stretch in upper chest", "Press back up to full extension"],
            commonMistakes: ["Bench angle too high turning it into a shoulder press", "Not controlling the negative"],
            proTips: ["Bring the dumbbells together at the top for a stronger contraction"]
        ),
        Exercise(
            id: "dumbbell-flyes", name: "Dumbbell Flyes", primaryMuscle: .chest,
            secondaryMuscles: [.shoulders], movementPattern: .isolation, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Lie on a flat bench holding dumbbells above your chest", "With a slight bend in the elbows, lower the weights in an arc", "Lower until you feel a stretch in the chest", "Squeeze the chest to bring the weights back together"],
            commonMistakes: ["Bending elbows too much turning it into a press", "Going too heavy and losing form", "Not controlling the stretch"],
            proTips: ["Think of hugging a large tree to get the arc right", "Use lighter weight and focus on the mind-muscle connection"]
        ),
        Exercise(
            id: "cable-crossover", name: "Cable Crossover", primaryMuscle: .chest,
            secondaryMuscles: [.shoulders], movementPattern: .isolation, equipment: .cable,
            difficulty: .intermediate, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Set the cables to the highest position", "Step forward with one foot for stability", "With a slight elbow bend, bring your hands together in front of you", "Squeeze at the bottom and slowly return"],
            commonMistakes: ["Using too much weight and losing the squeeze", "Letting the cables control you on the return"],
            proTips: ["Cross your hands at the bottom for extra range of motion", "Vary pulley height to target different chest areas"]
        ),
        Exercise(
            id: "chest-dips", name: "Chest Dips", primaryMuscle: .chest,
            secondaryMuscles: [.triceps, .shoulders], movementPattern: .verticalPress, equipment: .bodyweight,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .bodyweightReps, defaultRestSeconds: 90,
            instructions: ["Grip the parallel bars and lift yourself up", "Lean your torso slightly forward", "Lower yourself until your upper arms are parallel to the floor", "Push back up to the starting position"],
            commonMistakes: ["Staying too upright which shifts focus to triceps", "Going too deep and stressing the shoulders", "Swinging the body"],
            proTips: ["Lean forward about 30° to maximize chest engagement", "Add weight with a dip belt once bodyweight becomes easy"]
        ),
        Exercise(
            id: "machine-chest-press", name: "Machine Chest Press", primaryMuscle: .chest,
            secondaryMuscles: [.triceps, .shoulders], movementPattern: .horizontalPress, equipment: .machine,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Adjust the seat so handles are at chest level", "Grip the handles and press forward", "Extend your arms fully without locking elbows", "Return slowly to the starting position"],
            commonMistakes: ["Seat too high or too low", "Jerking the weight", "Not using full range of motion"],
            proTips: ["Great for burnout sets after free weight pressing", "Use single-arm pressing to fix imbalances"]
        ),
        Exercise(
            id: "push-ups", name: "Push-Ups", primaryMuscle: .chest,
            secondaryMuscles: [.triceps, .shoulders, .core], movementPattern: .horizontalPress, equipment: .bodyweight,
            difficulty: .beginner, exerciseType: .compound, trackingType: .bodyweightReps, defaultRestSeconds: 60,
            instructions: ["Place hands slightly wider than shoulder-width", "Keep body in a straight line from head to heels", "Lower chest to the ground", "Push back up to full arm extension"],
            commonMistakes: ["Sagging hips", "Flaring elbows out to 90°", "Not reaching full depth"],
            proTips: ["Keep elbows at a 45° angle to protect shoulders", "Elevate feet for more difficulty, hands for less"]
        ),
    ]

    static let back: [Exercise] = [
        Exercise(
            id: "barbell-deadlift", name: "Barbell Deadlift", primaryMuscle: .back,
            secondaryMuscles: [.hamstrings, .glutes, .core, .forearms], movementPattern: .hipHinge, equipment: .barbell,
            difficulty: .advanced, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 180,
            instructions: ["Stand with feet hip-width apart, bar over mid-foot", "Hinge at the hips and grip the bar just outside your knees", "Brace your core and flatten your back", "Drive through the floor, keeping the bar close to your body", "Stand tall and squeeze glutes at the top"],
            commonMistakes: ["Rounding the lower back", "Bar drifting away from the body", "Jerking the bar off the floor", "Hyperextending at the top"],
            proTips: ["Think of pushing the floor away rather than pulling the bar up", "Use mixed grip or straps for heavy sets", "Master the hip hinge pattern with lighter weight first"]
        ),
        Exercise(
            id: "barbell-row", name: "Barbell Row", primaryMuscle: .back,
            secondaryMuscles: [.biceps, .forearms, .core], movementPattern: .horizontalPull, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Hinge forward at the hips about 45°", "Grip the bar slightly wider than shoulder-width", "Pull the bar to your lower chest/upper abdomen", "Squeeze your shoulder blades together at the top", "Lower with control"],
            commonMistakes: ["Using momentum and standing too upright", "Rounding the back", "Pulling with arms instead of back"],
            proTips: ["Lead with your elbows, not your hands", "Pause at the top for a one-second squeeze"]
        ),
        Exercise(
            id: "pull-ups", name: "Pull-Ups", primaryMuscle: .back,
            secondaryMuscles: [.biceps, .forearms], movementPattern: .verticalPull, equipment: .bodyweight,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .bodyweightReps, defaultRestSeconds: 120,
            instructions: ["Grip the bar with hands slightly wider than shoulder-width, palms facing away", "Hang with arms fully extended", "Pull yourself up until your chin clears the bar", "Lower yourself with control to full extension"],
            commonMistakes: ["Kipping or swinging", "Not reaching full extension at the bottom", "Half reps"],
            proTips: ["Use a resistance band for assistance if needed", "Focus on pulling your elbows down and back"]
        ),
        Exercise(
            id: "lat-pulldown", name: "Lat Pulldown", primaryMuscle: .back,
            secondaryMuscles: [.biceps, .forearms], movementPattern: .verticalPull, equipment: .cable,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Sit at the lat pulldown station and adjust the knee pad", "Grip the bar wider than shoulder-width", "Pull the bar down to your upper chest", "Squeeze shoulder blades together at the bottom", "Return the bar slowly overhead"],
            commonMistakes: ["Leaning too far back", "Pulling the bar behind the neck", "Using momentum"],
            proTips: ["Imagine pulling your elbows into your back pockets", "Try different grip widths to target different areas"]
        ),
        Exercise(
            id: "seated-cable-row", name: "Seated Cable Row", primaryMuscle: .back,
            secondaryMuscles: [.biceps, .forearms], movementPattern: .horizontalPull, equipment: .cable,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Sit with feet on the footplate, knees slightly bent", "Grip the handle with arms extended", "Pull the handle to your lower chest", "Squeeze your shoulder blades together", "Return with control, allowing a slight stretch"],
            commonMistakes: ["Rocking the torso back and forth", "Shrugging the shoulders", "Not squeezing at the top"],
            proTips: ["Keep your torso stationary — only your arms should move", "Use a V-bar for close grip or wide bar for width"]
        ),
        Exercise(
            id: "dumbbell-row", name: "Single-Arm Dumbbell Row", primaryMuscle: .back,
            secondaryMuscles: [.biceps, .forearms], movementPattern: .horizontalPull, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Place one knee and hand on a bench for support", "Hold a dumbbell in the other hand, arm hanging straight", "Pull the dumbbell to your hip, leading with the elbow", "Squeeze at the top and lower slowly"],
            commonMistakes: ["Rotating the torso to swing the weight", "Not pulling high enough", "Rounding the back"],
            proTips: ["Drive your elbow past your torso for full contraction", "Keep your core braced throughout"]
        ),
        Exercise(
            id: "t-bar-row", name: "T-Bar Row", primaryMuscle: .back,
            secondaryMuscles: [.biceps, .forearms, .core], movementPattern: .horizontalPull, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Straddle the bar and grip the handle", "Bend at the hips with a flat back", "Pull the weight to your chest", "Lower with control"],
            commonMistakes: ["Standing too upright", "Using momentum", "Rounding the back"],
            proTips: ["Keep chest proud and core tight throughout", "Use different handles to vary the stimulus"]
        ),
        Exercise(
            id: "face-pulls", name: "Face Pulls", primaryMuscle: .back,
            secondaryMuscles: [.shoulders], movementPattern: .horizontalPull, equipment: .cable,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Set cable at upper chest height with rope attachment", "Pull the rope toward your face, splitting the ends", "Externally rotate your shoulders at the end", "Return slowly to the start"],
            commonMistakes: ["Using too much weight", "Not pulling far enough back", "Leaning back excessively"],
            proTips: ["Think about pulling the rope apart, not just toward you", "Great for shoulder health and posture"]
        ),
    ]

    static let shoulders: [Exercise] = [
        Exercise(
            id: "overhead-press", name: "Barbell Overhead Press", primaryMuscle: .shoulders,
            secondaryMuscles: [.triceps, .core], movementPattern: .verticalPress, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 120,
            instructions: ["Stand with feet shoulder-width apart", "Grip the bar at shoulder width, resting on your front delts", "Press the bar overhead until arms are locked out", "Move your head through as the bar passes your face", "Lower the bar back to your shoulders"],
            commonMistakes: ["Excessive back arching", "Pressing the bar forward instead of straight up", "Not bracing the core"],
            proTips: ["Squeeze your glutes to prevent lower back arching", "The bar should travel in a straight vertical line"]
        ),
        Exercise(
            id: "dumbbell-shoulder-press", name: "Dumbbell Shoulder Press", primaryMuscle: .shoulders,
            secondaryMuscles: [.triceps], movementPattern: .verticalPress, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Sit or stand with dumbbells at shoulder height", "Press the dumbbells overhead until arms are extended", "Lower the dumbbells back to shoulder height"],
            commonMistakes: ["Arching the back", "Not pressing directly overhead", "Using momentum"],
            proTips: ["Seated version isolates shoulders more; standing engages core more"]
        ),
        Exercise(
            id: "lateral-raises", name: "Lateral Raises", primaryMuscle: .shoulders,
            secondaryMuscles: [], movementPattern: .isolation, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Stand with dumbbells at your sides", "With a slight elbow bend, raise your arms out to the sides", "Lift until arms are parallel to the floor", "Lower slowly back to your sides"],
            commonMistakes: ["Swinging the weights up", "Shrugging the traps", "Going too heavy"],
            proTips: ["Lead with your elbows, not your hands", "A slight forward lean can reduce trap involvement"]
        ),
        Exercise(
            id: "front-raises", name: "Front Raises", primaryMuscle: .shoulders,
            secondaryMuscles: [.chest], movementPattern: .isolation, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Stand holding dumbbells in front of your thighs", "Raise one or both arms straight in front to shoulder height", "Lower with control"],
            commonMistakes: ["Swinging the body", "Raising above shoulder height", "Going too heavy"],
            proTips: ["Alternate arms to maintain better form", "Use a thumbs-up grip for a different stimulus"]
        ),
        Exercise(
            id: "reverse-flyes", name: "Reverse Flyes", primaryMuscle: .shoulders,
            secondaryMuscles: [.back], movementPattern: .isolation, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Bend forward at the hips with dumbbells hanging below", "Raise the dumbbells out to the sides with a slight elbow bend", "Squeeze your shoulder blades at the top", "Lower slowly"],
            commonMistakes: ["Using momentum", "Not bending over enough", "Shrugging"],
            proTips: ["Keep your thumbs pointing slightly down to target rear delts more", "Excellent for posture improvement"]
        ),
        Exercise(
            id: "arnold-press", name: "Arnold Press", primaryMuscle: .shoulders,
            secondaryMuscles: [.triceps], movementPattern: .verticalPress, equipment: .dumbbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Start with dumbbells in front of your chest, palms facing you", "As you press up, rotate your palms to face forward", "Press to full lockout", "Reverse the rotation as you lower"],
            commonMistakes: ["Rushing the rotation", "Not pressing fully overhead", "Arching the back"],
            proTips: ["The rotation engages all three delt heads", "Control the weight through the entire arc"]
        ),
        Exercise(
            id: "cable-lateral-raise", name: "Cable Lateral Raise", primaryMuscle: .shoulders,
            secondaryMuscles: [], movementPattern: .isolation, equipment: .cable,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Stand sideways to a low cable with the handle in the far hand", "Raise your arm out to the side to shoulder height", "Lower with control"],
            commonMistakes: ["Leaning away too much", "Using body momentum"],
            proTips: ["Cables provide constant tension unlike dumbbells", "Great finisher exercise"]
        ),
        Exercise(
            id: "machine-shoulder-press", name: "Machine Shoulder Press", primaryMuscle: .shoulders,
            secondaryMuscles: [.triceps], movementPattern: .verticalPress, equipment: .machine,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Adjust the seat so handles are at shoulder height", "Grip the handles and press overhead", "Lower with control"],
            commonMistakes: ["Seat too low causing excessive arching", "Not using full range of motion"],
            proTips: ["Good for heavy overload without needing a spotter", "Use for burnout sets after free weight pressing"]
        ),
    ]

    static let biceps: [Exercise] = [
        Exercise(
            id: "barbell-curl", name: "Barbell Curl", primaryMuscle: .biceps,
            secondaryMuscles: [.forearms], movementPattern: .flexion, equipment: .barbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Stand with feet shoulder-width apart holding a barbell", "Keep elbows pinned to your sides", "Curl the bar up to shoulder level", "Lower with control to full extension"],
            commonMistakes: ["Swinging the body", "Moving the elbows forward", "Not fully extending at the bottom"],
            proTips: ["Use an EZ-bar to reduce wrist strain", "Squeeze hard at the top for peak contraction"]
        ),
        Exercise(
            id: "dumbbell-curl", name: "Dumbbell Curl", primaryMuscle: .biceps,
            secondaryMuscles: [.forearms], movementPattern: .flexion, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Stand or sit with dumbbells at your sides", "Curl the dumbbells up, supinating your wrists", "Squeeze at the top", "Lower with control"],
            commonMistakes: ["Using momentum", "Not supinating the wrists", "Partial range of motion"],
            proTips: ["Alternate arms for better focus on each side", "Supinate your wrists as you curl for better bicep activation"]
        ),
        Exercise(
            id: "hammer-curl", name: "Hammer Curl", primaryMuscle: .biceps,
            secondaryMuscles: [.forearms], movementPattern: .flexion, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Stand with dumbbells at your sides, palms facing your body", "Curl the dumbbells up keeping the neutral grip", "Lower with control"],
            commonMistakes: ["Swinging the weights", "Moving elbows away from sides"],
            proTips: ["Great for building the brachialis which adds arm width", "Keep palms facing each other throughout"]
        ),
        Exercise(
            id: "incline-dumbbell-curl", name: "Incline Dumbbell Curl", primaryMuscle: .biceps,
            secondaryMuscles: [.forearms], movementPattern: .flexion, equipment: .dumbbell,
            difficulty: .intermediate, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Sit on an incline bench set to 45°", "Let your arms hang straight down with dumbbells", "Curl the weight up without moving your upper arm", "Lower with control, getting a full stretch"],
            commonMistakes: ["Bringing elbows forward", "Using too much weight", "Not getting a full stretch at the bottom"],
            proTips: ["The incline puts the bicep in a stretched position for more growth", "Use lighter weight than standing curls"]
        ),
        Exercise(
            id: "preacher-curl", name: "Preacher Curl", primaryMuscle: .biceps,
            secondaryMuscles: [.forearms], movementPattern: .flexion, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Sit at the preacher bench with upper arms on the pad", "Grip the EZ-bar with arms extended", "Curl the bar up to shoulder level", "Lower slowly with control"],
            commonMistakes: ["Lifting off the pad at the top", "Dropping the weight too fast", "Not fully extending"],
            proTips: ["The pad eliminates cheating, making every rep strict", "Great for building the bicep peak"]
        ),
        Exercise(
            id: "cable-curl", name: "Cable Curl", primaryMuscle: .biceps,
            secondaryMuscles: [.forearms], movementPattern: .flexion, equipment: .cable,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Stand facing a low cable with a straight or EZ attachment", "Curl the handle up to shoulder level", "Squeeze and lower with control"],
            commonMistakes: ["Leaning back", "Moving elbows"],
            proTips: ["Cables provide constant tension through the entire range of motion"]
        ),
        Exercise(
            id: "concentration-curl", name: "Concentration Curl", primaryMuscle: .biceps,
            secondaryMuscles: [], movementPattern: .flexion, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Sit on a bench with legs spread", "Brace your elbow against your inner thigh", "Curl the dumbbell up toward your shoulder", "Squeeze and lower slowly"],
            commonMistakes: ["Moving the upper arm", "Using body momentum"],
            proTips: ["The braced position makes cheating nearly impossible", "Focus on the peak contraction at the top"]
        ),
    ]

    static let triceps: [Exercise] = [
        Exercise(
            id: "tricep-pushdown", name: "Tricep Pushdown", primaryMuscle: .triceps,
            secondaryMuscles: [], movementPattern: .extension_, equipment: .cable,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Stand at a cable station with a straight bar or rope attachment", "Keep elbows pinned at your sides", "Push the handle down until arms are fully extended", "Return slowly to 90° elbow bend"],
            commonMistakes: ["Flaring elbows out", "Leaning over the bar", "Using momentum"],
            proTips: ["Use the rope attachment and split at the bottom for extra contraction", "Keep upper arms perfectly still"]
        ),
        Exercise(
            id: "skull-crushers", name: "Skull Crushers", primaryMuscle: .triceps,
            secondaryMuscles: [], movementPattern: .extension_, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Lie on a bench holding an EZ-bar with arms extended overhead", "Lower the bar toward your forehead by bending the elbows", "Keep upper arms still — only forearms move", "Extend back to the start"],
            commonMistakes: ["Moving the elbows", "Bringing the bar to the nose instead of forehead", "Going too heavy"],
            proTips: ["Lower the bar slightly behind your head for a better stretch on the long head"]
        ),
        Exercise(
            id: "close-grip-bench", name: "Close-Grip Bench Press", primaryMuscle: .triceps,
            secondaryMuscles: [.chest, .shoulders], movementPattern: .horizontalPress, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Grip the barbell shoulder-width or slightly narrower", "Lower the bar to your lower chest", "Press up while keeping elbows close to your body"],
            commonMistakes: ["Grip too narrow causing wrist pain", "Flaring elbows", "Bouncing off chest"],
            proTips: ["Shoulder-width grip is sufficient — no need to go extremely narrow"]
        ),
        Exercise(
            id: "overhead-tricep-extension", name: "Overhead Tricep Extension", primaryMuscle: .triceps,
            secondaryMuscles: [], movementPattern: .extension_, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Hold a dumbbell overhead with both hands", "Lower it behind your head by bending the elbows", "Keep upper arms close to your ears", "Extend back to the starting position"],
            commonMistakes: ["Flaring the elbows", "Arching the back", "Using momentum"],
            proTips: ["This targets the long head of the tricep which makes up the most mass"]
        ),
        Exercise(
            id: "tricep-dips", name: "Tricep Dips", primaryMuscle: .triceps,
            secondaryMuscles: [.chest, .shoulders], movementPattern: .verticalPress, equipment: .bodyweight,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .bodyweightReps, defaultRestSeconds: 90,
            instructions: ["Grip the parallel bars and lift yourself", "Keep your torso upright", "Lower until elbows are at 90°", "Press back up to lockout"],
            commonMistakes: ["Leaning too far forward which shifts to chest", "Going too deep"],
            proTips: ["Stay upright to keep focus on triceps", "Use a bench for assisted dips if needed"]
        ),
        Exercise(
            id: "diamond-push-ups", name: "Diamond Push-Ups", primaryMuscle: .triceps,
            secondaryMuscles: [.chest, .shoulders], movementPattern: .horizontalPress, equipment: .bodyweight,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .bodyweightReps, defaultRestSeconds: 60,
            instructions: ["Place hands close together forming a diamond shape", "Lower your chest to your hands", "Push back up to full extension", "Keep elbows close to your body"],
            commonMistakes: ["Flaring elbows wide", "Sagging hips", "Not going low enough"],
            proTips: ["One of the best bodyweight tricep exercises", "Progress to this from regular push-ups"]
        ),
        Exercise(
            id: "cable-overhead-extension", name: "Cable Overhead Extension", primaryMuscle: .triceps,
            secondaryMuscles: [], movementPattern: .extension_, equipment: .cable,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Attach a rope to a low cable", "Face away and hold the rope overhead", "Extend your arms forward and up", "Return slowly behind your head"],
            commonMistakes: ["Moving the elbows too much", "Using body momentum"],
            proTips: ["The cable provides constant tension in the stretched position"]
        ),
    ]

    static let quadriceps: [Exercise] = [
        Exercise(
            id: "barbell-squat", name: "Barbell Back Squat", primaryMuscle: .quadriceps,
            secondaryMuscles: [.glutes, .hamstrings, .core], movementPattern: .squat, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 180,
            instructions: ["Position the bar on your upper back", "Stand with feet shoulder-width apart, toes slightly out", "Brace your core and descend by pushing hips back and bending knees", "Squat until thighs are at least parallel to the floor", "Drive through your whole foot to stand back up"],
            commonMistakes: ["Knees caving inward", "Rising onto toes", "Rounding the lower back", "Not hitting depth"],
            proTips: ["Think about sitting back into a chair", "Keep your chest up and proud throughout", "Master bodyweight squats before adding weight"]
        ),
        Exercise(
            id: "front-squat", name: "Front Squat", primaryMuscle: .quadriceps,
            secondaryMuscles: [.glutes, .core], movementPattern: .squat, equipment: .barbell,
            difficulty: .advanced, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 150,
            instructions: ["Rack the bar on your front delts with elbows high", "Descend into a squat keeping your torso very upright", "Drive up through the whole foot"],
            commonMistakes: ["Elbows dropping causing the bar to slide", "Rounding the upper back", "Not staying upright enough"],
            proTips: ["Cross-arm grip is easier for beginners", "Front squats demand and build excellent core strength"]
        ),
        Exercise(
            id: "leg-press", name: "Leg Press", primaryMuscle: .quadriceps,
            secondaryMuscles: [.glutes, .hamstrings], movementPattern: .squat, equipment: .machine,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Sit in the leg press and place feet shoulder-width on the platform", "Release the safety and lower the weight", "Lower until knees are at about 90°", "Press the platform back up without locking knees"],
            commonMistakes: ["Going too deep and rounding the lower back", "Locking out the knees", "Placing feet too low"],
            proTips: ["Higher foot placement shifts emphasis to glutes and hamstrings", "Lower foot placement targets quads more"]
        ),
        Exercise(
            id: "leg-extension", name: "Leg Extension", primaryMuscle: .quadriceps,
            secondaryMuscles: [], movementPattern: .extension_, equipment: .machine,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Sit in the machine with the pad on your shins", "Extend your legs to full lockout", "Squeeze your quads at the top", "Lower with control"],
            commonMistakes: ["Using momentum to swing the weight", "Coming up too fast", "Not reaching full extension"],
            proTips: ["Pause at the top for maximum contraction", "Great as a warm-up or finisher for quads"]
        ),
        Exercise(
            id: "goblet-squat", name: "Goblet Squat", primaryMuscle: .quadriceps,
            secondaryMuscles: [.glutes, .core], movementPattern: .squat, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Hold a dumbbell vertically at your chest", "Squat down between your legs", "Keep your chest up and elbows inside your knees", "Stand back up"],
            commonMistakes: ["Rounding the back", "Knees caving", "Not going deep enough"],
            proTips: ["The front-loaded weight naturally keeps your torso upright", "Perfect for learning squat mechanics"]
        ),
        Exercise(
            id: "bulgarian-split-squat", name: "Bulgarian Split Squat", primaryMuscle: .quadriceps,
            secondaryMuscles: [.glutes, .hamstrings], movementPattern: .lunge, equipment: .dumbbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Place one foot on a bench behind you", "Hold dumbbells at your sides", "Lower into a lunge until your front thigh is parallel", "Drive through the front foot to stand"],
            commonMistakes: ["Front foot too close to the bench", "Leaning too far forward", "Rushing reps"],
            proTips: ["One of the best single-leg exercises for quad and glute development", "Start with bodyweight to master balance"]
        ),
        Exercise(
            id: "hack-squat", name: "Hack Squat", primaryMuscle: .quadriceps,
            secondaryMuscles: [.glutes], movementPattern: .squat, equipment: .machine,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Position yourself in the hack squat machine", "Place feet shoulder-width on the platform", "Release the safety and lower the weight", "Squat until thighs are parallel", "Press back up"],
            commonMistakes: ["Not going deep enough", "Knees caving in", "Placing feet too far forward"],
            proTips: ["Narrow stance targets outer quads", "Wide stance targets inner quads and adductors"]
        ),
    ]

    static let hamstrings: [Exercise] = [
        Exercise(
            id: "romanian-deadlift", name: "Romanian Deadlift", primaryMuscle: .hamstrings,
            secondaryMuscles: [.glutes, .back], movementPattern: .hipHinge, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Stand with feet hip-width apart holding the bar", "Push your hips back and lower the bar along your legs", "Keep a slight knee bend and flat back", "Lower until you feel a deep hamstring stretch", "Drive your hips forward to return to standing"],
            commonMistakes: ["Rounding the back", "Bending the knees too much", "Not pushing hips back enough"],
            proTips: ["Think about pushing your butt to the wall behind you", "The bar should stay in contact with your legs throughout"]
        ),
        Exercise(
            id: "lying-leg-curl", name: "Lying Leg Curl", primaryMuscle: .hamstrings,
            secondaryMuscles: [.calves], movementPattern: .flexion, equipment: .machine,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Lie face down on the leg curl machine", "Position the pad just above your heels", "Curl the weight up by bending your knees", "Squeeze at the top and lower slowly"],
            commonMistakes: ["Lifting hips off the pad", "Using momentum", "Not reaching full contraction"],
            proTips: ["Point your toes away from you to increase hamstring activation"]
        ),
        Exercise(
            id: "seated-leg-curl", name: "Seated Leg Curl", primaryMuscle: .hamstrings,
            secondaryMuscles: [], movementPattern: .flexion, equipment: .machine,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Sit in the machine with the pad behind your ankles", "Curl your legs down and back", "Squeeze at the full contraction", "Return slowly"],
            commonMistakes: ["Using momentum", "Not getting full range of motion"],
            proTips: ["Seated position provides a better stretch on the hamstrings than lying"]
        ),
        Exercise(
            id: "stiff-leg-deadlift", name: "Stiff-Leg Deadlift", primaryMuscle: .hamstrings,
            secondaryMuscles: [.glutes, .back], movementPattern: .hipHinge, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Stand with feet hip-width apart", "Keep legs almost completely straight", "Hinge at the hips and lower the bar", "Lower as far as flexibility allows", "Return to standing by driving hips forward"],
            commonMistakes: ["Rounding the back", "Locking the knees completely"],
            proTips: ["Keep a micro-bend in the knees to protect them", "Focus on feeling the hamstring stretch"]
        ),
        Exercise(
            id: "nordic-hamstring-curl", name: "Nordic Hamstring Curl", primaryMuscle: .hamstrings,
            secondaryMuscles: [], movementPattern: .flexion, equipment: .bodyweight,
            difficulty: .advanced, exerciseType: .isolation, trackingType: .bodyweightReps, defaultRestSeconds: 90,
            instructions: ["Kneel with ankles secured under a pad or by a partner", "Slowly lower your body forward using your hamstrings to resist", "Lower as far as you can control", "Push off the ground to return and use hamstrings to pull back up"],
            commonMistakes: ["Falling forward uncontrolled", "Bending at the hips instead of the knees"],
            proTips: ["One of the best exercises for hamstring injury prevention", "Start with negatives only if you can't do the full movement"]
        ),
        Exercise(
            id: "dumbbell-rdl", name: "Dumbbell Romanian Deadlift", primaryMuscle: .hamstrings,
            secondaryMuscles: [.glutes, .back], movementPattern: .hipHinge, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Stand holding dumbbells in front of your thighs", "Push your hips back keeping the dumbbells close to your legs", "Lower until you feel a hamstring stretch", "Drive hips forward to stand"],
            commonMistakes: ["Rounding the back", "Letting dumbbells drift forward"],
            proTips: ["Dumbbells allow a slightly different range of motion than barbells", "Great for beginners learning the hip hinge"]
        ),
    ]

    static let glutes: [Exercise] = [
        Exercise(
            id: "hip-thrust", name: "Barbell Hip Thrust", primaryMuscle: .glutes,
            secondaryMuscles: [.hamstrings, .core], movementPattern: .hipHinge, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Sit on the floor with your upper back against a bench", "Roll a barbell over your hips", "Drive through your heels to lift your hips", "Squeeze your glutes at the top — hips fully extended", "Lower with control"],
            commonMistakes: ["Hyperextending the lower back", "Not squeezing at the top", "Pushing through the toes"],
            proTips: ["Use a pad on the bar for comfort", "Posterior pelvic tilt at the top maximizes glute contraction"]
        ),
        Exercise(
            id: "glute-bridge", name: "Glute Bridge", primaryMuscle: .glutes,
            secondaryMuscles: [.hamstrings], movementPattern: .hipHinge, equipment: .bodyweight,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .bodyweightReps, defaultRestSeconds: 45,
            instructions: ["Lie on your back with knees bent and feet flat", "Drive through your heels to lift your hips", "Squeeze glutes at the top", "Lower back down"],
            commonMistakes: ["Pushing through the toes", "Not squeezing at the top"],
            proTips: ["Perfect for warming up the glutes before squats", "Add a band above the knees for extra activation"]
        ),
        Exercise(
            id: "cable-kickback", name: "Cable Kickback", primaryMuscle: .glutes,
            secondaryMuscles: [.hamstrings], movementPattern: .extension_, equipment: .cable,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Attach an ankle strap to a low cable", "Face the machine and kick your leg straight back", "Squeeze your glute at the top", "Return slowly"],
            commonMistakes: ["Arching the lower back", "Swinging the leg", "Using too much weight"],
            proTips: ["Keep your core braced and movement controlled", "Focus on the squeeze, not the weight"]
        ),
        Exercise(
            id: "walking-lunges", name: "Walking Lunges", primaryMuscle: .glutes,
            secondaryMuscles: [.quadriceps, .hamstrings], movementPattern: .lunge, equipment: .dumbbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Hold dumbbells at your sides", "Step forward into a lunge", "Lower until both knees are at 90°", "Push off the front foot and step forward with the other leg"],
            commonMistakes: ["Knee going past the toe excessively", "Short steps", "Torso leaning forward"],
            proTips: ["Longer steps target glutes more, shorter steps target quads", "Keep your torso upright"]
        ),
        Exercise(
            id: "step-ups", name: "Step-Ups", primaryMuscle: .glutes,
            secondaryMuscles: [.quadriceps], movementPattern: .lunge, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Stand in front of a bench or box holding dumbbells", "Step up with one foot, driving through the heel", "Stand fully on top of the box", "Step back down with control"],
            commonMistakes: ["Pushing off the back foot", "Not fully standing on top", "Box too high"],
            proTips: ["The higher the box, the more glute activation", "Really focus on driving through the working leg only"]
        ),
    ]

    static let calves: [Exercise] = [
        Exercise(
            id: "standing-calf-raise", name: "Standing Calf Raise", primaryMuscle: .calves,
            secondaryMuscles: [], movementPattern: .isolation, equipment: .machine,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Stand on the calf raise machine with balls of feet on the platform", "Lower your heels as far as possible", "Rise up on your toes as high as you can", "Squeeze at the top and lower slowly"],
            commonMistakes: ["Bouncing at the bottom", "Not getting a full stretch", "Not reaching full contraction"],
            proTips: ["Pause at both the stretch and the contraction for 1-2 seconds", "Calves respond well to high volume"]
        ),
        Exercise(
            id: "seated-calf-raise", name: "Seated Calf Raise", primaryMuscle: .calves,
            secondaryMuscles: [], movementPattern: .isolation, equipment: .machine,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Sit in the calf raise machine with knees under the pad", "Lower heels to get a full stretch", "Push up through the balls of your feet", "Squeeze and lower slowly"],
            commonMistakes: ["Not using full range of motion", "Going too fast"],
            proTips: ["Seated calf raises target the soleus muscle more", "Combine with standing raises for complete calf development"]
        ),
        Exercise(
            id: "single-leg-calf-raise", name: "Single-Leg Calf Raise", primaryMuscle: .calves,
            secondaryMuscles: [], movementPattern: .isolation, equipment: .bodyweight,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .bodyweightReps, defaultRestSeconds: 30,
            instructions: ["Stand on one foot on a step or platform edge", "Lower your heel below the step for a deep stretch", "Rise up as high as possible on your toes", "Hold at the top for a second"],
            commonMistakes: ["Not using full range of motion", "Going too fast"],
            proTips: ["Hold a dumbbell for added resistance", "Great for fixing calf imbalances between legs"]
        ),
    ]

    static let core: [Exercise] = [
        Exercise(
            id: "plank", name: "Plank", primaryMuscle: .core,
            secondaryMuscles: [.shoulders], movementPattern: .plank, equipment: .bodyweight,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .time, defaultRestSeconds: 30,
            instructions: ["Start in a push-up position on your forearms", "Keep body in a straight line from head to heels", "Brace your core as if you're about to be punched", "Hold this position for the target time"],
            commonMistakes: ["Sagging hips", "Piking the hips up", "Holding breath"],
            proTips: ["Squeeze your glutes and brace your abs hard", "Start with 20-second holds and build up"]
        ),
        Exercise(
            id: "hanging-leg-raise", name: "Hanging Leg Raise", primaryMuscle: .core,
            secondaryMuscles: [.forearms], movementPattern: .flexion, equipment: .bodyweight,
            difficulty: .advanced, exerciseType: .isolation, trackingType: .bodyweightReps, defaultRestSeconds: 60,
            instructions: ["Hang from a pull-up bar with arms extended", "Keep legs straight and raise them to 90°", "Lower with control, resisting the swing", "Avoid using momentum"],
            commonMistakes: ["Swinging the body", "Bending the knees", "Using momentum"],
            proTips: ["Start with knee raises if straight leg is too difficult", "One of the best exercises for lower abs"]
        ),
        Exercise(
            id: "cable-woodchop", name: "Cable Woodchop", primaryMuscle: .core,
            secondaryMuscles: [.shoulders], movementPattern: .rotation, equipment: .cable,
            difficulty: .intermediate, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 45,
            instructions: ["Set a cable at the highest position", "Stand sideways to the machine", "Pull the handle diagonally across your body", "Rotate your torso as you pull down and across", "Return with control"],
            commonMistakes: ["Using arms instead of rotating the torso", "Moving too fast"],
            proTips: ["Great for rotational core strength", "Also try low-to-high for a different angle"]
        ),
        Exercise(
            id: "russian-twist", name: "Russian Twist", primaryMuscle: .core,
            secondaryMuscles: [], movementPattern: .rotation, equipment: .bodyweight,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .repsOnly, defaultRestSeconds: 30,
            instructions: ["Sit with knees bent and lean back slightly", "Lift your feet off the ground for added difficulty", "Rotate your torso to one side, then the other", "Each rotation to one side counts as one rep"],
            commonMistakes: ["Moving the arms without rotating the torso", "Rounding the back"],
            proTips: ["Hold a weight to increase difficulty", "Keep your chest proud throughout"]
        ),
        Exercise(
            id: "ab-wheel-rollout", name: "Ab Wheel Rollout", primaryMuscle: .core,
            secondaryMuscles: [.shoulders], movementPattern: .plank, equipment: .none,
            difficulty: .advanced, exerciseType: .isolation, trackingType: .repsOnly, defaultRestSeconds: 60,
            instructions: ["Kneel on the floor holding an ab wheel", "Slowly roll the wheel forward, extending your body", "Go as far as you can while maintaining a flat back", "Pull the wheel back to the starting position using your abs"],
            commonMistakes: ["Sagging the lower back", "Not going far enough", "Using hip flexors instead of abs"],
            proTips: ["Start with partial range of motion and increase over time", "One of the most effective ab exercises available"]
        ),
        Exercise(
            id: "dead-bug", name: "Dead Bug", primaryMuscle: .core,
            secondaryMuscles: [], movementPattern: .plank, equipment: .bodyweight,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .repsOnly, defaultRestSeconds: 30,
            instructions: ["Lie on your back with arms extended toward ceiling", "Lift legs to 90° knee bend", "Slowly extend opposite arm and leg toward the floor", "Return and repeat on the other side"],
            commonMistakes: ["Arching the lower back off the floor", "Moving too fast", "Holding breath"],
            proTips: ["Press your lower back firmly into the floor", "Excellent for learning core bracing"]
        ),
        Exercise(
            id: "mountain-climbers", name: "Mountain Climbers", primaryMuscle: .core,
            secondaryMuscles: [.shoulders, .quadriceps], movementPattern: .plank, equipment: .bodyweight,
            difficulty: .beginner, exerciseType: .compound, trackingType: .time, defaultRestSeconds: 30,
            instructions: ["Start in a push-up position", "Drive one knee toward your chest", "Quickly switch legs in a running motion", "Keep your core tight and hips low"],
            commonMistakes: ["Piking the hips", "Not bringing knees far enough forward"],
            proTips: ["Slow mountain climbers are great for core control", "Fast mountain climbers add a cardio element"]
        ),
    ]

    static let forearms: [Exercise] = [
        Exercise(
            id: "wrist-curl", name: "Wrist Curl", primaryMuscle: .forearms,
            secondaryMuscles: [], movementPattern: .flexion, equipment: .barbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 30,
            instructions: ["Sit with forearms resting on your thighs, wrists over the edge", "Hold a barbell with palms up", "Curl your wrists up as high as possible", "Lower slowly"],
            commonMistakes: ["Moving the forearms", "Going too heavy", "Partial range of motion"],
            proTips: ["Let the bar roll to your fingertips at the bottom for extra range"]
        ),
        Exercise(
            id: "reverse-wrist-curl", name: "Reverse Wrist Curl", primaryMuscle: .forearms,
            secondaryMuscles: [], movementPattern: .extension_, equipment: .barbell,
            difficulty: .beginner, exerciseType: .isolation, trackingType: .weightReps, defaultRestSeconds: 30,
            instructions: ["Sit with forearms on your thighs, palms down", "Extend your wrists upward", "Lower slowly"],
            commonMistakes: ["Using too much weight", "Moving the forearms"],
            proTips: ["Use lighter weight than regular wrist curls — the extensors are smaller"]
        ),
        Exercise(
            id: "farmers-carry", name: "Farmer's Carry", primaryMuscle: .forearms,
            secondaryMuscles: [.core, .shoulders], movementPattern: .carry, equipment: .dumbbell,
            difficulty: .beginner, exerciseType: .compound, trackingType: .distanceTime, defaultRestSeconds: 60,
            instructions: ["Pick up heavy dumbbells or kettlebells", "Stand tall with shoulders back", "Walk forward with controlled steps", "Maintain an upright posture throughout"],
            commonMistakes: ["Leaning to one side", "Taking too-short steps", "Rounding shoulders"],
            proTips: ["Grip is usually the limiting factor — train grip specifically", "One of the most functional exercises you can do"]
        ),
    ]

    static let fullBody: [Exercise] = [
        Exercise(
            id: "barbell-clean", name: "Barbell Clean", primaryMuscle: .fullBody,
            secondaryMuscles: [.quadriceps, .hamstrings, .back, .shoulders], movementPattern: .hipHinge, equipment: .barbell,
            difficulty: .advanced, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 120,
            instructions: ["Stand over the bar with feet hip-width apart", "Grip the bar just outside your knees", "Explosively extend hips and knees, pulling the bar up", "Drop under the bar and catch it on your front delts", "Stand up to complete the clean"],
            commonMistakes: ["Pulling with the arms too early", "Not keeping the bar close", "Landing in a poor front rack position"],
            proTips: ["This is a highly technical lift — start with hang cleans", "Power comes from the hips, not the arms"]
        ),
        Exercise(
            id: "thrusters", name: "Thrusters", primaryMuscle: .fullBody,
            secondaryMuscles: [.quadriceps, .shoulders, .core], movementPattern: .squat, equipment: .barbell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Hold a barbell in the front rack position", "Squat down to parallel", "Explosively stand up and press the bar overhead", "Lower the bar back to the front rack and repeat"],
            commonMistakes: ["Pressing before the legs are fully extended", "Rounding the upper back", "Not hitting depth"],
            proTips: ["Use the momentum from the squat to drive the press", "Excellent conditioning exercise"]
        ),
        Exercise(
            id: "burpees", name: "Burpees", primaryMuscle: .fullBody,
            secondaryMuscles: [.chest, .quadriceps, .core], movementPattern: .plyometric, equipment: .bodyweight,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .repsOnly, defaultRestSeconds: 60,
            instructions: ["Stand with feet shoulder-width apart", "Drop into a squat and place hands on the floor", "Jump feet back into a push-up position", "Perform a push-up", "Jump feet forward and explosively jump up with arms overhead"],
            commonMistakes: ["Skipping the push-up", "Not jumping at the top", "Sloppy form as fatigue sets in"],
            proTips: ["Scale by stepping back instead of jumping", "One of the best conditioning exercises ever"]
        ),
        Exercise(
            id: "kettlebell-swing", name: "Kettlebell Swing", primaryMuscle: .fullBody,
            secondaryMuscles: [.glutes, .hamstrings, .core, .shoulders], movementPattern: .hipHinge, equipment: .kettlebell,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 60,
            instructions: ["Stand with feet wider than hip-width", "Hinge at the hips and grip the kettlebell with both hands", "Swing the bell between your legs", "Explosively drive your hips forward to swing the bell to chest height", "Let it swing back down and repeat"],
            commonMistakes: ["Squatting instead of hinging", "Using the arms to lift", "Rounding the back"],
            proTips: ["Power comes entirely from the hip snap", "Keep your arms relaxed — they're just holding the bell"]
        ),
        Exercise(
            id: "turkish-get-up", name: "Turkish Get-Up", primaryMuscle: .fullBody,
            secondaryMuscles: [.shoulders, .core, .glutes], movementPattern: .carry, equipment: .kettlebell,
            difficulty: .advanced, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 90,
            instructions: ["Lie on your back holding a kettlebell in one hand, arm locked out", "Roll to your elbow, then to your hand", "Bridge your hips up and sweep your leg under", "Stand up, keeping the kettlebell locked out overhead the entire time", "Reverse the steps to return to the floor"],
            commonMistakes: ["Bending the loaded arm", "Rushing the movement", "Not keeping eyes on the kettlebell"],
            proTips: ["Practice each step individually before chaining them together", "Builds incredible shoulder stability and full-body coordination"]
        ),
        Exercise(
            id: "man-makers", name: "Man Makers", primaryMuscle: .fullBody,
            secondaryMuscles: [.chest, .back, .shoulders, .core], movementPattern: .horizontalPress, equipment: .dumbbell,
            difficulty: .advanced, exerciseType: .compound, trackingType: .weightReps, defaultRestSeconds: 120,
            instructions: ["Start standing with dumbbells at your sides", "Drop into a push-up position on the dumbbells", "Perform a push-up", "Row each dumbbell to your hip", "Jump feet forward and clean the dumbbells to your shoulders", "Press overhead"],
            commonMistakes: ["Rushing through the movement", "Rounding the back during rows", "Not stabilizing during push-up"],
            proTips: ["Use lighter weight than you think — these are brutally taxing", "One rep is one full sequence"]
        ),
    ]

    static let cardioExercises: [Exercise] = [
        Exercise(
            id: "treadmill-run", name: "Treadmill Run", primaryMuscle: .cardio,
            secondaryMuscles: [.quadriceps, .hamstrings, .calves], movementPattern: .cardioPattern, equipment: .machine,
            difficulty: .beginner, exerciseType: .compound, trackingType: .distanceTime, defaultRestSeconds: 0,
            instructions: ["Step onto the treadmill and select your desired speed", "Start with a warm-up pace for 2-3 minutes", "Increase to your target running speed", "Maintain an upright posture with relaxed shoulders", "Cool down with a slow walk for 2-3 minutes"],
            commonMistakes: ["Holding onto the handles", "Overstriding", "Hunching shoulders"],
            proTips: ["Use incline to increase difficulty without increasing speed", "Aim for a cadence of 170-180 steps per minute"]
        ),
        Exercise(
            id: "rowing-machine", name: "Rowing Machine", primaryMuscle: .cardio,
            secondaryMuscles: [.back, .quadriceps, .biceps, .core], movementPattern: .cardioPattern, equipment: .machine,
            difficulty: .beginner, exerciseType: .compound, trackingType: .distanceTime, defaultRestSeconds: 0,
            instructions: ["Sit on the rower and strap your feet in", "Grab the handle with an overhand grip", "Drive with your legs first, then lean back slightly", "Pull the handle to your lower chest", "Reverse the motion: arms, body, then legs"],
            commonMistakes: ["Pulling with arms first", "Rounding the back", "Rushing the recovery"],
            proTips: ["The sequence is legs-body-arms on the drive and arms-body-legs on the return", "Aim for a 500m split time that you can sustain"]
        ),
        Exercise(
            id: "jump-rope", name: "Jump Rope", primaryMuscle: .cardio,
            secondaryMuscles: [.calves, .forearms, .shoulders], movementPattern: .plyometric, equipment: .none,
            difficulty: .beginner, exerciseType: .compound, trackingType: .time, defaultRestSeconds: 30,
            instructions: ["Hold the rope handles at hip height", "Rotate the rope using your wrists, not your arms", "Jump just high enough to clear the rope", "Land softly on the balls of your feet"],
            commonMistakes: ["Jumping too high", "Using arm circles instead of wrist rotation", "Landing flat-footed"],
            proTips: ["10 minutes of jump rope burns as many calories as 30 minutes of jogging", "Start with 30-second intervals"]
        ),
        Exercise(
            id: "cycling", name: "Stationary Cycling", primaryMuscle: .cardio,
            secondaryMuscles: [.quadriceps, .hamstrings, .calves], movementPattern: .cardioPattern, equipment: .machine,
            difficulty: .beginner, exerciseType: .compound, trackingType: .distanceTime, defaultRestSeconds: 0,
            instructions: ["Adjust the seat height so your leg has a slight bend at the bottom", "Start pedaling at a moderate resistance", "Maintain a steady cadence", "Keep upper body relaxed"],
            commonMistakes: ["Seat too low or too high", "Gripping handlebars too tight", "Bouncing in the saddle"],
            proTips: ["Intervals of high and low intensity are more effective than steady state", "Aim for 80-100 RPM cadence"]
        ),
        Exercise(
            id: "box-jumps", name: "Box Jumps", primaryMuscle: .cardio,
            secondaryMuscles: [.quadriceps, .glutes, .calves], movementPattern: .plyometric, equipment: .none,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .repsOnly, defaultRestSeconds: 45,
            instructions: ["Stand facing a sturdy box or platform", "Swing your arms and explode upward", "Land softly on top of the box with both feet", "Stand up fully, then step back down"],
            commonMistakes: ["Landing hard", "Not standing fully on top", "Jumping down instead of stepping"],
            proTips: ["Step down instead of jumping down to save your joints", "Start with a lower box and work up"]
        ),
        Exercise(
            id: "battle-ropes", name: "Battle Ropes", primaryMuscle: .cardio,
            secondaryMuscles: [.shoulders, .core, .forearms], movementPattern: .cardioPattern, equipment: .none,
            difficulty: .intermediate, exerciseType: .compound, trackingType: .time, defaultRestSeconds: 30,
            instructions: ["Stand with feet shoulder-width apart holding one rope end in each hand", "Alternate raising and slamming each arm to create waves", "Keep your core braced and knees slightly bent", "Maintain a consistent rhythm"],
            commonMistakes: ["Standing too upright", "Only using arms without engaging core", "Rope going slack"],
            proTips: ["Try different patterns: alternating, double slam, circles", "20-30 second bursts with short rest is highly effective"]
        ),
    ]
}
