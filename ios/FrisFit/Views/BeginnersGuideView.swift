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

        var icon: String {
            switch self {
            case .whatArePeptides: return "atom"
            case .reconstitution: return "drop.fill"
            case .injection: return "syringe.fill"
            case .storage: return "snowflake"
            case .coas: return "doc.text.magnifyingglass"
            }
        }

        var color: Color {
            switch self {
            case .whatArePeptides: return PepTheme.teal
            case .reconstitution: return PepTheme.blue
            case .injection: return .orange
            case .storage: return PepTheme.violet
            case .coas: return .green
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
                VStack(spacing: 20) {
                    heroHeader

                    sectionPicker

                    contentForSection
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Beginner's Guide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    selectedSection.color.opacity(0.5), PepTheme.blue.opacity(0.3), PepTheme.violet.opacity(0.3),
                    selectedSection.color.opacity(0.3), selectedSection.color.opacity(0.4), PepTheme.teal.opacity(0.2),
                    PepTheme.background, PepTheme.background, PepTheme.background
                ]
            )
            .frame(height: 120)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    Image(systemName: selectedSection.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(selectedSection.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedSection.rawValue)
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(selectedSection.subtitle)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .animation(.smooth(duration: 0.4), value: selectedSection)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GuideSection.allCases) { section in
                    let isSelected = selectedSection == section
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: section.icon)
                                .font(.system(size: 11))
                            Text(section.rawValue)
                                .font(.system(.caption, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? AnyShapeStyle(section.color) : AnyShapeStyle(PepTheme.cardSurface))
                        .clipShape(.capsule)
                        .overlay(
                            Capsule().strokeBorder(isSelected ? Color.clear : PepTheme.separatorColor, lineWidth: 1)
                        )
                    }
                    .sensoryFeedback(.selection, trigger: selectedSection)
                }
            }
            .padding(.horizontal, 16)
        }
        .contentMargins(.horizontal, 0)
    }

    @ViewBuilder
    private var contentForSection: some View {
        VStack(spacing: 14) {
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
        }
        .padding(.horizontal)
        .id(selectedSection)
    }

    // MARK: - Sections

    private var whatArePeptidesContent: some View {
        Group {
            guideCard(
                title: "What Are Peptides?",
                content: "Peptides are short chains of amino acids — the building blocks of proteins. They occur naturally in your body and play roles in signaling, healing, and regulation. Research peptides are synthetic versions studied for various biological effects.",
                icon: "atom"
            )
            guideCard(
                title: "How Do They Work?",
                content: "Peptides bind to specific receptors in your body, triggering biological responses. Different peptides target different systems — some promote tissue repair, others influence growth hormone release, metabolism, or cognitive function.",
                icon: "gearshape.2.fill"
            )
            categoryOverviewCard
            disclaimerCard
        }
    }

    private var categoryOverviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(selectedSection.color)
                    Text("Categories")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                VStack(spacing: 8) {
                    ForEach(PeptideCategory.allCases.filter { $0 != .all }) { cat in
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(cat.color.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(cat.color)
                            }
                            Text(cat.rawValue)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Text(categoryExamples(for: cat))
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                                .lineLimit(1)
                        }
                        if cat != PeptideCategory.allCases.filter({ $0 != .all }).last {
                            Rectangle()
                                .fill(PepTheme.separatorColor)
                                .frame(height: 0.5)
                        }
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
        case .all: return ""
        }
    }

    private var reconstitutionContent: some View {
        Group {
            guideCard(
                title: "What Is Reconstitution?",
                content: "Most peptides come as a freeze-dried (lyophilized) powder in a vial. Reconstitution is the process of adding bacteriostatic water (BAC water) to dissolve the powder so it can be measured and injected.",
                icon: "drop.fill"
            )
            guideStepCard(steps: [
                GuideStep(number: 1, title: "Gather Supplies", detail: "Peptide vial, BAC water, alcohol swabs, insulin syringe"),
                GuideStep(number: 2, title: "Clean Vial Tops", detail: "Swab both the peptide vial and BAC water vial tops with alcohol"),
                GuideStep(number: 3, title: "Draw BAC Water", detail: "Draw your desired volume of BAC water into the syringe (typically 1-2 mL)"),
                GuideStep(number: 4, title: "Add Water Slowly", detail: "Insert needle into peptide vial. Let water drip down the side — never spray directly onto the powder"),
                GuideStep(number: 5, title: "Gently Swirl", detail: "Roll the vial between your hands gently. Never shake — this can damage the peptide"),
                GuideStep(number: 6, title: "Wait for Clarity", detail: "The solution should become clear. If cloudy, continue gentle swirling. Discard if it remains cloudy"),
            ])
            mathCard
            disclaimerCard
        }
    }

    private var mathCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "function")
                        .font(.system(size: 13))
                        .foregroundStyle(selectedSection.color)
                    Text("Concentration Math")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    mathRow(label: "Example", value: "5mg vial + 2mL BAC water")
                    mathRow(label: "Concentration", value: "2,500 mcg/mL")
                    mathRow(label: "For 250mcg dose", value: "0.1 mL = 10 units")
                }
                .padding(12)
                .background(selectedSection.color.opacity(0.06))
                .clipShape(.rect(cornerRadius: 10))

                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(selectedSection.color)
                    Text("Use the Reconstitution Calculator in your protocol for easy math!")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private func mathRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private var injectionContent: some View {
        Group {
            guideCard(
                title: "Subcutaneous Injection",
                content: "Most peptides are injected subcutaneously (under the skin, into fat tissue). This is the most common and easiest injection method for peptides. Use insulin syringes with short, thin needles.",
                icon: "syringe.fill"
            )
            guideStepCard(steps: [
                GuideStep(number: 1, title: "Clean the Site", detail: "Swab the injection site with an alcohol pad and let it dry"),
                GuideStep(number: 2, title: "Pinch the Skin", detail: "Pinch a fold of skin at the injection site"),
                GuideStep(number: 3, title: "Insert at 45°", detail: "Insert the needle at a 45-degree angle into the pinched skin fold"),
                GuideStep(number: 4, title: "Inject Slowly", detail: "Push the plunger slowly and steadily"),
                GuideStep(number: 5, title: "Wait & Remove", detail: "Wait 5 seconds after pushing the plunger, then remove the needle"),
                GuideStep(number: 6, title: "Dispose Safely", detail: "Place used needles in a sharps container. Never recap or reuse needles"),
            ])
            siteRotationCard
            disclaimerCard
        }
    }

    private var siteRotationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13))
                        .foregroundStyle(selectedSection.color)
                    Text("Site Rotation")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                Text("Rotate injection sites to prevent tissue damage and lipodystrophy.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(3)

                HStack(spacing: 8) {
                    ForEach(["Abdomen", "Thighs", "Deltoids", "Love Handles"], id: \.self) { site in
                        Text(site)
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(selectedSection.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selectedSection.color.opacity(0.1))
                            .clipShape(.capsule)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.teal)
                    Text("PepPal tracks injection sites and suggests rotation automatically.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var storageContent: some View {
        Group {
            storageConditionCard(
                title: "Before Reconstitution",
                content: "Lyophilized (powder) peptides should be stored in a cool, dark place. Refrigeration (36-46°F / 2-8°C) is ideal. Some can be stored at room temperature short-term, but refrigeration extends shelf life significantly.",
                icon: "snowflake",
                temp: "36-46°F",
                tempLabel: "Refrigerated"
            )
            storageConditionCard(
                title: "After Reconstitution",
                content: "Once mixed with BAC water, peptides MUST be refrigerated. Most reconstituted peptides remain stable for 4-6 weeks when refrigerated properly. Never freeze reconstituted peptides.",
                icon: "thermometer.snowflake",
                temp: "4-6 wks",
                tempLabel: "Shelf Life"
            )
            guideCard(
                title: "BAC Water",
                content: "Bacteriostatic water contains 0.9% benzyl alcohol, which prevents bacterial growth. This is why it's preferred over sterile water — it allows multiple draws from the same vial safely. Store BAC water at room temperature.",
                icon: "drop.circle.fill"
            )
            keyRulesCard
            disclaimerCard
        }
    }

    private func storageConditionCard(title: String, content: String, icon: String, temp: String, tempLabel: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: icon)
                            .font(.system(size: 13))
                            .foregroundStyle(selectedSection.color)
                        Text(title)
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    VStack(spacing: 1) {
                        Text(temp)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(selectedSection.color)
                        Text(tempLabel)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedSection.color.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 8))
                }

                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(4)
            }
        }
    }

    private var keyRulesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "checklist")
                        .font(.system(size: 13))
                        .foregroundStyle(selectedSection.color)
                    Text("Key Rules")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array([
                        "Always use BAC water, not sterile water",
                        "Keep vials upright in the fridge",
                        "Protect from light",
                        "Never share needles or vials",
                        "Track expiration dates",
                        "Discard if solution becomes cloudy"
                    ].enumerated()), id: \.offset) { _, rule in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(selectedSection.color)
                            Text(rule)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                        }
                    }
                }
            }
        }
    }

    private var coaContent: some View {
        Group {
            guideCard(
                title: "What Is a COA?",
                content: "A Certificate of Analysis (COA) is a document from an analytical lab that verifies the identity, purity, and quality of a compound. Reputable vendors provide COAs for every batch they sell.",
                icon: "doc.text.magnifyingglass"
            )
            coaChecklistCard
            redFlagsCard
            guideCard(
                title: "Verified Vendors on PepPal",
                content: "Vendors with the verification badge on PepPal have submitted COAs and third-party lab results for review. This badge cannot be purchased — it's earned through transparency. Check the Discover tab for verified sources.",
                icon: "checkmark.shield.fill"
            )
            disclaimerCard
        }
    }

    private var coaChecklistCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(selectedSection.color)
                    Text("What to Look For")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                VStack(spacing: 6) {
                    ForEach(Array([
                        ("98%+", "Purity (ideally 99%+)"),
                        ("HPLC", "Identity confirmation"),
                        ("Low", "Endotoxin levels"),
                        ("Pass", "Sterility testing"),
                        ("Match", "Batch/lot number"),
                        ("3rd Party", "Independent lab")
                    ].enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 10) {
                            Text(item.0)
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(selectedSection.color)
                                .frame(width: 54, alignment: .trailing)
                            Rectangle()
                                .fill(PepTheme.separatorColor)
                                .frame(width: 1, height: 16)
                            Text(item.1)
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var redFlagsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                    Text("Red Flags")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array([
                        "No COA available",
                        "In-house testing only (no third-party lab)",
                        "Purity below 97%",
                        "COA doesn't match batch number",
                        "Generic/template COA",
                        "Vendor refuses to provide COA"
                    ].enumerated()), id: \.offset) { _, flag in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.7))
                            Text(flag)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shared Components

    private func guideCard(title: String, content: String, icon: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(selectedSection.color)
                    Text(title)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(4)
            }
        }
    }

    private func guideStepCard(steps: [GuideStep]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: "list.number")
                        .font(.system(size: 13))
                        .foregroundStyle(selectedSection.color)
                    Text("Step by Step")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [selectedSection.color, selectedSection.color.opacity(0.7)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 28, height: 28)
                                    Text("\(step.number)")
                                        .font(.system(.caption2, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                if step.number < steps.count {
                                    Rectangle()
                                        .fill(selectedSection.color.opacity(0.2))
                                        .frame(width: 2, height: 20)
                                }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(step.detail)
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .lineSpacing(2)
                            }
                            .padding(.bottom, step.number < steps.count ? 8 : 0)
                        }
                    }
                }
            }
        }
    }

    private var disclaimerCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(PepTheme.amber)

            Text("This guide is for educational purposes only. Always consult with a qualified healthcare professional before using any peptide or research compound.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
        }
        .padding(12)
        .background(PepTheme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.amber.opacity(0.15), lineWidth: 0.5)
        )
    }
}

nonisolated struct GuideStep: Identifiable, Sendable {
    let id = UUID()
    let number: Int
    let title: String
    let detail: String
}
