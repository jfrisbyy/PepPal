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
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(vendor.isVerified ? "VERIFIED VENDOR" : "VENDOR")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(vendor.isVerified ? PepTheme.teal : PepTheme.textSecondary)

            HStack(spacing: 8) {
                Text(vendor.name)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                if vendor.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PepTheme.teal)
                }
            }

            if vendor.isVerified {
                Text("COAs and third-party lab results submitted.")
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            vendorStat(
                value: String(format: "%.1f", vendor.rating),
                label: "Rating"
            )
            statDivider
            vendorStat(
                value: "\(vendor.reviewCount)",
                label: "Reviews"
            )
            statDivider
            vendorStat(
                value: "\(vendor.compoundsCarried.count)",
                label: "Compounds"
            )
        }
        .padding(.vertical, 14)
        .overlay(
            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.12))
                .frame(height: 0.5),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(PepTheme.textPrimary.opacity(0.12))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private func vendorStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.3)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PepTheme.textPrimary.opacity(0.12))
            .frame(width: 0.5, height: 36)
    }

    private var compoundsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionEyebrow("Compounds Carried", number: "01", accent: PepTheme.teal) {
                    Text("\(vendor.compoundsCarried.count)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(vendor.compoundsCarried, id: \.self) { name in
                        let compoundColor = compoundAccentColor(for: name)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(compoundColor)
                                .frame(width: 5, height: 5)
                            Text(name)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(
                            Capsule().strokeBorder(PepTheme.textPrimary.opacity(0.12), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Reviews", number: "02", accent: PepTheme.blue)
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
                                            .strokeBorder(PepTheme.textPrimary.opacity(0.18), lineWidth: 0.5)
                                            .frame(width: 32, height: 32)
                                        Text(String(review.userName.prefix(1)).uppercased())
                                            .font(.system(.caption, weight: .bold))
                                            .foregroundStyle(PepTheme.textPrimary)
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
                Text("VISIT WEBSITE")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.6)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(PepTheme.invertedText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PepTheme.textPrimary, in: .rect(cornerRadius: 14))
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
