// Supabase Edge Function: super-action
// Action router — reads { action, payload } and dispatches to a handler.
// Deployed as the canonical multi-action function so we don't depend on
// deploying per-action functions manually.

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

function json(status: number, body: unknown): Response {
    return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

// ---- Curated fake-user personas ---------------------------------------

interface Persona {
    name: string;
    username: string;
    bio: string;
    color: string;
    avatarSeed: number;
    bannerSeed: string;
    streak: number;
    totalFp: number;
    posts: string[];
    archetype: string;
    tagline: string;
    interests: string[];
}

// 30 hand-crafted personas — diverse archetypes. Posts are in their
// voice (short, idiosyncratic, slangy). Anti-AI-fitspo by design.
const PERSONAS: Persona[] = [
    {
        name: "Ava Chen", username: "avalifts", color: "#F59E0B", avatarSeed: 5, bannerSeed: "barbell-1",
        archetype: "Strength", tagline: "5/3/1 lifter, sub-1hr sessions or it didn't happen", interests: ["strength","powerlifting"],
        bio: "5/3/1 forever. Coffee then squats. Sub-1hr sessions or it didn't happen.", streak: 38, totalFp: 4820,
        posts: [
            "squats moved like trash today but i hit them anyway. that's the whole game tbh",
            "PR day 🥲 405x3 high bar, no belt. crying in the car park. #strength",
            "hot take: most of you don't need a new program, you need to actually run the one you have for 12 weeks",
            "deload week and i'm already itching to add weight on monday. someone stop me",
        ],
    },
    {
        name: "Marcus Diallo", username: "marcusruns", color: "#3B82F6", avatarSeed: 12, bannerSeed: "trail-run-2",
        archetype: "Marathoner", tagline: "Marathon #4, zone 2 evangelist", interests: ["running","endurance"],
        bio: "Marathon #4 in October. Slow miles, fast Tuesdays.", streak: 64, totalFp: 6200,
        posts: [
            "easy 8 this morning, 8:42 pace and my HR stayed under 145 the whole way. zone 2 finally clicking",
            "the second half of every long run is just bargaining with yourself",
            "rest day. ate a whole sleeve of fig bars. balance.",
            "track session — 6x800 at 5k pace. legs felt heavy but splits were on. #running",
            "new shoes day. nothing else matters",
        ],
    },
    {
        name: "Priya Kapoor", username: "priyamoves", color: "#EC4899", avatarSeed: 9, bannerSeed: "yoga-studio-3",
        archetype: "Yoga + Mobility", tagline: "Yoga teacher, mobility nerd, pigeon-pose pusher", interests: ["yoga","mobility"],
        bio: "Yoga teacher. Mobility nerd. I will make you do pigeon pose.", streak: 121, totalFp: 8410,
        posts: [
            "if your hips are tight you cannot squat well. it's not the program. it's the chair.",
            "taught a 6am class today and three people fell asleep in savasana. peak compliment.",
            "30 days of daily mobility. my deadlift went up and i didn't lift heavier once. interesting.",
            "slow flow + breathwork tonight if anyone's around",
        ],
    },
    {
        name: "Diego Ramirez", username: "diegohoops", color: "#F97316", avatarSeed: 15, bannerSeed: "basketball-court-4",
        archetype: "Hooper", tagline: "6'1 guard, working on the handle", interests: ["basketball","hoops"],
        bio: "Hooper. 6'1\". Working on the handle.", streak: 22, totalFp: 3140,
        posts: [
            "shot 200 free throws after practice. made 184. i'll take it",
            "new shoes are too grippy, can't slide cuts. anyone else?",
            "played 5v5 with college kids today and survived. recovery day tomorrow no question",
            "3pt drill — 100 shots, 7 spots. 62/100. need to be at 70+ before tryouts. #basketball",
        ],
    },
    {
        name: "Sofia Müller", username: "sofiacycles", color: "#10B981", avatarSeed: 20, bannerSeed: "road-bike-5",
        archetype: "Cyclist", tagline: "Watt watcher, espresso enjoyer, FTP grinder", interests: ["cycling","endurance"],
        bio: "Cyclist. Espresso enjoyer. Watt watcher.", streak: 47, totalFp: 5520,
        posts: [
            "FTP test today. went from 248 to 261. all that sweet spot work paid off",
            "got dropped on the climb. again. but came in with the second group so ¯\\_(ツ)_/¯",
            "3hr ride, 78km, one cafe stop, zero regrets",
            "riding indoors today bc rain. zwift racing is a different kind of pain",
        ],
    },
    {
        name: "Kenji Tanaka", username: "kenjicalisthenics", color: "#8B5CF6", avatarSeed: 33, bannerSeed: "calisthenics-park-6",
        archetype: "Calisthenics", tagline: "Bodyweight only — planche + front lever obsession", interests: ["calisthenics","bodyweight"],
        bio: "Bodyweight only. Working on planche + front lever.", streak: 89, totalFp: 7100,
        posts: [
            "first clean tuck planche hold today. 6 seconds. 18 months in.",
            "people say bodyweight isn't 'real' strength. ok come hold a front lever for 10s and let's talk",
            "rings session. straight arm work humbling as always",
            "deload from skill work, just doing pull-ups and dips this week. feels like a vacation",
        ],
    },
    {
        name: "Zara Ahmed", username: "zaraprotocol", color: "#A855F7", avatarSeed: 40, bannerSeed: "vials-7",
        archetype: "Peptide Protocols", tagline: "Logs every dose, every marker, every mood", interests: ["peptides","bloodwork","protocols"],
        bio: "Tracking everything. Bloods, sleep, training, mood.", streak: 73, totalFp: 5980,
        posts: [
            "week 6 of my protocol. sleep score is up 14% on average. lifts holding. cautiously optimistic",
            "got bloods back. liver markers normal, lipids actually improved. n=1 but i'll take it",
            "site rotation chart i made in notion is unhinged but it works",
            "reminder to anyone starting: log everything. you will forget. write it down",
        ],
    },
    {
        name: "Noah Williams", username: "noahhybrid", color: "#14B8A6", avatarSeed: 52, bannerSeed: "gym-mirror-8",
        archetype: "Hybrid Athlete", tagline: "Lifts heavy, runs far, eats enough", interests: ["hybrid","strength","running"],
        bio: "Hybrid athlete. Lift heavy, run far, eat enough.", streak: 56, totalFp: 6450,
        posts: [
            "squats then a 10k. legs were jelly by km 4 but i finished. hybrid life is type 2 fun only",
            "can't believe i used to skip running. cardio fixes everything you don't want to fix",
            "upped calories by 300 and the fatigue went away. eat your food people",
            "deadlift 200kg + sub-22 5k is the goal this year. 180 + 23:40 currently. closing in",
        ],
    },
    {
        name: "Emma Lindqvist", username: "emmaclimbs", color: "#EC4899", avatarSeed: 26, bannerSeed: "climbing-gym-9",
        archetype: "Climber", tagline: "V6 boulderer projecting V7, forearms = personality", interests: ["climbing","bouldering"],
        bio: "Boulderer. V6 projecting V7. Forearms are a personality.", streak: 31, totalFp: 3810,
        posts: [
            "sent the project. fourteen sessions. screamed in the gym. they clapped. peak life.",
            "hangboard repeaters this morning. fingers are noodles",
            "my favorite part of climbing is sitting on the mat between attempts pretending to think",
            "new gym opened across town and the setting is wild. v4s feel like v6s",
        ],
    },
    {
        name: "Liam O'Connor", username: "liamlifts531", color: "#F59E0B", avatarSeed: 60, bannerSeed: "chalk-bar-10",
        archetype: "Strength (Patient)", tagline: "5/3/1 BBB month 11 — boring works", interests: ["strength","powerlifting"],
        bio: "5/3/1 BBB. Boring works.", streak: 95, totalFp: 7320,
        posts: [
            "month 11 of 5/3/1. squat TM is 175kg. started at 140. boring works.",
            "jokers today on bench. felt great, didn't take them. sticking to the program.",
            "if your lifts aren't going up just run the program longer. it's almost always the answer",
            "deload + deload food. life is good",
        ],
    },
    {
        name: "Maya Singh", username: "mayarecomp", color: "#8B5CF6", avatarSeed: 44, bannerSeed: "meal-prep-11",
        archetype: "Recomp / Nutrition", tagline: "Slow recomp, weighs the food, runs the spreadsheet", interests: ["nutrition","recomp"],
        bio: "Recomp journey. Slow, painful, working.", streak: 51, totalFp: 4920,
        posts: [
            "down 4kg, up 12kg on bench, in 5 months. recomp is real, you just have to be patient and weigh your food",
            "made overnight oats with greek yogurt and the macros are stupid good. 38g protein, 410 cal",
            "scale was up 1.2kg this morning. last night was sushi. unrelated probably",
            "protein at every meal is the only diet rule that actually moved the needle for me",
        ],
    },
    {
        name: "Oliver Brown", username: "oliverpush", color: "#3B82F6", avatarSeed: 4, bannerSeed: "dumbbells-12",
        archetype: "Bodybuilder (PPL)", tagline: "PPL 6x a week, lateral raise enjoyer, volume junkie", interests: ["bodybuilding","hypertrophy"],
        bio: "PPL 6x a week. Volume junkie.", streak: 18, totalFp: 2640,
        posts: [
            "chest day went 90 minutes and i still wanted more sets. send help",
            "finally got my OHP to 70kg for a triple. the slowest lift on earth has moved 5kg in 8 months",
            "thinking of dropping to 5 days for recovery. we'll see",
            "lateral raises until the delts are crying. weekly ritual",
        ],
    },
    {
        name: "Isabela Costa", username: "isabelarun", color: "#10B981", avatarSeed: 47, bannerSeed: "morning-run-13",
        archetype: "5K → Half", tagline: "5am runner training her first half, running = therapy", interests: ["running","endurance"],
        bio: "5K to half marathon. Running is therapy.", streak: 42, totalFp: 4180,
        posts: [
            "first sub-25 5k this morning. 24:48. screamed at my watch like a crazy person",
            "long run done. 16k. kept it conversational. the trick is going slower than feels right",
            "woke up at 5:30, ran 10k, was at my desk by 7:15. some days are just like that",
            "taking a rest day even though i don't want to. that's the whole post.",
        ],
    },
    {
        name: "Finn Hartley", username: "finnpowerlifts", color: "#F97316", avatarSeed: 13, bannerSeed: "powerlifting-platform-14",
        archetype: "Powerlifter (Meet Prep)", tagline: "83kg meet prep, singlet enjoyer, opener obsessor", interests: ["powerlifting","strength"],
        bio: "83kg. Meet prep. Singlet enjoyer.", streak: 110, totalFp: 8920,
        posts: [
            "opener attempts felt like nothing today. 8 weeks out and i'm cautiously hyped",
            "new sleeves, new pr. correlation? probably not. but maybe.",
            "squat 240, bench 155, deadlift 280. that's the goal by november. on pace.",
            "if you've never failed a lift you aren't training hard enough. controversial maybe.",
        ],
    },
    {
        name: "Luna Park", username: "lunayoga", color: "#A855F7", avatarSeed: 25, bannerSeed: "sunrise-yoga-15",
        archetype: "Yoga / Breathwork", tagline: "Vinyasa teacher, breathwork pusher, HRV nerd", interests: ["yoga","breathwork","recovery"],
        bio: "Vinyasa + breathwork. Soft body strong mind.", streak: 67, totalFp: 5240,
        posts: [
            "30 days of breathwork. resting HR dropped 6bpm. wild what slow breathing does",
            "taught a 90min slow flow tonight, packed studio, everyone left smiling. that's the job",
            "i keep telling lifters to do yin yoga and they keep ignoring me and i keep being right",
            "new playlist for morning flows is unreasonably good",
        ],
    },
    {
        name: "Jordan Reyes", username: "jordancrossfit", color: "#14B8A6", avatarSeed: 67, bannerSeed: "crossfit-box-16",
        archetype: "CrossFit", tagline: "CF Open prep, muscle-up grinder, Murph survivor", interests: ["crossfit","hybrid"],
        bio: "CF athlete. Open prep szn.", streak: 84, totalFp: 6810,
        posts: [
            "Murph in 39:14. partitioned but unbroken pull-ups for the first time. that one stings tomorrow",
            "first muscle up on the rings today after a YEAR of trying. ugly. doesn't matter. counts.",
            "clean and jerk PR — 105kg. bar was moving",
            "open workout 24.2 was a soul crusher. sub it for me bc i didn't make it through round 4",
        ],
    },
    {
        name: "Aria Volkov", username: "ariastrength", color: "#EC4899", avatarSeed: 49, bannerSeed: "barbell-rack-17",
        archetype: "Strength Coach", tagline: "Coaches lifters + gen pop, writes templates, hates fluff", interests: ["coaching","strength"],
        bio: "Strength coach. Athletes + gen pop.", streak: 132, totalFp: 9100,
        posts: [
            "client hit her first chin-up today after 8 months of progressions. she cried. i cried. great morning.",
            "if your warmup is longer than your working sets you have too many warmup sets",
            "reposting the same advice for the 100th time: train submaximally most of the time, max occasionally, sleep more",
            "writing a new beginner template. it's basically just push pull legs but the cues are good",
        ],
    },
    {
        name: "Tomás Silva", username: "tomasswim", color: "#3B82F6", avatarSeed: 7, bannerSeed: "pool-lane-18",
        archetype: "Triathlete", tagline: "Sprint tri prep, hates the swim, loves the brick", interests: ["triathlon","endurance","swimming"],
        bio: "Triathlete. Swim is the worst part. Don't ask.", streak: 39, totalFp: 4620,
        posts: [
            "3km swim. sets of 200 on 3:00. i'm tired. that's the whole post.",
            "brick session — 60min bike then a 5k. legs were spaghetti for the first km",
            "open water swim sunday. wetsuit feels weird every single time and then fine",
            "first sprint tri in 3 weeks. taper started today. i feel slow already. classic",
        ],
    },
    {
        name: "Nina Berg", username: "ninapeptides", color: "#10B981", avatarSeed: 32, bannerSeed: "protocol-notebook-19",
        archetype: "Health Optimizer", tagline: "Bloods every 12 weeks, sleep score nerd, titration journaler", interests: ["peptides","bloodwork","sleep"],
        bio: "Health optimizer. Bloods every 12 weeks.", streak: 58, totalFp: 5160,
        posts: [
            "sleep efficiency this week: 92%. up from 78% three months ago. magnesium + cool room + no late caffeine. boring works",
            "new bloodwork in. CRP down, ferritin up, T trending in the right direction. all the right boring",
            "reminder that every 'biohack' that worked for me was something my grandma already did",
            "week 4 of titration. side effects mild, mood notably better. logging continues",
        ],
    },
    {
        name: "Ethan Walker", username: "ethannew", color: "#F59E0B", avatarSeed: 11, bannerSeed: "gym-floor-20",
        archetype: "Beginner", tagline: "3 months in, just trying to show up", interests: ["beginner","strength"],
        bio: "3 months in. Just trying to show up.", streak: 14, totalFp: 920,
        posts: [
            "showed up. that's the win.",
            "benched the 60kg plates today for the first time. felt heavy. they said it'd feel light eventually??",
            "learned what RPE means this week. game changer",
            "squats with a coach today. apparently i've been doing them wrong for 3 months. starting over and it's fine",
        ],
    },
    {
        name: "Hana Kim", username: "hanahybrid", color: "#A855F7", avatarSeed: 55, bannerSeed: "sunset-trail-21",
        archetype: "Trail + Lift Hybrid", tagline: "Trail runner who lifts heavy, coffee = meal", interests: ["running","hybrid","trail"],
        bio: "Trail runner + lifter. Coffee is a meal.", streak: 76, totalFp: 6420,
        posts: [
            "24k trail with 800m of climbing. legs filed for divorce on the descent",
            "front squats then a fasted run. would not recommend but here we are",
            "the move is: heavy lower mon, easy run tue, upper wed, long run sat, repeat forever",
            "new trail shoes feel like pillows. gonna regret it on technical stuff probably",
        ],
    },
    {
        name: "Caleb Nguyen", username: "calebbasketball", color: "#F97316", avatarSeed: 18, bannerSeed: "hoops-17",
        archetype: "Hooper → Lifter", tagline: "Hooper chasing the rim grab, plyo + trap bar fan", interests: ["basketball","strength","plyometrics"],
        bio: "Hooper turning into a lifter. Vertical goals.", streak: 28, totalFp: 3380,
        posts: [
            "trap bar deadlift PR — 180kg. vert tested at 31\" yesterday. correlation is real",
            "plyo day is the only day i'm sore the next morning consistently",
            "shooting form felt off all week then it just clicked tonight. game is weird",
            "finally a 1\" rim grab. coming for the rim by spring",
        ],
    },
    {
        name: "Yara Haddad", username: "yarayoga", color: "#EC4899", avatarSeed: 36, bannerSeed: "mat-natural-23",
        archetype: "Mobility-First Lifter", tagline: "Hip openers daily, lifts heavy, sun-mobility-coffee", interests: ["yoga","mobility","strength"],
        bio: "Mobility-first lifter. Hips don't lie, but they do lock up.", streak: 49, totalFp: 4710,
        posts: [
            "daily 10 min hip openers for 6 weeks and my squat depth is genuinely different. no notes.",
            "yin class last night was an emotional event. ten minutes in pigeon and i was processing 2019",
            "if you can't sit on the floor comfortably your training program needs to chill",
            "morning routine: coffee, mobility, sun. that's it. that's the post.",
        ],
    },
    {
        name: "Theo Rossi", username: "theostrong", color: "#8B5CF6", avatarSeed: 23, bannerSeed: "home-gym-24",
        archetype: "Home Gym Dad", tagline: "5am dad lifter, garage gym, macros are vibes", interests: ["strength","home-gym","dad-life"],
        bio: "Home gym dad. 5am club involuntarily.", streak: 102, totalFp: 7780,
        posts: [
            "kid woke up at 4:50 so i lifted at 5. squat day, heavy singles, one cup of coffee. unbeatable.",
            "finally finished the platform in the garage. dropping deadlifts without guilt now",
            "diet update: i eat whatever the kids leave behind. macros are vibes.",
            "hit a 200kg deadlift this morning, then made pancakes. full life.",
        ],
    },
    {
        name: "Esme Larsen", username: "esmesleeps", color: "#14B8A6", avatarSeed: 51, bannerSeed: "morning-light-25",
        archetype: "Recovery / Sleep", tagline: "Sleep first, train smart, mouth tape evangelist", interests: ["recovery","sleep"],
        bio: "Recovery first. Train smart sleep harder.", streak: 88, totalFp: 6940,
        posts: [
            "slept 8h12m last night. lifts felt like a different sport this morning. you cannot supplement your way past sleep.",
            "deload week and my HRV is up 22%. correlation is not subtle",
            "the protocol is: bed by 10, no screens, cool room, mouth tape if you're brave. that's it.",
            "missed a session because i needed sleep more. that's a win not a loss",
        ],
    },
    {
        name: "Ren Takeda", username: "renbjj", color: "#3B82F6", avatarSeed: 22, bannerSeed: "bjj-mat-26",
        archetype: "BJJ Grappler", tagline: "Blue belt grinding for purple, gi + nogi", interests: ["bjj","grappling","combat"],
        bio: "BJJ blue belt. Tap early tap often, sleep is the meta.", streak: 44, totalFp: 4280,
        posts: [
            "got smashed in open mat by a brown belt half my size. this is the sport.",
            "finally hit the de la riva to berimbolo i've been drilling for 6 months. one rep, in light rolling, but i'll take it",
            "two-a-day on saturdays is a mistake i keep making",
            "new gi, new ego. came in 7-1 last night. correlation? probably not.",
        ],
    },
    {
        name: "Sienna Park", username: "siennaglp", color: "#A855F7", avatarSeed: 28, bannerSeed: "weight-track-27",
        archetype: "GLP-1 Journey", tagline: "Down 14kg on tirzepatide, lifting through the cut", interests: ["glp1","recomp","nutrition"],
        bio: "Tirzepatide + lifting. Down 14kg, holding strength. Logging openly because nobody else will.", streak: 61, totalFp: 5340,
        posts: [
            "down 14kg in 5 months. lifts are holding. kept protein at 1.6g/kg the whole time. that's the whole post.",
            "appetite came back this week, dose was the same — interesting. logging it.",
            "the meds aren't a shortcut. they're a tool. i still cook, still walk 10k a day, still log it all",
            "side effect log: nausea was real for the first 2 weeks then gone. fatigue mostly resolved by changing injection day.",
        ],
    },
    {
        name: "Owen Brady", username: "owenrugby", color: "#F59E0B", avatarSeed: 16, bannerSeed: "rugby-pitch-28",
        archetype: "Rugby Athlete", tagline: "Flanker offseason, conditioning + power", interests: ["rugby","strength","conditioning"],
        bio: "Rugby flanker. Off-season recomp + power. Always sore, always hungry.", streak: 36, totalFp: 4070,
        posts: [
            "power cleans + 300m repeats. legs are gone but i feel like a small god",
            "preseason in 6 weeks and i can already feel the dread. love this sport.",
            "deadlift 220 + 30-5-30 in under 4:50 is the bar this offseason. 200 + 5:10 today",
            "old shoulder grumbling again. dropping bench volume, going more push press for a block",
        ],
    },
    {
        name: "Imani Brooks", username: "imanibody", color: "#EC4899", avatarSeed: 38, bannerSeed: "stage-prep-29",
        archetype: "Bikini Comp Prep", tagline: "15 weeks out, weighing food + posing daily", interests: ["bodybuilding","prep","physique"],
        bio: "Bikini prep, show in 15 weeks. Cardio is creeping. So are my abs.", streak: 71, totalFp: 5990,
        posts: [
            "first peek of midline this morning. it's the small stuff that keeps you going",
            "posing practice 15 min daily. nobody tells you how brutal a quarter turn is on day 7 of low carbs",
            "refeed day. i ate rice. i am a person again. brief and shining. tomorrow we cut again",
            "calves up to 6x a week, twice a day on heavy days. they are still small. nature is undefeated.",
        ],
    },
    {
        name: "Soraya Patel", username: "sorayapostpartum", color: "#10B981", avatarSeed: 56, bannerSeed: "morning-walk-30",
        archetype: "Postpartum Comeback", tagline: "6mo postpartum, rebuilding from the floor up", interests: ["postpartum","strength","recovery"],
        bio: "Postpartum 6mo. Rebuilding from the pelvic floor up. No pressure, no comparisons.", streak: 26, totalFp: 1880,
        posts: [
            "first real squats in 7 months today. 40kg. felt like a meet PR.",
            "sleep is awful, training has to fit around naps. i did three sets of pull-aparts in the kitchen yesterday and that's a workout now.",
            "diastasis is closing slowly. stopped doing direct ab work, doing dead bugs and breathing instead.",
            "slow is the only speed. that's the whole post.",
        ],
    },
];

const NAMES: string[] = PERSONAS.map((p) => p.name);
const AVATAR_PALETTE: string[] = ["#F59E0B", "#8B5CF6", "#14B8A6", "#3B82F6", "#EC4899", "#10B981", "#F97316", "#A855F7"];
const BIOS: string[] = PERSONAS.map((p) => p.bio);

// ---- Themed groups for one-time bulk populate ------------------------

interface SeedGroup {
    name: string;
    description: string;
    icon: string;
    color: string;
    interests: string[];
    posts: string[];
}

const SEED_GROUPS: SeedGroup[] = [
    {
        name: "Heavy Tuesdays",
        description: "Strength + powerlifting nerds. Block talk, programming, openers.",
        icon: "figure.strengthtraining.traditional", color: "#F59E0B",
        interests: ["strength","powerlifting","coaching"],
        posts: [
            "new block starts monday. 6 weeks volume, 3 weeks intensity, 1 week peak. anyone running similar?",
            "opener selection — go 96% gym single or 92%? meet in 8 wks",
            "squat went 200 → 222.5 in 8 months on 5/3/1 BBB. boring really does work",
            "failed bench at 142.5 today on a planned RPE 9. sticking the program, not chasing it.",
        ],
    },
    {
        name: "Easy Miles Club",
        description: "Runners. Zone 2 worship, long-run debriefs, race countdowns.",
        icon: "figure.run", color: "#3B82F6",
        interests: ["running","endurance","trail","triathlon"],
        posts: [
            "long run done — 22k under 150 hr the whole way. zone 2 finally not feeling like jogging in mud",
            "4 weeks out from my marathon. legs feel weirdly fresh. i'm suspicious.",
            "who actually does strides on tuesdays. the people who run fast. that's the post.",
        ],
    },
    {
        name: "Hybrid Lab",
        description: "Lift + run + suffer. People who refuse to pick a sport.",
        icon: "flame.fill", color: "#14B8A6",
        interests: ["hybrid","crossfit","plyometrics"],
        posts: [
            "squats then a 10k. type 2 fun. 0 regrets, 1 nap.",
            "running on lift days has fixed more recovery problems than any supplement i ever took",
            "hot take: most lifters hate cardio bc they only do hard cardio. easy zone 2 is a cheat code",
        ],
    },
    {
        name: "Mat People",
        description: "Yoga, mobility, breathwork. Hips don't lie. Neither does HRV.",
        icon: "figure.mind.and.body", color: "#EC4899",
        interests: ["yoga","mobility","breathwork","recovery"],
        posts: [
            "30 days of daily 10min hip work and my squat depth is genuinely different. no notes.",
            "breathwork before bed pulled my resting HR from 62 to 54 in 6 weeks. wild.",
            "if you can't sit on the floor your training program needs to chill",
        ],
    },
    {
        name: "Protocol Logbook",
        description: "Peptides, protocols, bloods. Track everything, share what you learn.",
        icon: "chart.line.uptrend.xyaxis", color: "#A855F7",
        interests: ["peptides","bloodwork","protocols","glp1"],
        posts: [
            "week 6 of titration. side effects mild, mood notably better. lifts holding. logging continues",
            "got bloods back. liver markers normal, lipids actually improved. n=1 but cautiously optimistic.",
            "reminder to anyone starting any protocol — log everything. you will forget. write it down",
            "appetite came back this week, dose unchanged. interesting. logging it.",
        ],
    },
    {
        name: "Hoops Lab",
        description: "Hoopers. Skill work, vert chasing, runs on runs.",
        icon: "basketball.fill", color: "#F97316",
        interests: ["basketball","hoops","plyometrics"],
        posts: [
            "100 free throws after practice. 87. taking it.",
            "trap bar deadlift PR + vert tested at 31\" yesterday. correlation is real",
            "who else's handle goes 30% worse on game day vs practice. it's the lights probably",
        ],
    },
    {
        name: "Recomp Receipts",
        description: "Cuts, lean gains, GLP-1 logs. Photos optional, macros mandatory.",
        icon: "scalemass.fill", color: "#10B981",
        interests: ["recomp","nutrition","glp1","prep","physique"],
        posts: [
            "down 4kg, up 12kg on bench, in 5 months. recomp is real, you just have to weigh your food",
            "refeed days are not optional, they are programmed",
            "protein at every meal is the only diet rule that ever actually moved the needle for me",
        ],
    },
];

const CROSS_COMMENT_BANK: string[] = [
    "goated",
    "yes!! the consistency thing is everything",
    "bro the second half line is too real",
    "this is exactly what i needed to read this morning",
    "how long did this take you to build to?",
    "oh that's a clean pr. respect.",
    "low key i feel this in my soul",
    "what shoes are those?",
    "showing up on the bad days is the whole sport",
    "saving this. starting monday lol",
    "this was me last week. fully you.",
    "send me the program i'll run it for 12 weeks i promise",
    "deload food is its own meal in our house",
    "that hip opener flow you posted last week unlocked me",
    "i tried this and my back stopped barking. so thank you",
    "we love a 5am garage gym post",
    "this is the most honest post i've seen in a while",
    "nah this is huge. don't downplay it",
    "i needed to see this. thanks for posting.",
    "easy zone 2 IS the cheat code. i'm tired of being right.",
    "big if true",
    "called out tbh. fixing tonight.",
    "this is the way",
    "how's recovery been on this volume?",
    "watching your progress on this has been wild",
];

const CROSS_DM_OPENERS: string[] = [
    "yo, your post on zone 2 — what watch are you using to keep HR honest?",
    "hey, saw your meet prep update. how are you handling the cut, weighing food or eyeballing?",
    "ok the hip opener routine actually worked. one week in, squat depth is nuts. thank you",
    "hey question — what's your warmup before heavy squats? hips locked no matter what",
    "big fan of your mobility takes. would you write up your full morning routine?",
    "how's preseason looking, you back full contact yet?",
    "thinking about starting a protocol, what bloodwork did you run before you started?",
    "random q — what's your favorite cue for hinge pattern with new lifters?",
    "yo your recomp post is the only honest one i've read. how are you logging cals?",
];

const CROSS_DM_REPLIES: string[] = [
    "polar h10 strap, never going back. wrist optical lies on intervals",
    "weighing food. i hate it but it's the only thing keeping me honest the last 6 weeks",
    "yesss let's gooo. add couch stretch every other day if you have hip flexor tightness",
    "empty bar 2x10, then add 20kg, sets of 5, until i'm at like 70%. takes 8-9 minutes. nothing fancy.",
    "i'll write it up. give me a couple days.",
    "yeah back contact yesterday actually. neck still sore. classic.",
    "full panel — lipids, liver, testosterone, igf-1, fasting glucose, a1c, thyroid. baseline.",
    "hinge from the hips not the knees — 'push the floor away' beats 'lift the bar' for most beginners",
    "macros app, weigh everything. takes 2 weeks to learn what 30g of oats looks like, then it's nothing.",
    "fr appreciate that. let me know how it goes",
];

function slugify(name: string): string {
    return name
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[^a-z0-9]+/g, "")
        .slice(0, 20);
}

