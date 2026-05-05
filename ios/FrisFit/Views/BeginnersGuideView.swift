import SwiftUI

struct BeginnersGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: GuideSection = .whatArePeptides

    private enum GuideSection: String, CaseIterable, Identifiable {
        case whatArePeptides = "What Are Peptides"
        case reconstitution = "Reconstitution"
        case injection = "Injection Technique"
        case storage = "Storage & Handling"
        case coas = "Reading COAs"

        var id: String { rawValue }

        var index: String {
            switch self {
            case .whatArePeptides: return "01"
            case .reconstitution: return "02"
            case .injection: return "03"
            case .storage: return "04"
            case .coas: return "05"
            }
        }

        var shortLabel: String {
            switch self {
            case .whatArePeptides: return "Basics"
            case .reconstitution: return "Reconstitution"
            case .injection: return "Injection"
            case .storage: return "Storage"
            case .coas: return "COAs"
            }
        }

        var subtitle: String {
            switch self {
            case .whatArePeptides: return "The fundamentals"
            case .reconstitution: return "Mixing peptides"
            case .injection: return "Safe administration"
            case .storage: return "Keep them potent"
            case .coas: return "Verify quality"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroHeader

                    sectionPicker

                    contentForSection
                        .transition(.opacity)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("THE GUIDE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("ISSUE 01")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PepTheme.teal.opacity(0.9))
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.45))
                Text("PEPTIDE RESEARCH")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                Spacer()
            }

            Text("Understanding\npeptide research")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .kerning(-0.6)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("A complete primer on reconstitution, injection technique, storage, and how to read a Certificate of Analysis.")
                .font(.system(.subheadline, weight: .regular))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                metaItem(label: "Sections", value: "05")
                hairlineDivider()
                metaItem(label: "Reading", value: "8 min")
                hairlineDivider()
                metaItem(label: "Level", value: "Beginner")
                Spacer()
            }
            .padding(.top, 4)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
                .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func metaItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            Text(value)
                .font(.system(.footnote, design: .serif, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private func hairlineDivider() -> some View {
        Rectangle()
            .fill(PepTheme.separatorColor)
            .frame(width: 0.5, height: 22)
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(GuideSection.allCases) { section in
                        let isSelected = selectedSection == section
                        Button {
                            withAnimation(.smooth(duration: 0.35)) {
                                selectedSection = section
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(section.index)
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary.opacity(0.55))
                                    Text(section.shortLabel.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundStyle(isSelected ? PepTheme.textPrimary : PepTheme.textSecondary.opacity(0.75))
                                }
                                Rectangle()
                                    .fill(isSelected ? PepTheme.teal : Color.clear)
                                    .frame(width: 28, height: 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: selectedSection)
                    }
                }
                .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, 20)

            Rectangle()
                .fill(PepTheme.separatorColor.opacity(0.6))
                .frame(height: 0.5)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionIntro

            switch selectedSection {
            case .whatArePeptides:
                whatArePeptidesContent
            case .reconstitution:
                reconstitutionContent
            case .injection:
                injectionContent
            case .storage:
                storageContent
            case .coas:
                coaContent
            }

            disclaimerLine
        }
        .padding(.horizontal, 20)
        .id(selectedSection)
    }

    private var sectionIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(selectedSection.index)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PepTheme.teal)
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.45))
                Text(selectedSection.subtitle.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
            }
            Text(selectedSection.rawValue)
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .kerning(-0.4)
        }
    }

    // MARK: - Sections

    private var whatArePeptidesContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            editorialPassage(
                eyebrow: "Definition",
                number: "01",
                title: "What are peptides?",
                body: "Peptides are short chains of amino acids — the building blocks of proteins. They occur naturally in your body and play roles in signaling, healing, and regulation. Research peptides are synthetic versions studied for various biological effects."
            )
            editorialPassage(
                eyebrow: "Mechanism",
                number: "02",
                title: "How they work",
                body: "Peptides bind to specific receptors in your body, triggering biological responses. Different peptides target different systems — some promote tissue repair, others influence growth hormone release, metabolism, or cognitive function."
            )
            categoryOverview
        }
    }

    private var categoryOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Categories", number: "03", accent: PepTheme.teal)

            VStack(spacing: 0) {
                let cats = PeptideCategory.allCases.filter { $0 != .all }
                ForEach(Array(cats.enumerated()), id: \.offset) { idx, cat in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(String(format: "%02d", idx + 1))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.55))
                            .frame(width: 22, alignment: .leading)
                        Text(cat.rawValue)
                            .font(.system(.subheadline, design: .serif, weight: .regular))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer(minLength: 12)
                        Text(categoryExamples(for: cat))
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 12)

                    if idx < cats.count - 1 {
                        Rectangle()
                            .fill(PepTheme.separatorColor.opacity(0.6))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private func categoryExamples(for category: PeptideCategory) -> String {
        switch category {
        case .muscleGrowth: return "CJC-1295, Ipamorelin"
        case .healing: return "BPC-157, TB-500"
        case .weightLoss: return "Semaglutide, Tirzepatide"
        case .cognitive: return "Semax, Selank"
        case .tanning: return "Melanotan II, GHK-Cu"
        case .antiAging: return "Epithalon, GHK-Cu"
        case .sexualHealth: return "PT-141, Kisspeptin"
        case .sarms: return "MK-677, RAD-140"
        case .igfVariants: return "IGF-1 LR3, IGF-1 DES"
        case .hormonal: return "HCG, Enclomiphene"
        case .ancillary: return "Arimidex, Aromasin"
        case .niche: return "DSIP, Thymosin Alpha-1"
        case .all: return ""
        }
    }

    private var reconstitutionContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            editorialPassage(
                eyebrow: "Overview",
                number: "01",
                title: "What is reconstitution?",
                body: "Most peptides come as a freeze-dried (lyophilized) powder in a vial. Reconstitution is the process of adding bacteriostatic water (BAC water) to dissolve the powder so it can be measured and injected."
            )
            editorialSteps(
                eyebrow: "The Method",
                number: "02",
                steps: [
                    GuideStep(number: 1, title: "Gather supplies", detail: "Peptide vial, BAC water, alcohol swabs, insulin syringe."),
                    GuideStep(number: 2, title: "Clean vial tops", detail: "Swab both the peptide vial and BAC water vial tops with alcohol."),
                    GuideStep(number: 3, title: "Draw BAC water", detail: "Draw your desired volume of BAC water into the syringe (typically 1–2 mL)."),
                    GuideStep(number: 4, title: "Add water slowly", detail: "Insert the needle into the peptide vial. Let water drip down the side — never spray onto the powder."),
                    GuideStep(number: 5, title: "Gently swirl", detail: "Roll the vial between your hands gently. Never shake — this can damage the peptide."),
                    GuideStep(number: 6, title: "Wait for clarity", detail: "The solution should become clear. If cloudy, continue gentle swirling. Discard if it remains cloudy.")
                ]
            )
            mathReference
        }
    }

    private var mathReference: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Concentration Math", number: "03", accent: PepTheme.teal)

            VStack(spacing: 0) {
                figureRow(label: "Example", value: "5 mg vial + 2 mL BAC")
                figureRow(label: "Concentration", value: "2,500 mcg / mL")
                figureRow(label: "For 250 mcg", value: "0.1 mL · 10 units", isLast: true)
            }

            footnote("Use the in-app reconstitution calculator for any vial size.")
        }
    }

    private func figureRow(label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                Spacer(minLength: 12)
                Text(value)
                    .font(.system(.subheadline, design: .monospaced, weight: .regular))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.vertical, 12)

            if !isLast {
                Rectangle()
                    .fill(PepTheme.separatorColor.opacity(0.6))
                    .frame(height: 0.5)
            }
        }
    }

    private var injectionContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            editorialPassage(
                eyebrow: "Method",
                number: "01",
                title: "Subcutaneous injection",
                body: "Most peptides are injected subcutaneously — under the skin, into fat tissue. It is the easiest and most common route for peptides. Use insulin syringes with short, thin needles."
            )
            editorialSteps(
                eyebrow: "The Procedure",
                number: "02",
                steps: [
                    GuideStep(number: 1, title: "Clean the site", detail: "Swab the injection site with an alcohol pad and let it dry."),
                    GuideStep(number: 2, title: "Pinch the skin", detail: "Pinch a fold of skin at the injection site."),
                    GuideStep(number: 3, title: "Insert at 45°", detail: "Insert the needle at a 45-degree angle into the pinched fold."),
                    GuideStep(number: 4, title: "Inject slowly", detail: "Push the plunger steadily — don't rush."),
                    GuideStep(number: 5, title: "Wait & remove", detail: "Wait 5 seconds after pushing the plunger, then remove the needle."),
                    GuideStep(number: 6, title: "Dispose safely", detail: "Place used needles in a sharps container. Never recap or reuse needles.")
                ]
            )
            siteRotation
        }
    }

    private var siteRotation: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Site Rotation", number: "03", accent: PepTheme.teal)
            Text("Rotate injection sites to prevent tissue damage and lipodystrophy.")
                .font(.system(.subheadline, design: .serif, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                let sites = ["Abdomen", "Thighs", "Deltoids", "Love handles"]
                ForEach(Array(sites.enumerated()), id: \.offset) { idx, site in
                    HStack(spacing: 12) {
                        Text(String(format: "%02d", idx + 1))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PepTheme.teal.opacity(0.85))
                            .frame(width: 22, alignment: .leading)
                        Text(site)
                            .font(.system(.subheadline, design: .serif, weight: .regular))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 11)
                    if idx < sites.count - 1 {
                        Rectangle()
                            .fill(PepTheme.separatorColor.opacity(0.6))
                            .frame(height: 0.5)
                    }
                }
            }

            footnote("EPTI tracks injection sites and suggests rotation automatically.")
        }
    }

    private var storageContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            storagePassage(
                eyebrow: "Lyophilized",
                number: "01",
                title: "Before reconstitution",
                body: "Powdered peptides should be stored in a cool, dark place. Refrigeration (36–46°F / 2–8°C) is ideal. Some can be stored at room temperature short-term, but refrigeration extends shelf life significantly.",
                meta: "36–46°F",
                metaLabel: "Refrigerated"
            )
            storagePassage(
                eyebrow: "Reconstituted",
                number: "02",
                title: "After reconstitution",
                body: "Once mixed with BAC water, peptides must be refrigerated. Most reconstituted peptides remain stable for 4–6 weeks when refrigerated properly. Never freeze reconstituted peptides.",
                meta: "4–6 wks",
                metaLabel: "Shelf life"
            )
            editorialPassage(
                eyebrow: "Solvent",
                number: "03",
                title: "Bacteriostatic water",
                body: "BAC water contains 0.9% benzyl alcohol, which prevents bacterial growth. This is why it's preferred over sterile water — it allows multiple safe draws from the same vial. Store BAC water at room temperature."
            )
            keyRules
        }
    }

    private func storagePassage(eyebrow: String, number: String, title: String, body: String, meta: String, metaLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow(eyebrow, number: number, accent: PepTheme.teal)

            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(.title3, design: .serif, weight: .regular))
                    .foregroundStyle(PepTheme.textPrimary)
                    .kerning(-0.3)
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(meta)
                        .font(.system(.subheadline, design: .monospaced, weight: .regular))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(metaLabel.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
                }
            }

            Text(body)
                .font(.system(.subheadline, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var keyRules: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Key Rules", number: "04", accent: PepTheme.teal)

            let rules = [
                "Always use BAC water, not sterile water.",
                "Keep vials upright in the fridge.",
                "Protect from light.",
                "Never share needles or vials.",
                "Track expiration dates.",
                "Discard if the solution becomes cloudy."
            ]

            VStack(spacing: 0) {
                ForEach(Array(rules.enumerated()), id: \.offset) { idx, rule in
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(format: "%02d", idx + 1))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.65))
                            .frame(width: 22, alignment: .leading)
                        Text(rule)
                            .font(.system(.subheadline, design: .serif, weight: .regular))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 11)

                    if idx < rules.count - 1 {
                        Rectangle()
                            .fill(PepTheme.separatorColor.opacity(0.6))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private var coaContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            editorialPassage(
                eyebrow: "Definition",
                number: "01",
                title: "What is a COA?",
                body: "A Certificate of Analysis is a document from an analytical lab verifying the identity, purity, and quality of a compound. Reputable vendors provide a COA for every batch they sell."
            )
            coaChecklist
            redFlags
            editorialPassage(
                eyebrow: "Trust Signals",
                number: "04",
                title: "Verified vendors on EPTI",
                body: "Vendors with the verification mark have submitted COAs and third-party lab results for review. The badge can't be purchased — it's earned through transparency."
            )
        }
    }

    private var coaChecklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("What to Look For", number: "02", accent: PepTheme.teal)

            let items: [(String, String)] = [
                ("98%+", "Purity (ideally 99%+)"),
                ("HPLC", "Identity confirmation"),
                ("LOW", "Endotoxin levels"),
                ("PASS", "Sterility testing"),
                ("MATCH", "Batch / lot number"),
                ("3RD PARTY", "Independent lab")
            ]

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(item.0)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PepTheme.teal)
                            .frame(width: 78, alignment: .leading)
                        Text(item.1)
                            .font(.system(.subheadline, design: .serif, weight: .regular))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 11)
                    if idx < items.count - 1 {
                        Rectangle()
                            .fill(PepTheme.separatorColor.opacity(0.6))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private var redFlags: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Red Flags", number: "03", accent: .red.opacity(0.85))

            let flags = [
                "No COA available.",
                "In-house testing only — no third-party lab.",
                "Purity below 97%.",
                "COA doesn't match the batch number.",
                "Generic or template COA.",
                "Vendor refuses to provide a COA."
            ]

            VStack(spacing: 0) {
                ForEach(Array(flags.enumerated()), id: \.offset) { idx, flag in
                    HStack(alignment: .top, spacing: 12) {
                        Text("✕")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(.red.opacity(0.75))
                            .frame(width: 22, alignment: .leading)
                        Text(flag)
                            .font(.system(.subheadline, design: .serif, weight: .regular))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 11)
                    if idx < flags.count - 1 {
                        Rectangle()
                            .fill(PepTheme.separatorColor.opacity(0.6))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    // MARK: - Building Blocks

    private func editorialPassage(eyebrow: String, number: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow(eyebrow, number: number, accent: PepTheme.teal)
            Text(title)
                .font(.system(.title3, design: .serif, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary)
                .kerning(-0.3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(body)
                .font(.system(.subheadline, weight: .regular))
                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func editorialSteps(eyebrow: String, number: String, steps: [GuideStep]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(eyebrow, number: number, accent: PepTheme.teal)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { idx, step in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            Text(String(format: "%02d", step.number))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PepTheme.teal)
                                .padding(.top, 1)
                            if idx < steps.count - 1 {
                                Rectangle()
                                    .fill(PepTheme.separatorColor.opacity(0.7))
                                    .frame(width: 0.5)
                                    .frame(maxHeight: .infinity)
                                    .padding(.top, 6)
                            }
                        }
                        .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.system(.subheadline, design: .serif, weight: .regular))
                                .foregroundStyle(PepTheme.textPrimary)
                                .kerning(-0.2)
                            Text(step.detail)
                                .font(.system(.footnote, weight: .regular))
                                .foregroundStyle(PepTheme.textSecondary)
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.bottom, idx < steps.count - 1 ? 16 : 0)
                    }
                }
            }
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .serif, weight: .regular))
            .italic()
            .foregroundStyle(PepTheme.textSecondary)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    private var disclaimerLine: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.5)
            HStack(alignment: .top, spacing: 10) {
                Text("§")
                    .font(.system(.subheadline, design: .serif, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                Text("This guide is for educational purposes only. Always consult a qualified healthcare professional before using any peptide or research compound.")
                    .font(.system(.caption, design: .serif, weight: .regular))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(.top, 8)
    }
}

nonisolated struct GuideStep: Identifiable, Sendable {
    let id = UUID()
    let number: Int
    let title: String
    let detail: String
}
