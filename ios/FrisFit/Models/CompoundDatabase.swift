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
            communityUsers: 2847,
            averageRating: 4.7,
            stackPartners: ["TB-500", "GHK-Cu"],
            iconName: "cross.case.fill"
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
            communityUsers: 1923,
            averageRating: 4.5,
            stackPartners: ["BPC-157", "GHK-Cu"],
            iconName: "bandage.fill"
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
            communityUsers: 1245,
            averageRating: 4.3,
            stackPartners: ["BPC-157", "Epithalon"],
            iconName: "sparkles"
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
            communityUsers: 2156,
            averageRating: 4.4,
            stackPartners: ["Ipamorelin", "MK-677"],
            iconName: "arrow.up.right"
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
            communityUsers: 1876,
            averageRating: 4.6,
            stackPartners: ["CJC-1295", "Tesamorelin"],
            iconName: "figure.strengthtraining.traditional"
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
            communityUsers: 3214,
            averageRating: 4.2,
            stackPartners: ["CJC-1295", "Ipamorelin"],
            iconName: "pills.fill"
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
            communityUsers: 987,
            averageRating: 4.5,
            stackPartners: ["Ipamorelin", "CJC-1295"],
            iconName: "flame.fill"
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
            communityUsers: 756,
            averageRating: 4.4,
            stackPartners: ["Selank", "Epithalon"],
            iconName: "brain.head.profile"
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
            communityUsers: 542,
            averageRating: 4.3,
            stackPartners: ["Semax"],
            iconName: "brain"
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
            communityUsers: 634,
            averageRating: 4.1,
            stackPartners: ["GHK-Cu", "Semax"],
            iconName: "hourglass"
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
            communityUsers: 1567,
            averageRating: 4.0,
            stackPartners: ["PT-141"],
            iconName: "sun.max.fill"
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
            communityUsers: 823,
            averageRating: 4.1,
            stackPartners: ["Melanotan II"],
            iconName: "heart.fill"
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
            communityUsers: 678,
            averageRating: 4.4,
            stackPartners: ["BPC-157", "GHK-Cu"],
            iconName: "wand.and.stars"
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
            communityUsers: 5432,
            averageRating: 4.6,
            stackPartners: ["Tirzepatide", "BPC-157"],
            iconName: "scalemass.fill"
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
            communityUsers: 3876,
            averageRating: 4.7,
            stackPartners: ["Semaglutide", "BPC-157"],
            iconName: "arrow.down.right"
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
            communityUsers: 1234,
            averageRating: 4.3,
            stackPartners: ["BPC-157"],
            iconName: "chart.line.downtrend.xyaxis"
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
            communityUsers: 1098,
            averageRating: 3.9,
            stackPartners: ["CJC-1295", "Ipamorelin"],
            iconName: "flame"
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
            communityUsers: 432,
            averageRating: 4.0,
            stackPartners: ["Semax", "Selank"],
            iconName: "moon.fill"
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
            communityUsers: 567,
            averageRating: 4.2,
            stackPartners: ["BPC-157", "GHK-Cu"],
            iconName: "leaf.fill"
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