function initialsFor(name: string): string {
    return name
        .split(/\s+/)
        .filter(Boolean)
        .map((p) => p[0]?.toUpperCase() ?? "")
        .join("")
        .slice(0, 2);
}

function randInt(min: number, maxInclusive: number): number {
    return Math.floor(Math.random() * (maxInclusive - min + 1)) + min;
}

function isoDate(daysAgo: number): string {
    const d = new Date();
    d.setDate(d.getDate() - daysAgo);
    return d.toISOString().slice(0, 10);
}

// ---- ISO week helpers -------------------------------------------------

function isoWeekStart(d: Date = new Date()): string {
    const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
    const day = date.getUTCDay() || 7; // Mon=1..Sun=7
    if (day !== 1) date.setUTCDate(date.getUTCDate() - (day - 1));
    return date.toISOString().slice(0, 10);
}

function previousIsoWeekStart(d: Date = new Date()): string {
    const start = new Date(isoWeekStart(d));
    start.setUTCDate(start.getUTCDate() - 7);
    return start.toISOString().slice(0, 10);
}

// ---- APNs push --------------------------------------------------------

async function importApnsKey(pem: string): Promise<CryptoKey | null> {
    try {
        const cleaned = pem.replace(/-----BEGIN PRIVATE KEY-----/g, "")
            .replace(/-----END PRIVATE KEY-----/g, "")
            .replace(/\s+/g, "");
        const der = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
        return await crypto.subtle.importKey(
            "pkcs8",
            der,
            { name: "ECDSA", namedCurve: "P-256" },
            false,
            ["sign"],
        );
    } catch (e) {
        console.error("importApnsKey failed", e);
        return null;
    }
}

function b64url(bytes: Uint8Array): string {
    let s = btoa(String.fromCharCode(...bytes));
    return s.replace(/=+$/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}
function b64urlString(str: string): string {
    return b64url(new TextEncoder().encode(str));
}

async function buildApnsJWT(teamId: string, keyId: string, key: CryptoKey): Promise<string> {
    const header = b64urlString(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
    const claims = b64urlString(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }));
    const signingInput = `${header}.${claims}`;
    const sig = new Uint8Array(
        await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput)),
    );
    return `${signingInput}.${b64url(sig)}`;
}

let cachedJwt: { token: string; created: number } | null = null;
async function getApnsJWT(): Promise<{ token: string; bundleId: string; host: string } | null> {
    const teamId = Deno.env.get("APNS_TEAM_ID");
    const keyId = Deno.env.get("APNS_KEY_ID");
    const keyPem = Deno.env.get("APNS_AUTH_KEY");
    const bundleId = Deno.env.get("APNS_BUNDLE_ID");
    const env = (Deno.env.get("APNS_ENV") ?? "production").toLowerCase();
    if (!teamId || !keyId || !keyPem || !bundleId) return null;
    if (cachedJwt && Date.now() - cachedJwt.created < 30 * 60 * 1000) {
        return { token: cachedJwt.token, bundleId, host: env === "sandbox" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com" };
    }
    const key = await importApnsKey(keyPem);
    if (!key) return null;
    const token = await buildApnsJWT(teamId, keyId, key);
    cachedJwt = { token, created: Date.now() };
    const host = env === "sandbox" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
    return { token, bundleId, host };
}

async function sendApnsToTokens(
    tokens: string[],
    title: string,
    body: string,
    data: Record<string, unknown> = {},
): Promise<{ sent: number; failed: number }> {
    const auth = await getApnsJWT();
    if (!auth || tokens.length === 0) return { sent: 0, failed: 0 };
    let sent = 0;
    let failed = 0;
    const payload = JSON.stringify({
        aps: { alert: { title, body }, sound: "default", "mutable-content": 1 },
        ...data,
    });
    await Promise.all(tokens.map(async (t) => {
        try {
            const r = await fetch(`${auth.host}/3/device/${t}`, {
                method: "POST",
                headers: {
                    "authorization": `bearer ${auth.token}`,
                    "apns-topic": auth.bundleId,
                    "apns-push-type": "alert",
                    "content-type": "application/json",
                },
                body: payload,
            });
            if (r.ok) sent += 1; else failed += 1;
        } catch (_) {
            failed += 1;
        }
    }));
    return { sent, failed };
}

async function pushToUsers(
    admin: SupabaseClient,
    userIds: string[],
    title: string,
    body: string,
    data: Record<string, unknown> = {},
): Promise<{ sent: number; failed: number }> {
    if (userIds.length === 0) return { sent: 0, failed: 0 };
    const { data: rows } = await admin
        .from("device_tokens")
        .select("token, user_id")
        .in("user_id", userIds);
    const tokens = (rows ?? [])
        .map((r: { token: unknown }) => (typeof r.token === "string" ? r.token : null))
        .filter((t): t is string => !!t);
    return await sendApnsToTokens(tokens, title, body, data);
}

// ---- Auth helper ------------------------------------------------------

async function requireUser(req: Request, admin: SupabaseClient): Promise<
    { userId: string } | { response: Response }
> {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.toLowerCase().startsWith("bearer ")
        ? authHeader.slice(7).trim()
        : "";
    if (!jwt) {
        return { response: json(401, { error: "unauthorized" }) };
    }
    const { data, error } = await admin.auth.getUser(jwt);
    if (error || !data?.user) {
        return { response: json(401, { error: "unauthorized" }) };
    }
    return { userId: data.user.id };
}

// ---- Handler: seedTestFriends ----------------------------------------
//
// Seeds (or refreshes) the global pool of 25 fake personas, ensures each
// has a profile, avatar, banner, posts, and an inter-fake follow graph,
// then bidirectionally follows the caller with all of them so they show
// up in real follower/following counts and lists.

async function seedTestFriends(
    admin: SupabaseClient,
    callerId: string,
    _payload: Record<string, unknown>,
): Promise<Response> {
    // Pre-load an active training program id if any exist
    let programIds: string[] = [];
    try {
        const { data } = await admin.from("training_programs").select("id").limit(50);
        if (Array.isArray(data)) {
            programIds = data
                .map((r: { id: unknown }) => (typeof r.id === "string" ? r.id : null))
                .filter((v): v is string => v !== null);
        }
    } catch (_) {
        programIds = [];
    }

    let created = 0;
    let existed = 0;
    const personaIds: string[] = [];
    const errors: string[] = [];

    // Pre-fetch existing auth users once (paginated) to avoid scanning every loop
    const existingByEmail = new Map<string, string>();
    {
        let page = 1;
        while (page < 20) {
            const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
            if (error) {
                errors.push(`listUsers page ${page}: ${error.message}`);
                break;
            }
            const users = data?.users ?? [];
            for (const u of users) {
                if (u.email) existingByEmail.set(u.email.toLowerCase(), u.id);
            }
            if (users.length < 200) break;
            page += 1;
        }
    }

    for (let i = 0; i < PERSONAS.length; i += 1) {
        const p = PERSONAS[i];
        const email = `frisfit-fake-${p.username}@frisfittest.app`;
        const program = programIds.length > 0
            ? programIds[i % programIds.length]
            : null;
        const avatarUrl = `https://i.pravatar.cc/400?img=${p.avatarSeed}`;
        const bannerUrl = `https://picsum.photos/seed/${encodeURIComponent(p.bannerSeed)}/1200/400`;

        let userId: string | null = existingByEmail.get(email.toLowerCase()) ?? null;

        if (!userId) {
            const { data: createRes, error: createErr } = await admin.auth.admin.createUser({
                email,
                password: crypto.randomUUID(),
                email_confirm: true,
                user_metadata: { is_test_user: true, full_name: p.name },
            });
            if (createRes?.user) {
                userId = createRes.user.id;
                created += 1;
            } else {
                const { data: list } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
                const match = list?.users?.find((u) => (u.email ?? "").toLowerCase() === email.toLowerCase());
                if (match) {
                    userId = match.id;
                    existed += 1;
                } else {
                    const msg = createErr?.message ?? "unknown";
                    errors.push(`createUser ${email}: ${msg}`);
                    console.error("createUser failed", email, createErr);
                    continue;
                }
            }
        } else {
            existed += 1;
        }

        if (!userId) continue;
        personaIds.push(userId);

        const { error: upsertErr } = await admin.from("profiles").upsert({
            id: userId,
            display_name: p.name,
            username: p.username,
            initials: initialsFor(p.name),
            bio: p.bio,
            avatar_color: p.color,
            avatar_url: avatarUrl,
            banner_url: bannerUrl,
            active_program: program,
            current_streak: p.streak,
            total_fp: p.totalFp,
            is_private: false,
            is_test_user: true,
            archetype_label: p.archetype,
            archetype_tagline: p.tagline,
        }, { onConflict: "id" });

        if (upsertErr) {
            errors.push(`profile upsert ${email}: ${upsertErr.message}`);
            console.error("profile upsert failed", email, upsertErr);
        }

        // Seed feed posts for this persona (idempotent: only insert if they
        // currently have no posts, so we don't duplicate on re-runs).
        try {
            const { count: existingPostCount } = await admin
                .from("feed_posts")
                .select("id", { count: "exact", head: true })
                .eq("user_id", userId);
            if ((existingPostCount ?? 0) === 0 && p.posts.length > 0) {
                const now = Date.now();
                const rows = p.posts.map((text, idx) => {
                    // Spread posts across the last ~14 days, most recent first.
                    const daysAgo = idx * 3 + (i % 3); // mild jitter per persona
                    const hoursJitter = ((i * 7 + idx * 11) % 11) - 5;
                    const created = new Date(
                        now - (daysAgo * 24 + hoursJitter) * 60 * 60 * 1000,
                    ).toISOString();
                    return {
                        user_id: userId,
                        text_content: text,
                        media_urls: [] as string[],
                        tags: [] as string[],
                        created_at: created,
                        updated_at: created,
                    };
                });
                const { error: postsErr } = await admin.from("feed_posts").insert(rows);
                if (postsErr) {
                    errors.push(`feed_posts insert ${p.username}: ${postsErr.message}`);
                }
            }
        } catch (e) {
            errors.push(`feed_posts pre-check ${p.username}: ${String(e)}`);
        }
    }

    // Inter-fake follow graph — each persona follows ~8 others (deterministic
    // ring with offsets) so their own follower counts look organic.
    const interRows: { follower_id: string; following_id: string }[] = [];
    if (personaIds.length > 1) {
        const offsets = [1, 2, 3, 5, 8, 13, 17, 21];
        for (let i = 0; i < personaIds.length; i += 1) {
            for (const off of offsets) {
                const j = (i + off) % personaIds.length;
                if (j === i) continue;
                interRows.push({ follower_id: personaIds[i], following_id: personaIds[j] });
            }
        }
    }

    // Caller ↔ every persona, bidirectional — so they show up in counts/lists
    const callerRows: { follower_id: string; following_id: string }[] = [];
    for (const id of personaIds) {
        callerRows.push({ follower_id: callerId, following_id: id });
        callerRows.push({ follower_id: id, following_id: callerId });
    }

    let followed = 0;
    const allFollowRows = [...interRows, ...callerRows];
    if (allFollowRows.length > 0) {
        const { error: followErr, count: followCount } = await admin
            .from("follows")
            .upsert(allFollowRows, { onConflict: "follower_id,following_id", ignoreDuplicates: true, count: "exact" });
        if (followErr) {
            errors.push(`follows upsert: ${followErr.message}`);
            console.error("follows upsert failed", followErr);
        } else {
            followed = followCount ?? allFollowRows.length;
        }
    }

    const { count: totalTestProfiles } = await admin
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("is_test_user", true);

    return json(200, {
        ok: errors.length === 0,
        version: "seed-v2",
        created,
        existed,
        total_test_profiles: totalTestProfiles ?? personaIds.length,
        followed,
        error: errors.length > 0 ? errors.slice(0, 5).join("; ") : undefined,
        error_details: errors,
    });
}

// ---- Handler: bootstrapFakeFollows -----------------------------------
//
// Lightweight call used right after signup. Doesn't create or modify the
// fake personas; just makes the caller follow every existing fake and
// vice-versa so their feed/Following list/counts populate immediately.
// If no fake personas exist yet, falls through to a full seed.

async function bootstrapFakeFollows(
    admin: SupabaseClient,
    callerId: string,
): Promise<Response> {
    const { data: rows, error } = await admin
        .from("profiles")
        .select("id")
        .eq("is_test_user", true);
    if (error) {
        return json(500, { ok: false, version: "seed-v2", error: error.message });
    }
    const personaIds = (rows ?? [])
        .map((r: { id: unknown }) => (typeof r.id === "string" ? r.id : null))
        .filter((v): v is string => !!v && v !== callerId);

    if (personaIds.length === 0) {
        // Cold start — run the full seed.
        return await seedTestFriends(admin, callerId, {});
    }

    const followRows: { follower_id: string; following_id: string }[] = [];
    for (const id of personaIds) {
        followRows.push({ follower_id: callerId, following_id: id });
        followRows.push({ follower_id: id, following_id: callerId });
    }
    const { count: followCount, error: followErr } = await admin
        .from("follows")
        .upsert(followRows, { onConflict: "follower_id,following_id", ignoreDuplicates: true, count: "exact" });

    return json(200, {
        ok: !followErr,
        version: "seed-v2",
        total_test_profiles: personaIds.length,
        followed: followCount ?? followRows.length,
        error: followErr?.message,
    });
}

// ---- Handler: clearTestFriends ---------------------------------------

async function clearTestFriends(admin: SupabaseClient): Promise<Response> {
    let deleted = 0;
    let page = 1;
    while (page < 20) {
        const { data } = await admin.auth.admin.listUsers({ page, perPage: 200 });
        const users = data?.users ?? [];
        const targets = users.filter((u) => {
            const e = (u.email ?? "").toLowerCase();
            return e.endsWith("@peppal.test")
                || e.endsWith("@peppaltest.app")
                || e.endsWith("@frisfittest.app");
        });
        for (const u of targets) {
            const { error } = await admin.auth.admin.deleteUser(u.id);
            if (error) {
                console.error("deleteUser failed", u.id, error);
                continue;
            }
            deleted += 1;
        }
        if (users.length < 200) break;
        page += 1;
    }
    return json(200, { ok: true, version: "seed-v2", deleted });
}

// ---- Friends helpers --------------------------------------------------

async function mutualFriendIds(admin: SupabaseClient, userId: string): Promise<string[]> {
    const [{ data: outRows }, { data: inRows }] = await Promise.all([
        admin.from("follows").select("following_id").eq("follower_id", userId),
        admin.from("follows").select("follower_id").eq("following_id", userId),
    ]);
    const out = new Set((outRows ?? []).map((r: { following_id: string }) => r.following_id));
    const inn = new Set((inRows ?? []).map((r: { follower_id: string }) => r.follower_id));
    return Array.from(out).filter((id) => inn.has(id));
}

async function followerIds(admin: SupabaseClient, userId: string): Promise<string[]> {
    const { data } = await admin.from("follows").select("follower_id").eq("following_id", userId);
    return (data ?? []).map((r: { follower_id: string }) => r.follower_id);
}

async function fetchProfilesByIds(admin: SupabaseClient, ids: string[]) {
    if (ids.length === 0) return [];
    const { data } = await admin
        .from("profiles")
        .select("id, display_name, username, avatar_url, avatar_color, active_program, total_fp, current_streak")
        .in("id", ids);
    return data ?? [];
}

async function friendsFeed(admin: SupabaseClient, userId: string): Promise<Response> {
    const friendIds = await mutualFriendIds(admin, userId);
    if (friendIds.length === 0) {
        return json(200, { ok: true, friends: [], events: [], myRecap: null });
    }

    const week = isoWeekStart();
    const [profilesData, prefsData, snapsData, eventsData] = await Promise.all([
        fetchProfilesByIds(admin, friendIds),
        admin.from("stat_sharing_prefs").select("*").in("user_id", friendIds).eq("is_enabled", true),
        admin.from("friend_stat_snapshots").select("*").in("user_id", friendIds).eq("week_start", week),
        admin
            .from("friend_activity_events")
            .select("*")
            .in("user_id", friendIds)
            .order("created_at", { ascending: false })
            .limit(60),
    ]);

    const prefsById = new Map<string, { audience: string; categories: string[] }>();
    for (const p of (prefsData.data ?? [])) {
        prefsById.set(p.user_id, { audience: p.audience, categories: p.categories });
    }
    const snapsById = new Map<string, Record<string, unknown>>();
    for (const s of (snapsData.data ?? [])) {
        snapsById.set(s.user_id, s);
    }

    const friends = profilesData.map((p: { id: string }) => ({
        profile: p,
        prefs: prefsById.get(p.id) ?? null,
        snapshot: snapsById.get(p.id) ?? null,
    })).filter((f) => f.prefs !== null);

    return json(200, {
        ok: true,
        friends,
        events: (eventsData.data ?? []).filter((e: { user_id: string }) => prefsById.has(e.user_id)),
        myRecap: await myRecapPayload(admin, userId),
    });
}

async function myRecapPayload(admin: SupabaseClient, userId: string): Promise<unknown> {
    const { data: latest } = await admin
        .from("friend_activity_events")
        .select("*")
        .eq("user_id", userId)
        .eq("type", "weekly_recap")
        .order("created_at", { ascending: false })
        .limit(1);
    return latest?.[0] ?? null;
}

async function recordActivityEvent(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const type = String(payload.type ?? "");
    const title = String(payload.title ?? "");
    const subtitle = payload.subtitle == null ? null : String(payload.subtitle);
    const data = (payload.data && typeof payload.data === "object") ? payload.data : {};
    const fanout = payload.fanout !== false;
    if (!type || !title) return json(400, { error: "missing_fields" });

    const { data: inserted, error } = await admin
        .from("friend_activity_events")
        .insert({ user_id: userId, type, title, subtitle, data })
        .select("*")
        .single();
    if (error) return json(500, { error: error.message });

    if (fanout) {
        const followers = await followerIds(admin, userId);
        if (followers.length > 0) {
            const notifRows = followers.map((uid) => ({
                user_id: uid,
                type: `friend_${type}`,
                title,
                body: subtitle ?? "",
                data: { event_id: inserted.id, friend_id: userId, ...(data as Record<string, unknown>) },
            }));
            await admin.from("notifications").insert(notifRows);
            await pushToUsers(admin, followers, title, subtitle ?? "", { event_id: inserted.id, friend_id: userId, type });
        }
    }
    return json(200, { ok: true, event: inserted });
}

async function sendNudge(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const receiver = String(payload.receiver_id ?? "");
    const kind = String(payload.kind ?? "check");
    const title = String(payload.title ?? "You got a nudge");
    const body = String(payload.body ?? "A friend is checking in.");
    if (!receiver) return json(400, { error: "missing_receiver" });

    // 6-hour cooldown
    const sixHoursAgo = new Date(Date.now() - 6 * 3600 * 1000).toISOString();
    const { data: recent } = await admin
        .from("friend_nudges")
        .select("id")
        .eq("sender_id", userId)
        .eq("receiver_id", receiver)
        .gte("created_at", sixHoursAgo)
        .limit(1);
    if ((recent ?? []).length > 0) return json(429, { error: "cooldown" });

    const { data: inserted, error } = await admin
        .from("friend_nudges")
        .insert({ sender_id: userId, receiver_id: receiver, kind })
        .select("*")
        .single();
    if (error) return json(500, { error: error.message });

    await admin.from("notifications").insert({
        user_id: receiver,
        type: "friend_nudge",
        title,
        body,
        data: { nudge_id: inserted.id, friend_id: userId, kind },
    });
    await pushToUsers(admin, [receiver], title, body, { nudge_id: inserted.id, friend_id: userId, kind, type: "nudge" });
    return json(200, { ok: true, nudge: inserted });
}

async function sendReaction(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const receiver = String(payload.receiver_id ?? "");
    const target = String(payload.target ?? "");
    const emoji = String(payload.emoji ?? "");
    if (!receiver || !target || !emoji) return json(400, { error: "missing_fields" });
    const { data: inserted, error } = await admin
        .from("friend_reactions")
        .insert({ sender_id: userId, receiver_id: receiver, target, emoji })
        .select("*")
        .single();
    if (error) return json(500, { error: error.message });
    await admin.from("notifications").insert({
        user_id: receiver,
        type: "friend_reaction",
        title: "New reaction",
        body: `Someone reacted ${emoji}`,
        data: { reaction_id: inserted.id, friend_id: userId, emoji, target },
    });
    return json(200, { ok: true, reaction: inserted });
}

async function upsertSharingPrefs(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const isEnabled = !!payload.is_enabled;
    const audience = String(payload.audience ?? "friends");
    const categories = Array.isArray(payload.categories) ? (payload.categories as unknown[]).map(String) : [];

    // Detect transition off→on
    const { data: existing } = await admin
        .from("stat_sharing_prefs")
        .select("is_enabled")
        .eq("user_id", userId)
        .maybeSingle();
    const wasEnabled = existing?.is_enabled === true;

    const { error } = await admin.from("stat_sharing_prefs").upsert({
        user_id: userId,
        is_enabled: isEnabled,
        audience,
        categories,
        updated_at: new Date().toISOString(),
    }, { onConflict: "user_id" });
    if (error) return json(500, { error: error.message });

    if (!wasEnabled && isEnabled) {
        // Fan out a sharing_on event
        const { data: profile } = await admin.from("profiles").select("display_name").eq("id", userId).maybeSingle();
        const name = profile?.display_name ?? "A friend";
        const { data: inserted } = await admin
            .from("friend_activity_events")
            .insert({
                user_id: userId,
                type: "sharing_on",
                title: `${name} is sharing stats now`,
                subtitle: "Tap to see their progress",
                data: {},
            })
            .select("*")
            .single();
        const followers = await followerIds(admin, userId);
        if (followers.length > 0) {
            const rows = followers.map((uid) => ({
                user_id: uid,
                type: "friend_sharing_on",
                title: `${name} turned on stat sharing`,
                body: "Check out their progress",
                data: { event_id: inserted?.id, friend_id: userId },
            }));
            await admin.from("notifications").insert(rows);
            await pushToUsers(admin, followers, `${name} is sharing stats`, "Check out their progress", { friend_id: userId, type: "sharing_on" });
        }
    }
    return json(200, { ok: true });
}

async function upsertWeeklySnapshot(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const week = String(payload.week_start ?? isoWeekStart());
    const row = {
        user_id: userId,
        week_start: week,
        weekly_workouts: Number(payload.weekly_workouts ?? 0) | 0,
        weekly_volume_kg: Number(payload.weekly_volume_kg ?? 0) | 0,
        weekly_steps: Number(payload.weekly_steps ?? 0) | 0,
        weekly_calories: Number(payload.weekly_calories ?? 0) | 0,
        weekly_water_ml: Number(payload.weekly_water_ml ?? 0) | 0,
        streak: Number(payload.streak ?? 0) | 0,
        latest_pr: payload.latest_pr == null ? null : String(payload.latest_pr),
        active_program: payload.active_program == null ? null : String(payload.active_program),
        active_protocol: payload.active_protocol == null ? null : String(payload.active_protocol),
        updated_at: new Date().toISOString(),
    };
    const { error } = await admin.from("friend_stat_snapshots").upsert(row, { onConflict: "user_id,week_start" });
    if (error) return json(500, { error: error.message });
    return json(200, { ok: true });
}

async function buildAndStoreRecap(admin: SupabaseClient, userId: string): Promise<unknown> {
    const lastWeek = previousIsoWeekStart();
    const thisWeek = isoWeekStart();
    const { data: rows } = await admin
        .from("friend_stat_snapshots")
        .select("*")
        .eq("user_id", userId)
        .in("week_start", [lastWeek, thisWeek]);
    const last = (rows ?? []).find((r: { week_start: string }) => r.week_start === lastWeek);
    const prev = (rows ?? []).find((r: { week_start: string }) => r.week_start === thisWeek);
    if (!last) return null;

    const workouts = last.weekly_workouts ?? 0;
    const volume = last.weekly_volume_kg ?? 0;
    const steps = last.weekly_steps ?? 0;
    const streak = last.streak ?? 0;
    const data = {
        week_start: lastWeek,
        weekly_workouts: workouts,
        weekly_volume_kg: volume,
        weekly_steps: steps,
        weekly_calories: last.weekly_calories ?? 0,
        weekly_water_ml: last.weekly_water_ml ?? 0,
        streak,
        latest_pr: last.latest_pr,
        prev_workouts: prev?.weekly_workouts ?? 0,
        prev_volume_kg: prev?.weekly_volume_kg ?? 0,
        prev_steps: prev?.weekly_steps ?? 0,
    };
    const title = `Your week: ${workouts} workouts`;
    const subtitle = volume > 0 ? `${(volume / 1000).toFixed(1)}t lifted · ${streak}d streak` : `${steps.toLocaleString()} steps · ${streak}d streak`;

    const { data: inserted } = await admin
        .from("friend_activity_events")
        .insert({ user_id: userId, type: "weekly_recap", title, subtitle, data })
        .select("*")
        .single();

    await admin.from("notifications").insert({
        user_id: userId,
        type: "weekly_recap",
        title: "Your weekly recap is ready",
        body: subtitle,
        data: { event_id: inserted?.id },
    });
    await pushToUsers(admin, [userId], "Your weekly recap is ready", subtitle, { type: "weekly_recap", event_id: inserted?.id });
    return inserted;
}

async function weeklyRecap(admin: SupabaseClient, userId: string): Promise<Response> {
    const inserted = await buildAndStoreRecap(admin, userId);
    return json(200, { ok: true, event: inserted });
}

async function weeklyRecapAll(admin: SupabaseClient, payload: Record<string, unknown>): Promise<Response> {
    const cronSecret = Deno.env.get("CRON_SECRET");
    if (cronSecret && payload.secret !== cronSecret) return json(401, { error: "unauthorized" });
    const lastWeek = previousIsoWeekStart();
    const { data: users } = await admin
        .from("friend_stat_snapshots")
        .select("user_id")
        .eq("week_start", lastWeek);
    const ids = Array.from(new Set((users ?? []).map((u: { user_id: string }) => u.user_id)));
    let count = 0;
    for (const id of ids) {
        await buildAndStoreRecap(admin, id);
        count += 1;
    }
    return json(200, { ok: true, count });
}

async function sendPushAction(
    admin: SupabaseClient,
    _userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const userIds = Array.isArray(payload.user_ids) ? (payload.user_ids as unknown[]).map(String) : [];
    const title = String(payload.title ?? "");
    const body = String(payload.body ?? "");
    const data = (payload.data && typeof payload.data === "object") ? payload.data as Record<string, unknown> : {};
    if (userIds.length === 0 || !title) return json(400, { error: "missing_fields" });
    const result = await pushToUsers(admin, userIds, title, body, data);
    return json(200, { ok: true, ...result });
}

// ---- Handler: createFakeUser ----------------------------------------
//
// Creates an arbitrary fake auth user + profile on demand. Used by the
// in-app Fake Account Switcher so the operator can spin up new fakes,
// post / message / log as them, and switch back. Returns email +
// password so the caller can sign in immediately.

function randomPassword(): string {
    const buf = new Uint8Array(18);
    crypto.getRandomValues(buf);
    return "Fk-" + Array.from(buf).map((b) => b.toString(16).padStart(2, "0")).join("") + "!1";
}

function randomHandle(seed: string): string {
    const slug = slugify(seed) || "fake";
    const tail = Math.random().toString(36).slice(2, 6);
    return (slug + tail).slice(0, 24);
}

async function createFakeUser(
    admin: SupabaseClient,
    callerId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const requestedName = typeof payload.display_name === "string" ? payload.display_name.trim() : "";
    const requestedHandle = typeof payload.username === "string" ? payload.username.trim() : "";
    const followCaller = payload.follow_caller !== false;
    // populate_level: 'none' | 'light' | 'medium' | 'heavy' | 'fresh'
    // 'fresh' = no profile data filled, used when operator wants to run
    // the new account through onboarding manually after switching in.
    const populateLevel = String(payload.populate_level ?? "light").toLowerCase();
    const archetypeKey = typeof payload.archetype === "string" ? payload.archetype.toLowerCase() : "";

    const fallbackName = NAMES[Math.floor(Math.random() * NAMES.length)] ?? "Fake User";
    const displayName = requestedName.length > 0 ? requestedName : fallbackName;
    const baseHandle = requestedHandle.length > 0 ? slugify(requestedHandle) : randomHandle(displayName);
    const username = (baseHandle.length > 0 ? baseHandle : randomHandle("user")).slice(0, 24);
    const email = `frisfit-fake-${username}-${Date.now().toString(36)}@frisfittest.app`;
    const password = randomPassword();

    // Optional: borrow archetype defaults from a curated persona
    const matchedPersona: Persona | null = archetypeKey.length > 0
        ? (PERSONAS.find((p) => p.archetype.toLowerCase() === archetypeKey) ?? null)
        : null;

    const { data: createRes, error: createErr } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { is_test_user: true, full_name: displayName },
    });
    if (createErr || !createRes?.user) {
        return json(500, { ok: false, error: createErr?.message ?? "create_failed" });
    }
    const userId = createRes.user.id;
    const isFresh = populateLevel === "fresh" || populateLevel === "none";
    const color = matchedPersona?.color ?? AVATAR_PALETTE[Math.floor(Math.random() * AVATAR_PALETTE.length)];
    const avatarSeed = matchedPersona?.avatarSeed ?? randInt(1, 70);
    const bio = isFresh
        ? ""
        : (matchedPersona?.bio ?? (requestedName.length > 0 ? "" : (BIOS[Math.floor(Math.random() * BIOS.length)] ?? "")));

    const { error: upsertErr } = await admin.from("profiles").upsert({
        id: userId,
        display_name: displayName,
        username,
        initials: initialsFor(displayName),
        bio,
        avatar_color: color,
        avatar_url: isFresh ? null : `https://i.pravatar.cc/400?img=${avatarSeed}`,
        banner_url: isFresh ? null : `https://picsum.photos/seed/${encodeURIComponent(username)}/1200/400`,
        current_streak: isFresh ? 0 : (matchedPersona?.streak ?? 0),
        total_fp: isFresh ? 0 : (matchedPersona?.totalFp ?? 0),
        is_private: false,
        is_test_user: true,
        archetype_label: matchedPersona?.archetype ?? null,
        archetype_tagline: matchedPersona?.tagline ?? null,
    }, { onConflict: "id" });
    if (upsertErr) {
        return json(500, { ok: false, error: `profile: ${upsertErr.message}` });
    }

    if (followCaller && !isFresh) {
        await admin.from("follows").upsert([
            { follower_id: callerId, following_id: userId },
            { follower_id: userId, following_id: callerId },
        ], { onConflict: "follower_id,following_id", ignoreDuplicates: true });
    }

    // Optional immediate populate based on level
    let populated = 0;
    if (populateLevel === "light" || populateLevel === "medium" || populateLevel === "heavy") {
        try {
            populated = await populateOnePersonaInline(admin, userId, matchedPersona, populateLevel);
        } catch (e) {
            console.error("populate inline failed", e);
        }
        // For medium/heavy, also run the deep-persona seed so the fake account
        // has weight history, workouts, meals, etc. — not just feed posts.
        if ((populateLevel === "medium" || populateLevel === "heavy") && matchedPersona) {
            try {
                await deepPopulateFakePersona(admin, userId, matchedPersona);
            } catch (e) {
                console.error("deep populate inline failed", e);
            }
        }
    }

    return json(200, {
        ok: true,
        version: "seed-v2",
        user_id: userId,
        email,
        password,
        display_name: displayName,
        username,
        populated,
        populate_level: populateLevel,
    });
}

