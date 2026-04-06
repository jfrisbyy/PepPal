import SwiftUI

struct VendorDetailView: View {
    let vendor: Vendor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroHeader
                statsBar
                compoundsSection
                reviewsSection
                websiteButton
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: vendor.isVerified
                                ? [PepTheme.teal.opacity(0.25), PepTheme.teal.opacity(0.05)]
                                : [PepTheme.elevated, PepTheme.elevated.opacity(0.5)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: vendor.isVerified ? "checkmark.shield.fill" : "building.2.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(vendor.isVerified ? PepTheme.teal : PepTheme.textSecondary)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(vendor.name)
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    if vendor.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(PepTheme.teal)
                    }
                }

                if vendor.isVerified {
                    HStack(spacing: 5) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 10))
                        Text("Verified — COAs and third-party lab results submitted")
                            .font(.system(.caption2, weight: .medium))
                    }
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PepTheme.teal.opacity(0.1))
                    .clipShape(.capsule)
                    .overlay(
                        Capsule().strokeBorder(PepTheme.teal.opacity(0.15), lineWidth: 0.5)
                    )
                }
            }
        }
        .padding(.top, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            vendorStat(
                value: String(format: "%.1f", vendor.rating),
                label: "Rating",
                icon: "star.fill",
                iconColor: .yellow
            )

            statDivider

            vendorStat(
                value: "\(vendor.reviewCount)",
                label: "Reviews",
                icon: "text.bubble.fill",
                iconColor: PepTheme.blue
            )

            statDivider

            vendorStat(
                value: "\(vendor.compoundsCarried.count)",
                label: "Compounds",
                icon: "pill.fill",
                iconColor: PepTheme.teal
            )
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func vendorStat(value: String, label: String, icon: String, iconColor: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PepTheme.separatorColor)
            .frame(width: 1, height: 36)
    }

    private var compoundsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "pill.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(PepTheme.teal)
                    Text("Compounds Carried")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text("\(vendor.compoundsCarried.count)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PepTheme.teal.opacity(0.1))
                        .clipShape(.capsule)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(vendor.compoundsCarried, id: \.self) { name in
                        let compoundColor = compoundAccentColor(for: name)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(compoundColor)
                                .frame(width: 5, height: 5)
                            Text(name)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(compoundColor.opacity(0.08))
                        .clipShape(.capsule)
                        .overlay(
                            Capsule().strokeBorder(compoundColor.opacity(0.12), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(PepTheme.blue)
                Text("Reviews")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal, 4)

            if vendor.reviews.isEmpty {
                GlassCard {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(PepTheme.elevated)
                                .frame(width: 48, height: 48)
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        }
                        Text("No reviews yet")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                ForEach(vendor.reviews) { review in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(PepTheme.teal.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Text(String(review.userName.prefix(1)).uppercased())
                                            .font(.system(.caption, weight: .bold))
                                            .foregroundStyle(PepTheme.teal)
                                    }
                                    Text(review.userName)
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                }
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(0..<5, id: \.self) { i in
                                        Image(systemName: i < review.rating ? "star.fill" : "star")
                                            .font(.system(size: 10))
                                            .foregroundStyle(i < review.rating ? .yellow : PepTheme.textSecondary.opacity(0.3))
                                    }
                                }
                            }

                            Text(review.text)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(3)

                            Text(review.date.formatted(.dateTime.month().day().year()))
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var websiteButton: some View {
        Button {
            if let url = URL(string: vendor.websiteURL) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 15, weight: .semibold))
                Text("Visit Website")
                    .font(.system(.body, weight: .bold))
            }
            .foregroundStyle(PepTheme.invertedText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: .rect(cornerRadius: 14)
            )
        }
        .buttonStyle(.scale)
    }

    private func compoundAccentColor(for name: String) -> Color {
        if let compound = CompoundDatabase.compound(named: name),
           let cat = compound.categories.first {
            return cat.color
        }
        return PepTheme.teal
    }
}
