import Foundation

enum CompoundDatabase {
    static let all: [CompoundProfile] = [
        CompoundProfile(
            name: "BPC-157",
            peptideType: "Body Protection Compound",
            categories: [.healing, .muscleGrowth],
            overview: "A pentadecapeptide derived from human gastric juice. Widely discussed in research communities for its role in tissue repair, gut healing, and tendon/ligament recovery. One of the most popular peptides among the community.",
            protocols: [
                CompoundProtocol(goalName: "Injury Recovery", description: "Commonly discussed for localized tissue repair", typicalDose: "250-500 mcg", frequency: "2x daily", duration: "4-6 weeks"),
                CompoundProtocol(goalName: "Gut Health", description: "Discussed for GI tract healing and inflammation", typicalDose: "250 mcg", frequency: "2x daily", duration: "4-8 weeks"),
            ],
            sideEffects: ["Nausea (rare)", "Dizziness (rare)", "Injection site irritation"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .mild, frequency: 8),
                CompoundSideEffect(name: "Dizziness", severity: .mild, frequency: 5),
                CompoundSideEffect(name: "Injection Site Irritation", severity: .mild, frequency: 15),
            ],
            communityUsers: 2847,
            averageRating: 4.7,
            stackPartners: ["TB-500", "GHK-Cu"],
            iconName: "cross.case.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,419 Da", administrationRoute: "Subcutaneous", halfLife: "~4 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "250-500 mcg")
        ),
        CompoundProfile(
            name: "TB-500",
            peptideType: "Thymosin Beta-4 Fragment",
            categories: [.healing, .muscleGrowth],
            overview: "A synthetic version of Thymosin Beta-4, a naturally occurring peptide. Discussed in research for systemic healing, reducing inflammation, and promoting tissue repair throughout the body.",
            protocols: [
                CompoundProtocol(goalName: "General Healing", description: "Systemic tissue repair and recovery", typicalDose: "2-5 mg", frequency: "2x weekly", duration: "4-6 weeks"),
            ],
            sideEffects: ["Headache", "Lethargy", "Injection site redness"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Headache", severity: .moderate, frequency: 18),
                CompoundSideEffect(name: "Lethargy", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Injection Site Redness", severity: .mild, frequency: 20),
            ],
            communityUsers: 1923,
            averageRating: 4.5,
            stackPartners: ["BPC-157", "GHK-Cu"],
            iconName: "bandage.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,963 Da", administrationRoute: "Subcutaneous", halfLife: "~2 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "2-5 mg")
        ),
        CompoundProfile(
            name: "GHK-Cu",
            peptideType: "Copper Peptide",
            categories: [.healing, .antiAging, .tanning],
            overview: "A naturally occurring copper complex found in human plasma. Researched for skin remodeling, wound healing, collagen synthesis, and anti-aging properties. Available in both injectable and topical forms.",
            protocols: [
                CompoundProtocol(goalName: "Skin Rejuvenation", description: "Topical or injectable for skin health", typicalDose: "1-2 mg", frequency: "Daily", duration: "4-8 weeks"),
            ],
            sideEffects: ["Skin irritation (topical)", "Injection site redness"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Skin Irritation", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Injection Site Redness", severity: .mild, frequency: 10),
            ],
            communityUsers: 1245,
            averageRating: 4.3,
            stackPartners: ["BPC-157", "Epithalon"],
            iconName: "sparkles",
            keyFacts: CompoundKeyFacts(molecularWeight: "403 Da", administrationRoute: "Subcutaneous / Topical", halfLife: "~30 min", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "1-2 mg")
        ),
        CompoundProfile(
            name: "CJC-1295",
            peptideType: "Growth Hormone Releasing Hormone",
            categories: [.muscleGrowth, .antiAging],
            overview: "A synthetic analog of growth hormone releasing hormone (GHRH). Often discussed with DAC (Drug Affinity Complex) for extended half-life. Researched for growth hormone elevation, body composition, and recovery.",
            protocols: [
                CompoundProtocol(goalName: "GH Optimization", description: "Combined with Ipamorelin for synergistic effect", typicalDose: "100-300 mcg", frequency: "Daily (before bed)", duration: "8-12 weeks"),
            ],
            sideEffects: ["Water retention", "Tingling/numbness", "Increased hunger", "Fatigue"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Water Retention", severity: .moderate, frequency: 35),
                CompoundSideEffect(name: "Tingling / Numbness", severity: .mild, frequency: 22),
                CompoundSideEffect(name: "Increased Hunger", severity: .mild, frequency: 28),
                CompoundSideEffect(name: "Fatigue", severity: .mild, frequency: 15),
            ],
            communityUsers: 2156,
            averageRating: 4.4,
            stackPartners: ["Ipamorelin", "MK-677"],
            iconName: "arrow.up.right",
            keyFacts: CompoundKeyFacts(molecularWeight: "3,367 Da", administrationRoute: "Subcutaneous", halfLife: "~30 min (no DAC) / ~8 days (DAC)", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100-300 mcg")
        ),
        CompoundProfile(
            name: "Ipamorelin",
            peptideType: "Growth Hormone Secretagogue",
            categories: [.muscleGrowth, .antiAging],
            overview: "A selective growth hormone secretagogue that stimulates GH release without significantly affecting cortisol or prolactin. Considered one of the mildest GH peptides with fewer side effects.",
            protocols: [
                CompoundProtocol(goalName: "Lean Mass & Recovery", description: "Often paired with CJC-1295", typicalDose: "200-300 mcg", frequency: "2-3x daily", duration: "8-12 weeks"),
            ],
            sideEffects: ["Mild hunger increase", "Water retention (mild)", "Head rush"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Hunger Increase", severity: .mild, frequency: 20),
                CompoundSideEffect(name: "Water Retention", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Head Rush", severity: .mild, frequency: 8),
            ],
            communityUsers: 1876,
            averageRating: 4.6,
            stackPartners: ["CJC-1295", "Tesamorelin"],
            iconName: "figure.strengthtraining.traditional",
            keyFacts: CompoundKeyFacts(molecularWeight: "711 Da", administrationRoute: "Subcutaneous", halfLife: "~2 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "200-300 mcg")
        ),
        CompoundProfile(
            name: "MK-677",
            peptideType: "Growth Hormone Secretagogue (Oral)",
            categories: [.muscleGrowth, .antiAging],
            overview: "An orally active growth hormone secretagogue (not technically a peptide). Researched for increasing GH and IGF-1 levels, improving sleep quality, and supporting lean mass. Taken orally, no injection needed.",
            protocols: [
                CompoundProtocol(goalName: "GH Elevation", description: "Oral dosing, typically before bed", typicalDose: "10-25 mg", frequency: "Daily", duration: "8-16 weeks"),
            ],
            sideEffects: ["Increased appetite", "Water retention", "Numbness/tingling", "Elevated blood sugar"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Increased Appetite", severity: .significant, frequency: 65),
                CompoundSideEffect(name: "Water Retention", severity: .moderate, frequency: 45),
                CompoundSideEffect(name: "Numbness / Tingling", severity: .mild, frequency: 20),
                CompoundSideEffect(name: "Elevated Blood Sugar", severity: .moderate, frequency: 18),
            ],
            communityUsers: 3214,
            averageRating: 4.2,
            stackPartners: ["CJC-1295", "Ipamorelin"],
            iconName: "pills.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "528 Da", administrationRoute: "Oral", halfLife: "~24 hours", storageTemp: "Room Temp", reconstitution: "N/A (oral)", typicalDoseRange: "10-25 mg")
        ),
        CompoundProfile(
            name: "Tesamorelin",
            peptideType: "Growth Hormone Releasing Hormone",
            categories: [.weightLoss, .muscleGrowth],
            overview: "An FDA-approved GHRH analog originally for HIV-associated lipodystrophy. Researched for reducing visceral fat, improving body composition, and elevating GH levels. One of the few peptides with FDA approval.",
            protocols: [
                CompoundProtocol(goalName: "Fat Reduction", description: "Targets visceral adiposity", typicalDose: "1-2 mg", frequency: "Daily", duration: "12-26 weeks"),
            ],
            sideEffects: ["Injection site reactions", "Joint pain", "Peripheral edema"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Reactions", severity: .mild, frequency: 25),
                CompoundSideEffect(name: "Joint Pain", severity: .moderate, frequency: 15),
                CompoundSideEffect(name: "Peripheral Edema", severity: .moderate, frequency: 12),
            ],
            communityUsers: 987,
            averageRating: 4.5,
            stackPartners: ["Ipamorelin", "CJC-1295"],
            iconName: "flame.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "5,136 Da", administrationRoute: "Subcutaneous", halfLife: "~26 min", storageTemp: "2-8°C", reconstitution: "Sterile Water", typicalDoseRange: "1-2 mg")
        ),
        CompoundProfile(
            name: "Semax",
            peptideType: "Nootropic Peptide",
            categories: [.cognitive],
            overview: "A synthetic analog of ACTH (4-10) developed in Russia. Researched for cognitive enhancement, neuroprotection, and mood improvement. Administered nasally, no injection required.",
            protocols: [
                CompoundProtocol(goalName: "Cognitive Enhancement", description: "Nasal administration for focus and memory", typicalDose: "200-600 mcg", frequency: "1-2x daily", duration: "2-4 weeks on, 2 weeks off"),
            ],
            sideEffects: ["Nasal irritation", "Headache (rare)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nasal Irritation", severity: .mild, frequency: 15),
                CompoundSideEffect(name: "Headache", severity: .mild, frequency: 5),
            ],
            communityUsers: 756,
            averageRating: 4.4,
            stackPartners: ["Selank", "Epithalon"],
            iconName: "brain.head.profile",
            keyFacts: CompoundKeyFacts(molecularWeight: "813 Da", administrationRoute: "Intranasal", halfLife: "~20 min", storageTemp: "2-8°C", reconstitution: "Pre-mixed nasal spray", typicalDoseRange: "200-600 mcg")
        ),
        CompoundProfile(
            name: "Selank",
            peptideType: "Anxiolytic Peptide",
            categories: [.cognitive],
            overview: "A synthetic analog of the immunomodulatory peptide tuftsin. Researched for anxiolytic effects, cognitive enhancement, and immune modulation. Administered nasally.",
            protocols: [
                CompoundProtocol(goalName: "Anxiety & Focus", description: "Nasal spray for mood and cognition", typicalDose: "250-500 mcg", frequency: "1-3x daily", duration: "2-4 weeks on, 2 weeks off"),
            ],
            sideEffects: ["Fatigue (rare)", "Nasal irritation"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Fatigue", severity: .mild, frequency: 6),
                CompoundSideEffect(name: "Nasal Irritation", severity: .mild, frequency: 12),
            ],
            communityUsers: 542,
            averageRating: 4.3,
            stackPartners: ["Semax"],
            iconName: "brain",
            keyFacts: CompoundKeyFacts(molecularWeight: "751 Da", administrationRoute: "Intranasal", halfLife: "~15 min", storageTemp: "2-8°C", reconstitution: "Pre-mixed nasal spray", typicalDoseRange: "250-500 mcg")
        ),
        CompoundProfile(
            name: "Epithalon",
            peptideType: "Telomerase Activator",
            categories: [.antiAging],
            overview: "A synthetic tetrapeptide researched for its potential to activate telomerase, the enzyme responsible for maintaining telomere length. Discussed in longevity and anti-aging research communities.",
            protocols: [
                CompoundProtocol(goalName: "Anti-Aging", description: "Cyclical protocol for longevity", typicalDose: "5-10 mg", frequency: "Daily", duration: "10-20 days, 2-3x per year"),
            ],
            sideEffects: ["Injection site irritation (rare)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Injection Site Irritation", severity: .mild, frequency: 5),
            ],
            communityUsers: 634,
            averageRating: 4.1,
            stackPartners: ["GHK-Cu", "Semax"],
            iconName: "hourglass",
            keyFacts: CompoundKeyFacts(molecularWeight: "390 Da", administrationRoute: "Subcutaneous", halfLife: "~2 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "5-10 mg")
        ),
        CompoundProfile(
            name: "Melanotan II",
            peptideType: "Melanocortin Receptor Agonist",
            categories: [.tanning],
            overview: "A synthetic analog of alpha-melanocyte stimulating hormone. Researched for its tanning effects and discussed in communities for UV-free tanning. Requires careful dosing and has notable side effects.",
            protocols: [
                CompoundProtocol(goalName: "Tanning", description: "Loading phase followed by maintenance", typicalDose: "250-500 mcg", frequency: "Daily (loading) then 1-2x/week", duration: "2 weeks loading, then maintenance"),
            ],
            sideEffects: ["Nausea", "Facial flushing", "Appetite suppression", "Darkened moles", "Increased libido"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 55),
                CompoundSideEffect(name: "Facial Flushing", severity: .moderate, frequency: 45),
                CompoundSideEffect(name: "Appetite Suppression", severity: .mild, frequency: 30),
                CompoundSideEffect(name: "Darkened Moles", severity: .moderate, frequency: 35),
                CompoundSideEffect(name: "Increased Libido", severity: .mild, frequency: 40),
            ],
            communityUsers: 1567,
            averageRating: 4.0,
            stackPartners: ["PT-141"],
            iconName: "sun.max.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,024 Da", administrationRoute: "Subcutaneous", halfLife: "~1 hour", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "250-500 mcg")
        ),
        CompoundProfile(
            name: "PT-141",
            peptideType: "Melanocortin Receptor Agonist",
            categories: [.tanning],
            overview: "Bremelanotide, a synthetic peptide that acts on melanocortin receptors. FDA-approved (as Vyleesi) for hypoactive sexual desire disorder in women. Discussed in communities for libido enhancement.",
            protocols: [
                CompoundProtocol(goalName: "Libido Enhancement", description: "As-needed dosing", typicalDose: "500-1000 mcg", frequency: "As needed (max 1x/24hr)", duration: "As needed"),
            ],
            sideEffects: ["Nausea", "Flushing", "Headache", "Increased blood pressure (transient)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 50),
                CompoundSideEffect(name: "Flushing", severity: .moderate, frequency: 40),
                CompoundSideEffect(name: "Headache", severity: .moderate, frequency: 25),
                CompoundSideEffect(name: "Increased Blood Pressure", severity: .moderate, frequency: 15),
            ],
            communityUsers: 823,
            averageRating: 4.1,
            stackPartners: ["Melanotan II"],
            iconName: "heart.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,025 Da", administrationRoute: "Subcutaneous", halfLife: "~2 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "500-1000 mcg")
        ),
        CompoundProfile(
            name: "Thymosin Beta-4",
            peptideType: "Thymic Peptide",
            categories: [.healing],
            overview: "The full-length naturally occurring peptide (TB-500 is a fragment). Researched for tissue repair, immune modulation, and wound healing. A cornerstone healing peptide in the research community.",
            protocols: [
                CompoundProtocol(goalName: "Systemic Healing", description: "Full-length thymosin beta-4 protocol", typicalDose: "750 mcg - 2 mg", frequency: "2x weekly", duration: "4-8 weeks"),
            ],
            sideEffects: ["Headache", "Flu-like symptoms (rare)"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Headache", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Flu-like Symptoms", severity: .mild, frequency: 5),
            ],
            communityUsers: 678,
            averageRating: 4.4,
            stackPartners: ["BPC-157", "GHK-Cu"],
            iconName: "wand.and.stars",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,963 Da", administrationRoute: "Subcutaneous", halfLife: "~2 hours", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "750 mcg - 2 mg")
        ),
        CompoundProfile(
            name: "Semaglutide",
            peptideType: "GLP-1 Receptor Agonist",
            categories: [.weightLoss],
            overview: "An FDA-approved GLP-1 receptor agonist (Ozempic/Wegovy). Extensively researched and prescribed for type 2 diabetes and weight management. One of the most discussed compounds in the weight loss community.",
            protocols: [
                CompoundProtocol(goalName: "Weight Loss", description: "Gradual dose titration over weeks", typicalDose: "0.25 mg → 2.4 mg", frequency: "Weekly", duration: "Ongoing (as prescribed)"),
            ],
            sideEffects: ["Nausea", "Diarrhea", "Constipation", "Decreased appetite", "Fatigue", "Injection site reactions"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 58),
                CompoundSideEffect(name: "Diarrhea", severity: .moderate, frequency: 30),
                CompoundSideEffect(name: "Constipation", severity: .moderate, frequency: 25),
                CompoundSideEffect(name: "Decreased Appetite", severity: .mild, frequency: 70),
                CompoundSideEffect(name: "Fatigue", severity: .mild, frequency: 20),
                CompoundSideEffect(name: "Injection Site Reactions", severity: .mild, frequency: 15),
            ],
            communityUsers: 5432,
            averageRating: 4.6,
            stackPartners: ["Tirzepatide", "BPC-157"],
            iconName: "scalemass.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,114 Da", administrationRoute: "Subcutaneous", halfLife: "~7 days", storageTemp: "2-8°C", reconstitution: "Pre-filled pen", typicalDoseRange: "0.25-2.4 mg")
        ),
        CompoundProfile(
            name: "Tirzepatide",
            peptideType: "GLP-1/GIP Dual Agonist",
            categories: [.weightLoss],
            overview: "An FDA-approved dual incretin agonist (Mounjaro/Zepbound). Acts on both GLP-1 and GIP receptors. Research shows significant weight loss potential, often discussed as more effective than semaglutide alone.",
            protocols: [
                CompoundProtocol(goalName: "Weight Loss", description: "Gradual dose escalation", typicalDose: "2.5 mg → 15 mg", frequency: "Weekly", duration: "Ongoing (as prescribed)"),
            ],
            sideEffects: ["Nausea", "Diarrhea", "Decreased appetite", "Injection site reactions", "Abdominal pain"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 52),
                CompoundSideEffect(name: "Diarrhea", severity: .moderate, frequency: 28),
                CompoundSideEffect(name: "Decreased Appetite", severity: .mild, frequency: 65),
                CompoundSideEffect(name: "Injection Site Reactions", severity: .mild, frequency: 12),
                CompoundSideEffect(name: "Abdominal Pain", severity: .moderate, frequency: 18),
            ],
            communityUsers: 3876,
            averageRating: 4.7,
            stackPartners: ["Semaglutide", "BPC-157"],
            iconName: "arrow.down.right",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,814 Da", administrationRoute: "Subcutaneous", halfLife: "~5 days", storageTemp: "2-8°C", reconstitution: "Pre-filled pen", typicalDoseRange: "2.5-15 mg")
        ),
        CompoundProfile(
            name: "Retatrutide",
            peptideType: "GLP-1/GIP/Glucagon Triple Agonist",
            categories: [.weightLoss],
            overview: "A next-generation triple agonist targeting GLP-1, GIP, and glucagon receptors. Currently in clinical trials with promising weight loss data. Discussed as potentially the most effective weight loss peptide in development.",
            protocols: [
                CompoundProtocol(goalName: "Weight Loss", description: "Research compound - dose titration", typicalDose: "1 mg → 12 mg", frequency: "Weekly", duration: "Per research protocol"),
            ],
            sideEffects: ["Nausea", "Diarrhea", "Vomiting", "Decreased appetite"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Nausea", severity: .significant, frequency: 48),
                CompoundSideEffect(name: "Diarrhea", severity: .moderate, frequency: 32),
                CompoundSideEffect(name: "Vomiting", severity: .moderate, frequency: 18),
                CompoundSideEffect(name: "Decreased Appetite", severity: .mild, frequency: 60),
            ],
            communityUsers: 1234,
            averageRating: 4.3,
            stackPartners: ["BPC-157"],
            iconName: "chart.line.downtrend.xyaxis",
            keyFacts: CompoundKeyFacts(molecularWeight: "4,605 Da", administrationRoute: "Subcutaneous", halfLife: "~6 days", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "1-12 mg")
        ),
        CompoundProfile(
            name: "AOD-9604",
            peptideType: "Growth Hormone Fragment",
            categories: [.weightLoss],
            overview: "A modified fragment of human growth hormone (amino acids 176-191). Researched specifically for fat metabolism without the growth-promoting effects of full GH. Discussed as a targeted fat loss peptide.",
            protocols: [
                CompoundProtocol(goalName: "Fat Loss", description: "Fasted administration for fat metabolism", typicalDose: "250-500 mcg", frequency: "Daily (fasted)", duration: "8-12 weeks"),
            ],
            sideEffects: ["Headache (rare)", "Injection site irritation"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Headache", severity: .mild, frequency: 8),
                CompoundSideEffect(name: "Injection Site Irritation", severity: .mild, frequency: 10),
            ],
            communityUsers: 1098,
            averageRating: 3.9,
            stackPartners: ["CJC-1295", "Ipamorelin"],
            iconName: "flame",
            keyFacts: CompoundKeyFacts(molecularWeight: "1,815 Da", administrationRoute: "Subcutaneous", halfLife: "~30 min", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "250-500 mcg")
        ),
        CompoundProfile(
            name: "DSIP",
            peptideType: "Delta Sleep-Inducing Peptide",
            categories: [.cognitive],
            overview: "A neuropeptide naturally found in the brain. Researched for its role in promoting delta wave sleep, stress reduction, and hormonal balance during sleep cycles.",
            protocols: [
                CompoundProtocol(goalName: "Sleep Optimization", description: "Pre-sleep administration", typicalDose: "100-300 mcg", frequency: "Daily (before bed)", duration: "2-4 weeks"),
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
            keyFacts: CompoundKeyFacts(molecularWeight: "849 Da", administrationRoute: "Subcutaneous / Intranasal", halfLife: "~15 min", storageTemp: "2-8°C", reconstitution: "BAC Water", typicalDoseRange: "100-300 mcg")
        ),
        CompoundProfile(
            name: "KPV",
            peptideType: "Anti-Inflammatory Tripeptide",
            categories: [.healing],
            overview: "A tripeptide fragment of alpha-MSH with potent anti-inflammatory properties. Researched for gut inflammation, skin conditions, and systemic inflammation reduction. Available in oral and injectable forms.",
            protocols: [
                CompoundProtocol(goalName: "Gut Health", description: "Oral or injectable for inflammation", typicalDose: "200-500 mcg", frequency: "1-2x daily", duration: "4-8 weeks"),
            ],
            sideEffects: ["Minimal reported side effects"],
            structuredSideEffects: [
                CompoundSideEffect(name: "Minimal Side Effects", severity: .mild, frequency: 3),
            ],
            communityUsers: 567,
            averageRating: 4.2,
            stackPartners: ["BPC-157", "GHK-Cu"],
            iconName: "leaf.fill",
            keyFacts: CompoundKeyFacts(molecularWeight: "357 Da", administrationRoute: "Oral / Subcutaneous", halfLife: "~20 min", storageTemp: "2-8°C", reconstitution: "BAC Water / Oral capsule", typicalDoseRange: "200-500 mcg")
        ),
    ]

    static let vendors: [Vendor] = [
        Vendor(
            name: "PeptideSciences",
            isVerified: true,
            rating: 4.8,
            reviewCount: 1247,
            compoundsCarried: ["BPC-157", "TB-500", "CJC-1295", "Ipamorelin", "GHK-Cu", "Semax", "Selank", "Epithalon", "AOD-9604", "DSIP", "KPV"],
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
            compoundsCarried: ["BPC-157", "TB-500", "Semaglutide", "Tirzepatide", "MK-677", "Tesamorelin", "Melanotan II", "PT-141"],
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
            compoundsCarried: ["BPC-157", "CJC-1295", "Ipamorelin", "Thymosin Beta-4", "GHK-Cu", "Retatrutide"],
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
            compoundsCarried: ["MK-677", "Semax", "Selank", "DSIP", "Epithalon", "AOD-9604"],
            websiteURL: "https://purerawz.co",
            reviews: [
                VendorReview(userName: "NootUser", rating: 4, text: "Good nootropic peptides. Nasal sprays work well.", daysAgo: 10),
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
