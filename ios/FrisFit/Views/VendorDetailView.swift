import SwiftUI

struct VendorDetailView: View {
    let vendor: Vendor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
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

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(vendor.isVerified ? PepTheme.teal.opacity(0.15) : PepTheme.elevated)
                    .frame(width: 80, height: 80)

                Image(systemName: vendor.isVerified ? "checkmark.shield.fill" : "building.2.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(vendor.isVerified ? PepTheme.teal : PepTheme.textSecondary)
            }

            HStack(spacing: 6) {
                Text(vendor.name)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)

                if vendor.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PepTheme.teal)
                }
            }

            if vendor.isVerified {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 11))
                    Text("Verified — COAs and third-party lab results submitted")
                        .font(.caption)
                }
                .foregroundStyle(PepTheme.teal)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(.capsule)
            }
        }
        .padding(.top, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", vendor.rating))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Text("Rating")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(PepTheme.separatorColor).frame(width: 1, height: 32)

            VStack(spacing: 4) {
                Text("\(vendor.reviewCount)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Reviews")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(PepTheme.separatorColor).frame(width: 1, height: 32)

            VStack(spacing: 4) {
                Text("\(vendor.compoundsCarried.count)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Compounds")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var compoundsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "pill.fill")
                        .foregroundStyle(PepTheme.teal)
                    Text("Compounds Carried")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(vendor.compoundsCarried, id: \.self) { name in
                        Text(name)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(PepTheme.teal.opacity(0.1))
                            .clipShape(.capsule)
                    }
                }
            }
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill")
                    .foregroundStyle(PepTheme.teal)
                Text("Reviews")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal, 4)

            if vendor.reviews.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No reviews yet")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                ForEach(vendor.reviews) { review in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(review.userName)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(0..<5, id: \.self) { i in
                                        Image(systemName: i < review.rating ? "star.fill" : "star")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.yellow)
                                    }
                                }
                            }

                            Text(review.text)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                                .lineSpacing(2)

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
                Text("Visit Website")
                    .font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(PepTheme.invertedText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(PepTheme.teal, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.scale)
    }
}