// ---- Bulk populate / cross-interactions / groups / DMs ----------------

function depthFor(level: string): { posts: number; daysBack: number; commentsPerPost: number; likesPerPost: number; dms: number } {
    switch (level) {
        case "heavy":  return { posts: 20, daysBack: 90, commentsPerPost: 8, likesPerPost: 18, dms: 8 };
        case "medium": return { posts: 14, daysBack: 90, commentsPerPost: 5, likesPerPost: 12, dms: 5 };
        case "light":
        default:       return { posts: 8,  daysBack: 60, commentsPerPost: 3, likesPerPost: 6,  dms: 2 };
    }
}

function pickN<T>(arr: T[], n: number, seed: number = 0): T[] {
    const out: T[] = [];
    const used = new Set<number>();
    for (let i = 0; i < n && i < arr.length; i += 1) {
        let idx = (Math.floor(Math.random() * arr.length) + seed * 13) % arr.length;
        let guard = 0;
        while (used.has(idx) && guard < arr.length) { idx = (idx + 1) % arr.length; guard += 1; }
        used.add(idx);
        out.push(arr[idx]);
    }
    return out;
}

async function fakePersonaIds(admin: SupabaseClient): Promise<{ id: string; username: string | null; archetype_label: string | null; interests?: string[] }[]> {
    const { data } = await admin
        .from("profiles")
        .select("id, username, archetype_label")
        .eq("is_test_user", true);
    const rows = (data ?? []) as Array<{ id: string; username: string | null; archetype_label: string | null }>;
    return rows.map((r) => {
        const persona = PERSONAS.find((p) => p.username === r.username) ?? null;
        return {
            id: r.id,
            username: r.username,
            archetype_label: r.archetype_label,
            interests: persona?.interests,
        };
    });
}

async function populateOnePersonaInline(
    admin: SupabaseClient,
    userId: string,
    persona: Persona | null,
    level: string,
): Promise<number> {
    const depth = depthFor(level);
    const bank = persona?.posts ?? FAKE_POST_BANK;
    const now = Date.now();
    const wanted = Math.max(1, Math.min(depth.posts, bank.length || depth.posts));
    const rows: Record<string, unknown>[] = [];
    const used = new Set<number>();
    for (let i = 0; i < wanted; i += 1) {
        let idx = Math.floor(Math.random() * bank.length);
        let guard = 0;
        while (used.has(idx) && guard < bank.length) { idx = (idx + 1) % bank.length; guard += 1; }
        used.add(idx);
        const daysAgo = Math.random() * depth.daysBack;
        const created = new Date(now - daysAgo * 24 * 3600 * 1000).toISOString();
        rows.push({
            user_id: userId,
            text_content: bank[idx],
            media_urls: [],
            tags: persona?.interests ?? [],
            created_at: created,
            updated_at: created,
        });
    }
    if (rows.length > 0) {
        await admin.from("feed_posts").insert(rows);
    }
    return rows.length;
}

async function generateCrossInteractions(
    admin: SupabaseClient,
    fakeIds: string[],
    level: string,
): Promise<{ likes: number; comments: number }> {
    if (fakeIds.length < 2) return { likes: 0, comments: 0 };
    const depth = depthFor(level);
    const idSet = new Set(fakeIds);
    const { data: postRows } = await admin
        .from("feed_posts")
        .select("id, user_id")
        .in("user_id", fakeIds)
        .order("created_at", { ascending: false })
        .limit(2000);
    const posts = (postRows ?? []) as Array<{ id: string; user_id: string }>;
    const likes: { post_id: string; user_id: string }[] = [];
    const comments: { post_id: string; user_id: string; content: string; created_at: string }[] = [];
    const otherFakes = (postUserId: string) => fakeIds.filter((x) => x !== postUserId && idSet.has(x));
    for (const post of posts) {
        const likers = pickN(otherFakes(post.user_id), depth.likesPerPost);
        for (const l of likers) likes.push({ post_id: post.id, user_id: l });
        const commenters = pickN(otherFakes(post.user_id), depth.commentsPerPost);
        for (const c of commenters) {
            const text = CROSS_COMMENT_BANK[Math.floor(Math.random() * CROSS_COMMENT_BANK.length)];
            const minutesOff = randInt(5, 60 * 24);
            const at = new Date(Date.now() - minutesOff * 60 * 1000).toISOString();
            comments.push({ post_id: post.id, user_id: c, content: text, created_at: at });
        }
    }
    if (likes.length > 0) {
        for (let i = 0; i < likes.length; i += 500) {
            await admin.from("post_likes").upsert(likes.slice(i, i + 500), { onConflict: "post_id,user_id", ignoreDuplicates: true });
        }
    }
    if (comments.length > 0) {
        for (let i = 0; i < comments.length; i += 500) {
            await admin.from("post_comments").insert(comments.slice(i, i + 500));
        }
    }
    return { likes: likes.length, comments: comments.length };
}

async function seedFakeGroups(admin: SupabaseClient, fakeIds: string[]): Promise<{ groups: number; members: number; messages: number }> {
    if (fakeIds.length === 0) return { groups: 0, members: 0, messages: 0 };
    const personasByUser = new Map<string, Persona>();
    {
        const { data } = await admin.from("profiles").select("id, username").in("id", fakeIds);
        for (const r of (data ?? []) as Array<{ id: string; username: string | null }>) {
            const p = PERSONAS.find((x) => x.username === r.username);
            if (p) personasByUser.set(r.id, p);
        }
    }
    let groupsCreated = 0;
    let membersAdded = 0;
    let messagesPosted = 0;
    for (const seed of SEED_GROUPS) {
        const matchingMembers = fakeIds.filter((uid) => {
            const p = personasByUser.get(uid);
            if (!p) return false;
            return p.interests.some((i) => seed.interests.includes(i));
        });
        if (matchingMembers.length === 0) continue;
        const owner = matchingMembers[0];
        // Idempotent: check if group with this name already exists
        const { data: existingRow } = await admin
            .from("groups").select("id").eq("name", seed.name).maybeSingle();
        let groupId: string | null = (existingRow as { id?: string } | null)?.id ?? null;
        if (!groupId) {
            const { data: created, error: gErr } = await admin
                .from("groups")
                .insert({
                    creator_id: owner,
                    name: seed.name,
                    description: seed.description,
                    privacy: "Public",
                    accent_color_hex: seed.color,
                    icon_name: seed.icon,
                })
                .select("id")
                .single();
            if (gErr || !created) { console.error("seed group create", seed.name, gErr); continue; }
            groupId = (created as { id: string }).id;
            groupsCreated += 1;
        }
        const memberRows = matchingMembers.map((uid, idx) => ({
            group_id: groupId, user_id: uid, role: idx === 0 ? "Owner" : "Member",
        }));
        if (memberRows.length > 0) {
            const { count: addedCount } = await admin
                .from("group_members")
                .upsert(memberRows, { onConflict: "group_id,user_id", ignoreDuplicates: true, count: "exact" });
            membersAdded += addedCount ?? 0;
        }
        const { count: existingMsgs } = await admin
            .from("group_messages").select("id", { count: "exact", head: true }).eq("group_id", groupId);
        const have = existingMsgs ?? 0;
        const targetMessages = 28;
        if (have < targetMessages) {
            // Build a bigger conversation: seed posts + filler chat lines
            const filler = [
                "who else is in tonight?",
                "deload week feels too short tbh",
                "send the playlist",
                "that program is a grinder but it works",
                "i'm in for saturday long run",
                "anyone running a similar block?",
                "hot take but caffeine ruins my sleep below 8hrs",
                "trying the new warmup you posted, it's clean",
                "recovery is the limiter for me rn",
                "watching this thread closely 👀",
                "feeling it today fr",
                "meet day countdown is on",
                "chicken rice broccoli stays undefeated",
                "who's doing the friday run",
                "i'm logging 2 weeks of macros to recalibrate",
                "new shoes tomorrow, will report back",
                "protein hit was easier than i thought today",
                "sleeping 8h was the cheat code all along",
            ];
            const lines = [...seed.posts, ...filler];
            const toAdd = Math.min(targetMessages - have, lines.length);
            const baseDays = 14;
            const msgRows: Record<string, unknown>[] = [];
            for (let i = 0; i < toAdd; i += 1) {
                const sender = matchingMembers[(i * 3) % matchingMembers.length];
                const minutesAgo = Math.round((baseDays * 24 * 60) * ((toAdd - i) / toAdd)) + Math.floor(Math.random() * 25);
                msgRows.push({
                    group_id: groupId, sender_id: sender, text_content: lines[i],
                    created_at: new Date(Date.now() - minutesAgo * 60 * 1000).toISOString(),
                });
            }
            if (msgRows.length > 0) {
                const { error } = await admin.from("group_messages").insert(msgRows);
                if (!error) messagesPosted += msgRows.length;
            }
        }
    }
    return { groups: groupsCreated, members: membersAdded, messages: messagesPosted };
}

async function seedFakeDMs(admin: SupabaseClient, fakeIds: string[], pairsCount: number): Promise<{ pairs: number; messages: number }> {
    if (fakeIds.length < 2) return { pairs: 0, messages: 0 };
    let pairs = 0;
    let messages = 0;
    const seen = new Set<string>();
    for (let attempt = 0; attempt < pairsCount * 3 && pairs < pairsCount; attempt += 1) {
        const a = fakeIds[Math.floor(Math.random() * fakeIds.length)];
        const b = fakeIds[Math.floor(Math.random() * fakeIds.length)];
        if (a === b) continue;
        const key = [a, b].sort().join(":");
        if (seen.has(key)) continue;
        seen.add(key);
        try {
            const { data: convExisting } = await admin
                .from("conversation_participants").select("conversation_id").eq("user_id", a);
            let convId: string | null = null;
            if (convExisting && convExisting.length > 0) {
                const ids = (convExisting as Array<{ conversation_id: string }>).map((r) => r.conversation_id);
                const { data: matches } = await admin
                    .from("conversation_participants").select("conversation_id")
                    .in("conversation_id", ids).eq("user_id", b);
                convId = ((matches ?? []) as Array<{ conversation_id: string }>)[0]?.conversation_id ?? null;
            }
            if (!convId) {
                const { data: newConv, error: convErr } = await admin
                    .from("conversations").insert({}).select("id").single();
                if (convErr || !newConv) continue;
                convId = (newConv as { id: string }).id;
                await admin.from("conversation_participants").insert([
                    { conversation_id: convId, user_id: a },
                    { conversation_id: convId, user_id: b },
                ]);
            }
            const opener = CROSS_DM_OPENERS[Math.floor(Math.random() * CROSS_DM_OPENERS.length)];
            const reply = CROSS_DM_REPLIES[Math.floor(Math.random() * CROSS_DM_REPLIES.length)];
            const baseAgo = randInt(1, 21) * 24 * 3600 * 1000;
            await admin.from("direct_messages").insert([
                { conversation_id: convId, sender_id: a, text_content: opener, is_read: true,
                    created_at: new Date(Date.now() - baseAgo).toISOString() },
                { conversation_id: convId, sender_id: b, text_content: reply, is_read: true,
                    created_at: new Date(Date.now() - baseAgo + 18 * 60 * 1000).toISOString() },
            ]);
            pairs += 1;
            messages += 2;
        } catch (e) {
            console.error("dm seed pair failed", e);
        }
    }
    return { pairs, messages };
}

