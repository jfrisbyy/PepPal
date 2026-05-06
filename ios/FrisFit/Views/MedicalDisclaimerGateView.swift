import SwiftUI

struct MedicalDisclaimerGateView: View {
    @Binding var isPresented: Bool
    @State private var confirmedAge: Bool = false
    @State private var confirmedNotMedicalAdvice: Bool = false
    @State private var confirmedOwnResponsibility: Bool = false

    private var canAccept: Bool {
        confirmedAge && confirmedNotMedicalAdvice && confirmedOwnResponsibility
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(PepTheme.amber.opacity(0.14))
                                .frame(width: 60, height: 60)
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(PepTheme.amber)
                        }
                        Text("Before you continue")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("EPTI is an educational and tracking tool. Please read and acknowledge the following before using the app.")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 12) {
                        disclaimerRow(title: "Not medical advice", body: "Content in this app — including compound information, protocol templates, AI chat responses, and dose calculators — is for educational and informational purposes only. It is not medical advice, diagnosis, or treatment and is not a substitute for consultation with a licensed healthcare provider.")

                        disclaimerRow(title: "Research compounds are not FDA-approved", body: "Many peptides and compounds referenced in this app are not approved by the FDA (or equivalent regulators) for human use. EPTI does not sell, prescribe, or endorse any compound, vendor, or supplier.")

                        disclaimerRow(title: "Talk to your provider", body: "Always consult a qualified healthcare professional before starting, changing, or stopping any compound, protocol, supplement, diet, or exercise program — especially if you have a medical condition, are pregnant or nursing, or are taking other medications.")

                        disclaimerRow(title: "You are responsible for your choices", body: "You are solely responsible for decisions you make based on information in this app. EPTI and its developers disclaim any liability for outcomes resulting from use of the app or the information it contains.")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        acknowledgementToggle(
                            isOn: $confirmedAge,
                            text: "I am at least 18 years old."
                        )
                        acknowledgementToggle(
                            isOn: $confirmedNotMedicalAdvice,
                            text: "I understand nothing in this app is medical advice, diagnosis, or treatment."
                        )
                        acknowledgementToggle(
                            isOn: $confirmedOwnResponsibility,
                            text: "I take full responsibility for any decisions I make and will consult a qualified healthcare provider before acting on anything in this app."
                        )
                    }

                    Button {
                        accept()
                    } label: {
                        Text("I Agree & Continue")
                            .font(.system(.headline, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canAccept ? PepTheme.teal : PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAccept)
                    .sensoryFeedback(.success, trigger: isPresented)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Medical Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)
        }
    }

    private func accept() {
        guard canAccept else { return }
        let now = Date()
        LocalStateResetCoordinator.setDisclaimerAccepted(
            date: now,
            version: MedicalDisclaimerManager.currentVersion,
            forUserId: LocalStateResetCoordinator.currentUserId()
        )
        // Always append a row to disclaimer_acknowledgements so version bumps
        // accumulate an audit trail instead of overwriting the prior ack.
        Task {
            await OnboardingManager.persistDisclaimerAcknowledgement(
                version: MedicalDisclaimerManager.currentVersion,
                acceptedAt: now
            )
        }
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }

    private func disclaimerRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(body)
                .font(.footnote)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
        )
    }

    private func acknowledgementToggle(isOn: Binding<Bool>, text: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn.wrappedValue ? PepTheme.teal : PepTheme.textSecondary.opacity(0.6))
                    .contentTransition(.symbolEffect(.replace))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(PepTheme.elevated.opacity(0.45))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn.wrappedValue)
    }
}

