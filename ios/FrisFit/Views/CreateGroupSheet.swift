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
                VStack(spacing: 24) {
                    groupPreview

                    VStack(alignment: .leading, spacing: 16) {
                        fieldSection(title: "Group Name") {
                            TextField("e.g. Morning Lifters", text: $name)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 12))
                        }

                        fieldSection(title: "Description") {
                            TextField("What's this group about?", text: $description, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(3...6)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 12))
                        }

                        fieldSection(title: "Privacy") {
                            HStack(spacing: 10) {
                                ForEach(GroupPrivacy.allCases, id: \.rawValue) { option in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            privacy = option
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: option.icon)
                                                .font(.system(size: 13))
                                            Text(option.rawValue)
                                                .font(.system(.subheadline, weight: .medium))
                                        }
                                        .foregroundStyle(privacy == option ? PepTheme.invertedText : PepTheme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(privacy == option ? PepTheme.teal : PepTheme.elevated)
                                        .clipShape(.rect(cornerRadius: 12))
                                    }
                                    .sensoryFeedback(.selection, trigger: privacy)
                                }
                            }

                            Text(privacy == .publicGroup
                                 ? "Anyone can find and join this group."
                                 : "Only invited members can join. Requires approval.")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }

                        fieldSection(title: "Icon") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                                ForEach(iconOptions, id: \.self) { icon in
                                    Button {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedIcon = icon
                                        }
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedIcon == icon ? selectedColor.opacity(0.2) : PepTheme.elevated)
                                                .frame(height: 48)

                                            Image(systemName: icon)
                                                .font(.system(size: 20))
                                                .foregroundStyle(selectedIcon == icon ? selectedColor : PepTheme.textSecondary)
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(selectedIcon == icon ? selectedColor : .clear, lineWidth: 2)
                                        )
                                    }
                                }
                            }
                        }

                        fieldSection(title: "Color") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                                ForEach(colorOptions, id: \.self) { color in
                                    Button {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedColor = color
                                        }
                                    } label: {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 32, height: 32)
                                            .overlay {
                                                if selectedColor == color {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                            .scaleEffect(selectedColor == color ? 1.15 : 1.0)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        viewModel.createGroup(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            privacy: privacy,
                            iconName: selectedIcon,
                            accentColor: selectedColor
                        )
                        dismiss()
                    }
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(isValid ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))
                    .disabled(!isValid)
                }
            }
        }
    }

    private var groupPreview: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(selectedColor.opacity(0.12))
                    .frame(width: 60, height: 60)

                Image(systemName: selectedIcon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(selectedColor)
            }

            Text(name.isEmpty ? "Group Name" : name)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(name.isEmpty ? PepTheme.textSecondary.opacity(0.4) : PepTheme.textPrimary)

            HStack(spacing: 8) {
                Label(privacy.rawValue, systemImage: privacy.icon)
                Label("1 member", systemImage: "person.2.fill")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(PepTheme.cardSurface)
    }

    private func fieldSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            content()
        }
    }
}
