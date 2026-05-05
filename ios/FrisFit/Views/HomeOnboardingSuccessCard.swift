import SwiftUI
import UIKit

/// One-time, dismissible card surfaced on the home screen the first time a
/// freshly-onboarded user lands. Reads the personalization counts staged by
/// `OnboardingManager.stageSuccessCardCounts` so the values are accurate for
/// the user that just completed onboarding.
struct HomeOnboardingSuccessCard: View {
    let onDismiss: () -> Void

    private var firstName: String {
        UserDefaults.standard.string(forKey: OnboardingManager.successFirstNameKey) ?? ""
    }
    private var factCount: Int {
        UserDefaults.standard.integer(forKey: OnboardingManager.successFactCountKey)
    }
    private var hkDays: Int {
        UserDefaults.standard.integer(forKey: OnboardingManager.successHKDaysKey)
    }
    private var pinCount: Int {
        UserDefaults.standard.integer(forKey: OnboardingManager.successPinCountKey)
    }
    private var protocolLine: String? {
        UserDefaults.standard.string(forKey: OnboardingManager.successProtocolKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You're all set\(firstName.isEmpty ? "" : ", \(firstName)")\u{2008}.")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Your EPTI is ready.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer(minLength: 8)
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    OnboardingManager.dismissSuccessCard()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(PepTheme.elevated.opacity(0.6), in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                bullet(icon: "brain", tint: PepTheme.violet, text: "\(factCount) facts seeded into your AI memory.")
                if hkDays > 0 {
                    bullet(icon: "heart.text.square.fill", tint: .red, text: "\(hkDays) days of HealthKit data imported.")
                }
                if pinCount > 0 {
                    bullet(icon: "mappin.and.ellipse", tint: PepTheme.teal, text: "\(pinCount) journey map \(pinCount == 1 ? "pin" : "pins") added.")
                }
                if let proto = protocolLine, !proto.isEmpty {
                    bullet(icon: "syringe.fill", tint: PepTheme.amber, text: "Active protocol: \(proto)")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PepTheme.teal.opacity(0.18), PepTheme.violet.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: PepTheme.teal.opacity(0.18), radius: 14, y: 6)
    }

    private func bullet(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