async function bulkPopulateAllFakes(
    admin: SupabaseClient,
    payload: Record<string, unknown>,
    callerId: string | null = null,
): Promise<Response> {
    const level = String(payload.level ?? "medium").toLowerCase();
    const fakes = await fakePersonaIds(admin);
    if (fakes.length === 0) return json(200, { ok: true, fakes: 0 });
    const ids = fakes.map((f) => f.id);

    let postsAdded = 0;
    for (const f of fakes) {
        const persona = PERSONAS.find((p) => p.username === f.username) ?? null;
        // Only add posts if the persona has fewer than depth.posts already
        const depth = depthFor(level);
        const { count: existing } = await admin
            .from("feed_posts").select("id", { count: "exact", head: true }).eq("user_id", f.id);
        const have = existing ?? 0;
        if (have >= depth.posts) continue;
        const wantToAdd = depth.posts - have;
        // Build a temporary persona-with-fewer-posts request
        const bank = persona?.posts ?? FAKE_POST_BANK;
        const subset = bank.slice(0, Math.min(wantToAdd, bank.length));
        const now = Date.now();
        const rows = subset.map((text, idx) => {
            const daysAgo = randInt(0, depth.daysBack);
            const created = new Date(now - daysAgo * 24 * 3600 * 1000 - idx * 90 * 60 * 1000).toISOString();
            // Attach media to ~60% of posts so the feed looks alive
            const includeMedia = (idx + (persona?.avatarSeed ?? 0)) % 5 < 3;
            const mediaSeed = `${persona?.bannerSeed ?? "post"}-${idx}`;
            return {
                user_id: f.id, text_content: text,
                media_urls: includeMedia ? [mediaUrlForSeed(mediaSeed)] : [],
                tags: persona?.interests ?? [],
                created_at: created, updated_at: created,
            };
        });
        if (rows.length > 0) {
            await admin.from("feed_posts").insert(rows);
            postsAdded += rows.length;
        }
    }

    // Deep-populate each fake with archetype-tuned weight history, workouts,
    // meals, protocols, etc. so they look like real accounts when impersonated.
    let deepWorkouts = 0, deepMeals = 0, deepDoses = 0, deepWeights = 0;
    for (const f of fakes) {
        const persona = PERSONAS.find((p) => p.username === f.username) ?? null;
        if (!persona) continue;
        try {
            const { inserted } = await deepPopulateFakePersona(admin, f.id, persona);
            deepWorkouts += inserted.workouts;
            deepMeals += inserted.meals;
            deepDoses += inserted.dose_logs;
            deepWeights += inserted.weights;
        } catch (e) {
            console.error("deep populate", f.username, e);
        }
    }

    const interactions = await generateCrossInteractions(admin, ids, level);
    const replies = await generateCommentReplies(admin, ids, level);
    const groups = await seedFakeGroups(admin, ids);
    const dms = await seedFakeDMs(admin, ids, level === "heavy" ? 30 : level === "medium" ? 18 : 8);

    // When caller is signed in, also seed their personal account so every
    // tab is screenshot-ready in one tap.
    let mySeed: unknown = null;
    if (callerId) {
        try {
            const resp = await screenshotSeedMe(admin, callerId);
            mySeed = await resp.json();
        } catch (e) {
            console.error("screenshotSeedMe inline failed", e);
        }
    }

    return json(200, {
        ok: true,
        version: "seed-v2",
        fakes: ids.length,
        posts_added: postsAdded,
        deep_workouts: deepWorkouts,
        deep_meals: deepMeals,
        deep_doses: deepDoses,
        deep_weights: deepWeights,
        likes: interactions.likes,
        comments: interactions.comments,
        groups_created: groups.groups,
        group_members_added: groups.members,
        group_messages: groups.messages,
        dm_pairs: dms.pairs,
        dm_messages: dms.messages,
        comment_replies: replies,
        my_account: mySeed,
    });
}

async function generateCommentReplies(
    admin: SupabaseClient,
    fakeIds: string[],
    level: string,
): Promise<number> {
    if (fakeIds.length < 2) return 0;
    const target = level === "heavy" ? 80 : level === "medium" ? 40 : 15;
    // Pull recent comments to reply to
    const { data: parents } = await admin
        .from("post_comments")
        .select("id, post_id, user_id")
        .in("user_id", fakeIds)
        .is("parent_comment_id", null)
        .order("created_at", { ascending: false })
        .limit(target * 2);
    const parentRows = (parents ?? []) as Array<{ id: string; post_id: string; user_id: string }>;
    if (parentRows.length === 0) return 0;
    const replies: Record<string, unknown>[] = [];
    const replyBank = [
        "this 100%",
        "hard agree",
        "how long did you build to that",
        "saving this",
        "yes — my coach said the same",
        "stealing this. thank you",
        "send the program 🙏",
        "underrated take",
        "this changed my training tbh",
        "called out lol",
    ];
    for (let i = 0; i < Math.min(target, parentRows.length); i += 1) {
        const parent = parentRows[i];
        const replier = fakeIds[(i * 13) % fakeIds.length];
        if (replier === parent.user_id) continue;
        const text = replyBank[i % replyBank.length];
        const minutesOff = randInt(2, 60 * 12);
        replies.push({
            post_id: parent.post_id,
            user_id: replier,
            content: text,
            parent_comment_id: parent.id,
            created_at: new Date(Date.now() - minutesOff * 60 * 1000).toISOString(),
        });
    }
    if (replies.length === 0) return 0;
    const { error } = await admin.from("post_comments").insert(replies);
    if (error) console.error("reply insert", error);
    return error ? 0 : replies.length;
}

// Cron-fired twice-daily auto-log: pick ~40% of fakes, each posts 0-1
// new feed entry, and we sprinkle a handful of cross-likes/comments.
// Authenticated via CRON_SECRET to allow service-role anonymous calls.
async function fakeDailyAutoLog(
    admin: SupabaseClient,
    payload: Record<string, unknown>,
): Promise<Response> {
    const cronSecret = Deno.env.get("CRON_SECRET");
    if (cronSecret && payload.secret !== cronSecret) {
        return json(401, { error: "unauthorized" });
    }
    const fakes = await fakePersonaIds(admin);
    if (fakes.length === 0) return json(200, { ok: true, posted: 0 });
    const targets = fakes.filter(() => Math.random() < 0.4);
    let posted = 0;
    for (const f of targets) {
        if (Math.random() < 0.35) continue; // some don't log
        const persona = PERSONAS.find((p) => p.username === f.username) ?? null;
        const bank = persona?.posts ?? FAKE_POST_BANK;
        const text = bank[Math.floor(Math.random() * bank.length)];
        const created = new Date().toISOString();
        const { error } = await admin.from("feed_posts").insert({
            user_id: f.id, text_content: text, media_urls: [], tags: persona?.interests ?? [],
            created_at: created, updated_at: created,
        });
        if (!error) posted += 1;
    }
    const interactions = await generateCrossInteractions(admin, fakes.map((f) => f.id), "light");
    return json(200, { ok: true, posted, likes: interactions.likes, comments: interactions.comments });
}

// ---- Handler: listFakeUsers ------------------------------------------

async function listFakeUsers(admin: SupabaseClient): Promise<Response> {
    const { data: profiles, error } = await admin
        .from("profiles")
        .select("id, display_name, username, avatar_url, avatar_color, current_streak, total_fp, updated_at, archetype_label, archetype_tagline")
        .eq("is_test_user", true)
        .order("archetype_label", { ascending: true, nullsFirst: false })
        .limit(200);
    if (error) return json(500, { ok: false, error: error.message });

    const emailById = new Map<string, string>();
    let page = 1;
    while (page < 20) {
        const { data, error: listErr } = await admin.auth.admin.listUsers({ page, perPage: 200 });
        if (listErr) break;
        const users = data?.users ?? [];
        for (const u of users) {
            if (u.email) emailById.set(u.id, u.email);
        }
        if (users.length < 200) break;
        page += 1;
    }

    const items = (profiles ?? []).map((p: Record<string, unknown>) => ({
        ...p,
        email: emailById.get(String(p.id)) ?? null,
    }));
    return json(200, { ok: true, version: "seed-v2", items });
}

// ---- Handler: rotateFakeUserPassword ---------------------------------
//
// Generates a new password for a fake auth user and returns it so the
// caller can sign in. Only allowed for users tagged is_test_user=true.

async function rotateFakeUserPassword(
    admin: SupabaseClient,
    payload: Record<string, unknown>,
): Promise<Response> {
    const userId = String(payload.user_id ?? "");
    if (!userId) return json(400, { error: "missing_user_id" });

    const { data: profile, error: profErr } = await admin
        .from("profiles")
        .select("id, is_test_user")
        .eq("id", userId)
        .maybeSingle();
    if (profErr) return json(500, { error: profErr.message });
    if (!profile || profile.is_test_user !== true) {
        return json(403, { error: "not_a_fake_user" });
    }

    const password = randomPassword();
    const { data: updated, error: updErr } = await admin.auth.admin.updateUserById(userId, { password });
    if (updErr) return json(500, { error: updErr.message });
    const email = updated?.user?.email ?? null;
    if (!email) return json(500, { error: "no_email" });
    return json(200, { ok: true, version: "seed-v2", user_id: userId, email, password });
}

// ---- Handler: generateFakeActivity -----------------------------------
//
// Inserts a small batch of plausible feed posts for a fake user spread
// over the last N days. Narrow scope so we never touch tables with
// strict business invariants. Service-role only.

const FAKE_POST_BANK: string[] = [
    "showed up. that's the win.",
    "squats moved like trash today but i hit them anyway",
    "easy 8 this morning, kept HR under 145 the whole way",
    "PR day. screaming in the car park",
    "deload week and i'm already itching to add weight",
    "slept 8h12m last night. lifts felt like a different sport",
    "new shoes day. nothing else matters",
    "protein at every meal is the only diet rule that ever moved the needle for me",
    "100 free throws after practice. made 87. i'll take it",
    "bloods back. lipids actually improved. cautiously optimistic",
    "missed a session because i needed sleep more. that's a win not a loss",
    "front squats then a fasted run. would not recommend but here we are",
    "upped calories by 300 and the fatigue went away. eat your food people",
    "reposting the same advice for the 100th time: train submaximally most of the time",
    "hangboard repeaters this morning. fingers are noodles",
    "long run done. 16k. kept it conversational",
    "new sleeves, new pr. correlation? probably not. but maybe.",
];

async function generateFakeActivity(
    admin: SupabaseClient,
    payload: Record<string, unknown>,
): Promise<Response> {
    const userId = String(payload.user_id ?? "");
    const count = Math.max(1, Math.min(10, Number(payload.count ?? 3) | 0));
    const daysBack = Math.max(1, Math.min(30, Number(payload.days_back ?? 7) | 0));
    if (!userId) return json(400, { error: "missing_user_id" });

    const { data: profile, error: profErr } = await admin
        .from("profiles")
        .select("id, is_test_user")
        .eq("id", userId)
        .maybeSingle();
    if (profErr) return json(500, { error: profErr.message });
    if (!profile || profile.is_test_user !== true) {
        return json(403, { error: "not_a_fake_user" });
    }

    const now = Date.now();
    const rows: Record<string, unknown>[] = [];
    const used = new Set<number>();
    for (let i = 0; i < count; i += 1) {
        let idx = Math.floor(Math.random() * FAKE_POST_BANK.length);
        let guard = 0;
        while (used.has(idx) && guard < 8) {
            idx = (idx + 1) % FAKE_POST_BANK.length;
            guard += 1;
        }
        used.add(idx);
        const daysAgo = Math.random() * daysBack;
        const created = new Date(now - daysAgo * 24 * 3600 * 1000).toISOString();
        rows.push({
            user_id: userId,
            text_content: FAKE_POST_BANK[idx],
            media_urls: [],
            tags: [],
            created_at: created,
            updated_at: created,
        });
    }
    const { error: insErr } = await admin.from("feed_posts").insert(rows);
    if (insErr) return json(500, { error: insErr.message });
    return json(200, { ok: true, version: "seed-v2", inserted: rows.length });
}

// ---- Handler: deleteFakeUser -----------------------------------------

async function deleteFakeUser(
    admin: SupabaseClient,
    payload: Record<string, unknown>,
): Promise<Response> {
    const userId = String(payload.user_id ?? "");
    if (!userId) return json(400, { error: "missing_user_id" });
    const { data: profile, error: profErr } = await admin
        .from("profiles")
        .select("id, is_test_user")
        .eq("id", userId)
        .maybeSingle();
    if (profErr) return json(500, { error: profErr.message });
    if (!profile || profile.is_test_user !== true) {
        return json(403, { error: "not_a_fake_user" });
    }
    try {
        await admin.rpc("delete_user_data", { target_user_id: userId });
    } catch (_) {
        // best-effort
    }
    const { error: authErr } = await admin.auth.admin.deleteUser(userId);
    if (authErr) return json(500, { error: authErr.message });
    return json(200, { ok: true, version: "seed-v2", deleted_user_id: userId });
}

// ---- Handler: deleteAccount (GDPR / App Store requirement) -----------

async function deleteAccount(
    admin: SupabaseClient,
    userId: string,
): Promise<Response> {
    // 1) Wipe every public.<table> row keyed to the user via the SECURITY
    //    DEFINER helper. Catches every table that has a `user_id` column,
    //    so we don't have to maintain a hand-curated list as the schema grows.
    try {
        const { error: rpcErr } = await admin.rpc("delete_user_data", { target_user_id: userId });
        if (rpcErr) {
            console.error("delete_user_data rpc failed", rpcErr);
            return json(500, { error: rpcErr.message });
        }
    } catch (e) {
        console.error("delete_user_data threw", e);
        return json(500, { error: String(e) });
    }

    // 2) Storage objects in per-user folders.
    const buckets = ["avatars", "banners", "body-progress", "meal-photos", "dm-media", "protocol-note-photos"];
    for (const bucket of buckets) {
        try {
            const { data: files } = await admin.storage.from(bucket).list(userId, { limit: 1000 });
            if (!files || files.length === 0) continue;
            const paths = files.map((f) => `${userId}/${f.name}`);
            const { error: rmErr } = await admin.storage.from(bucket).remove(paths);
            if (rmErr) console.error(`storage remove ${bucket} failed`, rmErr);
        } catch (e) {
            console.error(`storage cleanup ${bucket} threw`, e);
        }
    }

    // 3) Delete the auth.users row last so the client gets signed out.
    const { error: authErr } = await admin.auth.admin.deleteUser(userId);
    if (authErr) {
        console.error("auth deleteUser failed", authErr);
        return json(500, { error: authErr.message });
    }

    return json(200, { ok: true, deleted_user_id: userId });
}

// ---- Handler: logClientError -----------------------------------------

async function logClientError(
    admin: SupabaseClient,
    userId: string,
    payload: Record<string, unknown>,
): Promise<Response> {
    const message = String(payload.message ?? "").slice(0, 4000);
    if (!message) return json(400, { error: "missing_message" });
    const row = {
        user_id: userId,
        platform: String(payload.platform ?? "ios"),
        app_version: payload.app_version == null ? null : String(payload.app_version),
        os_version: payload.os_version == null ? null : String(payload.os_version),
        device_model: payload.device_model == null ? null : String(payload.device_model),
        screen: payload.screen == null ? null : String(payload.screen),
        severity: String(payload.severity ?? "error"),
        message,
        stack: payload.stack == null ? null : String(payload.stack).slice(0, 8000),
        context: (payload.context && typeof payload.context === "object") ? payload.context : {},
    };
    const { error } = await admin.from("client_errors").insert(row);
    if (error) return json(500, { error: error.message });
    return json(200, { ok: true });
}

// ---- Handler: deepPopulateFakePersona --------------------------------
//
// Make a fake persona feel like a real, lived-in account. Seeds 90 days
// of weight logs, a training program + workout history, archetype-tuned
// meals + macros, daily tasks + activity, and — only for archetypes
// that would actually use them — protocols, compounds, vials, dose
// logs, bloodwork, and side effects. Idempotent: rows are tagged with
// FAKE_SEED_MARK so re-running tops up rather than duplicates.

const FAKE_SEED_MARK = "[fake-persona-seed]";

type ArchetypeFlavor = {
    kind: "strength" | "running" | "cycling" | "yoga" | "hooper" | "climber" | "cali"
        | "crossfit" | "bjj" | "triathlon" | "recomp" | "bb" | "glp" | "beginner"
        | "postpartum" | "rugby" | "optimizer" | "protocol" | "hybrid" | "coach" | "dad" | "sleep";
    usesProtocols: boolean;
    usesBloodwork: boolean;
    weightTrend: "down" | "up" | "flat";
    startWeightLbs: number;
    targetWeightLbs: number;
    workoutNames: string[]; // subset of WORKOUT_BANK names
    programName: string;
    macros: { calories: number; protein: number; carbs: number; fat: number };
    sleepLogs: boolean;
    insertPRs: boolean;
};

function archetypeFlavorFor(persona: Persona): ArchetypeFlavor {
    const a = persona.archetype.toLowerCase();
    const has = (s: string) => a.includes(s);
    // Defaults (general lifter)
    let f: ArchetypeFlavor = {
        kind: "strength",
        usesProtocols: false,
        usesBloodwork: false,
        weightTrend: "flat",
        startWeightLbs: 180,
        targetWeightLbs: 180,
        workoutNames: ["Squat Day", "Bench Day", "Deadlift Day", "Pull Day", "Push Day"],
        programName: "5/3/1 BBB",
        macros: { calories: 2800, protein: 200, carbs: 320, fat: 80 },
        sleepLogs: false,
        insertPRs: true,
    };
    if (has("marathoner") || has("5k")) {
        f = { ...f, kind: "running", workoutNames: ["Easy Run", "Long Run", "Track Intervals", "Tempo Run"],
            programName: "Marathon Build Block", insertPRs: false,
            startWeightLbs: 155, targetWeightLbs: 152, weightTrend: "flat",
            macros: { calories: 2600, protein: 130, carbs: 360, fat: 75 } };
    } else if (has("yoga") || has("mobility") || has("breathwork")) {
        f = { ...f, kind: "yoga", workoutNames: ["Easy Run"], programName: "Daily Mobility + Flow",
            insertPRs: false, startWeightLbs: 138, targetWeightLbs: 138, weightTrend: "flat",
            macros: { calories: 2100, protein: 110, carbs: 240, fat: 70 }, sleepLogs: true };
    } else if (has("hooper") || has("basketball")) {
        f = { ...f, kind: "hooper", workoutNames: ["Push Day", "Pull Day", "Easy Run"],
            programName: "Hooper Strength + Plyo", startWeightLbs: 178, targetWeightLbs: 178,
            macros: { calories: 2900, protein: 180, carbs: 360, fat: 85 } };
    } else if (has("cyclist")) {
        f = { ...f, kind: "cycling", workoutNames: ["Z2 Bike", "Easy Run"], programName: "Build to FTP",
            insertPRs: false, startWeightLbs: 150, targetWeightLbs: 148,
            macros: { calories: 2700, protein: 130, carbs: 380, fat: 70 } };
    } else if (has("calisthenics") || has("climber")) {
        f = { ...f, kind: a.includes("climber") ? "climber" : "cali",
            workoutNames: ["Pull Day", "Push Day"], programName: "Skill + Strength",
            startWeightLbs: 152, targetWeightLbs: 150,
            macros: { calories: 2400, protein: 160, carbs: 280, fat: 70 } };
    } else if (has("peptide") || has("health optimizer") || has("optimizer")) {
        f = { ...f, kind: a.includes("optimizer") ? "optimizer" : "protocol",
            usesProtocols: true, usesBloodwork: true, sleepLogs: true,
            workoutNames: ["Squat Day", "Bench Day", "Easy Run"], programName: "Recovery + Recomp Stack",
            startWeightLbs: 178, targetWeightLbs: 172, weightTrend: "down",
            macros: { calories: 2500, protein: 200, carbs: 240, fat: 80 } };
    } else if (has("hybrid") || has("trail")) {
        f = { ...f, kind: "hybrid", workoutNames: ["Squat Day", "Long Run", "Pull Day", "Easy Run"],
            programName: "Hybrid 4-Day", startWeightLbs: 172, targetWeightLbs: 170,
            macros: { calories: 2900, protein: 180, carbs: 340, fat: 80 } };
    } else if (has("powerlifter") || has("5/3/1") || has("strength (patient)")) {
        f = { ...f, kind: "strength", programName: "5/3/1 BBB",
            startWeightLbs: 195, targetWeightLbs: 195,
            macros: { calories: 3200, protein: 200, carbs: 380, fat: 90 } };
    } else if (has("crossfit")) {
        f = { ...f, kind: "crossfit", workoutNames: ["Squat Day", "Push Day", "Pull Day", "Easy Run"],
            programName: "Open Prep Cycle", startWeightLbs: 170, targetWeightLbs: 170,
            macros: { calories: 2900, protein: 190, carbs: 340, fat: 85 } };
    } else if (has("coach")) {
        f = { ...f, kind: "coach", programName: "Coach Template Block",
            startWeightLbs: 168, targetWeightLbs: 168,
            macros: { calories: 2700, protein: 180, carbs: 300, fat: 80 } };
    } else if (has("triathlete") || has("triathlon")) {
        f = { ...f, kind: "triathlon", workoutNames: ["Easy Run", "Z2 Bike", "Track Intervals"],
            programName: "Sprint Tri Build", insertPRs: false,
            startWeightLbs: 162, targetWeightLbs: 160,
            macros: { calories: 2700, protein: 150, carbs: 360, fat: 75 } };
    } else if (has("recomp") || has("nutrition")) {
        f = { ...f, kind: "recomp", workoutNames: ["Push Day", "Pull Day", "Squat Day"],
            programName: "PPL Recomp", startWeightLbs: 168, targetWeightLbs: 162, weightTrend: "down",
            macros: { calories: 2200, protein: 180, carbs: 220, fat: 70 } };
    } else if (has("bodybuilder") || has("ppl") || has("bikini") || has("prep")) {
        const cutting = has("bikini") || has("prep");
        f = { ...f, kind: "bb", workoutNames: ["Push Day", "Pull Day", "Squat Day", "Bench Day"],
            programName: cutting ? "Bikini Prep PPL" : "PPL 6-Day",
            startWeightLbs: cutting ? 138 : 188, targetWeightLbs: cutting ? 128 : 192,
            weightTrend: cutting ? "down" : "up",
            macros: cutting
                ? { calories: 1700, protein: 145, carbs: 160, fat: 50 }
                : { calories: 3400, protein: 220, carbs: 420, fat: 95 } };
    } else if (has("5k") || has("half")) {
        f = { ...f, kind: "running", workoutNames: ["Easy Run", "Long Run", "Tempo Run"],
            programName: "First Half Block", insertPRs: false,
            startWeightLbs: 142, targetWeightLbs: 140,
            macros: { calories: 2200, protein: 110, carbs: 320, fat: 65 } };
    } else if (has("beginner")) {
        f = { ...f, kind: "beginner", workoutNames: ["Push Day", "Pull Day"],
            programName: "Beginner Full Body", startWeightLbs: 174, targetWeightLbs: 172,
            macros: { calories: 2500, protein: 150, carbs: 280, fat: 75 } };
    } else if (has("postpartum")) {
        f = { ...f, kind: "postpartum", workoutNames: ["Push Day"], programName: "Postpartum Rebuild",
            startWeightLbs: 152, targetWeightLbs: 145, weightTrend: "down",
            macros: { calories: 2200, protein: 140, carbs: 240, fat: 75 } };
    } else if (has("rugby")) {
        f = { ...f, kind: "rugby", workoutNames: ["Squat Day", "Deadlift Day", "Push Day", "Easy Run"],
            programName: "Rugby Offseason", startWeightLbs: 210, targetWeightLbs: 208,
            macros: { calories: 3400, protein: 220, carbs: 380, fat: 95 } };
    } else if (has("glp")) {
        f = { ...f, kind: "glp", usesProtocols: true, usesBloodwork: true,
            workoutNames: ["Push Day", "Pull Day", "Easy Run"], programName: "GLP-1 Recomp",
            startWeightLbs: 220, targetWeightLbs: 192, weightTrend: "down",
            macros: { calories: 1900, protein: 180, carbs: 180, fat: 60 } };
    } else if (has("home gym") || has("dad")) {
        f = { ...f, kind: "dad", programName: "Garage 5-Day",
            startWeightLbs: 200, targetWeightLbs: 195,
            macros: { calories: 2900, protein: 180, carbs: 320, fat: 90 } };
    } else if (has("recovery") || has("sleep")) {
        f = { ...f, kind: "sleep", sleepLogs: true,
            workoutNames: ["Push Day", "Easy Run"], programName: "Sleep-First Lifter",
            startWeightLbs: 170, targetWeightLbs: 170,
            macros: { calories: 2600, protein: 170, carbs: 300, fat: 80 } };
    } else if (has("bjj") || has("grappler")) {
        f = { ...f, kind: "bjj", workoutNames: ["Pull Day", "Push Day", "Easy Run"],
            programName: "BJJ S&C Block", startWeightLbs: 175, targetWeightLbs: 173,
            macros: { calories: 2700, protein: 180, carbs: 300, fat: 80 } };
    }
    // Strength personas that use creatine / ipamorelin / etc. — Finn included
    if (persona.username === "finnpowerlifts" || persona.username === "liamlifts531") {
        f.usesProtocols = true;
    }
    return f;
}

