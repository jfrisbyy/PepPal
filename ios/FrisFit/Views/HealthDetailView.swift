import SwiftUI
import HealthKit

struct HealthDetailView: View {
    @State private var viewModel = HealthDetailViewModel()

    @State private var showSync: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if viewModel.healthKit.isAuthorized {
                    HealthHeroView(viewModel: viewModel) { showSync = true }
                } else {
                    connectPrompt
                }
                HealthPeriodPicker(period: $viewModel.period)
                    .sensoryFeedback(.selection, trigger: viewModel.period)
                if viewModel.isRefreshing || viewModel.healthKit.isRefreshing {
                    refreshingIndicator
                }
                content
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.period)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSync = true } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
        }
        .sheet(isPresented: $showSync) {
            NavigationStack { AppleHealthSyncView() }
        }
        .task(id: viewModel.period) {
            viewModel.hydrateFromCache(period: viewModel.period)
            await viewModel.load()
        }
        .refreshable {
            await viewModel.healthKit.fetchAllData()
            await viewModel.load()
        }
    }

    private var refreshingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.mini)
            Text("Updating from Apple Health\u{2026}")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 10))
        .transition(.opacity)
    }

    private var connectPrompt: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [.red.opacity(0.4), .pink.opacity(0.05)], center: .center, startRadius: 2, endRadius: 80)
                    )
                    .frame(width: 140, height: 140)
                    .blur(radius: 8)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(.red, .pink)
                    .symbolRenderingMode(.palette)
            }
            Text("Connect Apple Health")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Unlock rings, recovery, trends, and personal bests pulled live from HealthKit.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button { showSync = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                    Text("Connect").fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing))
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 18))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.stepsSeries.isEmpty && viewModel.sleepNights.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            categoryList
            openAppleHealthLink
        }
    }

    private var categoryList: some View {
        VStack(spacing: 12) {
            ForEach(HealthCategory.allCases) { category in
                NavigationLink {
                    HealthCategoryDetailView(category: category, viewModel: viewModel)
                } label: {
                    HealthCategoryPreviewCard(category: category, viewModel: viewModel)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var openAppleHealthLink: some View {
        Button {
            if let url = URL(string: "x-apple-health://") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Open in Apple Health")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
        }
    }
}

struct HealthRecoveryBanner: View {
    let score: Int

    var body: some View {
        let tint: Color = score >= 75 ? .green : (score >= 55 ? PepTheme.amber : .red)
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.2), lineWidth: 6)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 64, height: 64)
                Text("\(score)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery Score")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(caption(score: score))
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(tint.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tint.opacity(0.25), lineWidth: 0.5)
        )
        .clipShape(.rect(cornerRadius: 14))
    }

    private func caption(score: Int) -> String {
        if score >= 75 { return "You're primed — great day to push training." }
        if score >= 55 { return "Moderate recovery — train at maintenance." }
        return "Low recovery — prioritize rest, sleep & hydration."
    }
}
