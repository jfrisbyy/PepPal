import SwiftUI

/// Editorial section header that can be tapped to collapse / expand its
/// associated content. Persists open / closed state across launches via
/// `@AppStorage` keyed by the supplied storage key.
///
/// Visual chrome matches `EditorialSectionHeader` (small-caps eyebrow,
/// hairline rule) with a thin chevron added on the trailing edge.
struct CollapsibleEditorialSection<Content: View, Trailing: View>: View {
    let eyebrow: String
    var meta: String? = nil
    let storageKey: String
    var defaultExpanded: Bool = true
    @ViewBuilder var trailingAction: () -> Trailing
    @ViewBuilder var content: () -> Content

    @State private var isExpanded: Bool = true
    @State private var didHydrate: Bool = false

    init(
        eyebrow: String,
        meta: String? = nil,
        storageKey: String,
        defaultExpanded: Bool = true,
        @ViewBuilder trailingAction: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.eyebrow = eyebrow
        self.meta = meta
        self.storageKey = storageKey
        self.defaultExpanded = defaultExpanded
        self.trailingAction = trailingAction
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
                UserDefaults.standard.set(isExpanded, forKey: defaultsKey)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(eyebrow.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.85))

                        Spacer(minLength: 8)

                        if let meta {
                            Text(meta.uppercased())
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.4)
                                .foregroundStyle(PepTheme.textTertiary)
                        }

                        trailingAction()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    }

                    LinearGradient(
                        colors: [
                            PepTheme.textPrimary.opacity(0.16),
                            PepTheme.textPrimary.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 0.5)
                    .padding(.top, 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isExpanded)
            .padding(.bottom, isExpanded ? 16 : 0)

            if isExpanded {
                content()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .onAppear {
            guard !didHydrate else { return }
            didHydrate = true
            if UserDefaults.standard.object(forKey: defaultsKey) != nil {
                isExpanded = UserDefaults.standard.bool(forKey: defaultsKey)
            } else {
                isExpanded = defaultExpanded
            }
        }
    }

    private var defaultsKey: String {
        "homeSectionExpanded.\(storageKey)"
    }
}
