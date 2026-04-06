import Foundation

enum CompoundDatabase {
    static let all: [CompoundProfile] = [
        // MARK: - Category 1: Growth Hormone Secretagogues

        CompoundProfile(
            name: "Sermorelin",
            peptideType: "GHRH Analog",
            categories: [.muscleGrowth, .antiAging],
            overview: "A synthetic analog of naturally occurring Growth Hormone-Releasing Hormone (GHRH). It binds to the GHRH receptor in the anterior pituitary gland, stimulating the secretion of endogenous growth hormone. Considered the mildest GHRH analog, making it an excellent starting point for beginners.",
            protocols: [
                CompoundProtocol(goalName: "Anti-Aging & Recovery", description: "Pre-bed fasted administration for GH pulse", typicalDose: "200-300 mcg", frequency: "1x daily", duration: "12-24 weeks"),
                CompoundProtocol(goalName: "Advanced Protocol", description: "Morning fasted + pre-bed fasted", typicalDose: "300 mcg", frequency: "2x daily", duration: "12-24 weeks"),
            ],
            sideEffects: ["Injection site reaction", "Flushing", "Mild headache", "Water retention", "Lethargy"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction", severity: .mild, frequency: 18),
                CompoundSideEffect(name: "Flushing", severity: .mild, frequency: 15),
                CompoundSideEffect(name: "Mild Headache", severity: .mild, frequency: 10),
                CompoundSideEffect(name: "Water Retention", severity: .mild, frequency: 12),
            ],
            communityUsers: 1856,
            averageRating: 4.3,
            stackPartners: ["Ipamorelin", "GHRP-2"],
            iconName: "arrow.up.heart.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "3,358 Da", administrationRoute: "Subcutaneous", halfLife: "10-20 min", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "200-300 mcg")
        ),
        CompoundProfile(
            name: "CJC-1295",
            peptideType: "GHRH Analog",
            categories: [.muscleGrowth, .antiAging],
            overview: "A modified version of the shortest fully functional fragment of GHRH. Available with and without DAC (Drug Affinity Complex). The no-DAC version produces natural pulsatile GH release, while the DAC version provides sustained, continuous GH elevation over days. Often paired with Ipamorelin for synergistic effects.",
            protocols: [
                CompoundProtocol(goalName: "GH Optimization (No DAC)", description: "Combined with Ipamorelin for synergistic effect", typicalDose: "100 mcg", frequency: "1-3x daily (fasted)", duration: "12-16 weeks"),
                CompoundProtocol(goalName: "Sustained GH (With DAC)", description: "Continuous IGF-1 elevation with infrequent dosing", typicalDose: "1-2 mg", frequency: "1x weekly", duration: "8-12 weeks"),
            ],
            sideEffects: ["Water retention", "Tingling/numbness", "Increased hunger", "Fatigue", "Head rush"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Water Retention", severity: .moderate, frequency: 35),
                CompoundSideEffect(name: "Tingling / Numbness", severity: .mild, frequency: 22),
                CompoundSideEffect(name: "Increased Hunger", severity: .mild, frequency: 28),
                CompoundSideEffect(name: "Head Rush", severity: .mild, frequency: 18),
                CompoundSideEffect(name: "Fatigue", severity: .mild, frequency: 15),
            ],
            communityUsers: 2156,
            averageRating: 4.4,
            stackPartners: ["Ipamorelin", "MK-677", "GHRP-6"],
            iconName: "arrow.up.right",
            keyFacts: CompoundKeyFacts(molecularWeight: "3,367 Da", administrationRoute: "Subcutaneous", halfLife: "~30 min (no DAC) / ~8 days (DAC)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100 mcg (no DAC) / 1-2 mg (DAC)")
        ),
        CompoundProfile(
            name: "Ipamorelin",
            peptideType: "Growth Hormone Releasing Peptide",
            categories: [.muscleGrowth, .antiAging],
            overview: "A selective growth hormone secretagogue that stimulates GH release without significantly affecting cortisol or prolactin. Considered the 'cleanest' GHRP available — it doesn't spike hunger, cortisol, or prolactin. Almost always stacked with a GHRH like CJC-1295 for a synergistic GH pulse much larger than either compound alone.",
            protocols: [
                CompoundProtocol(goalName: "Lean Mass & Recovery", description: "Often paired with CJC-1295 No DAC", typicalDose: "100-300 mcg", frequency: "1-3x daily (fasted)", duration: "12-16 weeks"),
            ],
            sideEffects: ["Mild hunger increase", "Water retention (mild)", "Head rush"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Hunger Increase", severity: .mild, frequency: 20),
                CompoundSideEffect(name: "Water Retention", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Head Rush", severity: .mild, frequency: 8),
            ],
            communityUsers: 1876,
            averageRating: 4.6,
            stackPartners: ["CJC-1295", "Tesamorelin", "BPC-157"],
            iconName: "figure.strengthtraining.traditional",
            keyFacts: CompoundKeyFacts(molecularWeight: "711 Da", administrationRoute: "Subcutaneous", halfLife: "~2 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100-300 mcg")
        ),
        CompoundProfile(
            name: "Tesamorelin",
            peptideType: "GHRH Analog (FDA Approved)",
            categories: [.weightLoss, .muscleGrowth],
            overview: "An FDA-approved GHRH analog originally for HIV-associated lipodystrophy. The most potent GHRH for targeted visceral fat reduction. Known as the 'Rolls Royce' of fat-loss peptides due to its specific efficacy against stubborn visceral fat. Degrades faster than other peptides once reconstituted — use within 7 days.",
            protocols: [
                CompoundProtocol(goalName: "Visceral Fat Reduction", description: "Targets visceral adiposity specifically", typicalDose: "1-2 mg", frequency: "1x daily (fasted)", duration: "12-16 weeks"),
            ],
            sideEffects: ["Injection site reactions", "Joint pain", "Peripheral edema", "Flushing"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reactions", severity: .mild, frequency: 25),
                CompoundSideEffect(name: "Joint Pain", severity: .moderate, frequency: 15),
                CompoundSideEffect(name: "Peripheral Edema", severity: .moderate, frequency: 12),
                CompoundSideEffect(name: "Flushing", severity: .mild, frequency: 10),
            ],
            communityUsers: 987,
            averageRating: 4.5,
            stackPartners: ["Ipamorelin", "CJC-1295"],
            iconName: "flame.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "5,136 Da", administrationRoute: "Subcutaneous", halfLife: "~26-38 min", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "1-2 mg")
        ),
        CompoundProfile(
            name: "MK-677",
            peptideType: "Non-Peptide Ghrelin Receptor Agonist",
            categories: [.muscleGrowth, .antiAging],
            overview: "An orally active, non-peptide ghrelin receptor agonist. Mimics ghrelin to stimulate sustained, pulsatile GH and IGF-1 release over 24 hours. Significantly increases appetite and can elevate blood glucose. The biggest risk is insulin resistance — monitoring fasting blood glucose is mandatory. Taking it before bed helps mitigate intense hunger.",
            protocols: [
                CompoundProtocol(goalName: "GH Elevation", description: "Oral dosing, typically before bed to sleep through hunger", typicalDose: "10-25 mg", frequency: "1x daily", duration: "12-24 weeks"),
            ],
            sideEffects: ["Increased appetite", "Water retention", "Numbness/tingling", "Elevated blood sugar", "Lethargy"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Intense Appetite", severity: .significant, frequency: 65),
                CompoundSideEffect(name: "Water Retention", severity: .moderate, frequency: 45),
                CompoundSideEffect(name: "Numbness / Tingling", severity: .mild, frequency: 20),
                CompoundSideEffect(name: "Elevated Blood Sugar", severity: .moderate, frequency: 18),
                CompoundSideEffect(name: "Lethargy", severity: .mild, frequency: 25),
            ],
            communityUsers: 3214,
            averageRating: 4.2,
            stackPartners: ["CJC-1295", "Ipamorelin", "LGD-4033"],
            iconName: "pills.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "528 Da", administrationRoute: "Oral", halfLife: "~24 hours", storageTemp: "Room Temp", reconstitution: "N/A (oral)", typicalDoseRange: "10-25 mg")
        ),
        CompoundProfile(
            name: "GHRP-2",
            peptideType: "Growth Hormone Releasing Peptide",
            categories: [.muscleGrowth],
            overview: "A potent synthetic ghrelin agonist that stimulates a strong pulse of growth hormone release. Less selective than Ipamorelin — causes mild elevations in cortisol and prolactin, and stimulates appetite. Stronger than Ipamorelin but with more side effects. If hunger is too intense, switch to Ipamorelin.",
            protocols: [
                CompoundProtocol(goalName: "Muscle Growth", description: "Pre-bed fasted for maximum GH pulse", typicalDose: "100-150 mcg", frequency: "1-3x daily (fasted)", duration: "8-12 weeks"),
            ],
            sideEffects: ["Increased appetite", "Water retention", "Flushing", "Elevated prolactin"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Increased Appetite", severity: .moderate, frequency: 40),
                CompoundSideEffect(name: "Water Retention", severity: .moderate, frequency: 30),
                CompoundSideEffect(name: "Flushing", severity: .mild, frequency: 20),
                CompoundSideEffect(name: "Elevated Prolactin", severity: .mild, frequency: 15),
            ],
            communityUsers: 1245,
            averageRating: 4.1,
            stackPartners: ["CJC-1295"],
            iconName: "bolt.heart.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "818 Da", administrationRoute: "Subcutaneous", halfLife: "15-30 min", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100-150 mcg")
        ),
        CompoundProfile(
            name: "GHRP-6",
            peptideType: "Growth Hormone Releasing Peptide",
            categories: [.muscleGrowth],
            overview: "A first-generation ghrelin agonist notorious for extreme, uncontrollable hunger within 20-30 minutes of injection. Elevates cortisol and prolactin more than newer GHRPs. Used exclusively by bodybuilders needing 4,000+ calories/day who physically cannot eat enough otherwise. Also speeds up gastric emptying.",
            protocols: [
                CompoundProtocol(goalName: "Extreme Bulking", description: "Pre-meal for appetite stimulation", typicalDose: "100-150 mcg", frequency: "1-3x daily (pre-meal)", duration: "8-12 weeks"),
            ],
            sideEffects: ["Extreme hunger", "Water retention", "Flushing", "Gynecomastia risk", "Lethargy"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Extreme Hunger", severity: .significant, frequency: 85),
                CompoundSideEffect(name: "Water Retention", severity: .moderate, frequency: 40),
                CompoundSideEffect(name: "Flushing", severity: .mild, frequency: 25),
                CompoundSideEffect(name: "Elevated Prolactin", severity: .moderate, frequency: 20),
            ],
            communityUsers: 890,
            averageRating: 3.8,
            stackPartners: ["CJC-1295"],
            iconName: "fork.knife",
            keyFacts: CompoundKeyFacts(molecularWeight: "873 Da", administrationRoute: "Subcutaneous", halfLife: "15-30 min", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100-150 mcg")
        ),
        CompoundProfile(
            name: "Hexarelin",
            peptideType: "Growth Hormone Releasing Peptide",
            categories: [.muscleGrowth],
            overview: "The most potent GHRP available, causing a massive release of GH. Also causes the most significant elevations in cortisol and prolactin. Does not significantly stimulate appetite unlike GHRP-6. Known for causing rapid pituitary desensitization — should not be used for more than 4-8 weeks. Reserved for advanced users needing maximum GH output short-term.",
            protocols: [
                CompoundProtocol(goalName: "Maximum GH Burst", description: "Short-term blast for rapid injury recovery", typicalDose: "100-200 mcg", frequency: "1-2x daily (fasted)", duration: "4-8 weeks max"),
            ],
            sideEffects: ["Water retention", "Flushing", "Lethargy", "Elevated prolactin/cortisol"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Water Retention", severity: .moderate, frequency: 40),
                CompoundSideEffect(name: "Flushing", severity: .mild, frequency: 30),
                CompoundSideEffect(name: "Lethargy", severity: .mild, frequency: 25),
                CompoundSideEffect(name: "Elevated Prolactin", severity: .moderate, frequency: 35),
            ],
            communityUsers: 567,
            averageRating: 3.9,
            stackPartners: ["CJC-1295"],
            iconName: "bolt.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "887 Da", administrationRoute: "Subcutaneous", halfLife: "1-2 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100-200 mcg")
        ),

        // MARK: - Category 2: Healing & Recovery

        CompoundProfile(
            name: "BPC-157",
            peptideType: "Pentadecapeptide (Gastric Juice Derivative)",
            categories: [.healing, .muscleGrowth],
            overview: "A synthetic 15-amino acid sequence derived from a protective protein in human gastric juice. Accelerates angiogenesis, modulates nitric oxide, and upregulates growth hormone receptors in healing tissues. For musculoskeletal injuries, inject SubQ near the injury site. For gut issues (IBS, reflux), oral administration using the Arginate salt form is far superior.",
            protocols: [
                CompoundProtocol(goalName: "Injury Recovery", description: "SubQ near injury site for localized tissue repair", typicalDose: "250-500 mcg", frequency: "1-2x daily", duration: "4-8 weeks"),
                CompoundProtocol(goalName: "Gut Health", description: "Oral Arginate form for GI tract healing", typicalDose: "250-500 mcg", frequency: "1-2x daily", duration: "4-8 weeks"),
            ],
            sideEffects: ["Mild injection site reaction", "Lethargy (rare)", "Mild headache"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Lethargy", severity: .mild, frequency: 5),
                CompoundSideEffect(name: "Mild Headache", severity: .mild, frequency: 4),
            ],
            communityUsers: 2847,
            averageRating: 4.7,
            stackPartners: ["TB-500", "GHK-Cu", "KPV"],
            iconName: "cross.case.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,419 Da", administrationRoute: "SubQ / Oral (Arginate)", halfLife: "<30 min (effects longer)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "250-500 mcg")
        ),
        CompoundProfile(
            name: "TB-500",
            peptideType: "Actin-Binding Protein Fragment",
            categories: [.healing, .muscleGrowth],
            overview: "A synthetic version of the active region of Thymosin Beta-4. Upregulates actin to promote rapid cellular migration to injury sites, reduces inflammation, and improves flexibility. Highly systemic — no need to inject near injury site. Loading phase is critical: 5-7 mg/week for the first month. Many users report significant lethargy after injection, so pin before bed.",
            protocols: [
                CompoundProtocol(goalName: "Loading Phase", description: "Systemic tissue repair with loading protocol", typicalDose: "2-2.5 mg", frequency: "2-3x weekly", duration: "4-6 weeks"),
                CompoundProtocol(goalName: "Maintenance", description: "Sustain healing after loading phase", typicalDose: "2 mg", frequency: "1x weekly", duration: "Ongoing"),
            ],
            sideEffects: ["Lethargy", "Head rush", "Flu-like symptoms (rare)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Lethargy", severity: .moderate, frequency: 30),
                CompoundSideEffect(name: "Head Rush", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Flu-like Symptoms", severity: .mild, frequency: 5),
            ],
            communityUsers: 1923,
            averageRating: 4.5,
            stackPartners: ["BPC-157", "GHK-Cu"],
            iconName: "bandage.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,963 Da", administrationRoute: "Subcutaneous / IM", halfLife: "1-2 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "2-2.5 mg")
        ),
        CompoundProfile(
            name: "GHK-Cu",
            peptideType: "Copper-Binding Tripeptide",
            categories: [.healing, .antiAging, .tanning],
            overview: "A naturally occurring copper complex that modulates expression of thousands of genes, resetting them to a younger, healthier state. Strongly stimulates collagen and elastin production. Notorious for intense Post-Injection Pain (PIP) — dilute further or mix BPC-157 in the same syringe. Supplement with Zinc to prevent copper-induced depletion. The powder/liquid should be bright blue.",
            protocols: [
                CompoundProtocol(goalName: "Skin Rejuvenation", description: "SubQ for systemic anti-aging effects", typicalDose: "1-2 mg", frequency: "1-2x daily", duration: "4-8 weeks (30 on / 30 off)"),
                CompoundProtocol(goalName: "Topical Anti-Aging", description: "Cream/serum for facial skin", typicalDose: "0.05-2% cream", frequency: "Daily", duration: "Continuous"),
            ],
            sideEffects: ["Severe injection site pain", "Welts/redness", "Nausea", "Headache"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Pain (PIP)", severity: .significant, frequency: 55),
                CompoundSideEffect(name: "Skin Welts / Redness", severity: .moderate, frequency: 40),
                CompoundSideEffect(name: "Nausea", severity: .mild, frequency: 8),
                CompoundSideEffect(name: "Headache", severity: .mild, frequency: 6),
            ],
            communityUsers: 1245,
            averageRating: 4.3,
            stackPartners: ["BPC-157", "Epithalon", "Zinc"],
            iconName: "sparkles",
            keyFacts: CompoundKeyFacts(molecularWeight: "403 Da", administrationRoute: "SubQ / Topical", halfLife: "~1 hour", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "1-2 mg")
        ),
        CompoundProfile(
            name: "KPV",
            peptideType: "Alpha-MSH Fragment (Tripeptide)",
            categories: [.healing],
            overview: "A tripeptide fragment of alpha-MSH with potent anti-inflammatory effects. Enters cells and directly inhibits NF-kB activation. Also possesses antimicrobial and antifungal properties. For gut-specific issues like Crohn's or UC, oral capsules are significantly more effective than SubQ. Highly regarded in the mold toxicity (CIRS) community.",
            protocols: [
                CompoundProtocol(goalName: "Gut Health", description: "Oral for IBD, Crohn's, or UC", typicalDose: "200-500 mcg", frequency: "1-2x daily", duration: "4-8 weeks"),
                CompoundProtocol(goalName: "Systemic Inflammation", description: "SubQ for systemic anti-inflammatory effect", typicalDose: "200-250 mcg", frequency: "1-2x daily", duration: "4-8 weeks"),
            ],
            sideEffects: ["Mild injection site reaction", "Mild fatigue"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction", severity: .mild, frequency: 5),
                CompoundSideEffect(name: "Mild Fatigue", severity: .mild, frequency: 3),
            ],
            communityUsers: 567,
            averageRating: 4.2,
            stackPartners: ["BPC-157", "Thymosin Alpha-1", "GHK-Cu"],
            iconName: "leaf.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "357 Da", administrationRoute: "Oral / Subcutaneous", halfLife: "Minutes (effects prolonged)", storageTemp: "2-8°C", reconstitution: "BAC Water / Oral capsule", typicalDoseRange: "200-500 mcg")
        ),
        CompoundProfile(
            name: "Thymosin Alpha-1",
            peptideType: "Immune Modulator",
            categories: [.healing, .antiAging],
            overview: "A naturally occurring peptide produced by the thymus gland. Acts as a master regulator of the immune system — can upregulate to fight infections or downregulate to calm autoimmune conditions. Has FDA Orphan Drug status as Zadaxin. Unique because it is an immune modulator, not just a stimulator, making it safe for autoimmune conditions.",
            protocols: [
                CompoundProtocol(goalName: "Immune Modulation", description: "For viral infections, autoimmune, or mold toxicity", typicalDose: "1.5 mg", frequency: "2-3x weekly", duration: "4-12 weeks"),
                CompoundProtocol(goalName: "Acute Infection", description: "Daily dosing for severe active infections", typicalDose: "1.5 mg", frequency: "1x daily", duration: "2-4 weeks"),
            ],
            sideEffects: ["Mild injection site redness", "Flu-like symptoms (Herxheimer)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Redness", severity: .mild, frequency: 10),
                CompoundSideEffect(name: "Herxheimer Reaction", severity: .moderate, frequency: 15),
            ],
            communityUsers: 723,
            averageRating: 4.4,
            stackPartners: ["BPC-157", "LL-37", "KPV"],
            iconName: "shield.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "3,108 Da", administrationRoute: "Subcutaneous", halfLife: "~2 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "1.5 mg")
        ),
        CompoundProfile(
            name: "LL-37",
            peptideType: "Cathelicidin Antimicrobial Peptide",
            categories: [.healing],
            overview: "A naturally occurring human antimicrobial peptide that disrupts cell membranes of bacteria, viruses, and fungi, causing them to burst. Also neutralizes bacterial endotoxins (LPS) and modulates inflammatory response. Used for chronic treatment-resistant infections, biofilm disruption, gut dysbiosis, and SIBO.",
            protocols: [
                CompoundProtocol(goalName: "Infection Clearing", description: "For chronic/biofilm infections", typicalDose: "100-200 mcg", frequency: "1x daily", duration: "4-8 weeks"),
            ],
            sideEffects: ["Injection site pain", "Flu-like symptoms", "Fatigue"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Pain", severity: .moderate, frequency: 25),
                CompoundSideEffect(name: "Flu-like Symptoms", severity: .mild, frequency: 15),
                CompoundSideEffect(name: "Fatigue", severity: .mild, frequency: 10),
            ],
            communityUsers: 456,
            averageRating: 4.1,
            stackPartners: ["Thymosin Alpha-1", "BPC-157"],
            iconName: "microbe.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,493 Da", administrationRoute: "Subcutaneous", halfLife: "Minutes to hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100-200 mcg")
        ),
        CompoundProfile(
            name: "Pentadecapeptide (BPC-157 Arginate)",
            peptideType: "Pentadecapeptide (Gut-Stable)",
            categories: [.healing],
            overview: "An advanced, highly stable analog of BPC-157 bound to an arginate salt instead of acetate. This dramatically increases oral bioavailability from <3% to >90%, allowing powerful systemic and GI healing effects when taken orally without injections. Always take on an empty stomach. Standard BPC-157 Acetate is destroyed by stomach acid — you must use the Arginate form for oral use.",
            protocols: [
                CompoundProtocol(goalName: "Severe GI Repair", description: "Oral for leaky gut, Crohn's, UC", typicalDose: "250-500 mcg", frequency: "1-2x daily (fasted)", duration: "4-8 weeks"),
            ],
            sideEffects: ["Mild bowel changes", "Lethargy (rare)", "Mild headache (rare)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Bowel Changes", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Lethargy", severity: .mild, frequency: 4),
            ],
            communityUsers: 389,
            averageRating: 4.3,
            stackPartners: ["KPV", "Butyrate"],
            iconName: "pill.circle.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,419 Da", administrationRoute: "Oral", halfLife: "<30 min (effects longer)", storageTemp: "Room Temp", reconstitution: "N/A (oral capsule)", typicalDoseRange: "250-500 mcg")
        ),

        // MARK: - Category 3: Fat Loss & Metabolic

        CompoundProfile(
            name: "Semaglutide",
            peptideType: "GLP-1 Receptor Agonist (FDA Approved)",
            categories: [.weightLoss],
            overview: "An FDA-approved GLP-1 receptor agonist (Ozempic/Wegovy). Acts on GLP-1 receptors in the brain to drastically reduce appetite and slows gastric emptying. The STEP trials demonstrated ~15% average weight loss over 68 weeks. Titration schedule is mandatory — jumping to high doses causes severe nausea. Prioritize protein intake and resistance training to combat 'Ozempic Face' and muscle loss.",
            protocols: [
                CompoundProtocol(goalName: "Weight Loss Titration", description: "Mandatory slow dose escalation over months", typicalDose: "0.25 mg → 2.4 mg", frequency: "1x weekly", duration: "Ongoing"),
            ],
            sideEffects: ["Nausea", "Diarrhea", "Constipation", "Decreased appetite", "Fatigue", "Injection site reactions"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 58),
                CompoundSideEffect(name: "Decreased Appetite", severity: .mild, frequency: 70),
                CompoundSideEffect(name: "Diarrhea", severity: .moderate, frequency: 30),
                CompoundSideEffect(name: "Constipation", severity: .moderate, frequency: 25),
                CompoundSideEffect(name: "Fatigue", severity: .mild, frequency: 20),
            ],
            communityUsers: 5432,
            averageRating: 4.6,
            stackPartners: ["BPC-157", "CJC-1295/Ipamorelin"],
            iconName: "scalemass.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,114 Da", administrationRoute: "Subcutaneous", halfLife: "~7 days", storageTemp: "2-8°C", reconstitution: "Pre-filled pen / BAC Water", typicalDoseRange: "0.25-2.4 mg weekly")
        ),
        CompoundProfile(
            name: "Tirzepatide",
            peptideType: "Dual GLP-1/GIP Agonist (FDA Approved)",
            categories: [.weightLoss],
            overview: "A 'twincreatin' that activates both GLP-1 and GIP receptors. The GIP agonism synergistically enhances appetite suppression while reducing nausea compared to pure GLP-1 agonists. Currently the most powerful FDA-approved weight-loss peptide. SURMOUNT trials showed up to 22.5% body weight loss over 72 weeks. Muscle loss is a severe risk — tracking protein macros is essential.",
            protocols: [
                CompoundProtocol(goalName: "Weight Loss Titration", description: "Slow escalation by 2.5 mg every 4 weeks", typicalDose: "2.5 mg → 15 mg", frequency: "1x weekly", duration: "Ongoing"),
            ],
            sideEffects: ["Nausea", "Diarrhea", "Decreased appetite", "Injection site reactions", "Constipation"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 52),
                CompoundSideEffect(name: "Decreased Appetite", severity: .mild, frequency: 65),
                CompoundSideEffect(name: "Diarrhea", severity: .moderate, frequency: 28),
                CompoundSideEffect(name: "Injection Site Reactions", severity: .mild, frequency: 12),
            ],
            communityUsers: 3876,
            averageRating: 4.7,
            stackPartners: ["Tesamorelin", "BPC-157"],
            iconName: "arrow.down.right",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,814 Da", administrationRoute: "Subcutaneous", halfLife: "~5 days", storageTemp: "2-8°C", reconstitution: "Pre-filled pen / BAC Water", typicalDoseRange: "2.5-15 mg weekly")
        ),
        CompoundProfile(
            name: "Retatrutide",
            peptideType: "Triple GLP-1/GIP/Glucagon Agonist",
            categories: [.weightLoss],
            overview: "A next-generation tri-agonist targeting GLP-1, GIP, and glucagon receptors. The glucagon agonism actively forces the body to burn stored fat and increases resting energy expenditure. Phase 2 trials showed unprecedented 24.2% weight loss at 48 weeks. Users report feeling 'warmer' and more energetic than on Semaglutide. Never skip the titration schedule.",
            protocols: [
                CompoundProtocol(goalName: "Weight Loss", description: "Strict 4-week dose escalation required", typicalDose: "2 mg → 12 mg", frequency: "1x weekly", duration: "Ongoing"),
            ],
            sideEffects: ["Nausea", "Diarrhea", "Constipation", "Mild increased heart rate", "Vomiting"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 48),
                CompoundSideEffect(name: "Decreased Appetite", severity: .mild, frequency: 60),
                CompoundSideEffect(name: "Diarrhea", severity: .moderate, frequency: 32),
                CompoundSideEffect(name: "Elevated Heart Rate", severity: .mild, frequency: 18),
            ],
            communityUsers: 1234,
            averageRating: 4.3,
            stackPartners: ["AOD-9604", "BPC-157"],
            iconName: "chart.line.downtrend.xyaxis",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,605 Da", administrationRoute: "Subcutaneous", halfLife: "~6 days", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "2-12 mg weekly")
        ),
        CompoundProfile(
            name: "AOD-9604",
            peptideType: "HGH Fragment (177-191)",
            categories: [.weightLoss],
            overview: "A modified fragment of the C-terminus of Human Growth Hormone isolating the lipolytic properties without stimulating IGF-1. Stimulates fat breakdown and inhibits fat formation. Highly dependent on a fasted state — injecting when insulin is elevated completely blunts its mechanism. Wait 45-60 minutes after injection before consuming calories. Does not cause insulin resistance or cellular proliferation risks.",
            protocols: [
                CompoundProtocol(goalName: "Targeted Fat Loss", description: "Fasted administration for maximum lipolysis", typicalDose: "250-300 mcg", frequency: "1-2x daily (fasted)", duration: "12-24 weeks"),
            ],
            sideEffects: ["Mild injection site redness", "Headache (rare)", "Mild indigestion"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Redness", severity: .mild, frequency: 10),
                CompoundSideEffect(name: "Headache", severity: .mild, frequency: 8),
            ],
            communityUsers: 1098,
            averageRating: 3.9,
            stackPartners: ["Tesamorelin", "BPC-157", "CJC-1295"],
            iconName: "flame",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,815 Da", administrationRoute: "Subcutaneous", halfLife: "Minutes (effects sustained)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "250-300 mcg")
        ),
        CompoundProfile(
            name: "Cagrilintide",
            peptideType: "Long-Acting Amylin Analog",
            categories: [.weightLoss],
            overview: "A synthetic analog of amylin that acts on the brain's hedonic (reward) centers to induce profound satiety and reduce desire to eat for pleasure. Preserves lean muscle mass better than GLP-1 agonists during weight loss. Rarely used alone — almost exclusively stacked with Semaglutide ('CagriSema') to attack appetite from two completely different brain pathways.",
            protocols: [
                CompoundProtocol(goalName: "CagriSema Protocol", description: "Combined with Semaglutide for synergistic effect", typicalDose: "0.25 mg → 2.4 mg", frequency: "1x weekly", duration: "Ongoing"),
            ],
            sideEffects: ["Nausea", "Constipation", "Injection site reactions", "Fatigue"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .moderate, frequency: 35),
                CompoundSideEffect(name: "Constipation", severity: .mild, frequency: 20),
                CompoundSideEffect(name: "Injection Site Reactions", severity: .mild, frequency: 12),
            ],
            communityUsers: 456,
            averageRating: 4.1,
            stackPartners: ["Semaglutide"],
            iconName: "brain.filled.head.profile",
            keyFacts: CompoundKeyFacts(molecularWeight: "3,990 Da", administrationRoute: "Subcutaneous", halfLife: "~7-8 days", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "0.25-2.4 mg weekly")
        ),
        CompoundProfile(
            name: "MOTS-c",
            peptideType: "Mitochondrial-Derived Peptide",
            categories: [.weightLoss, .antiAging],
            overview: "Encoded by mitochondrial DNA (not nuclear DNA), MOTS-c acts as an 'exercise mimetic' by activating AMPK. Increases cellular glucose uptake, improves insulin sensitivity, and shifts metabolism toward burning fatty acids. Used for enhancing mitochondrial function, overcoming weight-loss plateaus, and improving exercise endurance.",
            protocols: [
                CompoundProtocol(goalName: "Metabolic Enhancement", description: "Pre-workout for exercise mimetic effect", typicalDose: "5-10 mg", frequency: "1-2x weekly", duration: "4-8 weeks on / 4 weeks off"),
            ],
            sideEffects: ["Injection site reaction", "Mild fatigue"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction", severity: .mild, frequency: 10),
                CompoundSideEffect(name: "Fatigue", severity: .mild, frequency: 8),
            ],
            communityUsers: 345,
            averageRating: 4.0,
            stackPartners: ["5-Amino-1MQ", "AOD-9604"],
            iconName: "bolt.ring.closed",
            keyFacts: CompoundKeyFacts(molecularWeight: "2,174 Da", administrationRoute: "Subcutaneous", halfLife: "Short (effects prolonged)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "5-10 mg")
        ),

        // MARK: - Category 4: Cognitive & Nootropic

        CompoundProfile(
            name: "Semax",
            peptideType: "ACTH Analog (Nootropic)",
            categories: [.cognitive],
            overview: "A synthetic ACTH fragment that rapidly increases BDNF and NGF in the hippocampus. Modulates dopaminergic and serotonergic systems for enhanced focus, memory, and neuroprotection. The N-Acetyl Semax Amidate version is preferred for increased potency and stability. Stimulating — do not take late in the day. Intranasal administration bypasses the blood-brain barrier via the olfactory nerve.",
            protocols: [
                CompoundProtocol(goalName: "Cognitive Enhancement", description: "Intranasal morning administration for focus and memory", typicalDose: "200-600 mcg", frequency: "1-2x daily", duration: "10-30 days on / 30 days off"),
            ],
            sideEffects: ["Nasal irritation", "Overstimulation", "Insomnia (if taken late)", "Hair loss (anecdotal)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nasal Irritation", severity: .mild, frequency: 15),
                CompoundSideEffect(name: "Overstimulation", severity: .mild, frequency: 10),
                CompoundSideEffect(name: "Insomnia", severity: .moderate, frequency: 8),
            ],
            communityUsers: 756,
            averageRating: 4.4,
            stackPartners: ["Selank", "Epithalon"],
            iconName: "brain.head.profile",
            keyFacts: CompoundKeyFacts(molecularWeight: "813 Da", administrationRoute: "Intranasal", halfLife: "Minutes (effects 20-24h)", storageTemp: "2-8°C", reconstitution: "Pre-mixed nasal spray", typicalDoseRange: "200-600 mcg")
        ),
        CompoundProfile(
            name: "Selank",
            peptideType: "Tuftsin Analog (Anxiolytic)",
            categories: [.cognitive],
            overview: "A synthetic analog of tuftsin that exerts profound anxiolytic effects by modulating GABA receptors and increasing serotonin metabolism. Unlike benzodiazepines, does not cause sedation, cognitive impairment, or addiction. Provides 'clean calm' — removes anxiety without making you feel drugged or sleepy. Effective acutely before stressful situations.",
            protocols: [
                CompoundProtocol(goalName: "Anxiety & Focus", description: "Intranasal for mood and cognition", typicalDose: "200-600 mcg", frequency: "1-2x daily", duration: "10-30 days on / 30 days off"),
            ],
            sideEffects: ["Mild nasal irritation", "Mild fatigue (if dose too high)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nasal Irritation", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Fatigue", severity: .mild, frequency: 6),
            ],
            communityUsers: 542,
            averageRating: 4.3,
            stackPartners: ["Semax"],
            iconName: "brain",
            keyFacts: CompoundKeyFacts(molecularWeight: "751 Da", administrationRoute: "Intranasal", halfLife: "Minutes (effects 12-24h)", storageTemp: "2-8°C", reconstitution: "Pre-mixed nasal spray", typicalDoseRange: "200-600 mcg")
        ),
        CompoundProfile(
            name: "Dihexa",
            peptideType: "Angiotensin IV Analog",
            categories: [.cognitive],
            overview: "An incredibly potent metabolically stable analog of Angiotensin IV that triggers massive synaptogenesis (new synapse formation). Orders of magnitude more potent than BDNF at promoting dendritic spine growth. Has a 12.6-day half-life — accumulates rapidly. Start with very low doses. Activates c-Met pathway — never use with active malignancies. Cognitive effects build over weeks.",
            protocols: [
                CompoundProtocol(goalName: "Extreme Cognitive Enhancement", description: "Weekly oral or SubQ for synaptogenesis", typicalDose: "5-20 mg", frequency: "1x weekly", duration: "4-8 weeks on / 1-2 months off"),
            ],
            sideEffects: ["Overstimulation", "Jitteriness", "Insomnia", "Brain fog (if too high)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Overstimulation", severity: .moderate, frequency: 20),
                CompoundSideEffect(name: "Jitteriness", severity: .mild, frequency: 15),
                CompoundSideEffect(name: "Insomnia", severity: .moderate, frequency: 12),
            ],
            communityUsers: 321,
            averageRating: 4.0,
            stackPartners: ["Cerebrolysin"],
            iconName: "brain.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "507 Da", administrationRoute: "Oral / SubQ / Transdermal", halfLife: "~12.6 days", storageTemp: "Room Temp / 2-8°C", reconstitution: "BAC Water / Oral capsule", typicalDoseRange: "5-20 mg weekly")
        ),
        CompoundProfile(
            name: "Cerebrolysin",
            peptideType: "Porcine Brain-Derived Peptide Mixture",
            categories: [.cognitive],
            overview: "A purified mixture of low-molecular-weight peptides and amino acids derived from pig brains. Mimics endogenous neurotrophic factors (BDNF, GDNF, NGF). Approved as a prescription drug in 50+ countries for stroke, TBI, and dementia. Requires large IM injection volumes (2-5 mL) — too much for SubQ. Must use a filter needle from glass ampoules to prevent glass shards.",
            protocols: [
                CompoundProtocol(goalName: "Neuro-Recovery", description: "IM injection for brain healing", typicalDose: "2-5 mL", frequency: "1x daily (IM)", duration: "10-21 days on / 2-3 months off"),
            ],
            sideEffects: ["Injection site pain (large volume)", "Mild fever", "Agitation", "Dizziness"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Pain", severity: .moderate, frequency: 35),
                CompoundSideEffect(name: "Mild Fever", severity: .mild, frequency: 10),
                CompoundSideEffect(name: "Agitation", severity: .mild, frequency: 8),
            ],
            communityUsers: 287,
            averageRating: 4.2,
            stackPartners: ["Cortagen", "Pinealon"],
            iconName: "brain.head.profile.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "Mixture", administrationRoute: "IM / IV", halfLife: "Hours (effects long-lasting)", storageTemp: "Room Temp", reconstitution: "Pre-mixed ampoules", typicalDoseRange: "2-5 mL daily")
        ),
        CompoundProfile(
            name: "Pinealon",
            peptideType: "Short Synthetic Peptide (Tripeptide)",
            categories: [.cognitive],
            overview: "A synthetic tripeptide (Glu-Asp-Arg) from the Khavinson bioregulator family. Penetrates cell nuclei to bind gene promoter regions, stimulating protein synthesis in brain cells. Protects neurons from oxidative stress and hypoxia. Effects are epigenetic — benefits build over the cycle and persist for months after stopping. Oral capsules are effective, avoiding need for injections.",
            protocols: [
                CompoundProtocol(goalName: "Memory & Neuroprotection", description: "Oral capsule for brain bioregulation", typicalDose: "10-20 mg oral / 2 mg SubQ", frequency: "1x daily", duration: "10-30 days on / 3-6 months off"),
            ],
            sideEffects: ["Mild headache (uncommon)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Mild Headache", severity: .mild, frequency: 5),
            ],
            communityUsers: 198,
            averageRating: 4.0,
            stackPartners: ["Cortagen", "Semax"],
            iconName: "memorychip.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "389 Da", administrationRoute: "Oral / SubQ", halfLife: "Minutes (epigenetic effects months)", storageTemp: "2-8°C", reconstitution: "BAC Water / Oral capsule", typicalDoseRange: "10-20 mg oral")
        ),
        CompoundProfile(
            name: "Cortagen",
            peptideType: "Short Synthetic Peptide (Tetrapeptide)",
            categories: [.cognitive],
            overview: "A synthetic tetrapeptide (Ala-Glu-Asp-Pro) bioregulator targeting the cerebral cortex. Interacts directly with DNA to stimulate repair and regeneration of cortical neurons. Has pronounced antioxidant effects. Used for TBI recovery, reversing stress-induced cognitive decline, and enhancing learning. Run for 10-20 days; brain-healing benefits last up to 6 months.",
            protocols: [
                CompoundProtocol(goalName: "Cortex Repair", description: "Short cycle for brain bioregulation", typicalDose: "1-2 mg", frequency: "1x daily", duration: "10-20 days on / 3-6 months off"),
            ],
            sideEffects: ["Mild fatigue (first few days)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Mild Fatigue", severity: .mild, frequency: 5),
            ],
            communityUsers: 156,
            averageRating: 4.0,
            stackPartners: ["Pinealon", "Cerebrolysin"],
            iconName: "head.profile.arrow.forward.and.visionpro",
            keyFacts: CompoundKeyFacts(molecularWeight: "418 Da", administrationRoute: "SubQ / IM", halfLife: "Minutes (epigenetic effects months)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "1-2 mg daily")
        ),
        CompoundProfile(
            name: "DSIP",
            peptideType: "Delta Sleep-Inducing Peptide",
            categories: [.cognitive],
            overview: "A neuropeptide naturally found in the brain that promotes delta wave sleep, reduces stress, and balances hormones during sleep cycles. Used for sleep optimization, chronic insomnia, and improving sleep architecture. Administered before bed.",
            protocols: [
                CompoundProtocol(goalName: "Sleep Optimization", description: "Pre-sleep administration", typicalDose: "100-300 mcg", frequency: "1x daily (before bed)", duration: "2-4 weeks"),
            ],
            sideEffects: ["Morning grogginess", "Vivid dreams"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Morning Grogginess", severity: .mild, frequency: 22),
                CompoundSideEffect(name: "Vivid Dreams", severity: .mild, frequency: 30),
            ],
            communityUsers: 432,
            averageRating: 4.0,
            stackPartners: ["Semax", "Selank"],
            iconName: "moon.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "849 Da", administrationRoute: "SubQ / Intranasal", halfLife: "~15 min", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100-300 mcg")
        ),

        // MARK: - Category 5: Sexual Health

        CompoundProfile(
            name: "PT-141",
            peptideType: "Melanocortin Receptor Agonist (FDA Approved)",
            categories: [.sexualHealth],
            overview: "A synthetic alpha-MSH analog that works directly in the CNS by binding to melanocortin 4 receptors (MC4R) in the hypothalamus. Unlike Viagra/Cialis which work on blood flow, PT-141 triggers actual sexual arousal and desire. FDA-approved as Vyleesi for women with HSDD. Onset is variable (30 min to 4-6 hours). Nausea is the most common reason people stop — take Zofran 30 min prior or inject before bed.",
            protocols: [
                CompoundProtocol(goalName: "Libido Enhancement", description: "As-needed dosing 2-4 hours before activity", typicalDose: "1-2 mg", frequency: "As needed (max 8x/month)", duration: "As needed"),
            ],
            sideEffects: ["Nausea (severe)", "Flushing", "Headache", "Increased blood pressure"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 50),
                CompoundSideEffect(name: "Flushing", severity: .moderate, frequency: 40),
                CompoundSideEffect(name: "Headache", severity: .moderate, frequency: 25),
                CompoundSideEffect(name: "Blood Pressure Elevation", severity: .moderate, frequency: 15),
            ],
            communityUsers: 823,
            averageRating: 4.1,
            stackPartners: ["Tadalafil (Cialis)"],
            iconName: "heart.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,025 Da", administrationRoute: "Subcutaneous", halfLife: "~2.7 hours (effects 16h)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "1-2 mg as needed")
        ),
        CompoundProfile(
            name: "Kisspeptin-10",
            peptideType: "GnRH Stimulator",
            categories: [.sexualHealth],
            overview: "A peptide that acts on the hypothalamus to stimulate the release of GnRH, which triggers the pituitary to release LH and FSH. This restores natural testosterone and estrogen production. Used for restoring hormonal axis function after SARM or steroid cycles, and as an alternative to HCG for fertility support. Does not shut down the HPTA — it stimulates it.",
            protocols: [
                CompoundProtocol(goalName: "HPTA Recovery / PCT", description: "Stimulating natural hormone production", typicalDose: "100-500 mcg", frequency: "1-2x daily", duration: "2-4 weeks"),
            ],
            sideEffects: ["Injection site reaction", "Mild headache"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction", severity: .mild, frequency: 8),
                CompoundSideEffect(name: "Mild Headache", severity: .mild, frequency: 5),
            ],
            communityUsers: 345,
            averageRating: 4.0,
            stackPartners: ["Enclomiphene"],
            iconName: "arrow.triangle.2.circlepath",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,302 Da", administrationRoute: "Subcutaneous", halfLife: "~30 min", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100-500 mcg")
        ),

        // MARK: - Category 6: Tanning & Skin

        CompoundProfile(
            name: "Melanotan I",
            peptideType: "Melanocortin Receptor Agonist",
            categories: [.tanning],
            overview: "Also known as Afamelanotide, a synthetic analog of alpha-MSH that selectively targets MC1R to stimulate melanogenesis (tanning). More selective than Melanotan II with fewer sexual side effects. Approved in the EU as Scenesse for erythropoietic protoporphyria. Provides a more gradual, natural-looking tan. Still requires some UV exposure to activate melanocytes.",
            protocols: [
                CompoundProtocol(goalName: "Tanning", description: "Loading phase followed by maintenance", typicalDose: "0.5-1 mg", frequency: "Daily (loading) then 2x/week", duration: "2 weeks loading, then maintenance"),
            ],
            sideEffects: ["Nausea", "Facial flushing", "Headache", "Darkened moles"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .moderate, frequency: 30),
                CompoundSideEffect(name: "Facial Flushing", severity: .mild, frequency: 25),
                CompoundSideEffect(name: "Darkened Moles", severity: .moderate, frequency: 20),
            ],
            communityUsers: 678,
            averageRating: 4.2,
            stackPartners: ["Melanotan II"],
            iconName: "sun.max.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,647 Da", administrationRoute: "Subcutaneous", halfLife: "~1 hour", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "0.5-1 mg")
        ),
        CompoundProfile(
            name: "Melanotan II",
            peptideType: "Non-Selective Melanocortin Agonist",
            categories: [.tanning, .sexualHealth],
            overview: "A non-selective agonist of melanocortin receptors (MC1R through MC5R). Its MC1R binding stimulates tanning, while MC4R binding causes intense sexual arousal and spontaneous erections. PT-141 was actually developed as a metabolite of MT-II to isolate the sexual effects. Requires careful dosing and mole monitoring. Nausea and facial flushing are very common during loading.",
            protocols: [
                CompoundProtocol(goalName: "Tanning", description: "Loading phase to build melanin, then maintain", typicalDose: "250-500 mcg", frequency: "Daily (loading) then 1-2x/week", duration: "2 weeks loading, then maintenance"),
            ],
            sideEffects: ["Nausea", "Facial flushing", "Appetite suppression", "Darkened moles", "Increased libido"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 55),
                CompoundSideEffect(name: "Facial Flushing", severity: .moderate, frequency: 45),
                CompoundSideEffect(name: "Darkened Moles", severity: .moderate, frequency: 35),
                CompoundSideEffect(name: "Appetite Suppression", severity: .mild, frequency: 30),
                CompoundSideEffect(name: "Increased Libido", severity: .mild, frequency: 40),
            ],
            communityUsers: 1567,
            averageRating: 4.0,
            stackPartners: ["PT-141"],
            iconName: "sun.max.trianglebadge.exclamationmark.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,024 Da", administrationRoute: "Subcutaneous", halfLife: "~1 hour", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "250-500 mcg")
        ),
        CompoundProfile(
            name: "Snap-8",
            peptideType: "Acetyl Octapeptide-3",
            categories: [.tanning],
            overview: "A topical peptide that mimics the mechanism of Botox without injections. Inhibits the SNARE complex, reducing the release of neurotransmitters at the neuromuscular junction to relax facial muscles and reduce expression lines. Applied topically as a serum — no injection needed. Results take 2-4 weeks and are more subtle than Botox but completely non-invasive.",
            protocols: [
                CompoundProtocol(goalName: "Wrinkle Reduction", description: "Topical application to expression lines", typicalDose: "3-10% serum", frequency: "2x daily", duration: "Continuous"),
            ],
            sideEffects: ["Mild skin irritation (rare)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Skin Irritation", severity: .mild, frequency: 5),
            ],
            communityUsers: 234,
            averageRating: 3.8,
            stackPartners: ["GHK-Cu (Topical)"],
            iconName: "face.smiling",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,075 Da", administrationRoute: "Topical", halfLife: "N/A (topical)", storageTemp: "Room Temp", reconstitution: "N/A (serum)", typicalDoseRange: "3-10% serum")
        ),

        // MARK: - Category 7: Longevity & Anti-Aging

        CompoundProfile(
            name: "Epithalon",
            peptideType: "Pineal Gland Bioregulator (Tetrapeptide)",
            categories: [.antiAging, .cognitive],
            overview: "A synthetic tetrapeptide (Ala-Glu-Asp-Gly) famous for activating telomerase enzyme, which elongates telomeres to extend cell lifespan. Normalizes circadian rhythm by restoring natural melatonin production. Per the Khavinson Protocol, run for 10-20 days only, 1-2 times per year — running continuously provides no added benefit. Dosing timing is debated: some find it sedating, others stimulating.",
            protocols: [
                CompoundProtocol(goalName: "Anti-Aging & Telomere Extension", description: "Short cyclical protocol per Khavinson Protocol", typicalDose: "5-10 mg", frequency: "1x daily", duration: "10-20 days, 1-2x per year"),
            ],
            sideEffects: ["Vivid dreams", "Sleep changes (first few days)", "Mild nausea (rare)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Vivid Dreams", severity: .mild, frequency: 20),
                CompoundSideEffect(name: "Sleep Pattern Changes", severity: .mild, frequency: 15),
            ],
            communityUsers: 634,
            averageRating: 4.1,
            stackPartners: ["Thymalin", "GHK-Cu", "Semax"],
            iconName: "hourglass",
            keyFacts: CompoundKeyFacts(molecularWeight: "390 Da", administrationRoute: "Subcutaneous", halfLife: "20-30 min (epigenetic months)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "5-10 mg daily")
        ),
        CompoundProfile(
            name: "Thymalin",
            peptideType: "Thymus Bioregulator",
            categories: [.antiAging],
            overview: "A bioregulatory peptide extract that restores the function of the thymus gland, which deteriorates with age. The thymus produces T-cells crucial for adaptive immunity. By restoring thymic function, Thymalin reverses age-related immune decline. Often combined with Epithalon in the 'Ultimate Longevity Stack' — Epithalon restores the pineal gland, Thymalin restores the thymus.",
            protocols: [
                CompoundProtocol(goalName: "Immune Rejuvenation", description: "Short cyclical protocol for thymus restoration", typicalDose: "10 mg", frequency: "1x daily", duration: "10-20 days, 1-2x per year"),
            ],
            sideEffects: ["Mild injection site reaction"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction", severity: .mild, frequency: 5),
            ],
            communityUsers: 234,
            averageRating: 4.0,
            stackPartners: ["Epithalon"],
            iconName: "shield.lefthalf.filled",
            keyFacts: CompoundKeyFacts(molecularWeight: "Mixture", administrationRoute: "IM / SubQ", halfLife: "Short (effects months)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "10 mg daily")
        ),
        CompoundProfile(
            name: "SS-31 (Elamipretide)",
            peptideType: "Mitochondrial-Targeted Peptide",
            categories: [.antiAging],
            overview: "A cell-permeable peptide that concentrates within the inner mitochondrial membrane, where it stabilizes cardiolipin — a phospholipid essential for efficient electron transport chain function. By repairing the bioenergetic machinery of the cell, it restores ATP production and reduces oxidative stress at the source. Currently in clinical trials for Barth syndrome and heart failure.",
            protocols: [
                CompoundProtocol(goalName: "Mitochondrial Repair", description: "SubQ for cellular energy restoration", typicalDose: "5-20 mg", frequency: "1x daily", duration: "4-8 weeks on / 4 weeks off"),
            ],
            sideEffects: ["Injection site reaction", "Mild headache"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction", severity: .mild, frequency: 10),
                CompoundSideEffect(name: "Headache", severity: .mild, frequency: 5),
            ],
            communityUsers: 189,
            averageRating: 4.0,
            stackPartners: ["MOTS-c", "Humanin"],
            iconName: "bolt.batteryblock.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "639 Da", administrationRoute: "Subcutaneous", halfLife: "~3 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "5-20 mg daily")
        ),
        CompoundProfile(
            name: "Humanin",
            peptideType: "Mitochondrial-Derived Peptide",
            categories: [.antiAging],
            overview: "Like MOTS-c, Humanin is encoded by mitochondrial DNA. It is a powerful cytoprotective peptide that protects cells from apoptosis (programmed cell death). It acts as a guardian of cellular integrity under stress by inhibiting the pro-apoptotic protein Bax and activating the STAT3 survival pathway. Levels decline with age, correlating with neurodegenerative disease onset.",
            protocols: [
                CompoundProtocol(goalName: "Cellular Protection", description: "SubQ for anti-apoptotic effect", typicalDose: "1-5 mg", frequency: "1x daily", duration: "4-8 weeks on / 4 weeks off"),
            ],
            sideEffects: ["Mild injection site reaction"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction", severity: .mild, frequency: 5),
            ],
            communityUsers: 145,
            averageRating: 3.9,
            stackPartners: ["SS-31", "MOTS-c", "Epithalon"],
            iconName: "heart.circle.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "2,687 Da", administrationRoute: "Subcutaneous", halfLife: "Short (effects prolonged)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "1-5 mg daily")
        ),

        // MARK: - Category 8: SARMs

        CompoundProfile(
            name: "Ostarine (MK-2866)",
            peptideType: "Selective Androgen Receptor Modulator",
            categories: [.sarms],
            overview: "The mildest and most well-studied SARM. Selectively binds androgen receptors in muscle and bone with minimal prostate or liver impact. Despite common misconceptions, Ostarine DOES require PCT — even 10 mg/day suppresses testosterone by 40-60% over 8 weeks. Also suppresses estrogen, causing 'dry joints' at end of cycle.",
            protocols: [
                CompoundProtocol(goalName: "Lean Muscle Preservation", description: "Oral daily dosing with mandatory PCT after", typicalDose: "10-25 mg", frequency: "1x daily (oral)", duration: "8-12 weeks + PCT"),
            ],
            sideEffects: ["Testosterone suppression", "Decreased HDL", "Liver enzyme elevation", "Joint pain"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Testosterone Suppression", severity: .moderate, frequency: 80),
                CompoundSideEffect(name: "Decreased HDL", severity: .moderate, frequency: 60),
                CompoundSideEffect(name: "Liver Enzyme Elevation", severity: .mild, frequency: 15),
                CompoundSideEffect(name: "Joint Pain (dry joints)", severity: .mild, frequency: 20),
            ],
            communityUsers: 2345,
            averageRating: 4.2,
            stackPartners: ["Cardarine (GW-501516)"],
            iconName: "dumbbell.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "389 Da", administrationRoute: "Oral", halfLife: "~24 hours", storageTemp: "Room Temp", reconstitution: "N/A (oral)", typicalDoseRange: "10-25 mg daily")
        ),
        CompoundProfile(
            name: "Ligandrol (LGD-4033)",
            peptideType: "Selective Androgen Receptor Modulator",
            categories: [.sarms],
            overview: "A highly potent SARM with extremely high androgen receptor affinity. Significantly more anabolic than Ostarine, primarily used for adding sheer size and mass. Notorious for 'SARM flu' around week 4-5 — extreme lethargy from testosterone crashing. Many advanced users run a 'test base' (Enclomiphene) alongside. Causes more intracellular water retention, giving a 'full/puffy' look favored for bulking.",
            protocols: [
                CompoundProtocol(goalName: "Bulking", description: "Oral daily with strict PCT required after", typicalDose: "2.5-10 mg", frequency: "1x daily (oral)", duration: "8 weeks + PCT"),
            ],
            sideEffects: ["Significant testosterone suppression", "Water retention", "Lethargy", "Hair shedding", "HDL crash"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Testosterone Suppression", severity: .significant, frequency: 90),
                CompoundSideEffect(name: "Water Retention", severity: .moderate, frequency: 40),
                CompoundSideEffect(name: "Severe Lethargy (week 4-5)", severity: .significant, frequency: 45),
                CompoundSideEffect(name: "HDL Cholesterol Crash", severity: .moderate, frequency: 65),
            ],
            communityUsers: 1890,
            averageRating: 4.1,
            stackPartners: ["MK-677"],
            iconName: "figure.arms.open",
            keyFacts: CompoundKeyFacts(molecularWeight: "338 Da", administrationRoute: "Oral", halfLife: "24-36 hours", storageTemp: "Room Temp", reconstitution: "N/A (oral)", typicalDoseRange: "2.5-10 mg daily")
        ),
        CompoundProfile(
            name: "Testolone (RAD-140)",
            peptideType: "Selective Androgen Receptor Modulator",
            categories: [.sarms],
            overview: "Arguably the most potent and androgenic SARM available. Binds androgen receptors with affinity similar to DHT. Produces rapid strength gains, dry muscle mass, and vascularity. Recent data shows half-life is ~60 hours (not 20 as previously believed) — daily dosing causes massive accumulation. Known for causing intense aggression. Requires aggressive PCT (4 weeks Nolvadex/Enclomiphene).",
            protocols: [
                CompoundProtocol(goalName: "Strength & Recomp", description: "Oral daily or every-other-day dosing", typicalDose: "5-15 mg", frequency: "1x daily (oral)", duration: "6-8 weeks + aggressive PCT"),
            ],
            sideEffects: ["Severe testosterone suppression", "Aggression", "Insomnia", "Hair shedding", "Liver toxicity"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Severe T Suppression", severity: .significant, frequency: 95),
                CompoundSideEffect(name: "Aggression / Irritability", severity: .moderate, frequency: 45),
                CompoundSideEffect(name: "Insomnia", severity: .moderate, frequency: 30),
                CompoundSideEffect(name: "Hair Shedding", severity: .moderate, frequency: 25),
                CompoundSideEffect(name: "Liver Enzyme Elevation", severity: .moderate, frequency: 20),
            ],
            communityUsers: 1567,
            averageRating: 3.9,
            stackPartners: ["Enclomiphene"],
            iconName: "bolt.trianglebadge.exclamationmark.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "393 Da", administrationRoute: "Oral", halfLife: "~60 hours", storageTemp: "Room Temp", reconstitution: "N/A (oral)", typicalDoseRange: "5-15 mg daily")
        ),

        // MARK: - Category 9: IGF Variants

        CompoundProfile(
            name: "IGF-1 LR3",
            peptideType: "IGF-1 Analog (Long-Acting)",
            categories: [.igfVariants, .muscleGrowth],
            overview: "A synthetic IGF-1 analog modified to prevent binding to IGF-binding proteins, remaining active for 20-30 hours (vs 20 minutes for natural IGF-1). Drives systemic muscle hyperplasia (new muscle cells) and profound nutrient partitioning. WARNING: Acts like insulin — can cause severe, potentially fatal hypoglycemia. Always consume fast-acting carbs around injection time. Must be reconstituted in Acetic Acid, not BAC Water.",
            protocols: [
                CompoundProtocol(goalName: "Systemic Hyperplasia", description: "Pre-workout or morning, consume carbs", typicalDose: "20-100 mcg", frequency: "1x daily", duration: "4-6 weeks on / 4-6 weeks off"),
            ],
            sideEffects: ["Hypoglycemia", "Extreme hunger", "Lethargy", "Water retention", "Joint pain"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Hypoglycemia", severity: .significant, frequency: 60),
                CompoundSideEffect(name: "Extreme Hunger", severity: .moderate, frequency: 45),
                CompoundSideEffect(name: "Water Retention", severity: .moderate, frequency: 35),
                CompoundSideEffect(name: "Lethargy", severity: .mild, frequency: 25),
            ],
            communityUsers: 567,
            averageRating: 4.0,
            stackPartners: ["HGH / Secretagogues", "PEG-MGF"],
            iconName: "arrow.up.forward",
            keyFacts: CompoundKeyFacts(molecularWeight: "9,112 Da", administrationRoute: "SubQ / IM", halfLife: "20-30 hours", storageTemp: "Freezer (-20°C)", reconstitution: "Acetic Acid (0.6%)", typicalDoseRange: "20-100 mcg daily")
        ),
        CompoundProfile(
            name: "DES IGF-1",
            peptideType: "Truncated IGF-1 Analog",
            categories: [.igfVariants, .muscleGrowth],
            overview: "A truncated IGF-1 missing the first 3 amino acids. Extremely short half-life (20-30 min) — used exclusively for localized, site-specific muscle growth. Must inject directly into the target muscle 10-15 min before training it. Reconstituted in Acetic Acid (draw BAC Water first into syringe to dilute). Unique ability to bind receptors deformed by lactic acid, making it incredibly effective on fatigued muscles.",
            protocols: [
                CompoundProtocol(goalName: "Localized Muscle Growth", description: "IM into target muscle pre-workout", typicalDose: "20-50 mcg", frequency: "1x daily (split bilaterally)", duration: "4 weeks on / 4 weeks off"),
            ],
            sideEffects: ["Intense localized pump", "Injection site pain (Acetic Acid)", "Mild hypoglycemia"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Intense Muscle Pump", severity: .mild, frequency: 70),
                CompoundSideEffect(name: "Injection Site Pain (AA)", severity: .moderate, frequency: 50),
                CompoundSideEffect(name: "Mild Hypoglycemia", severity: .mild, frequency: 15),
            ],
            communityUsers: 345,
            averageRating: 3.9,
            stackPartners: ["PEG-MGF"],
            iconName: "scope",
            keyFacts: CompoundKeyFacts(molecularWeight: "7,372 Da", administrationRoute: "IM (site-specific)", halfLife: "20-30 min", storageTemp: "Freezer (-20°C)", reconstitution: "Acetic Acid", typicalDoseRange: "20-50 mcg daily")
        ),
        CompoundProfile(
            name: "PEG-MGF",
            peptideType: "Pegylated Mechano Growth Factor",
            categories: [.igfVariants, .muscleGrowth],
            overview: "An IGF-1 splice variant naturally produced by muscles during mechanical stress. PEGylation extends half-life to days for systemic muscle repair. Activates satellite cells (muscle stem cells) for hyperplasia. Systemic — no need to inject into trained muscle. Inject on rest days or hours after workout (pre-workout injection is counterproductive). Red welts at injection site are common PEG allergy reaction, not the peptide itself.",
            protocols: [
                CompoundProtocol(goalName: "Satellite Cell Activation", description: "Post-workout or rest day SubQ", typicalDose: "200-500 mcg", frequency: "2-3x weekly", duration: "4-6 weeks on / 4-6 weeks off"),
            ],
            sideEffects: ["Injection site redness/itching (PEG)", "Mild lethargy"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction (PEG)", severity: .mild, frequency: 30),
                CompoundSideEffect(name: "Mild Lethargy", severity: .mild, frequency: 10),
            ],
            communityUsers: 289,
            averageRating: 3.8,
            stackPartners: ["IGF-1 LR3", "DES IGF-1"],
            iconName: "figure.run",
            keyFacts: CompoundKeyFacts(molecularWeight: "PEGylated variant", administrationRoute: "SubQ / IM", halfLife: "48-72 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "200-500 mcg")
        ),

        // MARK: - Category 10: Niche & Other

        CompoundProfile(
            name: "5-Amino-1MQ",
            peptideType: "NNMT Inhibitor (Small Molecule)",
            categories: [.niche, .weightLoss],
            overview: "A small molecule that inhibits NNMT (Nicotinamide N-methyltransferase) enzyme. As we age, NNMT rises in fat tissue depleting NAD+ and slowing fat metabolism. Blocking NNMT prevents NAD+ depletion, shrinks fat tissue, and forces the body to burn fat without caloric restriction. Unique because it doesn't suppress appetite or act as a stimulant — just changes cellular energy processing. Split dosing recommended due to short half-life.",
            protocols: [
                CompoundProtocol(goalName: "Metabolic Enhancement", description: "Oral capsule for NNMT inhibition", typicalDose: "50-100 mg", frequency: "1-2x daily (oral)", duration: "4-8 weeks on / 2-4 weeks off"),
            ],
            sideEffects: ["Mild insomnia (if taken late)", "Mild jitteriness"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Insomnia", severity: .mild, frequency: 10),
                CompoundSideEffect(name: "Jitteriness", severity: .mild, frequency: 5),
            ],
            communityUsers: 234,
            averageRating: 3.9,
            stackPartners: ["NMN / NR", "MOTS-c"],
            iconName: "atom",
            keyFacts: CompoundKeyFacts(molecularWeight: "173 Da", administrationRoute: "Oral", halfLife: "4-7 hours", storageTemp: "Room Temp", reconstitution: "N/A (oral capsule)", typicalDoseRange: "50-100 mg daily")
        ),
        CompoundProfile(
            name: "Tesofensine",
            peptideType: "Triple Monoamine Reuptake Inhibitor",
            categories: [.niche, .weightLoss],
            overview: "A powerful centrally acting drug that inhibits reuptake of serotonin, norepinephrine, and dopamine. Originally for Alzheimer's/Parkinson's, found to cause profound weight loss. WARNING: 9-day half-life means severe side effects persist for weeks after stopping. Never combine with SSRIs (fatal Serotonin Syndrome risk). Start at absolute lowest dose (0.25 mg). Appetite suppression more profound than Adderall or Phentermine.",
            protocols: [
                CompoundProtocol(goalName: "Severe Obesity", description: "Oral daily, start at minimum dose", typicalDose: "0.25-1.0 mg", frequency: "1x daily (morning)", duration: "12-24 weeks"),
            ],
            sideEffects: ["Dry mouth", "Insomnia", "Constipation", "Increased heart rate", "Anxiety", "Hypertension"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Dry Mouth", severity: .moderate, frequency: 45),
                CompoundSideEffect(name: "Insomnia", severity: .moderate, frequency: 35),
                CompoundSideEffect(name: "Increased Heart Rate", severity: .moderate, frequency: 30),
                CompoundSideEffect(name: "Anxiety", severity: .moderate, frequency: 20),
                CompoundSideEffect(name: "Hypertension", severity: .significant, frequency: 15),
            ],
            communityUsers: 567,
            averageRating: 3.7,
            stackPartners: [],
            iconName: "exclamationmark.triangle.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "326 Da", administrationRoute: "Oral", halfLife: "~9 days (220 hours)", storageTemp: "Room Temp", reconstitution: "N/A (oral capsule)", typicalDoseRange: "0.25-1.0 mg daily")
        ),
        CompoundProfile(
            name: "Follistatin (FST-344)",
            peptideType: "Myostatin Inhibitor",
            categories: [.niche, .muscleGrowth],
            overview: "A naturally occurring protein that binds to and inhibits myostatin — the body's primary 'muscle growth brake.' By blocking myostatin, Follistatin unleashes the body's full potential for muscle hypertrophy. Extremely expensive and fragile. Effects are dramatic but temporary. Must maintain massive protein intake to fuel the rapid muscle growth. Research-grade only, very limited human data.",
            protocols: [
                CompoundProtocol(goalName: "Myostatin Inhibition", description: "SubQ for muscle growth potential", typicalDose: "100-300 mcg", frequency: "1x daily", duration: "10-30 days"),
            ],
            sideEffects: ["Injection site reaction", "Fatigue", "Joint stress (rapid growth)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reaction", severity: .mild, frequency: 15),
                CompoundSideEffect(name: "Fatigue", severity: .mild, frequency: 10),
                CompoundSideEffect(name: "Joint Stress", severity: .moderate, frequency: 8),
            ],
            communityUsers: 123,
            averageRating: 3.7,
            stackPartners: ["IGF-1 LR3"],
            iconName: "lock.open.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "36,000 Da", administrationRoute: "Subcutaneous", halfLife: "Short", storageTemp: "Freezer (-20°C)", reconstitution: "BAC Water", typicalDoseRange: "100-300 mcg daily")
        ),
    ]

    static let vendors: [Vendor] = [
        Vendor(
            name: "PeptideSciences",
            isVerified: true,
            rating: 4.8,
            reviewCount: 1247,
            compoundsCarried: ["BPC-157", "TB-500", "CJC-1295", "Ipamorelin", "GHK-Cu", "Semax", "Selank", "Epithalon", "AOD-9604", "DSIP", "KPV", "Sermorelin", "GHRP-2", "GHRP-6", "Hexarelin", "Thymosin Alpha-1", "LL-37"],
            websiteURL: "https://peptidesciences.com",
            reviews: [
                VendorReview(userName: "ResearcherJ", rating: 5, text: "Consistent quality, fast shipping. COAs always available.", daysAgo: 3),
                VendorReview(userName: "LabTech42", rating: 5, text: "Third-party tested. My go-to source.", daysAgo: 12),
                VendorReview(userName: "PepUser88", rating: 4, text: "Great products but pricing is on the higher end.", daysAgo: 20),
            ]
        ),
        Vendor(
            name: "CorePeptides",
            isVerified: true,
            rating: 4.6,
            reviewCount: 834,
            compoundsCarried: ["BPC-157", "TB-500", "Semaglutide", "Tirzepatide", "MK-677", "Tesamorelin", "Melanotan II", "PT-141", "Cagrilintide", "Retatrutide"],
            websiteURL: "https://corepeptides.com",
            reviews: [
                VendorReview(userName: "FitLife", rating: 5, text: "GLP-1 products are legit. Lab tested.", daysAgo: 5),
                VendorReview(userName: "PepNewbie", rating: 4, text: "Good customer service, helped me with reconstitution questions.", daysAgo: 15),
            ]
        ),
        Vendor(
            name: "AmericaResearch",
            isVerified: true,
            rating: 4.5,
            reviewCount: 612,
            compoundsCarried: ["BPC-157", "CJC-1295", "Ipamorelin", "GHK-Cu", "Retatrutide", "Sermorelin", "IGF-1 LR3", "PEG-MGF", "Follistatin (FST-344)"],
            websiteURL: "https://americaresearch.com",
            reviews: [
                VendorReview(userName: "ScienceFirst", rating: 5, text: "Best COAs in the business. Transparent testing.", daysAgo: 7),
                VendorReview(userName: "HealingJourney", rating: 4, text: "BPC and TB-500 quality is excellent.", daysAgo: 22),
            ]
        ),
        Vendor(
            name: "PureRawz",
            isVerified: false,
            rating: 4.1,
            reviewCount: 423,
            compoundsCarried: ["MK-677", "Semax", "Selank", "DSIP", "Epithalon", "AOD-9604", "Ostarine (MK-2866)", "Ligandrol (LGD-4033)", "Testolone (RAD-140)", "5-Amino-1MQ"],
            websiteURL: "https://purerawz.co",
            reviews: [
                VendorReview(userName: "NootUser", rating: 4, text: "Good nootropic peptides. Nasal sprays work well.", daysAgo: 10),
            ]
        ),
        Vendor(
            name: "SwissChems",
            isVerified: true,
            rating: 4.4,
            reviewCount: 567,
            compoundsCarried: ["Ostarine (MK-2866)", "Ligandrol (LGD-4033)", "Testolone (RAD-140)", "MK-677", "Tesofensine", "5-Amino-1MQ", "Dihexa", "Cerebrolysin"],
            websiteURL: "https://swisschems.is",
            reviews: [
                VendorReview(userName: "GymBro", rating: 5, text: "Best source for SARMs. Always potent.", daysAgo: 8),
                VendorReview(userName: "Researcher99", rating: 4, text: "Nootropic selection is excellent. Fast shipping to US.", daysAgo: 18),
            ]
        ),
    ]

    static func compounds(for category: PeptideCategory) -> [CompoundProfile] {
        if category == .all { return all }
        return all.filter { $0.categories.contains(category) }
    }

    static func vendors(for compoundName: String) -> [Vendor] {
        vendors.filter { $0.compoundsCarried.contains(compoundName) }
    }

    static func compound(named name: String) -> CompoundProfile? {
        all.first { $0.name == name }
    }
}
