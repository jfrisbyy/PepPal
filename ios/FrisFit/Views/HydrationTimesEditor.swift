import SwiftUI

struct HydrationTimesEditor: View {
    @Bindable var reminderManager: ReminderManager
    @State private var showAddPicker: Bool = false
    @State private var newTime: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(reminderManager.hydrationTimes.enumerated()), id: \.offset) { index, time in
                HStack {
                    Label("Nudge \(index + 1)", systemImage: "drop.fill")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { reminderManager.hydrationTimes[index] },
                            set: { reminderManager.updateHydrationTime(at: index, to: $0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(PepTheme.teal)

                    Button {
                        withAnimation {
                            reminderManager.removeHydrationTime(at: index)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                let time = Date()
                reminderManager.addHydrationTime(time)
            } label: {
                Label("Add nudge time", systemImage: "plus.circle.fill")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}