async function deepPopulateFakePersona(
    admin: SupabaseClient,
    userId: string,
    persona: Persona,
): Promise<{ inserted: Record<string, number>; errors: string[] }> {
    const flavor = archetypeFlavorFor(persona);
    const inserted: Record<string, number> = {
        weights: 0, workouts: 0, program: 0, prs: 0, meals: 0,
        protocols: 0, compounds: 0, vials: 0, dose_logs: 0,
        bloodwork: 0, biomarkers: 0, activity: 0, daily_tasks: 0,
        sleep_logs: 0, side_effects: 0,
        water_logs: 0, step_logs: 0,
    };
    const skipped_tables: string[] = [];
    const errors: string[] = [];
    const now = Date.now();
    const DAY = 24 * 3600 * 1000;

    // ---- Weight logs: 180 daily points w/ archetype trend + noise ------
    try {
        const { count: existing } = await admin
            .from("weight_logs").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("note", `%${FAKE_SEED_MARK}%`);
        if ((existing ?? 0) < 150) {
            // archetype weekly trend in lbs/week
            const weeklyDelta =
                flavor.weightTrend === "down" ? -0.9 :
                flavor.weightTrend === "up"   ?  0.55 : 0.0;
            const start = flavor.startWeightLbs;
            const points = 180;
            const rows: Record<string, unknown>[] = [];
            for (let i = 0; i < points; i += 1) {
                const daysAgo = points - 1 - i; // i=0 oldest, i=last today
                const weeksFromStart = i / 7;
                const noise = Math.sin(i * 0.73 + persona.avatarSeed) * 0.8
                            + ((i * 13) % 7 - 3) * 0.12;
                const w = start + weeklyDelta * weeksFromStart + noise;
                rows.push({
                    user_id: userId,
                    weight: Math.round(w * 10) / 10,
                    unit: "lbs",
                    note: i === 0 ? `start ${FAKE_SEED_MARK}`
                        : i === points - 1 ? `today ${FAKE_SEED_MARK}`
                        : FAKE_SEED_MARK,
                    logged_at: new Date(now - daysAgo * DAY).toISOString(),
                });
            }
            for (let i = 0; i < rows.length; i += 500) {
                const { error } = await admin.from("weight_logs").insert(rows.slice(i, i + 500));
                if (error) errors.push(`weights ${persona.username}: ${error.message}`);
                else inserted.weights += Math.min(500, rows.length - i);
            }
        }
    } catch (e) { errors.push(`weights: ${String(e)}`); }

    // ---- Profile weight + target -----------------------------------------
    try {
        await admin.from("profiles").update({
            weight_kg: Math.round(flavor.startWeightLbs / 2.20462 * 10) / 10,
            target_weight_kg: Math.round(flavor.targetWeightLbs / 2.20462 * 10) / 10,
        }).eq("id", userId);
    } catch (_) {}

    // ---- Training program -------------------------------------------------
    try {
        const { count: existingProgs } = await admin
            .from("training_programs").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("name", `%${FAKE_SEED_MARK}%`);
        if ((existingProgs ?? 0) === 0) {
            const days = flavor.workoutNames.map((n) => ({ name: n, exercises: [] as string[] }));
            const { error } = await admin.from("training_programs").insert({
                user_id: userId,
                name: `${flavor.programName} ${FAKE_SEED_MARK}`,
                program_type: "custom",
                days_per_week: Math.max(3, Math.min(6, flavor.workoutNames.length)),
                days_json: JSON.stringify(days),
                is_active: true,
                current_week: 3 + (persona.avatarSeed % 6),
                start_day_offset: 0,
            });
            if (!error) inserted.program = 1;
        }
    } catch (e) { errors.push(`program: ${String(e)}`); }

    // ---- Workouts: 90–120 sessions over 180 days, archetype-filtered ----
    try {
        const { count: existingW } = await admin
            .from("workouts").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("notes", `%${FAKE_SEED_MARK}%`);
        if ((existingW ?? 0) < 80) {
            const archBank = WORKOUT_BANK.filter((w) => flavor.workoutNames.includes(w.name));
            const bank = archBank.length > 0 ? archBank : WORKOUT_BANK;
            const target = flavor.kind === "beginner" || flavor.kind === "postpartum" ? 60 : 110;
            const rows: Record<string, unknown>[] = [];
            for (let i = 0; i < target; i += 1) {
                const w = bank[i % bank.length];
                // spread across 180 days, ~5-6/week with occasional gaps
                const daysAgo = Math.floor((i * 180) / target) + ((i * 7 + persona.avatarSeed) % 3);
                const completedAt = new Date(now - daysAgo * DAY - (i % 4) * 3600 * 1000);
                const startedAt = new Date(completedAt.getTime() - w.mins * 60 * 1000);
                const notesObj: Record<string, unknown> = { mark: FAKE_SEED_MARK };
                if (w.volume) notesObj.totalVolume = w.volume;
                rows.push({
                    user_id: userId,
                    date: completedAt.toISOString().slice(0, 10),
                    name: w.name,
                    sport: w.sport ?? null,
                    workout_type: w.type,
                    duration_minutes: w.mins,
                    calories_burned: w.cals,
                    distance: w.distance ?? null,
                    exercises: w.exercises ? JSON.stringify(w.exercises) : null,
                    notes: JSON.stringify(notesObj),
                    fp_earned: w.mins * 5 + Math.floor(w.cals / 10),
                    started_at: startedAt.toISOString(),
                    completed_at: completedAt.toISOString(),
                });
            }
            for (let i = 0; i < rows.length; i += 500) {
                const { error } = await admin.from("workouts").insert(rows.slice(i, i + 500));
                if (error) errors.push(`workouts ${persona.username}: ${error.message}`);
                else inserted.workouts += Math.min(500, rows.length - i);
            }
        }
    } catch (e) { errors.push(`workouts: ${String(e)}`); }

    // ---- Personal records (strength-relevant archetypes only) ------------
    try {
        if (flavor.insertPRs) {
            const subset = flavor.kind === "beginner" || flavor.kind === "postpartum"
                ? MY_PRS.slice(0, 3).map((p) => ({ ...p, best_weight: Math.round(p.best_weight * 0.55), best_one_rm: Math.round(p.best_one_rm * 0.55), best_volume: Math.round(p.best_volume * 0.55) }))
                : flavor.kind === "bb"
                    ? MY_PRS.map((p) => ({ ...p, best_weight: Math.round(p.best_weight * 0.85), best_one_rm: Math.round(p.best_one_rm * 0.85), best_volume: Math.round(p.best_volume * 0.85) }))
                    : MY_PRS;
            const prRows = subset.map((p) => ({ user_id: userId, ...p, updated_at: new Date(now - 3 * DAY).toISOString() }));
            const { error } = await admin.from("personal_records")
                .upsert(prRows, { onConflict: "user_id,exercise_id" });
            if (!error) inserted.prs = prRows.length;
        }
    } catch (e) { errors.push(`prs: ${String(e)}`); }

    // ---- Meals: 150 days × 3–5 meals/day → ~600 rows --------------------
    try {
        const { count: existingMeals } = await admin
            .from("logged_meals").select("id", { count: "exact", head: true })
            .eq("user_id", userId);
        if ((existingMeals ?? 0) < 500) {
            const rows: Record<string, unknown>[] = [];
            for (let d = 0; d < 150; d += 1) {
                if ((d * 7) % 19 < 2) continue; // ~11% missed days
                const dayBase = now - d * DAY;
                const breakfasts = MEAL_BANK.filter((m) => m.time === "breakfast");
                const lunches = MEAL_BANK.filter((m) => m.time === "lunch");
                const dinners = MEAL_BANK.filter((m) => m.time === "dinner");
                const snacks = MEAL_BANK.filter((m) => m.time === "snack");
                const meals = [
                    { m: breakfasts[(d + persona.avatarSeed) % breakfasts.length], hours: 8 },
                    { m: lunches[(d + persona.avatarSeed) % lunches.length], hours: 13 },
                    { m: dinners[(d + persona.avatarSeed) % dinners.length], hours: 19 },
                ];
                if (d % 3 === 0) meals.push({ m: snacks[(d + persona.avatarSeed) % snacks.length], hours: 16 });
                if (d % 5 === 0) meals.push({ m: snacks[(d + persona.avatarSeed + 3) % snacks.length], hours: 21 });
                for (const { m, hours } of meals) {
                    const ts = new Date(dayBase);
                    ts.setUTCHours(hours, 0, 0, 0);
                    rows.push({
                        user_id: userId,
                        food_name: m.name,
                        food_brand: m.brand ?? null,
                        calories: m.cal,
                        protein_g: m.p,
                        carbs_g: m.c,
                        fat_g: m.f,
                        servings: 1,
                        meal_time: m.time,
                        logged_at: ts.toISOString(),
                    });
                }
            }
            for (let i = 0; i < rows.length; i += 500) {
                const { error } = await admin.from("logged_meals").insert(rows.slice(i, i + 500));
                if (error) errors.push(`meals ${persona.username}: ${error.message}`);
                else inserted.meals += Math.min(500, rows.length - i);
            }
        }
        await admin.from("macro_targets").upsert({
            user_id: userId,
            calories: flavor.macros.calories,
            protein_g: flavor.macros.protein,
            carbs_g: flavor.macros.carbs,
            fat_g: flavor.macros.fat,
            source: "adaptive",
        }, { onConflict: "user_id" });
    } catch (e) { errors.push(`meals: ${String(e)}`); }

    // ---- Protocols / compounds / vials / doses ---------------------------
    let protocolIdForFixtures: string | null = null;
    if (flavor.usesProtocols) {
        try {
            const { data: existingProto } = await admin
                .from("protocols").select("id").eq("user_id", userId).ilike("name", `%${FAKE_SEED_MARK}%`).limit(1);
            let protocolId: string | null = ((existingProto ?? []) as Array<{ id: string }>)[0]?.id ?? null;
            if (!protocolId) {
                const startDate = new Date(now - 56 * DAY).toISOString().slice(0, 10);
                const protoName =
                    flavor.kind === "glp"      ? `Tirzepatide Recomp ${FAKE_SEED_MARK}` :
                    flavor.kind === "optimizer" ? `Optimizer Stack ${FAKE_SEED_MARK}` :
                    flavor.kind === "protocol"  ? `Recovery + Recomp Stack ${FAKE_SEED_MARK}` :
                                                  `Performance Stack ${FAKE_SEED_MARK}`;
                const { data: created, error } = await admin.from("protocols").insert({
                    user_id: userId, name: protoName, goal: flavor.weightTrend === "down" ? "Fat Loss" : "Performance",
                    start_date: startDate, total_weeks: 12, loading_weeks: 2, maintenance_weeks: 8,
                    tapering_weeks: 1, off_cycle_weeks: 1, is_active: true,
                }).select("id").single();
                if (!error && created) {
                    protocolId = (created as { id: string }).id;
                    inserted.protocols = 1;
                }
            }
            if (protocolId) {
                protocolIdForFixtures = protocolId;
                const compounds = flavor.kind === "glp"
                    ? [{ compound_name: "Tirzepatide", dose_mcg: 7500, frequency: "Weekly", injection_route: "Subcutaneous", vial_size_mg: 10 }]
                    : flavor.kind === "optimizer"
                    ? [
                        { compound_name: "BPC-157", dose_mcg: 250, frequency: "Daily", injection_route: "Subcutaneous", vial_size_mg: 5 },
                        { compound_name: "TB-500", dose_mcg: 500, frequency: "Twice weekly", injection_route: "Subcutaneous", vial_size_mg: 5 },
                      ]
                    : flavor.kind === "protocol"
                    ? [
                        { compound_name: "Retatrutide", dose_mcg: 2000, frequency: "Weekly", injection_route: "Subcutaneous", vial_size_mg: 10 },
                        { compound_name: "BPC-157", dose_mcg: 250, frequency: "Daily", injection_route: "Subcutaneous", vial_size_mg: 5 },
                      ]
                    : [
                        { compound_name: "Ipamorelin", dose_mcg: 300, frequency: "Pre-bed", injection_route: "Subcutaneous", vial_size_mg: 5 },
                      ];
                for (const c of compounds) {
                    const { count } = await admin.from("protocol_compounds")
                        .select("id", { count: "exact", head: true })
                        .eq("protocol_id", protocolId).eq("compound_name", c.compound_name);
                    if ((count ?? 0) === 0) {
                        const { error } = await admin.from("protocol_compounds").insert({
                            protocol_id: protocolId, ...c,
                            reconstitution_volume_ml: 2.0,
                            time_of_day: new Date(now).toISOString(),
                        });
                        if (!error) inserted.compounds += 1;
                    }
                }
                // Vials
                for (let i = 0; i < compounds.length; i += 1) {
                    const c = compounds[i];
                    const clientId = `fake-vial-${i + 1}-${userId.slice(0, 8)}`;
                    const { count } = await admin.from("vials")
                        .select("id", { count: "exact", head: true }).eq("user_id", userId).eq("client_id", clientId);
                    if ((count ?? 0) === 0) {
                        const { error } = await admin.from("vials").insert({
                            user_id: userId, client_id: clientId,
                            compound_name: c.compound_name, vial_size_mg: c.vial_size_mg,
                            diluent_ml: 2.0,
                            reconstituted_on: new Date(now - (21 - i * 5) * DAY).toISOString(),
                            storage: "Fridge", lot_number: `LOT-${2000 + i * 19}`,
                            vial_number: `${i + 1}`,
                            expiration_date: new Date(now + (60 - i * 10) * DAY).toISOString(),
                            typical_dose_mcg: c.dose_mcg,
                            mcg_used: c.dose_mcg * (6 - i),
                            bud_days: 30,
                        });
                        if (!error) inserted.vials += 1;
                    }
                }
                // Additional historical vials (3-6 prior)
                try {
                    for (let i = 0; i < compounds.length; i += 1) {
                        const c = compounds[i];
                        for (let h = 1; h <= 3; h += 1) {
                            const clientId = `fake-vial-hist-${i + 1}-${h}-${userId.slice(0, 8)}`;
                            const { count } = await admin.from("vials")
                                .select("id", { count: "exact", head: true })
                                .eq("user_id", userId).eq("client_id", clientId);
                            if ((count ?? 0) === 0) {
                                const { error } = await admin.from("vials").insert({
                                    user_id: userId, client_id: clientId,
                                    compound_name: c.compound_name, vial_size_mg: c.vial_size_mg,
                                    diluent_ml: 2.0,
                                    reconstituted_on: new Date(now - (28 * (h + 1)) * DAY).toISOString(),
                                    storage: "Fridge", lot_number: `LOT-${1000 + i * 19 + h * 7}`,
                                    vial_number: `${i + 1}.${h}`,
                                    expiration_date: new Date(now - (28 * h) * DAY).toISOString(),
                                    typical_dose_mcg: c.dose_mcg,
                                    mcg_used: c.vial_size_mg * 1000,
                                    bud_days: 30,
                                });
                                if (!error) inserted.vials += 1;
                            }
                        }
                    }
                } catch (_) {}
                // Dose logs — 120 days of history per compound
                const { count: existingDoses } = await admin
                    .from("dose_logs").select("id", { count: "exact", head: true }).eq("protocol_id", protocolId);
                if ((existingDoses ?? 0) < 80) {
                    const sites = [
                        "Left Abdomen", "Right Abdomen", "Left Thigh", "Right Thigh",
                        "Left Glute", "Right Glute", "Left Deltoid", "Right Deltoid",
                    ];
                    const rows: Record<string, unknown>[] = [];
                    for (const c of compounds) {
                        const isDaily = c.frequency === "Daily";
                        const isWeekly = c.frequency === "Weekly" || c.frequency === "Pre-bed";
                        if (isDaily) {
                            for (let d = 0; d < 120; d += 1) {
                                const skip = (d * 7 + persona.avatarSeed) % 20 === 0;
                                rows.push({
                                    user_id: userId, protocol_id: protocolId,
                                    compound_name: c.compound_name, dose_mcg: c.dose_mcg,
                                    injection_site: sites[d % sites.length],
                                    was_skipped: skip,
                                    skip_reason: skip ? "travel" : null,
                                    notes: d % 17 === 3 ? "site bruise, rotated" : null,
                                    logged_at: new Date(now - (120 - d) * DAY).toISOString(),
                                });
                            }
                        } else if (isWeekly) {
                            for (let w = 0; w < 17; w += 1) {
                                rows.push({
                                    user_id: userId, protocol_id: protocolId,
                                    compound_name: c.compound_name, dose_mcg: c.dose_mcg,
                                    injection_site: sites[w % sites.length],
                                    was_skipped: false,
                                    notes: w % 6 === 2 ? "slight fatigue day 2" : null,
                                    logged_at: new Date(now - (7 * (17 - w)) * DAY).toISOString(),
                                });
                            }
                        } else {
                            // twice weekly for 17 weeks
                            for (let w = 0; w < 17; w += 1) {
                                for (const off of [0, 3]) {
                                    rows.push({
                                        user_id: userId, protocol_id: protocolId,
                                        compound_name: c.compound_name, dose_mcg: c.dose_mcg,
                                        injection_site: sites[(w * 2 + off) % sites.length],
                                        was_skipped: false, notes: null,
                                        logged_at: new Date(now - (7 * (17 - w) + off) * DAY).toISOString(),
                                    });
                                }
                            }
                        }
                    }
                    for (let i = 0; i < rows.length; i += 500) {
                        const { error } = await admin.from("dose_logs").insert(rows.slice(i, i + 500));
                        if (error) errors.push(`doses ${persona.username}: ${error.message}`);
                        else inserted.dose_logs += Math.min(500, rows.length - i);
                    }
                }
            }
        } catch (e) { errors.push(`protocol: ${String(e)}`); }
    }

    // ---- Bloodwork: 3-4 panels × 18-25 biomarkers each ------------------
    if (flavor.usesBloodwork) {
        try {
            const { count: existingBio } = await admin
                .from("bloodwork_entries").select("id", { count: "exact", head: true })
                .eq("user_id", userId).ilike("notes", `%${FAKE_SEED_MARK}%`);
            if ((existingBio ?? 0) < 3) {
                // Marcus's trending-worse case: ALT 38→52→68, LDL 118→138→162
                const isMarcus = persona.username === "marcusruns";
                const altByPanel = isMarcus ? [38, 52, 68, 72] : [28, 26, 24, 23];
                const ldlByPanel = isMarcus ? [118, 138, 162, 168] : [128, 118, 108, 100];
                const labelByPanel = ["Baseline", "Q2 follow-up", "Q3 follow-up", "Most recent"];
                const daysAgoByPanel = [168, 112, 56, 10];
                const buildMarkers = (idx: number) => [
                    { biomarker: "Total Cholesterol", value: 200 - idx * 8 },
                    { biomarker: "LDL", value: ldlByPanel[idx] },
                    { biomarker: "HDL", value: 44 + idx * 3 },
                    { biomarker: "Triglycerides", value: 150 - idx * 9 },
                    { biomarker: "Fasting Glucose", value: 96 - idx },
                    { biomarker: "HbA1c", value: 5.5 - idx * 0.05 },
                    { biomarker: "ALT", value: altByPanel[idx] },
                    { biomarker: "AST", value: 22 + idx * 2 },
                    { biomarker: "eGFR", value: 92 + idx },
                    { biomarker: "BUN", value: 16 + (idx % 2) },
                    { biomarker: "Creatinine", value: 0.95 + idx * 0.02 },
                    { biomarker: "TSH", value: 2.1 - idx * 0.1 },
                    { biomarker: "Vitamin D", value: 32 + idx * 3 },
                    { biomarker: "Ferritin", value: 92 + idx * 4 },
                    { biomarker: "CK", value: 180 - idx * 6 },
                    { biomarker: "hsCRP", value: 1.4 - idx * 0.1 },
                    { biomarker: "WBC", value: 6.2 + idx * 0.1 },
                    { biomarker: "RBC", value: 4.9 },
                    { biomarker: "Hemoglobin", value: 14.6 + idx * 0.1 },
                    { biomarker: "Hematocrit", value: 43 + (idx % 2) },
                    { biomarker: "Platelets", value: 240 + idx * 3 },
                    { biomarker: "Testosterone", value: 580 + idx * 18 },
                    { biomarker: "Sodium", value: 140 },
                    { biomarker: "Potassium", value: 4.3 },
                    { biomarker: "Calcium", value: 9.6 },
                ];
                const panels = daysAgoByPanel.map((daysAgo, i) => ({
                    daysAgo,
                    notes: `${labelByPanel[i]} ${FAKE_SEED_MARK}`,
                    results: buildMarkers(i),
                }));
                for (const panel of panels) {
                    const entryDate = new Date(now - panel.daysAgo * DAY).toISOString().slice(0, 10);
                    const { data: entry, error } = await admin.from("bloodwork_entries")
                        .insert({ user_id: userId, entry_date: entryDate, notes: panel.notes })
                        .select("id").single();
                    if (error || !entry) { errors.push(`bloodwork: ${error?.message}`); continue; }
                    inserted.bloodwork += 1;
                    const entryId = (entry as { id: string }).id;
                    const { error: bErr } = await admin.from("biomarker_results")
                        .insert(panel.results.map((r) => ({ entry_id: entryId, ...r })));
                    if (!bErr) inserted.biomarkers += panel.results.length;
                }
            }
        } catch (e) { errors.push(`bloodwork: ${String(e)}`); }
    }

    // ---- Water logs: 180 days ------------------------------------------
    try {
        const baseWaterMl = flavor.kind === "running" || flavor.kind === "triathlon" || flavor.kind === "cycling"
            ? 3200 : flavor.kind === "glp" ? 2800 : 2400;
        const { count: existingWater } = await admin
            .from("water_logs").select("id", { count: "exact", head: true }).eq("user_id", userId);
        if ((existingWater ?? 0) < 120) {
            const rows: Record<string, unknown>[] = [];
            for (let d = 0; d < 180; d += 1) {
                if ((d * 11 + persona.avatarSeed) % 23 < 2) continue;
                const variance = ((d * 31 + persona.avatarSeed) % 600) - 300;
                const ml = Math.max(800, baseWaterMl + variance);
                const at = new Date(now - d * DAY);
                at.setUTCHours(20, 0, 0, 0);
                rows.push({
                    user_id: userId,
                    amount_ml: ml,
                    logged_at: at.toISOString(),
                });
            }
            for (let i = 0; i < rows.length; i += 500) {
                const { error } = await admin.from("water_logs").insert(rows.slice(i, i + 500));
                if (error) {
                    skipped_tables.push("water_logs");
                    break;
                } else inserted.water_logs += Math.min(500, rows.length - i);
            }
        }
    } catch (e) {
        skipped_tables.push("water_logs");
        errors.push(`water: ${String(e)}`);
    }

    // ---- Step logs: 180 days, archetype-tuned averages ------------------
    try {
        const baseSteps =
            flavor.kind === "running" || flavor.kind === "triathlon" ? 14000 :
            flavor.kind === "hooper" || flavor.kind === "hybrid" || flavor.kind === "crossfit" ? 11000 :
            flavor.kind === "glp" ? 9500 :
            flavor.kind === "sleep" || flavor.kind === "yoga" ? 7500 :
            flavor.kind === "postpartum" || flavor.kind === "dad" ? 6500 :
            8000;
        const { count: existingSteps } = await admin
            .from("step_logs").select("id", { count: "exact", head: true }).eq("user_id", userId);
        if ((existingSteps ?? 0) < 120) {
            const rows: Record<string, unknown>[] = [];
            for (let d = 0; d < 180; d += 1) {
                if ((d * 5 + persona.avatarSeed) % 29 < 1) continue;
                const variance = ((d * 41 + persona.avatarSeed * 7) % 4000) - 2000;
                const trendBoost = flavor.kind === "glp" ? Math.floor((180 - d) * 8) : 0;
                const steps = Math.max(1500, baseSteps + variance + trendBoost);
                const at = new Date(now - d * DAY);
                at.setUTCHours(22, 0, 0, 0);
                rows.push({
                    user_id: userId,
                    step_count: steps,
                    logged_at: at.toISOString(),
                });
            }
            for (let i = 0; i < rows.length; i += 500) {
                const { error } = await admin.from("step_logs").insert(rows.slice(i, i + 500));
                if (error) {
                    skipped_tables.push("step_logs");
                    break;
                } else inserted.step_logs += Math.min(500, rows.length - i);
            }
        }
    } catch (e) {
        skipped_tables.push("step_logs");
        errors.push(`steps: ${String(e)}`);
    }

    // ---- Activity logs (heatmap) -----------------------------------------
    try {
        const { count: existingActivity } = await admin
            .from("activity_logs").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("notes", `%${FAKE_SEED_MARK}%`);
        if ((existingActivity ?? 0) < 20) {
            const rows: Record<string, unknown>[] = [];
            for (let d = 0; d < 60; d += 1) {
                if ((d * 5 + persona.avatarSeed) % 13 < 2) continue;
                const date = new Date(now - d * DAY);
                rows.push({
                    user_id: userId,
                    activity_date: date.toISOString().slice(0, 10),
                    activity_type: d % 3 === 0 ? "workout" : d % 3 === 1 ? "cardio" : "steps",
                    sport: d % 3 === 1 ? (flavor.kind === "cycling" ? "Cycling" : "Running") : null,
                    duration_minutes: 20 + (d % 40),
                    calories_burned: 180 + (d % 12) * 35,
                    notes: `auto ${FAKE_SEED_MARK}`,
                });
            }
            for (let i = 0; i < rows.length; i += 200) {
                const { error } = await admin.from("activity_logs").insert(rows.slice(i, i + 200));
                if (error) errors.push(`activity: ${error.message}`);
                else inserted.activity += Math.min(200, rows.length - i);
            }
        }
    } catch (e) { errors.push(`activity: ${String(e)}`); }

    // ---- Daily tasks: last 90 days at ~75% completion -------------------
    try {
        const taskBank = [
            { title: "Hit protein target", icon: "flame.fill", category: "Nutrition" },
            { title: "10k steps", icon: "figure.walk", category: "Movement" },
            { title: "Drink 1 gal water", icon: "drop.fill", category: "Hydration" },
            { title: "8h sleep", icon: "moon.zzz.fill", category: "Recovery" },
            { title: "Workout", icon: "dumbbell.fill", category: "Training" },
        ];
        if (flavor.usesProtocols) taskBank.push({ title: "Log dose", icon: "syringe.fill", category: "Protocol" });
        // Batch all 90 days at once and rely on existing-count gate to skip
        const { count: existingTasks } = await admin.from("daily_tasks")
            .select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("description", `%${FAKE_SEED_MARK}%`);
        if ((existingTasks ?? 0) < 200) {
            const allRows: Record<string, unknown>[] = [];
            for (let d = 0; d < 90; d += 1) {
                const date = new Date(now - d * DAY).toISOString().slice(0, 10);
                for (let i = 0; i < taskBank.length; i += 1) {
                    const t = taskBank[i];
                    // ~75% completion rate, deterministic per day+task
                    const completed = d === 0
                        ? i < 2
                        : ((d * 17 + i * 11 + persona.avatarSeed) % 100) < 75;
                    allRows.push({
                        user_id: userId, title: t.title, description: FAKE_SEED_MARK,
                        category: t.category, action_link: "None",
                        target_value: 0, goal_description: null,
                        is_completed: completed,
                        task_date: date, schedule_type: "Daily",
                        scheduled_days: [1, 2, 3, 4, 5, 6, 7],
                        icon: t.icon, is_user_created: false, custom_category_id: null,
                    });
                }
            }
            for (let i = 0; i < allRows.length; i += 500) {
                const { error } = await admin.from("daily_tasks").insert(allRows.slice(i, i + 500));
                if (error) errors.push(`tasks: ${error.message}`);
                else inserted.daily_tasks += Math.min(500, allRows.length - i);
            }
        }
    } catch (e) { errors.push(`tasks: ${String(e)}`); }

    // ---- Sleep logs: 90 nights, mostly 6.5–8h --------------------------
    if (flavor.sleepLogs) {
        try {
            const rows: Record<string, unknown>[] = [];
            for (let i = 0; i < 90; i += 1) {
                // Center 7.3h with sinusoidal weekly variance + per-persona noise
                const wk = Math.sin((i / 7) * Math.PI * 2) * 0.35;
                const noise = (((i * 17 + persona.avatarSeed * 13) % 11) - 5) * 0.18;
                const rough = ((i * 23 + persona.avatarSeed) % 21 === 0) ? -2.1 : 0;
                const hours = Math.max(4.2, Math.min(9.1, 7.3 + wk + noise + rough));
                const quality = rough < 0 ? 2 : hours > 7.5 ? 4 + ((i + persona.avatarSeed) % 2)
                              : hours > 6.8 ? 4 : 3;
                const night = new Date(now - (i + 1) * DAY);
                const wake = new Date(night);
                wake.setUTCHours(7, 0, 0, 0);
                const bed = new Date(wake.getTime() - hours * 3600 * 1000);
                rows.push({
                    user_id: userId,
                    night: night.toISOString().slice(0, 10),
                    bedtime: bed.toISOString(),
                    wake_time: wake.toISOString(),
                    hours: Math.round(hours * 10) / 10,
                    quality,
                    notes: FAKE_SEED_MARK,
                });
            }
            for (let i = 0; i < rows.length; i += 500) {
                const { error, count } = await admin
                    .from("manual_sleep_logs")
                    .upsert(rows.slice(i, i + 500), { onConflict: "user_id,night", ignoreDuplicates: true, count: "exact" });
                if (!error) inserted.sleep_logs += count ?? Math.min(500, rows.length - i);
            }
        } catch (e) { errors.push(`sleep: ${String(e)}`); }
    }

    // ---- Side effects (protocol personas only): 8-12 over 90 days ------
    if (protocolIdForFixtures && flavor.usesProtocols) {
        try {
            const { count: existingSE } = await admin.from("side_effect_logs")
                .select("id", { count: "exact", head: true })
                .eq("protocol_id", protocolIdForFixtures)
                .ilike("notes", `%${FAKE_SEED_MARK}%`);
            if ((existingSE ?? 0) < 8) {
                const isGLP = persona.username === "sienn aglp" || persona.username === "priyamoves";
                const entries = [
                    { symptom: "Nausea", severity: isGLP ? 3 : 2, hoursAgo: 88 * 24, notes: "week 1 — settled with smaller meals" },
                    { symptom: "Headache", severity: 2, hoursAgo: 76 * 24, notes: "front of head, water helped" },
                    { symptom: "Fatigue", severity: 1, hoursAgo: 64 * 24, notes: "afternoon dip on dose day" },
                    { symptom: "Injection site soreness", severity: 1, hoursAgo: 58 * 24, notes: "left abdomen, gone by morning" },
                    { symptom: "Nausea", severity: 2, hoursAgo: 47 * 24, notes: "mild after dose escalation" },
                    { symptom: "Constipation", severity: 1, hoursAgo: 41 * 24, notes: "added fiber + water" },
                    { symptom: "Headache", severity: 1, hoursAgo: 33 * 24, notes: "resolved with hydration" },
                    { symptom: "Fatigue", severity: 2, hoursAgo: 24 * 24, notes: "big training week, recovered" },
                    { symptom: "Injection site bruise", severity: 1, hoursAgo: 16 * 24, notes: "right thigh, normal" },
                    { symptom: "Reflux", severity: 1, hoursAgo: 11 * 24, notes: "late meal, won't repeat" },
                    { symptom: "Mood — sharper", severity: 1, hoursAgo: 9 * 24, notes: "positive — logging it" },
                    { symptom: "Appetite blunt", severity: 1, hoursAgo: 5 * 24, notes: "easier to hit cut macros" },
                ];
                const rows = entries.map((e) => ({
                    user_id: userId, protocol_id: protocolIdForFixtures,
                    symptom: e.symptom, severity: e.severity,
                    notes: `${e.notes} ${FAKE_SEED_MARK}`,
                    logged_at: new Date(now - e.hoursAgo * 3600 * 1000).toISOString(),
                }));
                const { error } = await admin.from("side_effect_logs").insert(rows);
                if (!error) inserted.side_effects = rows.length;
            }
        } catch (e) { errors.push(`side effects: ${String(e)}`); }
    }

    // ---- Profile streak/FP bump matching the persona --------------------
    try {
        await admin.from("profiles").update({
            current_streak: persona.streak,
            total_fp: persona.totalFp,
        }).eq("id", userId);
    } catch (_) {}

    return { inserted, errors, skipped_tables };
}

