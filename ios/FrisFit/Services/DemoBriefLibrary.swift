import Foundation

/// Hardcoded Daily Brief responses per demo persona. Used to bypass the AI
/// roundtrip entirely while a persona is active so screenshots are 100%
/// deterministic and always mirror the persona's cross-stream "aha" scenario.
///
/// The AI brief pipeline has been too brittle across persona switches —
/// stale memos, JSON truncation on dense personas, "nothing logged yet" at
/// off-hours. For screenshot use, we want the brief to look exactly like
/// the data injected for that persona, every single time.
nonisolated enum DemoBriefLibrary {
    static func brief(for scenario: DemoScenario) -> TodaysPlanResponse {
        switch scenario {
        case .maya:    return mayaBrief
        case .priya:   return priyaBrief
        case .theo:    return theoBrief
        case .marcus:  return marcusBrief
        case .ava:     return avaBrief
        case .shayla:  return shaylaBrief
        }
    }

    // MARK: - Maya · rough sleep → adaptive lift

    private static let mayaBrief = TodaysPlanResponse(
        summary: "Maya, you're 6 weeks into the hypertrophy block and last night was the roughest sleep of the cycle — 4h 38m, HRV down 18%, RHR up 6. Today is Lower B on paper, but every time you've squatted under 6 hours of sleep this block the bar speed dropped and Thursday's upper day suffered. We're cutting working volume in half, keeping intensity, and reflowing the missed sets into next week.",
        modules: [
            TodaysPlanModule(
                type: "training",
                title: "Lower B — half-volume mode",
                content: "Back squat 3x5 at your working 185 instead of 5x5, then RDL 3x6 and hip thrust 3x8. Same intensity, half the damage. Your last three sub-6h nights all bled into Thursday's pressing — protecting today protects the rest of the week."
            ),
            TodaysPlanModule(
                type: "body",
                title: "Recomp on track",
                content: "139.4 lb, 1.4 lb from goal and 2.6 lb down from your starting 142. Trajectory is exactly where it should be at week 6 — nothing here calls for a calorie change."
            ),
            TodaysPlanModule(
                type: "nutrition",
                title: "145g protein floor",
                content: "Protein adherence has been 130–150g for 12 of the last 14 days. Recovery on a short-sleep night leans hardest on protein — front-load 40g at lunch so dinner isn't doing all the work."
            )
        ],
        actionItems: [
            PlanActionItem(title: "Accept half-volume Lower B", icon: "figure.strengthtraining.traditional", category: "Fitness", reason: "HRV -18% and 4h 38m sleep — half volume protects Thursday's upper day."),
            PlanActionItem(title: "Front-load 40g protein at lunch", icon: "fork.knife", category: "Nutrition", reason: "Recovery debt is highest after sub-6h sleep; lunch is your best protein anchor."),
            PlanActionItem(title: "10-min mobility flow tonight", icon: "figure.cooldown", category: "Wellness", reason: "Light parasympathetic work on a low-HRV day; pairs with an earlier wind-down.")
        ],
        narrative: BriefNarrative(
            greeting: "Morning, Maya.",
            headline: "4h 38m sleep + HRV -18% — Lower B drops to half volume today.",
            body: "You slept 4h 38m vs your 7.1h baseline and HRV came back -18%. Lower B is on the board, but your last three under-6h nights all spilled into Thursday's push day. We're keeping the bar weight (185 working) and cutting to 3x5 — something beats nothing here, and lifting heavy through this likely costs you Thursday. Accept the bundle in one tap; the missed volume reflows into next week.",
            watchFor: "If bar speed feels off on the first working set, drop to 175 and stay at 3x5 — don't chase 185 today.",
            adaptiveCallout: AdaptiveCallout(
                trigger: "Slept 4h 38m vs 7.1h avg · HRV -18% · RHR +6",
                recommendation: "Half-volume Lower B today: 3x5 at 185 instead of 5x5. Missed sets reflow into next week."
            )
        )
    )

    // MARK: - Priya · dose-day GI → nutrition pivot

    private static let priyaBrief = TodaysPlanResponse(
        summary: "Priya, you logged GI discomfort 4 hours after yesterday's Tirzepatide 5mg dose — right on your usual pattern. You're 6 weeks in, 23.2 lb down from your 198 start, on the conservative side of ideal at -0.9 lb/week. Today and tomorrow we're pivoting nutrition: lower-fat, lower-FODMAP, protein-first. Full Body Beginner is scheduled for tomorrow — we'll keep it on the board but soften it if dose-day fatigue is still there.",
        modules: [
            TodaysPlanModule(
                type: "protocol",
                title: "Tirzepatide week 6",
                content: "5mg subq yesterday — peak window now, declining through Thursday. Appetite suppression is highest in the next 24h, which is exactly when protein adherence usually slips for you. The dose-day → GI pattern has held for 5 of the last 6 weeks; the playbook is the same."
            ),
            TodaysPlanModule(
                type: "nutrition",
                title: "Low-FODMAP for 48h",
                content: "Calorie target stays 1,500, protein floor stays 130g. Swap the usual lunch burrito for the rice bowl, skip onion/garlic in tonight's prep, lean on eggs and grilled chicken. Lower fat helps too — the heavy-fat meals are what spike the post-dose GI."
            ),
            TodaysPlanModule(
                type: "training",
                title: "Full Body Beginner tomorrow",
                content: "Last session: goblet squat 30 lb x 10, DB row 25 lb x 12, push-up x 8. If GI is still rough tomorrow, drop to 2 sets per lift instead of 3. The point right now is consistency, not load."
            ),
            TodaysPlanModule(
                type: "body",
                title: "174.8 lb, 16.8 to goal",
                content: "Averaging -0.9 lb/week — the muscle-preservation pace we want on Tirz. 7 of the last 14 days hit the 130g protein floor; that number is the biggest lever for keeping lean mass through the cut."
            )
        ],
        actionItems: [
            PlanActionItem(title: "Swap lunch burrito → rice bowl", icon: "fork.knife", category: "Nutrition", reason: "GI discomfort logged 4h post-dose; low-FODMAP for 48h."),
            PlanActionItem(title: "Pre-log tomorrow's breakfast (40g protein)", icon: "checklist", category: "Nutrition", reason: "Dose-day evenings are your biggest protein miss — front-load tomorrow."),
            PlanActionItem(title: "Hydrate 16 oz before bed", icon: "drop.fill", category: "Wellness", reason: "Post-dose GI clears faster with steady fluid intake."),
            PlanActionItem(title: "Log tonight's GI severity", icon: "exclamationmark.triangle.fill", category: "Wellness", reason: "Tracking the pattern across dose days informs next week's titration conversation.")
        ],
        narrative: BriefNarrative(
            greeting: "Hey Priya.",
            headline: "Dose-day GI logged — nutrition pivots low-FODMAP for 48h.",
            body: "You're 6 weeks into Tirz 5mg, 23.2 lb down from your 198 start, and yesterday's dose hit your usual GI pattern at the 4-hour mark. We're swapping today's plan to lower-fat, lower-FODMAP meals for 48h — the rice bowl over the burrito, skip the onion/garlic, lean on eggs and grilled chicken. Protein floor stays 130g; that's what protects lean mass on a GLP-1. Tomorrow's Full Body Beginner is still on the board, soften to 2 sets per lift if GI is still rough.",
            watchFor: "If GI severity climbs above where you usually land (mild → moderate), bring it up at your next provider check-in — that's titration territory, not a today problem.",
            adaptiveCallout: AdaptiveCallout(
                trigger: "GI discomfort logged 4h after Tirzepatide dose · 5/6 weeks pattern",
                recommendation: "Low-FODMAP, lower-fat meals for 48h. Camera swap suggested at lunch."
            )
        )
    )

    // MARK: - Theo · missed BPC-157 → recalibrated week

    private static let theoBrief = TodaysPlanResponse(
        summary: "Theo, you missed Wednesday's BPC-157 evening dose. Compound level dipped through Thursday and is sitting at ~62% of your usual baseline this week. Tendon support is the lowest it's been since the rebuild started, and Saturday's heavy pull is on the schedule. Not pulling the plug — just flagging the soft-warning. 5/3/1 BBB is otherwise running clean: squat 365 working, pull 425 top single last week, bench still 10% off pre-injury.",
        modules: [
            TodaysPlanModule(
                type: "protocol",
                title: "BPC-157 250mcg · 1 dose down this week",
                content: "Twice-daily plan, Wednesday PM skipped. PK level ~62% of typical Friday baseline. TB-500 weekly was on time Monday so the longer-acting support is fine — the daily floor is what's soft. Tonight's dose puts you back on the curve by Saturday morning."
            ),
            TodaysPlanModule(
                type: "training",
                title: "Saturday pull — soft-warning",
                content: "Last top single 425 felt clean. With tendon support below your usual baseline, the call is: hit the working 365x5 on volume, then make the decision on a top single by feel — not for ego. Historically your tendon flare-ups have followed missed BPC days within 48h; tomorrow morning is the read."
            ),
            TodaysPlanModule(
                type: "body",
                title: "201.2 lb, slow lean gain",
                content: "On track for the 205 target. Calorie average 2,950, protein 195g across the last 14 days — both inside the target band, no changes needed."
            )
        ],
        actionItems: [
            PlanActionItem(title: "Take tonight's BPC-157", icon: "syringe.fill", category: "Wellness", reason: "Missed Wednesday PM; tonight's dose restores the daily floor before Saturday."),
            PlanActionItem(title: "Soft-warning Saturday pull", icon: "exclamationmark.triangle.fill", category: "Fitness", reason: "Tendon support 38% below baseline; volume yes, top single by feel."),
            PlanActionItem(title: "Log shoulder/tendon feel tomorrow AM", icon: "pencil.and.list.clipboard", category: "Wellness", reason: "Historical pattern: flare-ups follow missed BPC days within 48h."),
            PlanActionItem(title: "Push Sunday's pull to Monday if needed", icon: "calendar.badge.clock", category: "Fitness", reason: "Pre-authorized reshuffle so a 24h delay doesn't break the BBB block.")
        ],
        narrative: BriefNarrative(
            greeting: "Morning, Theo.",
            headline: "Missed BPC Wednesday — tendon support 38% under baseline before Saturday's pull.",
            body: "BPC-157 didn't get logged Wednesday PM, and your circulating level is sitting at ~62% of where it usually is this point in the week. TB-500 was on time Monday so the long-acting support is fine — the daily floor is what's soft. 425 felt clean last week, but I'd hit the 365x5 working sets first and make the top-single call by feel on Saturday. Tonight's BPC puts you back on the curve. If the right shoulder talks tomorrow morning, push the session to Monday — pre-authorized, no break to the BBB block.",
            watchFor: "Right shoulder tightness or tendon irritability before warmup Saturday — that's the read on whether the missed dose actually mattered.",
            adaptiveCallout: AdaptiveCallout(
                trigger: "BPC-157 missed Wed PM · level 62% of typical Friday baseline",
                recommendation: "Soft-warning on Saturday's top single. Hit working volume, decide top set by feel."
            )
        )
    )

    // MARK: - Marcus · bloodwork drift → protocol + plate

    private static let marcusBrief = TodaysPlanResponse(
        summary: "Marcus, the last three liver panels are the story. ALT moved 38 → 52 → 68 over your last three draws, LDL crept from 118 → 134, and your last panel is 78 days old now — past your usual 90-day cadence by 12 days. The trend is mild and below clinical alarm, but it's a trend, and it lines up with month 14 of TRT plus nightly Ipamorelin. Today's nutrition starts prioritizing omega-3 and fiber; hydration goal bumps to 4L. Worth a conversation with your provider before the next draw — these are the two compounds most associated.",
        modules: [
            TodaysPlanModule(
                type: "bloodwork",
                title: "Last 3 panels — ALT 38 → 52 → 68",
                content: "Mild ALT drift, still inside the upper bound but trending one direction. LDL 118 → 126 → 134. AST stable, lipids otherwise unremarkable. Schedule the next panel within the next 10 days so you have the read before any protocol decisions."
            ),
            TodaysPlanModule(
                type: "protocol",
                title: "TRT + Ipamorelin · month 14",
                content: "Test Cyp 100mg/wk and nightly Ipamorelin both have light hepatic signal in the literature, especially when paired. Not stopping anything — the order of operations is panel first, then conversation. Today's dose is logged and on time."
            ),
            TodaysPlanModule(
                type: "nutrition",
                title: "Omega-3 + fiber priority · 4L water",
                content: "Calorie target stays 2,600, protein 180g. Today's plate prioritizes salmon, walnuts, leafy greens, and a 30g fiber floor. Cut alcohol entirely until the next panel; the swing on ALT is bigger than the average person realizes."
            ),
            TodaysPlanModule(
                type: "training",
                title: "Optimizer PPL — adherence 95%",
                content: "188.6 lb, 1.4 lb to target. Push day on the board, last bench 245x6 felt clean. Nothing in the bloodwork changes today's session."
            )
        ],
        actionItems: [
            PlanActionItem(title: "Schedule next bloodwork", icon: "drop.fill", category: "Wellness", reason: "Last panel 78 days old; ALT and LDL trending — get the read."),
            PlanActionItem(title: "Note labs trend for provider call", icon: "pencil.and.list.clipboard", category: "Wellness", reason: "ALT 38 → 52 → 68 with LDL drift — your provider should see the trajectory."),
            PlanActionItem(title: "Add salmon or walnuts at lunch", icon: "fork.knife", category: "Nutrition", reason: "Omega-3 priority while liver markers settle."),
            PlanActionItem(title: "Hit 4L water today", icon: "drop.fill", category: "Wellness", reason: "Bumped from 3.5L to support hepatic clearance through the next panel.")
        ],
        narrative: BriefNarrative(
            greeting: "Marcus.",
            headline: "ALT 38 → 52 → 68 across your last 3 panels — labs first, then conversation.",
            body: "Your last three liver panels tell a story: ALT 38 → 52 → 68, LDL 118 → 134, last draw 78 days ago. Mild, still below clinical alarm, but it's a trend and it lines up with month 14 of TRT plus nightly Ipamorelin — the two compounds most associated. Today's plate prioritizes omega-3 and fiber, hydration goal bumps to 4L, alcohol stays at zero until the next panel. Order of operations: schedule labs in the next 10 days, then bring the trajectory to your provider — not a dose decision to make from the dashboard.",
            watchFor: "Any new fatigue, RUQ discomfort, or sleep disruption — those would change the urgency on the panel from 'this month' to 'this week.'",
            adaptiveCallout: AdaptiveCallout(
                trigger: "ALT 38 → 52 → 68 · LDL 118 → 134 · panel 78 days old",
                recommendation: "Omega-3 + fiber priority today, 4L water, schedule the next draw within 10 days."
            )
        )
    )

    // MARK: - Ava · RHR elevated 5 days → fork

    private static let avaBrief = TodaysPlanResponse(
        summary: "Ava, RHR is up +8 bpm on 5 straight mornings with sleep holding at 7.9h and HRV unchanged in the mid-50s. That pattern usually means one of two things — early overtraining from week 8 of base block 2, or something viral incubating. You're at the fork. If you feel fine, this week deloads 30%. If you feel off, peptides pause and the focus shifts to sleep + hydration. Either way, today's interval session moves to easy mileage until you make the call.",
        modules: [
            TodaysPlanModule(
                type: "training",
                title: "Base block 2 · week 8 of 16",
                content: "Five sessions/week with intervals on Thursday and the long run Sunday. Mileage held week-over-week. Today's intervals shift to a 40-min Z2 easy until the fork is called. If 'feeling fine' wins, week 9 is the deload — drop mileage 30%, keep one tempo, drop intervals entirely."
            ),
            TodaysPlanModule(
                type: "protocol",
                title: "Ipamorelin · tendon recovery",
                content: "Low-dose nightly. If 'feeling off' wins the fork, pause for 5-7 days. The peptide isn't driving today's RHR but cutting non-essential variables makes the read on next week cleaner."
            ),
            TodaysPlanModule(
                type: "nutrition",
                title: "2,400 cal · 330g carbs",
                content: "Adherence has been steady — no signal here. If illness is the fork, bump fluids and electrolytes by 30%. If overtraining, hold the numbers — calorie deficits inside an elevated-RHR week are how you turn a deload into a real setback."
            )
        ],
        actionItems: [
            PlanActionItem(title: "Pick the fork: feeling fine vs feeling off", icon: "questionmark.circle.fill", category: "Wellness", reason: "RHR +8 on 5 straight mornings with sleep & HRV stable — the read is yours to make."),
            PlanActionItem(title: "Swap today's intervals for 40min Z2", icon: "figure.run", category: "Fitness", reason: "Either fork answer points to easy mileage today; intervals can wait 48h."),
            PlanActionItem(title: "Log temperature this morning", icon: "thermometer", category: "Wellness", reason: "A low-grade reading clarifies the fork faster than another day of waiting."),
            PlanActionItem(title: "Hide social challenge invites", icon: "bell.slash.fill", category: "Lifestyle", reason: "Pre-set so a low-RHR week doesn't get derailed by leaderboard pressure.")
        ],
        narrative: BriefNarrative(
            greeting: "Morning, Ava.",
            headline: "RHR +8 for 5 days straight — overtraining vs illness fork is on the board.",
            body: "Resting HR is up 8 bpm on 5 consecutive mornings with sleep holding at 7.9h and HRV mid-50s — that combination usually means early overtraining from base block 2 or a virus incubating. You're at the fork. Today's intervals drop to a 40-minute Z2 either way. If you tap 'feeling fine,' week 9 becomes the deload (mileage -30%, intervals out). If you tap 'feeling off,' Ipamorelin pauses, social challenges hide, and the focus is sleep, fluids, and a temp reading by tomorrow morning. The call is yours; the playbook is already set.",
            watchFor: "Sore throat, low-grade fever, or HRV finally crashing — any of those flip the fork to 'feeling off' regardless of mileage feel.",
            adaptiveCallout: AdaptiveCallout(
                trigger: "RHR +8 bpm × 5 mornings · sleep 7.9h stable · HRV mid-50s",
                recommendation: "Two-path prompt: feeling fine → 30% deload week. Feeling off → peptides pause, sleep + hydration."
            )
        )
    )

    // MARK: - Shayla · borrowed protocol → safer dose

    private static let shaylaBrief = TodaysPlanResponse(
        summary: "Shayla, you borrowed Marcus's TRT-style stack from the feed yesterday — he runs Test Cyp at 100mg/wk. Cross-checking your last panel, your current sleep average (6.4h), and 18 months of training data, the start dose for your context is 50mg/wk for the first two weeks, not 100. Same compound, your math. Upper/Lower 4x is otherwise solid — hip thrust 165, cable row 90, incline DB press 30 — and the cut is on pace at 149.8 lb, 4.8 lb from goal.",
        modules: [
            TodaysPlanModule(
                type: "protocol",
                title: "Test Cyp · start at 50mg/wk",
                content: "Marcus runs 100mg because he's 41, 14 months in, with established labs. You're 27, year 2 of training, last panel was unremarkable but baseline-only. 50mg for the first 2 weeks lets you watch for sleep, mood, and skin shifts before stepping up. Borrowing the protocol is fine — using his dose isn't."
            ),
            TodaysPlanModule(
                type: "training",
                title: "Upper/Lower 4x · year 2",
                content: "Lifts are moving — hip thrust progressed 10 lb in 4 weeks, cable row at 90, incline DB 30. Nothing in the borrowed protocol changes this week's plan. Cut is on a 0.4 lb/week pace, conservative but sticking."
            ),
            TodaysPlanModule(
                type: "nutrition",
                title: "1,800 cal · 140g protein",
                content: "Weekday adherence 85%, weekends drift +400 cal. If you start any TRT-style protocol, that weekend drift becomes a much bigger signal — lean mass swings are easier to read on consistent calories."
            ),
            TodaysPlanModule(
                type: "bloodwork",
                title: "Baseline panel before anything else",
                content: "Last labs were screening-level only. Before you run anything in the Test Cyp family, pull a full panel with total T, free T, estradiol, SHBG, hematocrit, lipids, and liver enzymes. That's the receipt you'll want against the next draw."
            )
        ],
        actionItems: [
            PlanActionItem(title: "Set borrowed Test Cyp dose to 50mg", icon: "syringe.fill", category: "Wellness", reason: "Marcus runs 100mg at month 14; your context says start at half-dose."),
            PlanActionItem(title: "Order baseline labs this week", icon: "drop.fill", category: "Wellness", reason: "Total T, free T, E2, SHBG, hematocrit, lipids, liver — the read before anything moves."),
            PlanActionItem(title: "Tighten weekend calorie window", icon: "fork.knife", category: "Nutrition", reason: "+400 cal weekend drift makes any compound response harder to read."),
            PlanActionItem(title: "Log sleep + mood daily for 14 days", icon: "moon.fill", category: "Wellness", reason: "The earliest TRT signals show up in sleep and mood before they show on a scale.")
        ],
        narrative: BriefNarrative(
            greeting: "Hey Shayla.",
            headline: "Borrowed Marcus's stack — your context says start at 50mg, not 100.",
            body: "You pulled Marcus's protocol from the feed yesterday. He runs Test Cyp at 100mg/wk, but he's 41, 14 months in, with three panels of receipts. You're 27, year 2 of training, last labs were screening-only, sleep averaging 6.4h. The math your data supports is 50mg/wk for the first two weeks while you watch sleep, mood, and skin — then re-evaluate. Order a full baseline panel (total T, free T, E2, SHBG, hematocrit, lipids, liver) this week so the next draw has something to compare against. Borrowing protocols is fine; copying doses isn't.",
            watchFor: "Sleep dropping below 6h, mood swings, or skin shifts in the first 2 weeks — any of those means hold the dose, not step it up.",
            adaptiveCallout: AdaptiveCallout(
                trigger: "Borrowed Test Cyp 100mg from Marcus · your sleep 6.4h, no baseline labs",
                recommendation: "Start at 50mg/wk for 2 weeks, pull a full baseline panel before any step-up."
            )
        )
    )
}
