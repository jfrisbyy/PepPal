import SwiftUI

struct MedicalDisclaimerBanner: View {
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: compact ? 14 : 18))
                .foregroundStyle(PepTheme.amber)

            Text("For educational and informational purposes only. Not medical advice. Peptides and research compounds discussed are not FDA-approved for human use. Consult a qualified healthcare professional before starting, changing, or stopping any compound.")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.amber.opacity(0.15), lineWidth: 0.5)
        )
    }
}