// ---- Handler: deepPopulateFakePersona (single user) ----------------
//
// Action payload: { user_id: string, archetype?: string }. Wipes prior
// [fake-persona-seed] rows for the user, then re-seeds an archetype-tuned
// profile: 90-day weight trend, program + 25–45 workouts, PRs, 60 days
// of meals + macro targets, archetype-appropriate protocols/vials/doses,
// optional bloodwork + side effects, sleep logs, daily tasks, activity
// heatmap. Returns per-table counts.

async function wipeFakePersonaSeed(admin: SupabaseClient, userId: string): Promise<void> {
    const M = FAKE_SEED_MARK;
    const safe = async (fn: () => Promise<unknown>) => { try { await fn(); } catch (_) {} };
    await safe(() => admin.from("weight_logs").delete().eq("user_id", userId).ilike("note", `%${M}%`));
    await safe(() => admin.from("workouts").delete().eq("user_id", userId).ilike("notes", `%${M}%`));
    await safe(() => admin.from("activity_logs").delete().eq("user_id", userId).ilike("notes", `%${M}%`));
    await safe(() => admin.from("daily_tasks").delete().eq("user_id", userId).ilike("description", `%${M}%`));
    await safe(() => admin.from("bloodwork_entries").delete().eq("user_id", userId).ilike("notes", `%${M}%`));
    await safe(() => admin.from("manual_sleep_logs").delete().eq("user_id", userId).ilike("notes", `%${M}%`));
    await safe(() => admin.from("side_effect_logs").delete().eq("user_id", userId).ilike("notes", `%${M}%`));
    await safe(() => admin.from("training_programs").delete().eq("user_id", userId).ilike("name", `%${M}%`));
    await safe(() => admin.from("protocols").delete().eq("user_id", userId).ilike("name", `%${M}%`));
    await safe(() => admin.from("vials").delete().eq("user_id", userId).like("client_id", "fake-vial-%"));
    await safe(async () => {
        const prIds = MY_PRS.map((p) => p.exercise_id);
        await admin.from("personal_records").delete().eq("user_id", userId).in("exercise_id", prIds);
    });
    await safe(async () => {
        const names = MEAL_BANK.map((m) => m.name);
        await admin.from("logged_meals").delete().eq("user_id", userId).in("food_name", names);
    });
}

// ---- Scenario-anchor pin: deterministic 'today' state for 7 personas
// so the adaptive daily-brief fires the expected scenario when switching
// into them. Every insert is wrapped — if the target table doesn't exist
// yet on this DB, its name is added to skipped_tables and we keep going.

async function pinScenarioForPersona(
    admin: SupabaseClient,
    userId: string,
    persona: Persona,
    skipped: string[],
): Promise<string | null> {
    const now = Date.now();
    const DAY = 24 * 3600 * 1000;
    const tryInsert = async (table: string, row: Record<string, unknown> | Record<string, unknown>[]) => {
        try {
            const { error } = await admin.from(table).insert(row as never);
            if (error && /relation .* does not exist|Could not find the table/i.test(error.message)) {
                if (!skipped.includes(table)) skipped.push(table);
            }
        } catch (_) {
            if (!skipped.includes(table)) skipped.push(table);
        }
    };
    // Maya — rough sleep last night, recovery dipped, leg day today
    if (persona.username === "mayarecomp") {
        try {
            const lastNight = new Date(now - DAY);
            const wake = new Date(lastNight); wake.setUTCHours(6, 30, 0, 0);
            const bed = new Date(wake.getTime() - 4.63 * 3600 * 1000);
            await admin.from("manual_sleep_logs").upsert({
                user_id: userId, night: lastNight.toISOString().slice(0, 10),
                bedtime: bed.toISOString(), wake_time: wake.toISOString(),
                hours: 4.63, quality: 2,
                notes: `scenario rough-night ${FAKE_SEED_MARK}`,
            }, { onConflict: "user_id,night" });
        } catch (_) {}
        await tryInsert("recovery_log", { user_id: userId, hrv_delta_pct: -18, rhr_delta: 6, logged_at: new Date().toISOString() });
        return "maya";
    }
    // Priya — GI side effect logged 4h ago, GLP-1 dose yesterday
    if (persona.username === "priyamoves") {
        try {
            await admin.from("side_effect_logs").insert({
                user_id: userId,
                symptom: "GI discomfort", severity: 3,
                notes: `scenario fresh ${FAKE_SEED_MARK}`,
                logged_at: new Date(now - 4 * 3600 * 1000).toISOString(),
            });
        } catch (_) {}
        await tryInsert("meal_suggestion_override", {
            user_id: userId, kind: "low_fodmap_lower_fat",
            expires_at: new Date(now + 48 * 3600 * 1000).toISOString(),
        });
        return "priya";
    }
    // Theo — Wednesday BPC-157 marked missed
    if (persona.username === "theostrong") {
        try {
            const today = new Date(now);
            const dow = today.getUTCDay();
            const daysSinceWed = (dow + 7 - 3) % 7 || 7;
            await admin.from("dose_logs").insert({
                user_id: userId,
                compound_name: "BPC-157", dose_mcg: 250,
                was_skipped: true, skip_reason: "missed",
                notes: `scenario missed ${FAKE_SEED_MARK}`,
                logged_at: new Date(now - daysSinceWed * DAY).toISOString(),
            });
        } catch (_) {}
        for (let i = 0; i < 14; i += 1) {
            await tryInsert("compound_level_estimate", {
                user_id: userId, compound_name: "BPC-157",
                estimated_level_pct: 100 - i * 4,
                logged_at: new Date(now - i * DAY).toISOString(),
            });
        }
        return "theo";
    }
    // Marcus — trending-worse labs handled by buildMarkers above; add flags
    if (persona.username === "marcusruns") {
        await tryInsert("bloodwork_flag", [
            { user_id: userId, compound_hint: "oral_compound_a", marker: "ALT", trend: "rising" },
            { user_id: userId, compound_hint: "oral_compound_b", marker: "LDL", trend: "rising" },
        ]);
        await tryInsert("nutrition_priority", {
            user_id: userId, priority: "omega3_fiber_hydration",
            expires_at: new Date(now + 14 * DAY).toISOString(),
        });
        return "marcus";
    }
    // Ava — endurance, 5 days elevated RHR
    if (persona.username === "avalifts") {
        for (let i = 0; i < 5; i += 1) {
            await tryInsert("recovery_log", {
                user_id: userId, rhr_delta: 8 + (i % 2),
                logged_at: new Date(now - i * DAY).toISOString(),
            });
        }
        await tryInsert("adaptive_decision_pending", {
            user_id: userId, kind: "illness_or_overtraining_fork",
            options: JSON.stringify(["feeling_fine", "feeling_off"]),
        });
        return "ava";
    }
    // Sam — comeback day 1; streak break
    if (persona.username === "soraya postpartum" || persona.username === "ethannew") {
        try {
            await admin.from("profiles").update({
                current_streak: 0,
                longest_streak: 47,
            }).eq("id", userId);
        } catch (_) {}
        await tryInsert("recovery_day_plan", {
            user_id: userId, kind: "comeback_day_1",
            for_date: new Date().toISOString().slice(0, 10),
        });
        await tryInsert("social_recommendation", {
            user_id: userId, kind: "comeback_story",
            target_username: "avalifts",
        });
        return "sam";
    }
    // Jordan — borrowed protocol + adaptation
    if (persona.username === "jordancrossfit") {
        await tryInsert("borrowed_protocol", {
            user_id: userId, source_username: "marcusruns", compound: "Compound X", source_dose_mg: 5,
        });
        await tryInsert("protocol_adaptation", {
            user_id: userId, recommended_dose_mg: 2.5, taper_weeks: 2,
            reason: JSON.stringify({ labs: "mild_alt", sleep_baseline_h: 6.2, training_load: "high" }),
        });
        return "jordan";
    }
    return null;
}

async function deepPopulateFakePersonaAction(
    admin: SupabaseClient,
    payload: Record<string, unknown>,
): Promise<Response> {
    const userId = String(payload.user_id ?? "");
    if (!userId) return json(400, { error: "missing_user_id" });
    const requestedArchetype = typeof payload.archetype === "string" ? payload.archetype.toLowerCase() : "";

    // Find the profile so we can locate (or pick) a matching curated persona.
    const { data: profile, error: profErr } = await admin
        .from("profiles")
        .select("id, username, display_name, is_test_user, archetype_label")
        .eq("id", userId)
        .maybeSingle();
    if (profErr) return json(500, { error: profErr.message });
    if (!profile || profile.is_test_user !== true) {
        return json(403, { error: "not_a_fake_user" });
    }

    let persona: Persona | null =
        PERSONAS.find((p) => p.username === profile.username) ?? null;
    if (!persona && requestedArchetype.length > 0) {
        persona = PERSONAS.find((p) => p.archetype.toLowerCase() === requestedArchetype) ?? null;
    }
    if (!persona && typeof profile.archetype_label === "string") {
        const label = profile.archetype_label.toLowerCase();
        persona = PERSONAS.find((p) => p.archetype.toLowerCase() === label) ?? null;
    }
    if (!persona) {
        persona = PERSONAS[0]; // safe fallback so we still produce data
    }

    // Idempotent: wipe prior [fake-persona-seed] rows before re-inserting.
    await wipeFakePersonaSeed(admin, userId);

    const { inserted, errors, skipped_tables } = await deepPopulateFakePersona(admin, userId, persona);
    const scenarioKey = await pinScenarioForPersona(admin, userId, persona, skipped_tables);
    return json(200, {
        ok: errors.length === 0,
        version: "deep-v3",
        user_id: userId,
        persona: persona.username,
        archetype: persona.archetype,
        inserted,
        scenario: scenarioKey,
        skipped_tables,
        errors: errors.length > 0 ? errors.slice(0, 10) : undefined,
    });
}

async function deepPopulateAllFakes(
    admin: SupabaseClient,
    payload: Record<string, unknown>,
): Promise<Response> {
    const onlyUserId = typeof payload.user_id === "string" ? payload.user_id : null;
    const { data: profiles } = await admin
        .from("profiles").select("id, username").eq("is_test_user", true);
    const rows = ((profiles ?? []) as Array<{ id: string; username: string | null }>)
        .filter((r) => !onlyUserId || r.id === onlyUserId);
    if (rows.length === 0) return json(200, { ok: true, fakes: 0 });

    let totalWorkouts = 0, totalMeals = 0, totalDoses = 0, totalProtocols = 0,
        totalWeights = 0, totalSleep = 0, totalPRs = 0,
        totalWater = 0, totalSteps = 0, totalBloodwork = 0, totalBiomarkers = 0,
        totalSideEffects = 0, totalDailyTasks = 0, totalVials = 0;
    const errors: string[] = [];
    const skipped_tables = new Set<string>();
    const scenarioPersonas: string[] = [];
    for (const row of rows) {
        const persona = PERSONAS.find((p) => p.username === row.username);
        if (!persona) continue; // can only deep-populate curated personas
        try {
            const { inserted, errors: errs, skipped_tables: sk } = await deepPopulateFakePersona(admin, row.id, persona);
            totalWorkouts += inserted.workouts;
            totalMeals += inserted.meals;
            totalDoses += inserted.dose_logs;
            totalProtocols += inserted.protocols;
            totalWeights += inserted.weights;
            totalSleep += inserted.sleep_logs;
            totalPRs += inserted.prs;
            totalWater += inserted.water_logs;
            totalSteps += inserted.step_logs;
            totalBloodwork += inserted.bloodwork;
            totalBiomarkers += inserted.biomarkers;
            totalSideEffects += inserted.side_effects;
            totalDailyTasks += inserted.daily_tasks;
            totalVials += inserted.vials;
            for (const t of sk) skipped_tables.add(t);
            errors.push(...errs.slice(0, 3));
            const scenario = await pinScenarioForPersona(admin, row.id, persona, Array.from(skipped_tables));
            if (scenario) scenarioPersonas.push(scenario);
        } catch (e) {
            errors.push(`${row.username}: ${String(e)}`);
        }
    }
    return json(200, {
        ok: errors.length === 0,
        version: "deep-v3",
        fakes: rows.length,
        personas: rows.length,
        workouts: totalWorkouts,
        meals: totalMeals,
        dose_logs: totalDoses,
        doses: totalDoses,
        protocols: totalProtocols,
        weights: totalWeights,
        sleep_logs: totalSleep,
        prs: totalPRs,
        water_logs: totalWater,
        step_logs: totalSteps,
        bloodwork_panels: totalBloodwork,
        biomarkers: totalBiomarkers,
        side_effects: totalSideEffects,
        daily_tasks: totalDailyTasks,
        vials: totalVials,
        scenario_personas: scenarioPersonas,
        skipped_tables: Array.from(skipped_tables),
        errors: errors.length > 0 ? errors.slice(0, 10) : undefined,
    });
}

// ---- Handler: screenshotSeedMe ---------------------------------------
//
// Populate the caller's OWN account with rich, realistic data across
// every major surface so App Store screenshots look like a power user:
// own feed posts (with media), auto-join 5 themed groups, DM threads
// with named personas, a full protocol stack with vials + dose history,
// a training program + 45+ workout logs + PRs, a 90-day weight trend,
// meals logged on ~80% of days, biomarker results, activity heatmap,
// and daily-task history. Idempotent: tops up anything thin.

const SCREENSHOT_MARK = "[screenshot-seed]"; // suffix to identify rows for wipe

const MY_POST_BANK: { text: string; media?: string[] }[] = [
    { text: "squat day done. felt heavy but moved well. trusting the program.", media: ["barbell-personal-1"] },
    { text: "easy 10k this morning. kept HR under 142 the whole way. zone 2 finally clicking", media: ["morning-run-personal"] },
    { text: "week 6 of titration. side effects mild. appetite cues are night and day. logging continues." },
    { text: "meal prep sunday — 12 portions of chicken, rice, broccoli. boring? yes. effective? extremely.", media: ["meal-prep-personal"] },
    { text: "hit a 405 deadlift today. five years in the making. crying in the parking lot 😭 #PR", media: ["deadlift-pr-personal"] },
    { text: "protein at every meal is the only diet rule that ever actually moved the needle for me" },
    { text: "bloods back from last week — lipids actually improved on the protocol. cautiously optimistic." },
    { text: "long run done. 16k. legs feel weirdly fresh. taper week 1 of 3.", media: ["long-run-personal"] },
    { text: "new training block starts monday. 4 days lift + 3 run. wish me luck" },
    { text: "showing up on the bad days is the whole sport. that's it. that's the post." },
    { text: "my coach told me to stop chasing PRs and start chasing consistency. it's working.", media: ["gym-mirror-personal"] },
    { text: "updated my stack — added BPC-157 for the rotator cuff that won't quit. logging side effects daily." },
];

const MY_GROUP_NAMES = [
    "Heavy Tuesdays",
    "Easy Miles Club",
    "Hybrid Lab",
    "Protocol Logbook",
    "Recomp Receipts",
];

