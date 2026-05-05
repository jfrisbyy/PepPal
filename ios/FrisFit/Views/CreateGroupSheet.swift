import SwiftUI

struct CreateGroupSheet: View {
    @Bindable var viewModel: GroupsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var privacy: GroupPrivacy = .publicGroup
    @State private var selectedIcon: String = "figure.strengthtraining.traditional"
    @State private var selectedColor: Color = PepTheme.teal

    private let iconOptions: [String] = [
        "figure.strengthtraining.traditional", "figure.run", "figure.pool.swim",
        "bicycle", "soccerball", "tennis.racket", "basketball.fill",
        "fork.knife", "heart.fill", "flame.fill", "bolt.fill",
        "trophy.fill", "sunrise.fill", "moon.fill", "leaf.fill",
        "checkmark.shield.fill", "star.fill", "flag.fill"
    ]

    private let colorOptions: [Color] = [
        PepTheme.teal, PepTheme.blue, PepTheme.violet, PepTheme.amber,
        .red, .pink, .orange, .green, .mint, .indigo
    ]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    editorialHeader
                    heroPreview

                    VStack(alignment: .leading, spacing: 28) {
                        identitySection
                        privacySection
                        iconSection
                        colorSection
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.createGroup(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            privacy: privacy,
                            iconName: selectedIcon,
                            accentColor: selectedColor
                        )
                        dismiss()
                    } label: {
                        Text("Create")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(isValid ? PepTheme.invertedText : PepTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isValid ? selectedColor : PepTheme.elevated)
                            .clipShape(Capsule())
                    }
                    .disabled(!isValid)
                    .sensoryFeedback(.success, trigger: !isValid)
                }
            }
        }
    }

    // MARK: - Editorial header

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HeadlineText(text: "New Group · Issue 01")
                .foregroundStyle(selectedColor)
            Text("Build your\ncollective.")
                .font(.pepDisplay(size: 38, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .kerning(-0.6)
                .lineSpacing(-2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Rectangle()
                    .fill(selectedColor)
                    .frame(width: 28, height: 1.5)
                Text("Define the identity, set the tone, invite the crew.")
                    .font(.pepUI(size: 13, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary)
                    .italic()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero preview

    private var heroPreview: some View {
        VStack(spacing: 18) {
            HStack {
                HeadlineText(text: "Cover")
                Spacer()
                MetaText(text: "Live preview")
            }

            ZStack {
                // Layered editorial card with subtle gradient + grain
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                selectedColor.opacity(0.22),
                                selectedColor.opacity(0.06),
                                PepTheme.cardSurface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(selectedColor.opacity(0.18), lineWidth: 0.5)
                    )

                // Decorative serif numeral in the corner
                Text("№01")
                    .font(.pepDisplay(size: 14, weight: .regular))
                    .italic()
                    .foregroundStyle(selectedColor.opacity(0.55))
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(selectedColor.opacity(0.18))
                            .frame(width: 84, height: 84)
                        Circle()
                            .strokeBorder(selectedColor.opacity(0.4), lineWidth: 1)
                            .frame(width: 84, height: 84)

                        Image(systemName: selectedIcon)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(selectedColor)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .shadow(color: selectedColor.opacity(0.25), radius: 18, y: 8)

                    VStack(spacing: 4) {
                        Text(name.isEmpty ? "Group Name" : name)
                            .font(.pepDisplay(size: 22, weight: .semibold))
                            .kerning(-0.3)
                            .foregroundStyle(name.isEmpty ? PepTheme.textTertiary : PepTheme.textPrimary)
                            .lineLimit(1)
                            .contentTransition(.opacity)

                        Text(description.isEmpty ? "A short editorial line about your group goes here." : description)
                            .font(.pepUI(size: 12, weight: .regular))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 28)
                    }

                    HStack(spacing: 8) {
                        Label(privacy.rawValue, systemImage: privacy.icon)
                        Text("·")
                        Label("1 founding member", systemImage: "person.2.fill")
                    }
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 20)
            }
            .frame(height: 260)
            .padding(.horizontal, 20)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedColor)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedIcon)
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(number: "01", title: "Identity")

            editorialField(label: "Name") {
                TextField("e.g. Morning Lifters", text: $name)
                    .font(.pepDisplay(size: 18, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .tint(selectedColor)
            }

            editorialField(label: "Manifesto") {
                TextField("What's this group about?", text: $description, axis: .vertical)
                    .font(.pepUI(size: 14, weight: .regular))
                    .lineLimit(2...5)
                    .foregroundStyle(PepTheme.textPrimary)
                    .tint(selectedColor)
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(number: "02", title: "Access")

            VStack(spacing: 0) {
                ForEach(Array(GroupPrivacy.allCases.enumerated()), id: \.element.rawValue) { index, option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            privacy = option
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(privacy == option ? selectedColor.opacity(0.18) : PepTheme.elevated)
                                    .frame(width: 38, height: 38)
                                Image(systemName: option.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(privacy == option ? selectedColor : PepTheme.textSecondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.rawValue)
                                    .font(.pepUI(size: 15, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(option == .publicGroup
                                     ? "Anyone can find and join."
                                     : "Invite only · approval required.")
                                    .font(.pepUI(size: 12, weight: .regular))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .italic()
                            }

                            Spacer()

                            ZStack {
                                Circle()
                                    .strokeBorder(privacy == option ? selectedColor : PepTheme.textTertiary.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                                if privacy == option {
                                    Circle()
                                        .fill(selectedColor)
                                        .frame(width: 10, height: 10)
                                }
                            }
                        }
                        .padding(.vertical, 14)
                    }
                    .sensoryFeedback(.selection, trigger: privacy)

                    if index < GroupPrivacy.allCases.count - 1 {
                        Divider()
                            .overlay(PepTheme.textTertiary.opacity(0.15))
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(PepTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(PepTheme.textTertiary.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }

    // MARK: - Icon

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(number: "03", title: "Sigil")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(iconOptions, id: \.self) { icon in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedIcon = icon
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedIcon == icon ? selectedColor.opacity(0.18) : PepTheme.cardSurface)
                                .frame(height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            selectedIcon == icon ? selectedColor : PepTheme.textTertiary.opacity(0.1),
                                            lineWidth: selectedIcon == icon ? 1.5 : 0.5
                                        )
                                )

                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(selectedIcon == icon ? selectedColor : PepTheme.textSecondary)
                                .scaleEffect(selectedIcon == icon ? 1.08 : 1.0)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: selectedIcon)
                }
            }
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(number: "04", title: "Palette")

            HStack(spacing: 0) {
                ForEach(colorOptions, id: \.self) { color in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedColor = color
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)

                            if selectedColor == color {
                                Circle()
                                    .strokeBorder(color.opacity(0.35), lineWidth: 1.5)
                                    .frame(width: 44, height: 44)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .sensoryFeedback(.selection, trigger: selectedColor)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(PepTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(PepTheme.textTertiary.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }

    // MARK: - Helpers

    private func sectionHeader(number: String, title: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.pepDisplay(size: 13, weight: .regular))
                .italic()
                .foregroundStyle(selectedColor)
            Rectangle()
                .fill(PepTheme.textTertiary.opacity(0.25))
                .frame(width: 18, height: 0.5)
            HeadlineText(text: title)
            Spacer()
        }
    }

    private func editorialField<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(PepTheme.textTertiary)

            content()

            Rectangle()
                .fill(PepTheme.textTertiary.opacity(0.2))
                .frame(height: 0.5)
        }
    }
}
