import SwiftUI

struct StatSharingOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabled: Bool = false
    @State private var audience: ShareAudience = .friends

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero

                    VStack(alignment: .leading, spacing: 0) {
                        SectionEyebrow("What gets shared", number: "01", accent: PepTheme.teal)
                            .padding(.bottom, 14)
                        bulletRow(index: "01", title: "Workouts", text: "Friends can see your weekly training activity and sessions.")
                        Divider().overlay(PepTheme.separatorColor)
                        bulletRow(index: "02", title: "Personal records", text: "Share your biggest lifts and recent PRs with the people cheering you on.")
                        Divider().overlay(PepTheme.separatorColor)
                        bulletRow(index: "03", title: "Programs & protocols", text: "Let friends follow along with the programs and protocols you're running.")
                        Divider().overlay(PepTheme.separatorColor)
                        bulletRow(index: "04", title: "You stay in control", text: "Every stat has its own toggle. Turn anything off whenever you want.")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionEyebrow("Audience", number: "02", accent: PepTheme.teal)
                        audiencePicker
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionEyebrow("Sharing", number: "03", accent: PepTheme.teal)
                        Toggle(isOn: $isEnabled) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Enable stat sharing")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text("You can change this anytime in settings.")
                                    .font(.caption2)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                        .tint(PepTheme.teal)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(PepTheme.separatorColor, lineWidth: 0.6)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                    dismiss()
                } label: {
                    Text(isEnabled ? "Start sharing" : "Not now")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(isEnabled ? PepTheme.invertedText : PepTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            Capsule().fill(isEnabled ? PepTheme.textPrimary : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(isEnabled ? Color.clear : PepTheme.separatorColor, lineWidth: 0.8)
                        )
                }
                .buttonStyle(.scale)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .padding(.top, 12)
                .background(
                    LinearGradient(
                        colors: [PepTheme.background.opacity(0), PepTheme.background.opacity(0.95), PepTheme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SHARE YOUR STATS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { save(skipping: true); dismiss() }
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .task {
                if let id = try? AuthService.shared.currentUserId() {
                    let prefs = StatSharingService.shared.prefs(for: id)
                    isEnabled = prefs.isEnabled
                    audience = prefs.audience
                }
            }
        }
        .presentationDetents([.large])
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A QUIET BROADCAST")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(PepTheme.teal.opacity(0.9))

            Text("See your friends' stats —\nand share your own.")
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.6)
                .padding(.top, 4)

            Text("Stat sharing is off by default. Turn it on to unlock the Friends tab. Every category has its own toggle, and you can change your mind any time.")
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private func bulletRow(index: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(index)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PepTheme.textTertiary)
                .frame(width: 22, alignment: .leading)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }

    private var audiencePicker: some View {
        VStack(spacing: 0) {
            ForEach(Array(ShareAudience.allCases.enumerated()), id: \.element.id) { idx, option in
                Button {
                    audience = option
                } label: {
                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(audience == option ? PepTheme.textPrimary : PepTheme.separatorColor, lineWidth: 1)
                                .frame(width: 18, height: 18)
                            if audience == option {
                                Circle()
                                    .fill(PepTheme.textPrimary)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(option.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx < ShareAudience.allCases.count - 1 {
                    Divider().overlay(PepTheme.separatorColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(PepTheme.separatorColor, lineWidth: 0.6)
        )
    }

    private func save(skipping: Bool = false) {
        guard let id = try? AuthService.shared.currentUserId() else { return }
        var prefs = StatSharingService.shared.prefs(for: id)
        if !skipping {
            prefs.isEnabled = isEnabled
            prefs.audience = audience
            StatSharingService.shared.save(prefs, for: id)
        }
        StatSharingService.shared.markOnboardingSeen(for: id)
    }
}

struct StatSharingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prefs: StatSharingPrefs = .default

    private var sharedCount: Int { prefs.categories.count }
    private var totalCount: Int { StatShareCategory.allCases.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                hero

                masterToggleSection

                audienceSection
                    .opacity(prefs.isEnabled ? 1 : 0.45)
                    .allowsHitTesting(prefs.isEnabled)

                categoriesSection
                    .opacity(prefs.isEnabled ? 1 : 0.45)
                    .allowsHitTesting(prefs.isEnabled)

                quickActions
                    .opacity(prefs.isEnabled ? 1 : 0.45)
                    .allowsHitTesting(prefs.isEnabled)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SHARING SETTINGS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: prefs.isEnabled)
        .onChange(of: prefs.isEnabled) { _, _ in save() }
        .onChange(of: prefs.audience) { _, _ in save() }
        .onChange(of: prefs.categories) { _, _ in save() }
        .task {
            if let id = try? AuthService.shared.currentUserId() {
                prefs = StatSharingService.shared.prefs(for: id)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prefs.isEnabled ? "BROADCASTING" : "PRIVATE BY DEFAULT")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(prefs.isEnabled ? PepTheme.teal.opacity(0.9) : PepTheme.textTertiary)

            Text(prefs.isEnabled ? "Your stats are visible —\non your terms." : "Choose what to share —\nand who gets to see it.")
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(PepTheme.separatorColor)
                .frame(height: 0.6)
                .padding(.top, 4)

            HStack(spacing: 18) {
                heroStat(value: prefs.isEnabled ? "On" : "Off", label: "Sharing")
                Rectangle().fill(PepTheme.separatorColor).frame(width: 0.6, height: 28)
                heroStat(value: prefs.audience == .friends ? "Friends" : "Followers", label: "Audience")
                Rectangle().fill(PepTheme.separatorColor).frame(width: 0.6, height: 28)
                heroStat(value: "\(sharedCount)/\(totalCount)", label: "Stats on")
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textTertiary)
        }
    }

    // MARK: - Master toggle

    private var masterToggleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Sharing", number: "01", accent: PepTheme.teal)

            Toggle(isOn: $prefs.isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share stats with friends")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(prefs.isEnabled
                         ? "Visible to your \(prefs.audience.title.lowercased())."
                         : "Nothing is shared until this is on.")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineSpacing(2)
                }
            }
            .tint(PepTheme.teal)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(PepTheme.separatorColor, lineWidth: 0.6)
            )
        }
    }

    // MARK: - Audience

    private var audienceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Audience", number: "02", accent: PepTheme.teal)

            VStack(spacing: 0) {
                ForEach(Array(ShareAudience.allCases.enumerated()), id: \.element.id) { idx, option in
                    Button {
                        prefs.audience = option
                    } label: {
                        HStack(alignment: .center, spacing: 14) {
                            ZStack {
                                Circle()
                                    .stroke(prefs.audience == option ? PepTheme.textPrimary : PepTheme.separatorColor, lineWidth: 1)
                                    .frame(width: 18, height: 18)
                                if prefs.audience == option {
                                    Circle()
                                        .fill(PepTheme.textPrimary)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(option.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < ShareAudience.allCases.count - 1 {
                        Divider().overlay(PepTheme.separatorColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(PepTheme.separatorColor, lineWidth: 0.6)
            )
        }
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionEyebrow("What to share", number: "03", accent: PepTheme.teal)

            ForEach(Array(StatShareGroup.allCases.enumerated()), id: \.element) { groupIdx, group in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(group.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(PepTheme.textTertiary)
                        Spacer(minLength: 0)
                        Text("\(group.categories.filter { prefs.categories.contains($0) }.count) / \(group.categories.count)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(PepTheme.textTertiary)
                    }
                    .padding(.bottom, 6)

                    ForEach(Array(group.categories.enumerated()), id: \.element) { idx, cat in
                        categoryRow(cat)
                        if idx < group.categories.count - 1 {
                            Divider().overlay(PepTheme.separatorColor)
                        }
                    }
                }
                if groupIdx < StatShareGroup.allCases.count - 1 {
                    Rectangle()
                        .fill(PepTheme.separatorColor.opacity(0.6))
                        .frame(height: 0.6)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func categoryRow(_ cat: StatShareCategory) -> some View {
        let isOn = prefs.categories.contains(cat)
        return Button {
            if isOn { prefs.categories.remove(cat) } else { prefs.categories.insert(cat) }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: cat.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? cat.color : PepTheme.textTertiary)
                    .frame(width: 22, alignment: .center)

                Text(cat.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)

                Spacer(minLength: 0)

                ZStack {
                    Capsule()
                        .fill(isOn ? PepTheme.teal : Color.clear)
                        .overlay(
                            Capsule().stroke(isOn ? Color.clear : PepTheme.separatorColor, lineWidth: 0.8)
                        )
                        .frame(width: 36, height: 20)
                    Circle()
                        .fill(isOn ? PepTheme.invertedText : PepTheme.textPrimary.opacity(0.55))
                        .frame(width: 14, height: 14)
                        .offset(x: isOn ? 8 : -8)
                        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isOn)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Quick set", number: "04", accent: PepTheme.teal)

            HStack(spacing: 10) {
                quickActionButton(title: "Share everything", isPrimary: true) {
                    prefs.categories = Set(StatShareCategory.allCases)
                }
                quickActionButton(title: "Share nothing", isPrimary: false) {
                    prefs.categories = []
                }
            }
        }
    }

    private func quickActionButton(title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(isPrimary ? PepTheme.invertedText : PepTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(isPrimary ? PepTheme.textPrimary : Color.clear)
                )
                .overlay(
                    Capsule().stroke(isPrimary ? Color.clear : PepTheme.separatorColor, lineWidth: 0.8)
                )
        }
        .buttonStyle(.scale)
    }

    private func save() {
        guard let id = try? AuthService.shared.currentUserId() else { return }
        StatSharingService.shared.save(prefs, for: id)
    }
}
