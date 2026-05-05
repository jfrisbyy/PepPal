import SwiftUI

struct InteractionWarningsView: View {
    let interactions: [CompoundInteraction]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(interactions) { inter in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: inter.severity.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(inter.severity.color)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(inter.compoundA)
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(inter.compoundB)
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Text(inter.severity.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(inter.severity.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(inter.severity.color.opacity(0.12))
                                .clipShape(.capsule)
                        }
                        Text(inter.note)
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(inter.severity.color.opacity(0.06))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }
}