struct MedicalDisclaimerDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(PepTheme.amber)
                    Text("Medical Disclaimer")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                section(
                    title: "Not medical advice",
                    body: "Content in EPTI — including compound information, protocol templates, AI chat responses, and dose calculators — is for educational and informational purposes only. It is not medical advice, diagnosis, or treatment and is not a substitute for consultation with a licensed healthcare provider."
                )
                section(
                    title: "Research compounds are not FDA-approved",
                    body: "Many peptides and compounds referenced in this app are not approved by the FDA (or equivalent regulators) for human use. EPTI does not sell, prescribe, or endorse any compound, vendor, or supplier."
                )
                section(
                    title: "Talk to your provider",
                    body: "Always consult a qualified healthcare professional before starting, changing, or stopping any compound, protocol, supplement, diet, or exercise program — especially if you have a medical condition, are pregnant or nursing, or are taking other medications."
                )
                section(
                    title: "You are responsible for your choices",
                    body: "You are solely responsible for decisions you make based on information in this app. EPTI and its developers disclaim any liability for outcomes resulting from use of the app or the information it contains."
                )
                section(
                    title: "Emergencies",
                    body: "If you are experiencing a medical emergency, call your local emergency number or go to the nearest emergency room. Do not rely on this app for urgent medical decisions."
                )
            }
            .padding(20)
        }
        .appBackground()
        .navigationTitle("Medical Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(body)
                .font(.footnote)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
        )
    }
}

enum MedicalDisclaimerManager {
    /// Legacy global keys. Per-user state lives under
    /// `LocalStateResetCoordinator.disclaimerAcceptedKey(for:)` etc.
    static let acceptedKey = "peppal.medicalDisclaimer.accepted.v1"
    static let acceptedDateKey = "peppal.medicalDisclaimer.acceptedDate.v1"
    static let acceptedVersionKey = "peppal.medicalDisclaimer.acceptedVersion.v1"
    /// Bump this when disclaimer copy changes — launch check will re-prompt users
    /// whose stored ack version doesn't match.
    static let currentVersion = "v1"

    static var hasAccepted: Bool {
        let uid = LocalStateResetCoordinator.currentUserId()
        guard LocalStateResetCoordinator.isDisclaimerAccepted(forUserId: uid) else { return false }
        let storedVersion = LocalStateResetCoordinator.disclaimerAcceptedVersion(forUserId: uid) ?? "v1"
        return storedVersion == currentVersion
    }

    static var acceptedVersion: String? {
        LocalStateResetCoordinator.disclaimerAcceptedVersion(
            forUserId: LocalStateResetCoordinator.currentUserId()
        )
    }

    static var needsReprompt: Bool {
        let uid = LocalStateResetCoordinator.currentUserId()
        guard LocalStateResetCoordinator.isDisclaimerAccepted(forUserId: uid) else { return false }
        let storedVersion = LocalStateResetCoordinator.disclaimerAcceptedVersion(forUserId: uid) ?? "v1"
        return storedVersion != currentVersion
    }

    static func reset() {
        LocalStateResetCoordinator.resetDisclaimer(
            forUserId: LocalStateResetCoordinator.currentUserId()
        )
        // Also drop the legacy global keys so a stale ack from an older build
        // can't satisfy the gate after reset.
        UserDefaults.standard.removeObject(forKey: acceptedKey)
        UserDefaults.standard.removeObject(forKey: acceptedDateKey)
        UserDefaults.standard.removeObject(forKey: acceptedVersionKey)
    }

    static func persistAcceptance(at date: Date) async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        let iso = ISO8601DateFormatter().string(from: date)
        let update = ProfileUpdate(
            display_name: nil,
            username: nil,
            bio: nil,
            avatar_url: nil,
            avatar_color: nil,
            banner_url: nil,
            active_program: nil,
            date_of_birth: nil,
            biological_sex: nil,
            height_cm: nil,
            is_private: nil,
            medical_disclaimer_accepted_at: iso,
            instagram_handle: nil,
            twitter_handle: nil,
            facebook_handle: nil,
            tiktok_handle: nil
        )
        try? await ProfileService.shared.updateProfile(userId: userId, update: update)
    }

    @MainActor
    static func syncFromRemote() async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        guard let profile = try? await ProfileService.shared.fetchProfile(userId: userId) else { return }
        if let acceptedAt = profile.medical_disclaimer_accepted_at,
           !acceptedAt.isEmpty,
           !LocalStateResetCoordinator.isDisclaimerAccepted(forUserId: userId) {
            let date = ISO8601DateFormatter().date(from: acceptedAt) ?? Date()
            LocalStateResetCoordinator.setDisclaimerAccepted(
                date: date,
                version: currentVersion,
                forUserId: userId
            )
            NotificationCenter.default.post(name: .medicalDisclaimerSynced, object: nil)
        }
    }
}

extension Notification.Name {
    static let medicalDisclaimerSynced = Notification.Name("peppal.medicalDisclaimer.synced")
}
