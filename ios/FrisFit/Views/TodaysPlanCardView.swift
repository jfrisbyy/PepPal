import SwiftUI

struct TodaysPlanCardView: View {
    @Bindable var viewModel: TodaysPlanViewModel
    let onTapChat: () -> Void

    @State private var appearedModules: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            headerCard

            if viewModel.isExpanded && viewModel.hasPlan {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.isExpanded)
    }

    private var headerCard: some View {
        Button {
            if viewModel.hasPlan {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    viewModel.isExpanded.toggle()
                }
            } else {
                onTapChat()
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.bottom, viewModel.isLoading || viewModel.hasPlan ? 12 : 0)

                if viewModel.isLoading {
                    loadingState
                } else if let error = viewModel.errorMessage, !viewModel.hasPlan {
                    errorState(error)
                } else if viewModel.hasPlan {
                    summaryText
                } else {
                    emptyState
                }
            }
            .padding(16)
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
        .buttonStyle(.scale)
        .sensoryFeedback(.selection, trigger: viewModel.isExpanded)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            PepAvatar(size: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Pep's Daily Briefing")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)

                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(PepTheme.violet)
                    }
                }

                if let date = viewModel.lastFetchDate {
                    Text(timeAgoString(from: date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                }
            }

            Spacer()

            if viewModel.hasPlan {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    .rotationEffect(.degrees(viewModel.isExpanded ? 180 : 0))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.violet.opacity(0.5))
            }
        }
    }

    private var loadingState: some View {
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

    private func errorState(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(.leading, 50)
    }

    private var emptyState: some View {
        Text("Tap to get your personalized daily briefing")
            .font(.caption)
            .foregroundStyle(PepTheme.textSecondary)
            .padding(.top, 4)
            .padding(.leading, 50)
    }

    private var summaryText: some View {
        Text(viewModel.summary)
            .font(.subheadline)
            .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
            .lineSpacing(3)
            .multilineTextAlignment(.leading)
            .padding(.leading, 50)
            .lineLimit(viewModel.isExpanded ? nil : 3)
    }

    private var expandedContent: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.modules.enumerated()), id: \.element.id) { index, module in
                moduleCard(module, index: index)
                    .opacity(appearedModules.contains(module.type) ? 1 : 0)
                    .offset(y: appearedModules.contains(module.type) ? 0 : 12)
                    .onAppear {
                        let moduleType = module.type
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.06)) {
                            _ = appearedModules.insert(moduleType)
                        }
                    }
            }

            refreshButton
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(
            PepTheme.cardSurface
                .overlay(PepTheme.cardOverlay)
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        .padding(.top, -8)
        .onDisappear {
            appearedModules.removeAll()
        }
    }

    private func moduleCard(_ module: TodaysPlanModule, index: Int) -> some View {
        let moduleType = PlanModuleType(rawValue: module.type)
        let color = moduleType?.color ?? PepTheme.teal
        let icon = moduleType?.icon ?? "sparkles"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 6))

                Text(module.title)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(color)
                    .textCase(.uppercase)
                    .tracking(0.3)

                Spacer()
            }

            Text(module.content)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary.opacity(0.8))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            color.opacity(0.03)
                .overlay(PepTheme.elevated.opacity(0.5))
        )
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var refreshButton: some View {
        Button {
            viewModel.isExpanded = false
            viewModel.planResponse = nil
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                Text("Refresh Briefing")
                    .font(.system(.caption, weight: .semibold))
            }
            .foregroundStyle(PepTheme.violet.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(PepTheme.violet.opacity(0.06))
            .clipShape(.rect(cornerRadius: 10))
        }
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
