import SwiftUI

struct ReminderToggleRow: View {
    let category: ReminderCategory
    @Binding var isEnabled: Bool
    let onToggle: (Bool) -> Void
    @ViewBuilder var expandedContent: () -> AnyView

    init(
        category: ReminderCategory,
        isEnabled: Binding<Bool>,
        onToggle: @escaping (Bool) -> Void,
        @ViewBuilder expandedContent: @escaping () -> some View = { EmptyView() }
    ) {
        self.category = category
        self._isEnabled = isEnabled
        self.onToggle = onToggle
        self.expandedContent = { AnyView(expandedContent()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isEnabled) {
                HStack(spacing: 10) {
                    Image(systemName: category.icon)
                        .font(.subheadline)
                        .foregroundStyle(iconColor)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title)
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(category.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .tint(PepTheme.teal)
            .onChange(of: isEnabled) { _, newValue in
                onToggle(newValue)
            }

            if isEnabled {
                Divider()
                    .overlay(PepTheme.glassBorderTop)
                    .padding(.vertical, 8)

                expandedContent()
            }
        }
    }

    private var iconColor: Color {
        switch category.iconColor {
        case .teal: return PepTheme.teal
        case .red: return .red
        case .blue: return PepTheme.blue
        case .amber: return PepTheme.amber
        case .violet: return PepTheme.violet
        }
    }
}

struct ReminderTimePicker: View {
    let label: String
    let icon: String
    @Binding var time: Date

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(PepTheme.teal)
        }
    }
}

struct ReminderDayPicker: View {
    let label: String
    @Binding var day: WeighInDay

    var body: some View {
        HStack {
            Label(label, systemImage: "calendar")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Menu {
                ForEach(WeighInDay.allCases, id: \.rawValue) { d in
                    Button(d.name) { day = d }
                }
            } label: {
                Text(day.name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.teal.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
    }
}

struct ReminderIntervalPicker: View {
    let label: String
    @Binding var interval: BloodworkInterval

    var body: some View {
        HStack {
            Label(label, systemImage: "repeat")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Menu {
                ForEach(BloodworkInterval.allCases, id: \.rawValue) { i in
                    Button(i.label) { interval = i }
                }
            } label: {
                Text(interval.label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.teal.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
    }
}

struct NotificationDeniedBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(PepTheme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications Disabled")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Enable notifications in Settings → FrisFit → Notifications to receive reminders.")
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.teal.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(PepTheme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }
}
