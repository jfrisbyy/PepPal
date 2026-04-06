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
            case .whatArePeptides: return "questionmark.circle.fill"
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
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    sectionPicker

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
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Beginner's Guide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
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
        }
        .contentMargins(.horizontal, 0)
    }

    private var whatArePeptidesContent: some View {
        VStack(spacing: 12) {
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
            guideCard(
                title: "Categories",
                content: "• Growth Hormone Peptides (CJC-1295, Ipamorelin)\n• Healing Peptides (BPC-157, TB-500)\n• Weight Loss (Semaglutide, Tirzepatide)\n• Cognitive (Semax, Selank)\n• Cosmetic (Melanotan II, GHK-Cu)\n• Anti-Aging (Epithalon)",
                icon: "list.bullet"
            )
            disclaimerCard
        }
    }

    private var reconstitutionContent: some View {
        VStack(spacing: 12) {
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
            guideCard(
                title: "Concentration Math",
                content: "If you have a 5mg vial and add 2mL of water:\n5mg ÷ 2mL = 2.5mg/mL (or 2,500mcg/mL)\n\nFor a 250mcg dose:\n250mcg ÷ 2,500mcg/mL = 0.1mL = 10 units on a 100-unit insulin syringe\n\nUse the Reconstitution Calculator in PepPal for easy math!",
                icon: "function"
            )
            disclaimerCard
        }
    }

    private var injectionContent: some View {
        VStack(spacing: 12) {
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
            guideCard(
                title: "Site Rotation",
                content: "Rotate injection sites to prevent tissue damage and lipodystrophy. Common sites: abdomen (2 inches from navel), thighs, deltoids, love handles.\n\nPepPal tracks your injection sites and suggests the next rotation automatically.",
                icon: "arrow.triangle.2.circlepath"
            )
            disclaimerCard
        }
    }

    private var storageContent: some View {
        VStack(spacing: 12) {
            guideCard(
                title: "Before Reconstitution",
                content: "Lyophilized (powder) peptides should be stored in a cool, dark place. Refrigeration (36-46°F / 2-8°C) is ideal. Some can be stored at room temperature short-term, but refrigeration extends shelf life significantly.",
                icon: "snowflake"
            )
            guideCard(
                title: "After Reconstitution",
                content: "Once mixed with BAC water, peptides MUST be refrigerated. Most reconstituted peptides remain stable for 4-6 weeks when refrigerated properly. Never freeze reconstituted peptides.",
                icon: "thermometer.snowflake"
            )
            guideCard(
                title: "BAC Water",
                content: "Bacteriostatic water contains 0.9% benzyl alcohol, which prevents bacterial growth. This is why it's preferred over sterile water — it allows multiple draws from the same vial safely. Store BAC water at room temperature.",
                icon: "drop.circle.fill"
            )
            guideCard(
                title: "Key Rules",
                content: "• Always use BAC water, not sterile water (unless single-use)\n• Keep vials upright in the fridge\n• Protect from light\n• Never share needles or vials\n• Track expiration dates\n• Discard if solution becomes cloudy",
                icon: "checklist"
            )
            disclaimerCard
        }
    }

    private var coaContent: some View {
        VStack(spacing: 12) {
            guideCard(
                title: "What Is a COA?",
                content: "A Certificate of Analysis (COA) is a document from an analytical lab that verifies the identity, purity, and quality of a compound. Reputable vendors provide COAs for every batch they sell.",
                icon: "doc.text.magnifyingglass"
            )
            guideCard(
                title: "What to Look For",
                content: "• Purity: Should be 98%+ (ideally 99%+)\n• Identity: HPLC or Mass Spec confirming the correct peptide\n• Endotoxin levels: Should be below acceptable limits\n• Sterility testing: Important for injectable compounds\n• Batch/lot number: Should match your vial\n• Lab name: Should be a third-party lab, not in-house",
                icon: "magnifyingglass"
            )
            guideCard(
                title: "Red Flags",
                content: "• No COA available\n• In-house testing only (no third-party lab)\n• Purity below 97%\n• COA doesn't match the batch number on your vial\n• Generic/template COA without specific test results\n• Vendor refuses to provide COA when asked",
                icon: "exclamationmark.triangle.fill"
            )
            guideCard(
                title: "Verified Vendors on PepPal",
                content: "Vendors with the verification badge on PepPal have submitted COAs and third-party lab results for review. This badge cannot be purchased — it's earned through transparency. Check the Discover tab for verified sources.",
                icon: "checkmark.shield.fill"
            )
            disclaimerCard
        }
    }

    private func guideCard(title: String, content: String, icon: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "list.number")
                        .font(.subheadline)
                        .foregroundStyle(selectedSection.color)
                    Text("Step by Step")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.number)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.invertedText)
                                .frame(width: 24, height: 24)
                                .background(selectedSection.color)
                                .clipShape(.circle)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(step.detail)
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .lineSpacing(2)
                            }
                        }
                    }
                }
            }
        }
    }

    private var disclaimerCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title3)
                .foregroundStyle(PepTheme.amber)

            Text("This guide is for educational purposes only. Always consult with a qualified healthcare professional before using any peptide or research compound.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
        }
        .padding(12)
        .background(PepTheme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }
}

nonisolated struct GuideStep: Identifiable, Sendable {
    let id = UUID()
    let number: Int
    let title: String
    let detail: String
}
