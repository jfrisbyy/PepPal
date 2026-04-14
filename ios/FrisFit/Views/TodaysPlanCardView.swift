import SwiftUI

struct TodaysPlanCardView: View {
    @Bindable var viewModel: TodaysPlanViewModel
    var onRefresh: (() -> Void)?
    let onTapChat: () -> Void

    @State private var appearedModules: Set<String> = []
    @State private var showAllModules: Bool = false
    @State private var isMinimized: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            summaryCard
            if !isMinimized && viewModel.hasPlan && !viewModel.modules.isEmpty {
                modulesList
            }
        }
        .onDisappear {
            appearedModules.removeAll()
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.bottom, isMinimized ? 0 : 12)

            if !isMinimized {
                if viewModel.isLoading && !viewModel.hasPlan {
                    loadingShimmer
                } else if viewModel.hasPlan {
                    Text(viewModel.summary)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.88))
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 50)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(16)
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                isMinimized.toggle()
            }
        }
        .sensoryFeedback(.selection, trigger: isMinimized)
        .background(
            LinearGradient(
                colors: [
                    PepTheme.violet.opacity(0.08),
                    PepTheme.teal.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(PepTheme.cardSurface.opacity(0.75))
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.violet.opacity(0.2), PepTheme.teal.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: PepTheme.violet.opacity(0.12), radius: 12, x: 0, y: 4)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            PepAvatar(size: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Today's Plan")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)

                    if viewModel.isBackgroundRefreshing {
                        ProgressView()
                            .scaleEffect(0.5)
                            .tint(PepTheme.violet.opacity(0.6))
                    }
                }

                if let date = viewModel.lastFetchDate {
                    Text(timeAgoString(from: date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                }
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PepTheme.violet.opacity(0.4))
                .rotationEffect(.degrees(isMinimized ? -90 : 0))

            HStack(spacing: 8) {
                if viewModel.hasPlan {
                    Button {
                        onRefresh?()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.violet.opacity(0.5))
                            .frame(width: 28, height: 28)
                            .background(PepTheme.violet.opacity(0.08))
                            .clipShape(Circle())
                    }
                }

                Button {
                    onTapChat()
                } label: {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.violet.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(PepTheme.violet.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
    }

    private var loadingShimmer: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(PepTheme.shimmerHighlight)
                    .frame(height: 12)
                    .frame(maxWidth: i == 2 ? 180 : .infinity, alignment: .leading)
            }
        }
        .padding(.leading, 50)
    }

    private var modulesList: some View {
        let visibleModules = showAllModules ? viewModel.modules : Array(viewModel.modules.prefix(3))

        return VStack(spacing: 8) {
            ForEach(Array(visibleModules.enumerated()), id: \.element.id) { index, module in
                moduleCard(module, index: index)
                    .opacity(appearedModules.contains(module.type) ? 1 : 0)
                    .offset(y: appearedModules.contains(module.type) ? 0 : 10)
                    .onAppear {
                        let moduleType = module.type
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82).delay(Double(index) * 0.05)) {
                            _ = appearedModules.insert(moduleType)
                        }
                    }
            }

            if viewModel.modules.count > 3 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAllModules.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllModules ? "Show Less" : "Show All Insights")
                            .font(.system(.caption, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(showAllModules ? 180 : 0))
                    }
                    .foregroundStyle(PepTheme.violet.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(PepTheme.violet.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 10))
                }
                .sensoryFeedback(.selection, trigger: showAllModules)
            }
        }
    }

    private func moduleCard(_ module: TodaysPlanModule, index: Int) -> some View {
        let moduleType = PlanModuleType(rawValue: module.type)
        let color = moduleType?.color ?? PepTheme.teal
        let icon = moduleType?.icon ?? "sparkles"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 5))

                Text(module.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                    .textCase(.uppercase)
                    .tracking(0.3)

                Spacer()
            }

            Text(module.content)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary.opacity(0.82))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            color.opacity(0.03)
                .overlay(PepTheme.cardSurface.opacity(0.9))
        )
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func timeAgoString(from date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "Yesterday"
    }
}
