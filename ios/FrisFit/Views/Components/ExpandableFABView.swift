import SwiftUI

struct FABAction {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
}

struct ExpandableFABView: View {
    @Binding var isExpanded: Bool
    let actions: [FABAction]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            isExpanded = false
                        }
                    }
                    .transition(.opacity)
            }

            VStack(alignment: .trailing, spacing: 12) {
                if isExpanded {
                    ForEach(Array(actions.enumerated()), id: \.offset) { index, item in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded = false
                            }
                            item.action()
                        } label: {
                            HStack(spacing: 10) {
                                Text(item.label)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(PepTheme.cardSurface)
                                    .clipShape(.capsule)
                                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)

                                ZStack {
                                    Circle()
                                        .fill(item.color.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: item.icon)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(item.color)
                                }
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.4, anchor: .bottomTrailing)
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7).delay(Double(actions.count - 1 - index) * 0.04)),
                            removal: .scale(scale: 0.4, anchor: .bottomTrailing)
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.25, dampingFraction: 0.8).delay(Double(index) * 0.02))
                        ))
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                        isExpanded.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [PepTheme.teal, PepTheme.teal.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: PepTheme.teal.opacity(0.4), radius: 12, x: 0, y: 4)

                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(isExpanded ? 45 : 0))
                    }
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: isExpanded)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
