import SwiftUI

struct BriefLineRow: View {
    let line: BriefLine
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BriefLineRow.toneColor(line.tone))
                .frame(width: 24, height: 24)
                .background(BriefLineRow.toneColor(line.tone).opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(line.label.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    Text(line.value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(line.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BriefLineRow.toneColor(line.tone).opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }

    static func toneColor(_ tone: BriefLine.Tone) -> Color {
        switch tone {
        case .positive: return .green
        case .neutral: return PepTheme.teal
        case .caution: return PepTheme.amber
        case .warning: return .red
        }
    }
}
