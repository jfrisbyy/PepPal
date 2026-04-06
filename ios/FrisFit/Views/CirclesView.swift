import SwiftUI

struct CirclesView: View {
    @Bindable var viewModel: CirclesViewModel
    @State private var selectedSection: CirclesSection = .myCircles

    private enum CirclesSection: String, CaseIterable {
        case myCircles = "My Circles"
        case discover = "Discover"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                ForEach(CirclesSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .sensoryFeedback(.selection, trigger: selectedSection)

            switch selectedSection {
            case .myCircles:
                myCirclesContent
            case .discover:
                discoverContent
            }
        }
    }

    private var myCirclesContent: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if !viewModel.pendingInvites.isEmpty {
                    invitesBanner
                }

                if !viewModel.cheerlines.filter({ !$0.read }).isEmpty {
                    cheerlinesBanner
                }

                if viewModel.myCircles.isEmpty {
                    EmptyStateView(
                        icon: "circle.hexagongrid",
                        title: "No Circles Yet",
                        message: "Create or join a circle to start training with friends.",
                        actionTitle: "Create Circle"
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(viewModel.myCircles) { circle in
                        Button {
                            viewModel.selectCircle(circle)
                        } label: {
                            CircleCardView(circle: circle)
                        }
                        .buttonStyle(.scale)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable {
            try? await Task.sleep(for: .seconds(0.5))
        }
    }

    private var discoverContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("Search circles...", text: $viewModel.searchQuery)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(PepTheme.elevated)
            .clipShape(.capsule)
            .padding(.horizontal)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 14) {
                    joinByCodeCard

                    if viewModel.filteredPublicCircles.isEmpty {
                        EmptyStateView(
                            icon: "globe",
                            title: "No Circles Found",
                            message: "Try a different search or create your own circle."
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(viewModel.filteredPublicCircles) { circle in
                            PublicCircleCard(circle: circle) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.joinCircle(circle)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    private var invitesBanner: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.pendingInvites) { invite in
                HStack(spacing: 12) {
                    Circle()
                        .fill(PepTheme.violet.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(PepTheme.violet)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(invite.inviter.name) invited you")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("to join \(invite.circleName)")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                        } label: {
                            Text("Join")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.invertedText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(PepTheme.teal, in: .capsule)
                        }
                        Button {
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                .padding(12)
                .background(PepTheme.violet.opacity(0.06))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.violet.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
    }

    private var cheerlinesBanner: some View {
        let unread = viewModel.cheerlines.filter { !$0.read }
        return VStack(spacing: 8) {
            ForEach(unread) { cheer in
                HStack(spacing: 10) {
                    Circle()
                        .fill(cheer.sender.avatarColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text(cheer.sender.avatarInitial)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(cheer.sender.avatarColor)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cheer.sender.name)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(cheer.message)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "megaphone.fill")
                        .font(.caption)
                        .foregroundStyle(PepTheme.amber)
                }
                .padding(12)
                .background(PepTheme.amber.opacity(0.06))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.amber.opacity(0.12), lineWidth: 0.5)
                )
            }
        }
    }

    private var joinByCodeCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "ticket.fill")
                    .font(.title3)
                    .foregroundStyle(PepTheme.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Join by Invite Code")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Enter a code from a friend")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
        }
    }
}

struct CircleCardView: View {
    let circle: FitCircle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [circle.accentColor, circle.accentColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(String(circle.name.prefix(1)))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(circle.name)
                            .font(.system(.headline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        if circle.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                    HStack(spacing: 8) {
                        Label("\(circle.memberCount)", systemImage: "person.2.fill")
                        Text("·")
                        Text("\(circle.totalCirclePoints.formatted()) pts")
                    }
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }

            if let weeklyGoal = circle.weeklyPointGoal {
                let weeklyTotal = circle.members.reduce(0) { $0 + $1.weeklyPoints }
                let progress = min(Double(weeklyTotal) / Double(weeklyGoal), 1.0)
                VStack(spacing: 6) {
                    HStack {
                        Text("Weekly Progress")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Text("\(weeklyTotal) / \(weeklyGoal)")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(circle.accentColor)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(PepTheme.elevated)
                                .frame(height: 5)
                            Capsule()
                                .fill(circle.accentColor)
                                .frame(width: geo.size.width * progress, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }

            HStack(spacing: -8) {
                ForEach(Array(circle.members.prefix(4).enumerated()), id: \.element.id) { idx, member in
                    Circle()
                        .fill(member.user.avatarColor.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(member.user.avatarInitial)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(member.user.avatarColor)
                        }
                        .overlay(
                            Circle().strokeBorder(PepTheme.cardSurface, lineWidth: 2)
                        )
                        .zIndex(Double(4 - idx))
                }
                if circle.memberCount > 4 {
                    Circle()
                        .fill(PepTheme.elevated)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text("+\(circle.memberCount - 4)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .overlay(
                            Circle().strokeBorder(PepTheme.cardSurface, lineWidth: 2)
                        )
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
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
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

struct PublicCircleCard: View {
    let circle: FitCircle
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [circle.accentColor, circle.accentColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(String(circle.name.prefix(1)))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(circle.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    HStack(spacing: 6) {
                        Label("\(circle.memberCount) members", systemImage: "person.2")
                        Text("·")
                        Text("\(circle.totalCirclePoints.formatted()) pts")
                    }
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()
            }

            Text(circle.description)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(2)

            Button {
                onJoin()
            } label: {
                Text("Join Circle")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(circle.accentColor, in: .rect(cornerRadius: 10))
            }
            .buttonStyle(.scalePrimary)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
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
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}
