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

    var body: some View {
        List {
            Section {
                Toggle(isOn: $prefs.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share stats with friends")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(prefs.isEnabled ? "Your selected stats are visible to your \(prefs.audience.title.lowercased())." : "Turn on to let people see your stats.")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .tint(PepTheme.teal)
            } footer: {
                Text("You can change what gets shared at any time. Nothing is shared until this is on.")
                    .font(.caption2)
            }

            Section("Who can see your stats") {
                Picker("Audience", selection: $prefs.audience) {
                    ForEach(ShareAudience.allCases) { a in
                        Text(a.title).tag(a)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .disabled(!prefs.isEnabled)
            }

            ForEach(StatShareGroup.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(group.categories) { cat in
                        Toggle(isOn: Binding(
                            get: { prefs.categories.contains(cat) },
                            set: { newValue in
                                if newValue { prefs.categories.insert(cat) } else { prefs.categories.remove(cat) }
                            }
                        )) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle().fill(cat.color.opacity(0.15)).frame(width: 30, height: 30)
                                    Image(systemName: cat.icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(cat.color)
                                }
                                Text(cat.title)
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(PepTheme.textPrimary)
                            }
                        }
                        .tint(PepTheme.teal)
                        .disabled(!prefs.isEnabled)
                    }
                }
            }

            Section {
                Button {
                    prefs.categories = Set(StatShareCategory.allCases)
                } label: {
                    Text("Share everything")
                        .foregroundStyle(PepTheme.teal)
                }
                .disabled(!prefs.isEnabled)

                Button(role: .destructive) {
                    prefs.categories = []
                } label: {
                    Text("Share nothing")
                }
                .disabled(!prefs.isEnabled)
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Sharing Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { save(); dismiss() }
                    .foregroundStyle(PepTheme.teal)
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: prefs.isEnabled) { _, _ in save() }
        .onChange(of: prefs.audience) { _, _ in save() }
        .onChange(of: prefs.categories) { _, _ in save() }
        .task {
            if let id = try? AuthService.shared.currentUserId() {
                prefs = StatSharingService.shared.prefs(for: id)
            }
        }
    }

    private func save() {
        guard let id = try? AuthService.shared.currentUserId() else { return }
        StatSharingService.shared.save(prefs, for: id)
    }
}
