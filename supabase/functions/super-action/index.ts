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
        case "heavy": return { posts: 8, daysBack: 90, commentsPerPost: 4, likesPerPost: 8, dms: 6 };
        case "medium": return { posts: 5, daysBack: 60, commentsPerPost: 3, likesPerPost: 5, dms: 3 };
        case "light":
        default: return { posts: 3, daysBack: 30, commentsPerPost: 2, likesPerPost: 3, dms: 1 };
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
        if ((existingMsgs ?? 0) === 0) {
            const msgRows = seed.posts.map((text, i) => {
                const sender = matchingMembers[i % matchingMembers.length];
                const daysAgo = (seed.posts.length - i) * 4 + Math.floor(Math.random() * 3);
                return {
                    group_id: groupId, sender_id: sender, text_content: text,
                    created_at: new Date(Date.now() - daysAgo * 24 * 3600 * 1000).toISOString(),
                };
            });
            await admin.from("group_messages").insert(msgRows);
            messagesPosted += msgRows.length;
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
            return {
                user_id: f.id, text_content: text, media_urls: [], tags: persona?.interests ?? [],
                created_at: created, updated_at: created,
            };
        });
        if (rows.length > 0) {
            await admin.from("feed_posts").insert(rows);
            postsAdded += rows.length;
        }
    }

    const interactions = await generateCrossInteractions(admin, ids, level);
    const groups = await seedFakeGroups(admin, ids);
    const dms = await seedFakeDMs(admin, ids, level === "heavy" ? 30 : level === "medium" ? 18 : 8);

    return json(200, {
        ok: true,
        version: "seed-v2",
        fakes: ids.length,
        posts_added: postsAdded,
        likes: interactions.likes,
        comments: interactions.comments,
        groups_created: groups.groups,
        group_members_added: groups.members,
        group_messages: groups.messages,
        dm_pairs: dms.pairs,
        dm_messages: dms.messages,
    });
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
                return await bulkPopulateAllFakes(admin, payload);
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