const DM_THREADS: { personaUsername: string; messages: { from: "me" | "them"; text: string; hoursAgo: number }[] }[] = [
    { personaUsername: "marcusruns", messages: [
        { from: "them", text: "yo, your zone 2 post — what watch are you using to keep HR honest?", hoursAgo: 36 },
        { from: "me",   text: "polar h10 strap. wrist optical lies on intervals", hoursAgo: 35 },
        { from: "them", text: "yeah i suspected. ordering one tonight", hoursAgo: 34 },
        { from: "me",   text: "trust me. game changer for easy days", hoursAgo: 33 },
        { from: "them", text: "how's marathon prep going?", hoursAgo: 8 },
        { from: "me",   text: "long run was clean. taper this week. nervous but ready", hoursAgo: 6 },
        { from: "them", text: "you're gonna eat. send the splits after", hoursAgo: 5 },
    ]},
    { personaUsername: "finnpowerlifts", messages: [
        { from: "me",   text: "opener selection — go 96% gym single or 92%? meet in 8 wks", hoursAgo: 60 },
        { from: "them", text: "92. always. you'll thank me", hoursAgo: 59 },
        { from: "me",   text: "i hate that you're right", hoursAgo: 58 },
        { from: "them", text: "haha — gym singles lie. meet day adrenaline is +5%", hoursAgo: 58 },
        { from: "me",   text: "sending you my peak this week, lmk if it looks dumb", hoursAgo: 12 },
        { from: "them", text: "deal. send raw numbers, no commentary", hoursAgo: 10 },
    ]},
    { personaUsername: "priyamoves", messages: [
        { from: "me",   text: "hip opener flow you posted last week actually unlocked me. squat depth is nuts", hoursAgo: 22 },
        { from: "them", text: "YESS. add couch stretch every other day, your hip flexors will thank you", hoursAgo: 22 },
        { from: "me",   text: "on it. you teaching saturday?", hoursAgo: 21 },
        { from: "them", text: "6am slow flow. come early, i'll save you a spot near the window", hoursAgo: 20 },
        { from: "me",   text: "see you sat 🫡", hoursAgo: 2 },
    ]},
    { personaUsername: "ninapeptides", messages: [
        { from: "me",   text: "thinking about adding tesa to the stack — your experience?", hoursAgo: 48 },
        { from: "them", text: "loved it for healing but pulled my appetite up. worth knowing if you're cutting", hoursAgo: 47 },
        { from: "me",   text: "good call. on a recomp so maybe later in the cycle", hoursAgo: 47 },
        { from: "them", text: "that's the move. and log everything from day 1, you will forget", hoursAgo: 46 },
        { from: "me",   text: "already a step ahead — got a whole spreadsheet 😅", hoursAgo: 4 },
    ]},
    { personaUsername: "avalifts", messages: [
        { from: "them", text: "saw your deadlift PR. 405?? insane.", hoursAgo: 14 },
        { from: "me",   text: "five years 🥲. wanted to quit so many times", hoursAgo: 13 },
        { from: "them", text: "that's the post tho. consistency > everything", hoursAgo: 13 },
        { from: "me",   text: "appreciate you. you're next, i can see your bar speed", hoursAgo: 1 },
    ]},
    { personaUsername: "mayarecomp", messages: [
        { from: "me",   text: "how are you logging cals on the cut? eyeballing or weighing?", hoursAgo: 30 },
        { from: "them", text: "weighing. i hate it but it's the only thing keeping me honest", hoursAgo: 29 },
        { from: "me",   text: "yeah same. 2 weeks in and it's autopilot now", hoursAgo: 29 },
        { from: "them", text: "exactly. you'll never go back", hoursAgo: 28 },
        { from: "me",   text: "down 4lb this month. slow and clean", hoursAgo: 6 },
        { from: "them", text: "that's the rate. perfect.", hoursAgo: 5 },
    ]},
];

const MEAL_BANK: { name: string; brand?: string; cal: number; p: number; c: number; f: number; time: "breakfast" | "lunch" | "dinner" | "snack" }[] = [
    { name: "Oats, banana, peanut butter", cal: 540, p: 22, c: 78, f: 18, time: "breakfast" },
    { name: "Greek yogurt + berries + granola", cal: 380, p: 28, c: 48, f: 8, time: "breakfast" },
    { name: "3 egg omelette, toast, avocado", cal: 510, p: 32, c: 32, f: 28, time: "breakfast" },
    { name: "Protein shake + bagel + jam", cal: 480, p: 38, c: 70, f: 6, time: "breakfast" },
    { name: "Chicken rice bowl", cal: 680, p: 52, c: 78, f: 14, time: "lunch" },
    { name: "Salmon, sweet potato, broccoli", cal: 620, p: 44, c: 56, f: 22, time: "lunch" },
    { name: "Burrito bowl (Chipotle)", brand: "Chipotle", cal: 780, p: 48, c: 86, f: 24, time: "lunch" },
    { name: "Turkey sandwich + chips", cal: 640, p: 36, c: 78, f: 18, time: "lunch" },
    { name: "Steak, rice, asparagus", cal: 720, p: 56, c: 64, f: 26, time: "dinner" },
    { name: "Ground beef pasta", cal: 760, p: 48, c: 82, f: 24, time: "dinner" },
    { name: "Chicken thighs, potatoes, salad", cal: 650, p: 50, c: 54, f: 22, time: "dinner" },
    { name: "Sushi (16 pc)", cal: 720, p: 38, c: 100, f: 14, time: "dinner" },
    { name: "Whey shake", cal: 160, p: 30, c: 6, f: 2, time: "snack" },
    { name: "Rice cakes + peanut butter", cal: 240, p: 8, c: 28, f: 12, time: "snack" },
    { name: "Cottage cheese + honey", cal: 220, p: 24, c: 18, f: 4, time: "snack" },
];

const WORKOUT_BANK: { name: string; type: string; sport?: string; mins: number; cals: number; volume?: number; distance?: number; exercises?: { name: string; sets: { setNumber: number; weight: number; reps: number }[] }[] }[] = [
    { name: "Squat Day", type: "strength", mins: 65, cals: 480, volume: 12400, exercises: [
        { name: "Back Squat", sets: [{ setNumber: 1, weight: 225, reps: 5 }, { setNumber: 2, weight: 275, reps: 5 }, { setNumber: 3, weight: 315, reps: 3 }, { setNumber: 4, weight: 335, reps: 3 }, { setNumber: 5, weight: 355, reps: 1 }] },
        { name: "Romanian Deadlift", sets: [{ setNumber: 1, weight: 225, reps: 8 }, { setNumber: 2, weight: 245, reps: 8 }, { setNumber: 3, weight: 265, reps: 6 }] },
        { name: "Walking Lunge", sets: [{ setNumber: 1, weight: 40, reps: 20 }, { setNumber: 2, weight: 40, reps: 20 }] },
    ]},
    { name: "Bench Day", type: "strength", mins: 58, cals: 410, volume: 9200, exercises: [
        { name: "Bench Press", sets: [{ setNumber: 1, weight: 135, reps: 8 }, { setNumber: 2, weight: 185, reps: 5 }, { setNumber: 3, weight: 225, reps: 3 }, { setNumber: 4, weight: 245, reps: 1 }] },
        { name: "Incline DB Press", sets: [{ setNumber: 1, weight: 70, reps: 10 }, { setNumber: 2, weight: 70, reps: 10 }, { setNumber: 3, weight: 75, reps: 8 }] },
        { name: "Cable Fly", sets: [{ setNumber: 1, weight: 30, reps: 12 }, { setNumber: 2, weight: 30, reps: 12 }, { setNumber: 3, weight: 35, reps: 10 }] },
    ]},
    { name: "Deadlift Day", type: "strength", mins: 70, cals: 520, volume: 14200, exercises: [
        { name: "Deadlift", sets: [{ setNumber: 1, weight: 225, reps: 5 }, { setNumber: 2, weight: 315, reps: 3 }, { setNumber: 3, weight: 365, reps: 1 }, { setNumber: 4, weight: 385, reps: 1 }, { setNumber: 5, weight: 405, reps: 1 }] },
        { name: "Barbell Row", sets: [{ setNumber: 1, weight: 135, reps: 8 }, { setNumber: 2, weight: 155, reps: 8 }, { setNumber: 3, weight: 175, reps: 6 }] },
    ]},
    { name: "Pull Day", type: "strength", mins: 60, cals: 430, volume: 8800, exercises: [
        { name: "Pull-up", sets: [{ setNumber: 1, weight: 0, reps: 10 }, { setNumber: 2, weight: 0, reps: 10 }, { setNumber: 3, weight: 25, reps: 6 }] },
        { name: "Lat Pulldown", sets: [{ setNumber: 1, weight: 140, reps: 10 }, { setNumber: 2, weight: 160, reps: 8 }, { setNumber: 3, weight: 180, reps: 6 }] },
        { name: "Face Pull", sets: [{ setNumber: 1, weight: 40, reps: 15 }, { setNumber: 2, weight: 40, reps: 15 }] },
    ]},
    { name: "Easy Run", type: "sport", sport: "Running", mins: 48, cals: 520, distance: 5.2 },
    { name: "Long Run", type: "sport", sport: "Running", mins: 92, cals: 980, distance: 10.0 },
    { name: "Track Intervals", type: "sport", sport: "Running", mins: 52, cals: 580, distance: 5.8 },
    { name: "Tempo Run", type: "sport", sport: "Running", mins: 38, cals: 460, distance: 4.4 },
    { name: "Z2 Bike", type: "sport", sport: "Cycling", mins: 75, cals: 620, distance: 22.0 },
    { name: "Push Day", type: "strength", mins: 55, cals: 400, volume: 7600, exercises: [
        { name: "Overhead Press", sets: [{ setNumber: 1, weight: 95, reps: 8 }, { setNumber: 2, weight: 115, reps: 5 }, { setNumber: 3, weight: 135, reps: 3 }] },
        { name: "Dip", sets: [{ setNumber: 1, weight: 0, reps: 12 }, { setNumber: 2, weight: 25, reps: 8 }, { setNumber: 3, weight: 25, reps: 8 }] },
        { name: "Lateral Raise", sets: [{ setNumber: 1, weight: 15, reps: 15 }, { setNumber: 2, weight: 15, reps: 15 }, { setNumber: 3, weight: 20, reps: 12 }] },
    ]},
];

const MY_PRS: { exercise_id: string; exercise_name: string; best_weight: number; best_one_rm: number; best_volume: number }[] = [
    { exercise_id: "back_squat", exercise_name: "Back Squat", best_weight: 355, best_one_rm: 380, best_volume: 12400 },
    { exercise_id: "deadlift", exercise_name: "Deadlift", best_weight: 405, best_one_rm: 425, best_volume: 14200 },
    { exercise_id: "bench_press", exercise_name: "Bench Press", best_weight: 245, best_one_rm: 260, best_volume: 9200 },
    { exercise_id: "overhead_press", exercise_name: "Overhead Press", best_weight: 135, best_one_rm: 145, best_volume: 4200 },
    { exercise_id: "pull_up", exercise_name: "Pull-up", best_weight: 25, best_one_rm: 50, best_volume: 1800 },
    { exercise_id: "barbell_row", exercise_name: "Barbell Row", best_weight: 185, best_one_rm: 200, best_volume: 4800 },
    { exercise_id: "front_squat", exercise_name: "Front Squat", best_weight: 265, best_one_rm: 285, best_volume: 6800 },
    { exercise_id: "romanian_deadlift", exercise_name: "Romanian Deadlift", best_weight: 285, best_one_rm: 305, best_volume: 7200 },
];

function mediaUrlForSeed(seed: string): string {
    return `https://picsum.photos/seed/${encodeURIComponent(seed)}/1080/1080`;
}

