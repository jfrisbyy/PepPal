import SwiftUI
import PhotosUI
import UIKit

struct SocialIdentityStepView: View {
    @Bindable var state: OnboardingState
    let onContinue: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarPreview: UIImage?
    @FocusState private var usernameFocused: Bool

    private var initial: String {
        let trimmed = state.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first { return String(first).uppercased() }
        let name = state.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = name.first { return String(first).uppercased() }
        return "?"
    }

    private var resolvedColor: Color {
        if let hex = state.avatarColorHex { return OnboardingAvatarPalette.color(forHex: hex) }
        return OnboardingAvatarPalette.color(forHex: OnboardingAvatarPalette.swatches[0])
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                avatarHero

                avatarControls

                usernameSection

                continueButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if state.avatarColorHex == nil {
                state.avatarColorHex = OnboardingAvatarPalette.swatches.randomElement()
            }
            // If we already have a username candidate (e.g. resumed draft),
            // re-run the availability check.
            if !state.username.isEmpty {
                scheduleAvailabilityCheck(for: state.username)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Make it yours")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Pick a handle and an avatar so friends can find you in EPTI.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var avatarHero: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [resolvedColor.opacity(0.85), resolvedColor.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 128, height: 128)
                .shadow(color: resolvedColor.opacity(0.35), radius: 24, x: 0, y: 10)

            if let avatarPreview {
                Image(uiImage: avatarPreview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 128, height: 128)
                    .clipShape(Circle())
            } else {
                Text(initial)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.avatarColorHex)
        .animation(.easeInOut(duration: 0.2), value: avatarPreview)
    }

    private var avatarControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(OnboardingAvatarPalette.swatches, id: \.self) { hex in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        state.avatarColorHex = hex
                    } label: {
                        Circle()
                            .fill(OnboardingAvatarPalette.color(forHex: hex))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        state.avatarColorHex == hex ? PepTheme.textPrimary : .clear,
                                        lineWidth: 2.5
                                    )
                                    .padding(-3)
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(avatarPreview == nil ? 1 : 0.4)
                    .disabled(avatarPreview != nil)
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                        Text(avatarPreview == nil ? "Upload photo" : "Change photo")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(PepTheme.elevated)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if avatarPreview != nil {
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        avatarPreview = nil
                        selectedPhoto = nil
                        state.avatarImageData = nil
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                            Text("Use initial")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(PepTheme.elevated.opacity(0.6))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Username")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PepTheme.textSecondary)

            HStack(spacing: 8) {
                Text("@")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("yourhandle", text: $state.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .focused($usernameFocused)
                    .onChange(of: state.username) { _, newValue in
                        let lowered = newValue.lowercased()
                        if lowered != newValue { state.username = lowered }
                        scheduleAvailabilityCheck(for: lowered)
                    }
                availabilityIcon
            }
            .padding(14)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: state.usernameAvailability)

            if let helper = helperText {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(helperColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var availabilityIcon: some View {
        switch state.usernameAvailability {
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PepTheme.teal)
        case .taken, .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .idle:
            EmptyView()
        }
    }

    private var borderColor: Color {
        switch state.usernameAvailability {
        case .available: return PepTheme.teal.opacity(0.6)
        case .taken, .invalid: return Color.red.opacity(0.6)
        default: return PepTheme.glassBorderTop
        }
    }

    private var helperText: String? {
        switch state.usernameAvailability {
        case .idle:
            return "3–20 characters. Letters, numbers, _ and . only."
        case .checking:
            return "Checking availability…"
        case .available:
            return "@\(state.username) is available."
        case .taken:
            return "@\(state.username) is taken. Try another."
        case .invalid(let reason):
            return reason
        }
    }

    private var helperColor: Color {
        switch state.usernameAvailability {
        case .available: return PepTheme.teal
        case .taken, .invalid: return .red
        default: return PepTheme.textSecondary
        }
    }

    private var continueButton: some View {
        Button {
            usernameFocused = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onContinue()
        } label: {
            Text("Continue")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(state.canAdvance(from: .socialIdentity) ? PepTheme.teal : PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!state.canAdvance(from: .socialIdentity))
        .animation(.easeInOut(duration: 0.2), value: state.canAdvance(from: .socialIdentity))
    }

    // MARK: - Logic

    private func scheduleAvailabilityCheck(for raw: String) {
        state.usernameCheckTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            state.usernameAvailability = .idle
            return
        }
        if let invalid = SocialIdentityRules.validationMessage(trimmed) {
            state.usernameAvailability = .invalid(reason: invalid)
            return
        }
        guard SocialIdentityRules.isValidFormat(trimmed) else {
            state.usernameAvailability = .invalid(reason: "Invalid format.")
            return
        }
        state.usernameAvailability = .checking
        let task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if Task.isCancelled { return }
            let available = await OnboardingManager.isUsernameAvailable(trimmed)
            if Task.isCancelled { return }
            // Make sure the result still applies to the current input.
            if state.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed.lowercased() {
                state.usernameAvailability = available ? .available : .taken
            }
        }
        state.usernameCheckTask = task
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let image = UIImage(data: data) else { return }
        let processed = downscale(image, maxDimension: 1024)
        let jpeg = processed.jpegData(compressionQuality: 0.85) ?? data
        await MainActor.run {
            avatarPreview = processed
            state.avatarImageData = jpeg
        }
    }

    private func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