async function screenshotSeedMe(admin: SupabaseClient, userId: string): Promise<Response> {
    const summary: Record<string, number> = {
        own_posts: 0,
        groups_joined: 0,
        dm_threads: 0,
        dm_messages: 0,
        protocols: 0,
        compounds: 0,
        vials: 0,
        dose_logs: 0,
        workouts: 0,
        prs: 0,
        weights: 0,
        meals: 0,
        biomarker_entries: 0,
        biomarkers: 0,
        activity_logs: 0,
        daily_tasks: 0,
        sleep_logs: 0,
        side_effects: 0,
    };
    const errors: string[] = [];
    const now = Date.now();
    const DAY = 24 * 3600 * 1000;
    let protocolIdForFixtures: string | null = null;

    // ------ 1) Own feed posts with media ------
    try {
        const { count: existingPosts } = await admin
            .from("feed_posts").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("text_content", `%${SCREENSHOT_MARK}%`);
        if ((existingPosts ?? 0) < MY_POST_BANK.length) {
            const rows = MY_POST_BANK.map((p, i) => {
                const daysAgo = i * 7 + (i % 3);
                const created = new Date(now - daysAgo * DAY - i * 3 * 3600 * 1000).toISOString();
                return {
                    user_id: userId,
                    text_content: `${p.text} ${SCREENSHOT_MARK}`,
                    media_urls: (p.media ?? []).map(mediaUrlForSeed),
                    tags: [] as string[],
                    created_at: created,
                    updated_at: created,
                };
            });
            const { error } = await admin.from("feed_posts").insert(rows);
            if (error) errors.push(`own posts: ${error.message}`);
            else summary.own_posts = rows.length;
        }
    } catch (e) { errors.push(`own posts: ${String(e)}`); }

    // ------ 2) Auto-join 5 themed groups ------
    try {
        const { data: gRows } = await admin
            .from("groups").select("id, name").in("name", MY_GROUP_NAMES);
        const groups = (gRows ?? []) as Array<{ id: string; name: string }>;
        if (groups.length > 0) {
            const memberRows = groups.map((g) => ({ group_id: g.id, user_id: userId, role: "Member" as const }));
            const { count } = await admin.from("group_members")
                .upsert(memberRows, { onConflict: "group_id,user_id", ignoreDuplicates: true, count: "exact" });
            summary.groups_joined = count ?? memberRows.length;
        }
    } catch (e) { errors.push(`groups join: ${String(e)}`); }

    // ------ 3) DM threads with named personas ------
    try {
        const usernames = DM_THREADS.map((t) => t.personaUsername);
        const { data: personaRows } = await admin
            .from("profiles").select("id, username").in("username", usernames);
        const idByUser = new Map<string, string>();
        for (const r of (personaRows ?? []) as Array<{ id: string; username: string }>) {
            idByUser.set(r.username, r.id);
        }
        for (const thread of DM_THREADS) {
            const otherId = idByUser.get(thread.personaUsername);
            if (!otherId) continue;
            // Find existing conversation between caller and other
            let convId: string | null = null;
            const { data: myConvs } = await admin
                .from("conversation_participants").select("conversation_id").eq("user_id", userId);
            const ids = ((myConvs ?? []) as Array<{ conversation_id: string }>).map((r) => r.conversation_id);
            if (ids.length > 0) {
                const { data: matches } = await admin
                    .from("conversation_participants").select("conversation_id")
                    .in("conversation_id", ids).eq("user_id", otherId);
                convId = ((matches ?? []) as Array<{ conversation_id: string }>)[0]?.conversation_id ?? null;
            }
            if (!convId) {
                const { data: newConv, error: convErr } = await admin
                    .from("conversations").insert({}).select("id").single();
                if (convErr || !newConv) continue;
                convId = (newConv as { id: string }).id;
                await admin.from("conversation_participants").insert([
                    { conversation_id: convId, user_id: userId },
                    { conversation_id: convId, user_id: otherId },
                ]);
            }
            // Check existing messages — skip if already seeded a chunk
            const { count: existing } = await admin
                .from("direct_messages").select("id", { count: "exact", head: true }).eq("conversation_id", convId);
            if ((existing ?? 0) >= thread.messages.length) continue;
            const msgRows = thread.messages.map((m) => ({
                conversation_id: convId!,
                sender_id: m.from === "me" ? userId : otherId,
                text_content: m.text,
                is_read: true,
                created_at: new Date(now - m.hoursAgo * 3600 * 1000).toISOString(),
            }));
            const { error: insErr } = await admin.from("direct_messages").insert(msgRows);
            if (insErr) errors.push(`dm ${thread.personaUsername}: ${insErr.message}`);
            else { summary.dm_threads += 1; summary.dm_messages += msgRows.length; }
        }
    } catch (e) { errors.push(`dms: ${String(e)}`); }

    // ------ 4) Protocol + compounds + vials + dose history ------
    try {
        // Idempotent: only create if no active screenshot-marked protocol
        const { data: existingProto } = await admin
            .from("protocols").select("id, name").eq("user_id", userId).ilike("name", `%${SCREENSHOT_MARK}%`).limit(1);
        let protocolId: string | null = ((existingProto ?? []) as Array<{ id: string }>)[0]?.id ?? null;
        if (!protocolId) {
            const startDate = new Date(now - 56 * DAY).toISOString().slice(0, 10);
            const { data: created, error: pErr } = await admin
                .from("protocols")
                .insert({
                    user_id: userId,
                    name: `Cut + Recovery Stack ${SCREENSHOT_MARK}`,
                    goal: "Fat Loss",
                    start_date: startDate,
                    total_weeks: 12,
                    loading_weeks: 2,
                    maintenance_weeks: 8,
                    tapering_weeks: 1,
                    off_cycle_weeks: 1,
                    is_active: true,
                })
                .select("id").single();
            if (!pErr && created) {
                protocolId = (created as { id: string }).id;
                summary.protocols = 1;
            } else if (pErr) errors.push(`protocol: ${pErr.message}`);
        }
        if (protocolId) {
            protocolIdForFixtures = protocolId;
            const compounds = [
                { compound_name: "Retatrutide", dose_mcg: 2000, frequency: "Weekly", injection_route: "Subcutaneous", vial_size_mg: 10 },
                { compound_name: "BPC-157", dose_mcg: 250, frequency: "Daily", injection_route: "Subcutaneous", vial_size_mg: 5 },
                { compound_name: "TB-500", dose_mcg: 500, frequency: "Twice weekly", injection_route: "Subcutaneous", vial_size_mg: 5 },
            ];
            for (const c of compounds) {
                const { count } = await admin.from("protocol_compounds")
                    .select("id", { count: "exact", head: true }).eq("protocol_id", protocolId).eq("compound_name", c.compound_name);
                if ((count ?? 0) === 0) {
                    const { error } = await admin.from("protocol_compounds").insert({
                        protocol_id: protocolId, ...c,
                        reconstitution_volume_ml: 2.0,
                        time_of_day: new Date(now).toISOString(),
                    });
                    if (!error) summary.compounds += 1;
                }
            }
            // Vials (compound_name reused; client_id stable per compound)
            for (let i = 0; i < compounds.length; i += 1) {
                const c = compounds[i];
                const clientId = `screenshot-vial-${i + 1}-${userId.slice(0, 8)}`;
                const { count } = await admin.from("vials")
                    .select("id", { count: "exact", head: true }).eq("user_id", userId).eq("client_id", clientId);
                if ((count ?? 0) === 0) {
                    const { error } = await admin.from("vials").insert({
                        user_id: userId,
                        client_id: clientId,
                        compound_name: c.compound_name,
                        vial_size_mg: c.vial_size_mg,
                        diluent_ml: 2.0,
                        reconstituted_on: new Date(now - (28 - i * 7) * DAY).toISOString(),
                        storage: "Fridge",
                        lot_number: `LOT-${1000 + i * 37}`,
                        vial_number: `${i + 1}`,
                        expiration_date: new Date(now + (60 - i * 10) * DAY).toISOString(),
                        typical_dose_mcg: c.dose_mcg,
                        mcg_used: c.dose_mcg * (8 - i * 2),
                        bud_days: 30,
                    });
                    if (!error) summary.vials += 1;
                    else errors.push(`vial ${c.compound_name}: ${error.message}`);
                }
            }
            // Dose log history — last 8 weeks, site rotation
            const { count: existingDoses } = await admin
                .from("dose_logs").select("id", { count: "exact", head: true }).eq("protocol_id", protocolId);
            if ((existingDoses ?? 0) < 40) {
                const sites = ["Left Abdomen", "Right Abdomen", "Left Thigh", "Right Thigh", "Left Glute", "Right Glute"];
                const rows: Record<string, unknown>[] = [];
                // Retatrutide weekly for 8 weeks
                for (let w = 0; w < 8; w += 1) {
                    rows.push({
                        user_id: userId, protocol_id: protocolId,
                        compound_name: "Retatrutide", dose_mcg: 2000 + w * 500,
                        injection_site: sites[w % sites.length],
                        was_skipped: false,
                        notes: w === 3 ? "slight nausea day 2, resolved" : null,
                        logged_at: new Date(now - (7 * (8 - w)) * DAY).toISOString(),
                    });
                }
                // BPC-157 daily for last 28 days
                for (let d = 0; d < 28; d += 1) {
                    rows.push({
                        user_id: userId, protocol_id: protocolId,
                        compound_name: "BPC-157", dose_mcg: 250,
                        injection_site: sites[d % sites.length],
                        was_skipped: d === 12 || d === 21,
                        skip_reason: (d === 12 || d === 21) ? "travel" : null,
                        notes: null,
                        logged_at: new Date(now - (28 - d) * DAY).toISOString(),
                    });
                }
                // TB-500 twice weekly for 6 weeks
                for (let w = 0; w < 6; w += 1) {
                    for (const dayOffset of [0, 3]) {
                        rows.push({
                            user_id: userId, protocol_id: protocolId,
                            compound_name: "TB-500", dose_mcg: 500,
                            injection_site: sites[(w * 2 + dayOffset) % sites.length],
                            was_skipped: false,
                            notes: null,
                            logged_at: new Date(now - (7 * (6 - w) + dayOffset) * DAY).toISOString(),
                        });
                    }
                }
                for (let i = 0; i < rows.length; i += 200) {
                    const { error } = await admin.from("dose_logs").insert(rows.slice(i, i + 200));
                    if (error) errors.push(`doses chunk: ${error.message}`);
                    else summary.dose_logs += Math.min(200, rows.length - i);
                }
            }
        }
    } catch (e) { errors.push(`protocol: ${String(e)}`); }

    // ------ 5) Training program ------
    try {
        const { count: existingProgs } = await admin
            .from("training_programs").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("name", `%${SCREENSHOT_MARK}%`);
        if ((existingProgs ?? 0) === 0) {
            const days = [
                { name: "Squat", exercises: ["Back Squat", "Romanian Deadlift", "Walking Lunge"] },
                { name: "Bench", exercises: ["Bench Press", "Incline DB Press", "Cable Fly"] },
                { name: "Deadlift", exercises: ["Deadlift", "Barbell Row", "Pull-up"] },
                { name: "Press", exercises: ["Overhead Press", "Dip", "Lateral Raise"] },
            ];
            await admin.from("training_programs").insert({
                user_id: userId,
                name: `Hybrid 4-Day ${SCREENSHOT_MARK}`,
                program_type: "custom",
                days_per_week: 4,
                days_json: JSON.stringify(days),
                is_active: true,
                current_week: 5,
                start_day_offset: 0,
            });
        }
    } catch (e) { errors.push(`program: ${String(e)}`); }

    // ------ 6) Workouts: ~50 sessions over 90 days ------
    try {
        const { count: existingW } = await admin
            .from("workouts").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("notes", `%${SCREENSHOT_MARK}%`);
        if ((existingW ?? 0) < 40) {
            const target = 50;
            const rows: Record<string, unknown>[] = [];
            for (let i = 0; i < target; i += 1) {
                const w = WORKOUT_BANK[i % WORKOUT_BANK.length];
                const daysAgo = Math.floor(i * 1.7) + (i % 2);
                const completedAt = new Date(now - daysAgo * DAY - (i % 4) * 3600 * 1000);
                const startedAt = new Date(completedAt.getTime() - w.mins * 60 * 1000);
                const notesObj: Record<string, unknown> = { mark: SCREENSHOT_MARK };
                if (w.volume) notesObj.totalVolume = w.volume;
                rows.push({
                    user_id: userId,
                    date: completedAt.toISOString().slice(0, 10),
                    name: w.name,
                    sport: w.sport ?? null,
                    workout_type: w.type,
                    duration_minutes: w.mins,
                    calories_burned: w.cals,
                    distance: w.distance ?? null,
                    exercises: w.exercises ? JSON.stringify(w.exercises) : null,
                    notes: JSON.stringify(notesObj),
                    fp_earned: w.mins * 5 + Math.floor(w.cals / 10),
                    started_at: startedAt.toISOString(),
                    completed_at: completedAt.toISOString(),
                });
            }
            for (let i = 0; i < rows.length; i += 200) {
                const { error } = await admin.from("workouts").insert(rows.slice(i, i + 200));
                if (error) errors.push(`workouts: ${error.message}`);
                else summary.workouts += Math.min(200, rows.length - i);
            }
        }
    } catch (e) { errors.push(`workouts: ${String(e)}`); }

    // ------ 7) PRs ------
    try {
        const prRows = MY_PRS.map((p) => ({ user_id: userId, ...p, updated_at: new Date(now - 3 * DAY).toISOString() }));
        const { error } = await admin.from("personal_records")
            .upsert(prRows, { onConflict: "user_id,exercise_id" });
        if (error) errors.push(`prs: ${error.message}`);
        else summary.prs = prRows.length;
    } catch (e) { errors.push(`prs: ${String(e)}`); }

    // ------ 8) Weight logs (90 days, smooth downward trend) ------
    try {
        const { count: existingWeights } = await admin
            .from("weight_logs").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("note", `%${SCREENSHOT_MARK}%`);
        if ((existingWeights ?? 0) < 30) {
            const rows: Record<string, unknown>[] = [];
            const startWeight = 192.4;
            const endWeight = 184.2;
            const points = 36;
            for (let i = 0; i < points; i += 1) {
                const t = i / (points - 1);
                const noise = Math.sin(i * 0.9) * 0.4;
                const w = startWeight + (endWeight - startWeight) * t + noise;
                const daysAgo = Math.round((1 - t) * 84);
                rows.push({
                    user_id: userId,
                    weight: Math.round(w * 10) / 10,
                    unit: "lbs",
                    note: i === 0 ? `start ${SCREENSHOT_MARK}` : i === points - 1 ? `today ${SCREENSHOT_MARK}` : SCREENSHOT_MARK,
                    logged_at: new Date(now - daysAgo * DAY).toISOString(),
                });
            }
            for (let i = 0; i < rows.length; i += 200) {
                const { error } = await admin.from("weight_logs").insert(rows.slice(i, i + 200));
                if (error) errors.push(`weights: ${error.message}`);
                else summary.weights += Math.min(200, rows.length - i);
            }
        }
    } catch (e) { errors.push(`weights: ${String(e)}`); }

    // ------ 9) Meals on ~80% of last 60 days ------
    try {
        const { count: existingMeals } = await admin
            .from("logged_meals").select("id", { count: "exact", head: true })
            .eq("user_id", userId);
        if ((existingMeals ?? 0) < 80) {
            const rows: Record<string, unknown>[] = [];
            for (let d = 0; d < 60; d += 1) {
                if ((d * 7) % 11 < 2) continue; // skip ~18% of days
                const dayBase = now - d * DAY;
                const breakfasts = MEAL_BANK.filter((m) => m.time === "breakfast");
                const lunches = MEAL_BANK.filter((m) => m.time === "lunch");
                const dinners = MEAL_BANK.filter((m) => m.time === "dinner");
                const snacks = MEAL_BANK.filter((m) => m.time === "snack");
                const meals = [
                    { m: breakfasts[d % breakfasts.length], hours: 8 },
                    { m: lunches[d % lunches.length], hours: 13 },
                    { m: dinners[d % dinners.length], hours: 19 },
                ];
                if (d % 3 === 0) meals.push({ m: snacks[d % snacks.length], hours: 16 });
                for (const { m, hours } of meals) {
                    const ts = new Date(dayBase);
                    ts.setUTCHours(hours, 0, 0, 0);
                    rows.push({
                        user_id: userId,
                        food_name: m.name,
                        food_brand: m.brand ?? null,
                        calories: m.cal,
                        protein_g: m.p,
                        carbs_g: m.c,
                        fat_g: m.f,
                        servings: 1,
                        meal_time: m.time,
                        logged_at: ts.toISOString(),
                    });
                }
            }
            for (let i = 0; i < rows.length; i += 200) {
                const { error } = await admin.from("logged_meals").insert(rows.slice(i, i + 200));
                if (error) errors.push(`meals: ${error.message}`);
                else summary.meals += Math.min(200, rows.length - i);
            }
        }
        // Macro targets
        await admin.from("macro_targets").upsert({
            user_id: userId, calories: 2400, protein_g: 200, carbs_g: 260, fat_g: 75, source: "adaptive",
        }, { onConflict: "user_id" });
    } catch (e) { errors.push(`meals: ${String(e)}`); }

    // ------ 10) Biomarker entries ------
    try {
        const { count: existingBio } = await admin
            .from("bloodwork_entries").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("notes", `%${SCREENSHOT_MARK}%`);
        if ((existingBio ?? 0) < 2) {
            const panels = [
                { daysAgo: 70, notes: `Baseline panel ${SCREENSHOT_MARK}`, results: [
                    { biomarker: "Total Cholesterol", value: 188 },
                    { biomarker: "LDL", value: 112 },
                    { biomarker: "HDL", value: 48 },
                    { biomarker: "Triglycerides", value: 132 },
                    { biomarker: "Fasting Glucose", value: 94 },
                    { biomarker: "HbA1c", value: 5.4 },
                    { biomarker: "ALT", value: 28 },
                    { biomarker: "AST", value: 24 },
                    { biomarker: "Testosterone", value: 612 },
                ]},
                { daysAgo: 10, notes: `Mid-protocol follow-up ${SCREENSHOT_MARK}`, results: [
                    { biomarker: "Total Cholesterol", value: 172 },
                    { biomarker: "LDL", value: 96 },
                    { biomarker: "HDL", value: 54 },
                    { biomarker: "Triglycerides", value: 108 },
                    { biomarker: "Fasting Glucose", value: 88 },
                    { biomarker: "HbA1c", value: 5.2 },
                    { biomarker: "ALT", value: 24 },
                    { biomarker: "AST", value: 22 },
                    { biomarker: "Testosterone", value: 668 },
                ]},
            ];
            for (const panel of panels) {
                const entryDate = new Date(now - panel.daysAgo * DAY).toISOString().slice(0, 10);
                const { data: entry, error: eErr } = await admin
                    .from("bloodwork_entries")
                    .insert({ user_id: userId, entry_date: entryDate, notes: panel.notes })
                    .select("id").single();
                if (eErr || !entry) { errors.push(`bloodwork: ${eErr?.message}`); continue; }
                summary.biomarker_entries += 1;
                const entryId = (entry as { id: string }).id;
                const bioRows = panel.results.map((r) => ({ entry_id: entryId, ...r }));
                const { error: bErr } = await admin.from("biomarker_results").insert(bioRows);
                if (bErr) errors.push(`biomarkers: ${bErr.message}`);
                else summary.biomarkers += bioRows.length;
            }
        }
    } catch (e) { errors.push(`biomarkers: ${String(e)}`); }

    // ------ 11) Activity logs (heatmap) — last 60 days ------
    try {
        const dateOnly = (d: Date) => d.toISOString().slice(0, 10);
        const { count: existingActivity } = await admin
            .from("activity_logs").select("id", { count: "exact", head: true })
            .eq("user_id", userId).ilike("notes", `%${SCREENSHOT_MARK}%`);
        if ((existingActivity ?? 0) < 30) {
            const rows: Record<string, unknown>[] = [];
            for (let d = 0; d < 60; d += 1) {
                if ((d * 5) % 13 < 2) continue;
                const date = new Date(now - d * DAY);
                rows.push({
                    user_id: userId,
                    activity_date: dateOnly(date),
                    activity_type: d % 3 === 0 ? "workout" : d % 3 === 1 ? "cardio" : "steps",
                    sport: d % 3 === 1 ? "Running" : null,
                    duration_minutes: 20 + (d % 40),
                    calories_burned: 180 + (d % 12) * 35,
                    notes: `auto ${SCREENSHOT_MARK}`,
                });
            }
            for (let i = 0; i < rows.length; i += 200) {
                const { error } = await admin.from("activity_logs").insert(rows.slice(i, i + 200));
                if (error) errors.push(`activity: ${error.message}`);
                else summary.activity_logs += Math.min(200, rows.length - i);
            }
        }
    } catch (e) { errors.push(`activity: ${String(e)}`); }

    // ------ 12) Daily tasks (recent week) ------
    try {
        const taskBank = [
            { title: "Hit protein target", icon: "flame.fill", category: "Nutrition" },
            { title: "10k steps", icon: "figure.walk", category: "Movement" },
            { title: "Log dose", icon: "syringe.fill", category: "Protocol" },
            { title: "Drink 1 gal water", icon: "drop.fill", category: "Hydration" },
            { title: "8h sleep", icon: "moon.zzz.fill", category: "Recovery" },
            { title: "Workout", icon: "dumbbell.fill", category: "Training" },
        ];
        for (let d = 0; d < 7; d += 1) {
            const date = new Date(now - d * DAY).toISOString().slice(0, 10);
            const { count } = await admin.from("daily_tasks")
                .select("id", { count: "exact", head: true })
                .eq("user_id", userId).eq("task_date", date);
            if ((count ?? 0) >= 4) continue;
            const rows = taskBank.map((t, i) => ({
                user_id: userId,
                title: t.title,
                description: SCREENSHOT_MARK,
                category: t.category,
                action_link: "None",
                target_value: 0,
                goal_description: null,
                is_completed: d > 0 ? (i % 7 !== 5) : i < 3,
                task_date: date,
                schedule_type: "Daily",
                scheduled_days: [1, 2, 3, 4, 5, 6, 7],
                icon: t.icon,
                is_user_created: false,
                custom_category_id: null,
            }));
            const { error } = await admin.from("daily_tasks").insert(rows);
            if (error) errors.push(`tasks ${date}: ${error.message}`);
            else summary.daily_tasks += rows.length;
        }
    } catch (e) { errors.push(`tasks: ${String(e)}`); }

    // ------ 13) Manual sleep logs — 14 nights of durable history ------
    // Mostly normal hours so the "rough sleep" detector does NOT fire today;
    // one rough night sits 5 days back so the sleep trend chart shows a dip.
    try {
        const dateOnly = (d: Date) => d.toISOString().slice(0, 10);
        // Hours pattern by nights-ago index (0 = last night):
        // 0: 7.6h, 1: 8.1h, 2: 7.2h, 3: 6.9h, 4: 7.8h, 5: 4.8h (rough),
        // 6: 6.4h, 7: 7.5h, 8: 8.0h, 9: 7.3h, 10: 6.8h, 11: 7.6h, 12: 7.9h, 13: 7.4h
        const hoursPattern = [7.6, 8.1, 7.2, 6.9, 7.8, 4.8, 6.4, 7.5, 8.0, 7.3, 6.8, 7.6, 7.9, 7.4];
        const qualityPattern = [4, 5, 4, 3, 4, 2, 3, 4, 5, 4, 3, 4, 5, 4];
        const rows: Record<string, unknown>[] = [];
        for (let i = 0; i < hoursPattern.length; i += 1) {
            const night = new Date(now - (i + 1) * DAY); // i=0 -> "last night"
            const wake = new Date(night);
            wake.setUTCHours(7, 0, 0, 0);
            const bed = new Date(wake.getTime() - hoursPattern[i] * 3600 * 1000);
            rows.push({
                user_id: userId,
                night: dateOnly(night),
                bedtime: bed.toISOString(),
                wake_time: wake.toISOString(),
                hours: hoursPattern[i],
                quality: qualityPattern[i],
                notes: i === 5 ? `rough night ${SCREENSHOT_MARK}` : SCREENSHOT_MARK,
            });
        }
        const { error, count } = await admin
            .from("manual_sleep_logs")
            .upsert(rows, { onConflict: "user_id,night", ignoreDuplicates: true, count: "exact" });
        if (error) errors.push(`sleep: ${error.message}`);
        else summary.sleep_logs = count ?? rows.length;
    } catch (e) { errors.push(`sleep: ${String(e)}`); }

    // ------ 14) Side effect log — durable historical entries ------
    // All entries are >48h old so the "side effect today" detector does NOT
    // fire; the protocol screen still shows a populated symptom timeline.
    try {
        if (protocolIdForFixtures) {
            const { count: existingSE } = await admin
                .from("side_effect_logs")
                .select("id", { count: "exact", head: true })
                .eq("protocol_id", protocolIdForFixtures)
                .ilike("notes", `%${SCREENSHOT_MARK}%`);
            if ((existingSE ?? 0) < 4) {
                const entries = [
                    { symptom: "Nausea", severity: 2, hoursAgo: 4 * 24 + 3,  notes: "mild — settled after a meal" },
                    { symptom: "Headache", severity: 2, hoursAgo: 6 * 24 + 7, notes: "front of head, water + nap helped" },
                    { symptom: "Fatigue", severity: 1, hoursAgo: 9 * 24 + 11, notes: "second half of the day" },
                    { symptom: "Injection site soreness", severity: 1, hoursAgo: 12 * 24 + 2, notes: "left abdomen, gone next morning" },
                ];
                const rows = entries.map((e) => ({
                    user_id: userId,
                    protocol_id: protocolIdForFixtures,
                    symptom: e.symptom,
                    severity: e.severity,
                    notes: `${e.notes} ${SCREENSHOT_MARK}`,
                    logged_at: new Date(now - e.hoursAgo * 3600 * 1000).toISOString(),
                }));
                const { error } = await admin.from("side_effect_logs").insert(rows);
                if (error) errors.push(`side effects: ${error.message}`);
                else summary.side_effects = rows.length;
            }
        }
    } catch (e) { errors.push(`side effects: ${String(e)}`); }

    // ------ 15) Streak + FP bump on profile ------
    try {
        await admin.from("profiles").update({
            current_streak: 47,
            total_fp: 12480,
        }).eq("id", userId);
    } catch (_) {}

    return json(200, {
        ok: errors.length === 0,
        version: "seed-v2",
        summary,
        errors: errors.length > 0 ? errors.slice(0, 10) : undefined,
    });
}

async function wipeMyScreenshotData(admin: SupabaseClient, userId: string): Promise<Response> {
    const deleted: Record<string, number> = {};
    async function del(table: string, builder: (q: ReturnType<typeof admin.from>) => unknown): Promise<void> {
        try {
            const q = admin.from(table).delete().eq("user_id", userId);
            const final = builder(q as unknown as ReturnType<typeof admin.from>);
            // deno-lint-ignore no-explicit-any
            const { count } = await (final as any).select("id", { count: "exact", head: true });
            deleted[table] = count ?? 0;
        } catch (_) { deleted[table] = 0; }
    }
    // Simpler approach: per-table tagged deletes
    try { await admin.from("feed_posts").delete().eq("user_id", userId).ilike("text_content", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    try { await admin.from("weight_logs").delete().eq("user_id", userId).ilike("note", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    try { await admin.from("workouts").delete().eq("user_id", userId).ilike("notes", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    try { await admin.from("activity_logs").delete().eq("user_id", userId).ilike("notes", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    try { await admin.from("daily_tasks").delete().eq("user_id", userId).ilike("description", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    try { await admin.from("bloodwork_entries").delete().eq("user_id", userId).ilike("notes", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    try { await admin.from("manual_sleep_logs").delete().eq("user_id", userId).ilike("notes", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    try { await admin.from("side_effect_logs").delete().eq("user_id", userId).ilike("notes", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    try { await admin.from("training_programs").delete().eq("user_id", userId).ilike("name", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    // Protocols (cascades to compounds, dose logs, side effects, supplements)
    try { await admin.from("protocols").delete().eq("user_id", userId).ilike("name", `%${SCREENSHOT_MARK}%`); } catch (_) {}
    // Vials by client_id prefix
    try { await admin.from("vials").delete().eq("user_id", userId).like("client_id", "screenshot-vial-%"); } catch (_) {}
    // PRs from our list
    try {
        const prIds = MY_PRS.map((p) => p.exercise_id);
        await admin.from("personal_records").delete().eq("user_id", userId).in("exercise_id", prIds);
    } catch (_) {}
    // Logged meals — meals don't have a mark column; only delete recent
    // ones that match our bank to avoid removing user's real data
    try {
        const names = MEAL_BANK.map((m) => m.name);
        await admin.from("logged_meals").delete().eq("user_id", userId).in("food_name", names);
    } catch (_) {}
    // Leave group memberships and DM threads intact — they're shared
    // social state with real personas; safe to keep across screenshot sessions.
    return json(200, { ok: true, version: "seed-v2", deleted_marker: SCREENSHOT_MARK });
}

// ---- Handler: generateFakePersonas (one-button wrapper) -------------
//
// Runs sequentially: seedTestFriends → deepPopulateAllFakes →
// bulkPopulateAllFakes. Accumulates counts. On phase error, returns
// { ok: false, phase, error, partial } with a 200 status so the client
// can render the partial result in the status line.

async function generateFakePersonas(
    admin: SupabaseClient,
    callerId: string,
): Promise<Response> {
    const partial: Record<string, number> = {
        personas: 0, workouts: 0, meals: 0, weights: 0, doses: 0, prs: 0,
        posts: 0, groups: 0, dm_threads: 0,
    };

    // Phase 1: seedTestFriends ------------------------------------------
    try {
        const resp = await seedTestFriends(admin, callerId, {});
        const body = await resp.json();
        partial.personas = Number(body?.total_test_profiles ?? 0) || 0;
        if (body?.ok === false) {
            return json(200, {
                ok: false, phase: "seedTestFriends",
                error: String(body?.error ?? "seed_failed"), partial,
            });
        }
    } catch (e) {
        return json(200, { ok: false, phase: "seedTestFriends", error: String(e), partial });
    }

    const richPartial: Record<string, unknown> = { ...partial };
    const skipped_tables = new Set<string>();
    let scenarioPersonas: string[] = [];

    // Phase 2: deepPopulateAllFakes -------------------------------------
    try {
        const resp = await deepPopulateAllFakes(admin, {});
        const body = await resp.json();
        partial.workouts = Number(body?.workouts ?? 0) || 0;
        partial.meals = Number(body?.meals ?? 0) || 0;
        partial.weights = Number(body?.weights ?? 0) || 0;
        partial.doses = Number(body?.dose_logs ?? body?.doses ?? 0) || 0;
        partial.prs = Number(body?.prs ?? 0) || 0;
        richPartial.water_logs = Number(body?.water_logs ?? 0) || 0;
        richPartial.step_logs = Number(body?.step_logs ?? 0) || 0;
        richPartial.bloodwork_panels = Number(body?.bloodwork_panels ?? 0) || 0;
        richPartial.biomarkers = Number(body?.biomarkers ?? 0) || 0;
        richPartial.side_effects = Number(body?.side_effects ?? 0) || 0;
        richPartial.daily_tasks = Number(body?.daily_tasks ?? 0) || 0;
        richPartial.sleep_logs = Number(body?.sleep_logs ?? 0) || 0;
        richPartial.vials = Number(body?.vials ?? 0) || 0;
        if (Array.isArray(body?.scenario_personas)) scenarioPersonas = body.scenario_personas as string[];
        if (Array.isArray(body?.skipped_tables)) for (const t of body.skipped_tables as string[]) skipped_tables.add(t);
    } catch (e) {
        return json(200, { ok: false, phase: "deepPopulateAllFakes", error: String(e), partial: { ...partial, ...richPartial } });
    }

    // Phase 3: bulkPopulateAllFakes -------------------------------------
    try {
        const resp = await bulkPopulateAllFakes(admin, { level: "medium" }, callerId);
        const body = await resp.json();
        partial.posts = Number(body?.posts_added ?? 0) || 0;
        partial.groups = Number(body?.groups_created ?? 0) || 0;
        partial.dm_threads = Number(body?.dm_pairs ?? 0) || 0;
        richPartial.comments = Number(body?.comments ?? 0) || 0;
        richPartial.comment_replies = Number(body?.comment_replies ?? 0) || 0;
        richPartial.group_members = Number(body?.group_members_added ?? 0) || 0;
        richPartial.group_posts = Number(body?.group_messages ?? 0) || 0;
        richPartial.dm_messages = Number(body?.dm_messages ?? 0) || 0;
        if (body?.ok === false) {
            return json(200, {
                ok: false, phase: "bulkPopulateAllFakes",
                error: String(body?.error ?? "bulk_failed"),
                partial: { ...partial, ...richPartial },
            });
        }
    } catch (e) {
        return json(200, { ok: false, phase: "bulkPopulateAllFakes", error: String(e), partial: { ...partial, ...richPartial } });
    }

    return json(200, {
        ok: true,
        version: "seed-v3",
        personas: partial.personas,
        workouts: partial.workouts,
        meals: partial.meals,
        weights: partial.weights,
        doses: partial.doses,
        prs: partial.prs,
        posts: partial.posts,
        groups: partial.groups,
        dm_threads: partial.dm_threads,
        water_logs: richPartial.water_logs ?? 0,
        step_logs: richPartial.step_logs ?? 0,
        bloodwork_panels: richPartial.bloodwork_panels ?? 0,
        biomarkers: richPartial.biomarkers ?? 0,
        side_effects: richPartial.side_effects ?? 0,
        sleep_logs: richPartial.sleep_logs ?? 0,
        daily_tasks: richPartial.daily_tasks ?? 0,
        vials: richPartial.vials ?? 0,
        comments: richPartial.comments ?? 0,
        group_members: richPartial.group_members ?? 0,
        group_posts: richPartial.group_posts ?? 0,
        dm_messages: richPartial.dm_messages ?? 0,
        scenario_personas: scenarioPersonas,
        skipped_tables: Array.from(skipped_tables),
    });
}

// ---- Entry point ------------------------------------------------------

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL");
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        if (!supabaseUrl || !serviceRoleKey) {
            return json(500, { error: "server_misconfigured" });
        }

        const admin = createClient(supabaseUrl, serviceRoleKey, {
            auth: { autoRefreshToken: false, persistSession: false },
        });

        const auth = await requireUser(req, admin);
        if ("response" in auth) return auth.response;

        let body: { action?: unknown; payload?: unknown } = {};
        try {
            body = await req.json();
        } catch (_) {
            body = {};
        }

        const action = typeof body.action === "string" ? body.action : "";
        const payload = (body.payload && typeof body.payload === "object")
            ? body.payload as Record<string, unknown>
            : {};

        switch (action) {
            case "ping":
                return json(200, { ok: true, version: "seed-v2", action: "ping" });
            case "seedTestFriends":
            case "seedFakeUsers":
                return await seedTestFriends(admin, auth.userId, payload);
            case "clearTestFriends":
            case "clearFakeUsers":
                return await clearTestFriends(admin);
            case "bootstrapFakeFollows":
                return await bootstrapFakeFollows(admin, auth.userId);
            case "friendsFeed":
                return await friendsFeed(admin, auth.userId);
            case "recordActivityEvent":
                return await recordActivityEvent(admin, auth.userId, payload);
            case "sendNudge":
                return await sendNudge(admin, auth.userId, payload);
            case "sendReaction":
                return await sendReaction(admin, auth.userId, payload);
            case "upsertSharingPrefs":
                return await upsertSharingPrefs(admin, auth.userId, payload);
            case "upsertWeeklySnapshot":
                return await upsertWeeklySnapshot(admin, auth.userId, payload);
            case "weeklyRecap":
                return await weeklyRecap(admin, auth.userId);
            case "weeklyRecapAll":
                return await weeklyRecapAll(admin, payload);
            case "sendPush":
                return await sendPushAction(admin, auth.userId, payload);
            case "deleteAccount":
                return await deleteAccount(admin, auth.userId);
            case "logClientError":
                return await logClientError(admin, auth.userId, payload);
            case "createFakeUser":
                return await createFakeUser(admin, auth.userId, payload);
            case "listFakeUsers":
                return await listFakeUsers(admin);
            case "rotateFakeUserPassword":
                return await rotateFakeUserPassword(admin, payload);
            case "generateFakeActivity":
                return await generateFakeActivity(admin, payload);
            case "deleteFakeUser":
                return await deleteFakeUser(admin, payload);
            case "bulkPopulateAllFakes":
                return await bulkPopulateAllFakes(admin, payload, auth.userId);
            case "screenshotSeedMe":
                return await screenshotSeedMe(admin, auth.userId);
            case "deepPopulateAllFakes":
            case "deepPopulateFake":
                return await deepPopulateAllFakes(admin, payload);
            case "deepPopulateFakePersona":
                return await deepPopulateFakePersonaAction(admin, payload);
            case "generateFakePersonas":
                return await generateFakePersonas(admin, auth.userId);
            case "wipeMyScreenshotData":
                return await wipeMyScreenshotData(admin, auth.userId);
            case "fakeDailyAutoLog":
                return await fakeDailyAutoLog(admin, payload);
            default:
                return json(400, { error: "unknown_action", action });
        }
    } catch (err) {
        console.error("super-action error", err);
        return json(500, { error: String(err) });
    }
});
