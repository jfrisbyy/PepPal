import SwiftUI

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = GlobalSearchViewModel()
    @State private var ask = AskEptiAnswerStore()
    @State private var recorder = WhisperRecorder()
    @State private var recents: [RecentSearchItem] = []
    @FocusState private var searchFieldFocused: Bool

    // Navigation destinations
    @State private var selectedUser: SocialUser?
    @State private var selectedExercise: Exercise?
    @State private var selectedCompound: CompoundProfile?
    @State private var selectedFood: FoodItem?
    @State private var selectedFitCircle: FitCircle?
    @State private var selectedFeedPost: FeedPost?
    @State private var selectedGuide: GuideEntry?

    // Quick-action sheets
    @State private var showAskEptiChat: Bool = false
    @State private var pepChatSeedQuestion: String? = nil
    @State private var showFoodLog: Bool = false
    @State private var showVoicePermissionAlert: Bool = false

    // Shared VMs for child destinations
    @State private var profileViewModel = ProfileViewModel()
    @State private var exerciseLibraryVM = ExerciseLibraryViewModel()
    @State private var socialViewModel = SocialViewModel()
    @State private var circlesViewModel = CirclesViewModel()
    @State private var loadingPostId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                scopePicker
                    .opacity(vm.query.isEmpty ? 0.92 : 1)
                content
            }
            .appBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Search")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .onAppear {
                recents = RecentItemsStore.shared.load()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    searchFieldFocused = true
                }
            }
            .onChange(of: vm.query) { _, newValue in
                vm.search()
                let intent = QueryClassifier.classify(newValue, hasResults: !vm.results.isEmpty)
                ask.ask(newValue, intent: intent)
            }
            .onChange(of: vm.results.count) { _, _ in
                let intent = QueryClassifier.classify(vm.query, hasResults: !vm.results.isEmpty)
                if intent == .lookup { ask.cancel() }
            }
            .onChange(of: vm.scope) { _, _ in vm.search() }
            .onChange(of: recorder.partialTranscript) { _, transcript in
                guard recorder.isRecording, !transcript.isEmpty else { return }
                vm.query = transcript
            }
            .alert("Microphone access needed", isPresented: $showVoicePermissionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable microphone and speech recognition in Settings to dictate searches.")
            }
            .navigationDestination(item: $selectedUser) { user in
                UserProfileView(user: user, viewModel: profileViewModel)
            }
            .navigationDestination(item: $selectedExercise) { ex in
                ExerciseDetailView(exercise: ex, viewModel: exerciseLibraryVM)
            }
            .navigationDestination(item: $selectedCompound) { c in
                CompoundDetailView(compound: c)
            }
            .navigationDestination(item: $selectedFitCircle) { _ in
                CircleDetailView(viewModel: circlesViewModel)
            }
            .sheet(item: $selectedFood) { food in
                FoodQuickLogSheet(food: food)
            }
            .sheet(item: $selectedFeedPost) { post in
                NavigationStack {
                    PostDetailView(post: post, viewModel: socialViewModel)
                }
            }
            .fullScreenCover(isPresented: $showAskEptiChat) {
                PepChatView(initialQuestion: pepChatSeedQuestion)
            }
            .sheet(item: $selectedGuide) { guide in
                guideDestinationView(for: guide)
            }
            .onChange(of: showAskEptiChat) { _, isShowing in
                if !isShowing { pepChatSeedQuestion = nil }
            }
        }
    }

    // MARK: - Search bar (custom for full control over mic/clear)

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: recorder.isRecording ? "waveform" : "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(recorder.isRecording ? PepTheme.teal : PepTheme.textSecondary)
                    .symbolEffect(.variableColor.iterative, isActive: recorder.isRecording)

                TextField("Search exercises, foods, people…", text: $vm.query)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .focused($searchFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(PepTheme.textPrimary)
                    .onSubmit { vm.commitRecent() }

                if vm.isSearching && !vm.query.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .tint(PepTheme.teal)
                } else if !vm.query.isEmpty {
                    Button {
                        vm.query = ""
                        ask.cancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(PepTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    toggleVoice()
                } label: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(recorder.isRecording ? PepTheme.coral : PepTheme.teal)
                        .padding(.leading, 2)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: recorder.isRecording)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PepTheme.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(searchFieldFocused ? PepTheme.teal.opacity(0.35) : PepTheme.separatorColor, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.18), value: searchFieldFocused)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Scope picker

    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GlobalSearchScope.allCases) { scope in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            vm.scope = scope
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: scope.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(scope.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(vm.scope == scope ? PepTheme.invertedText : PepTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            ZStack {
                                if vm.scope == scope {
                                    Capsule().fill(PepTheme.textPrimary)
                                } else {
                                    Capsule().fill(PepTheme.elevated)
                                }
                            }
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(vm.scope == scope ? Color.clear : PepTheme.separatorColor, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: vm.scope)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Content router

    private var currentIntent: QueryIntent {
        QueryClassifier.classify(vm.query, hasResults: !vm.results.isEmpty)
    }

    @ViewBuilder
    private var content: some View {
        if vm.query.trimmingCharacters(in: .whitespaces).isEmpty {
            discoverySurface
        } else if vm.results.isEmpty && !vm.isSearching {
            noResultsWithAsk
        } else {
            resultsList
        }
    }

    // MARK: - Discovery surface

    private var discoverySurface: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Color.clear.frame(height: 0).id("top")
                quickActionsRow

                if !recents.isEmpty {
                    recentItemsSection
                }

                trendingSection

                suggestedSection

                if !vm.recents.isEmpty {
                    recentSearchesSection
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var quickActionsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Quick actions")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    quickActionButton(label: "Log meal", icon: "fork.knife", tint: PepSection.nutrition) {
                        triggerQuickAction(.logMeal)
                    }
                    quickActionButton(label: "Start workout", icon: "dumbbell.fill", tint: PepSection.training) {
                        triggerQuickAction(.startWorkout)
                    }
                    quickActionButton(label: "Log activity", icon: "figure.run", tint: PepTheme.blue) {
                        triggerQuickAction(.logActivity)
                    }
                    quickActionButton(label: "View steps", icon: "figure.walk", tint: PepTheme.violet) {
                        triggerQuickAction(.viewSteps)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func quickActionButton(label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(tint.opacity(0.14))
                    )
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .frame(width: 84, height: 84)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PepTheme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: showFoodLog)
    }

    private var recentItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("Recently viewed")
                Spacer()
                Button("Clear") {
                    RecentItemsStore.shared.clear()
                    recents = []
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.trailing, 16)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recents) { item in
                        Button {
                            handleTapRecent(item)
                        } label: {
                            recentItemCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func recentItemCard(_ item: RecentSearchItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tintForKind(item.kind).opacity(0.14))
                Image(systemName: iconForKind(item.kind))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tintForKind(item.kind))
            }
            .frame(width: 36, height: 36)

            Text(item.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(item.subtitle)
                .font(.system(size: 10))
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 130, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PepTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
        )
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(PepTheme.success)
                    .frame(width: 6, height: 6)
                Text("Trending now")
                    .font(.system(size: 12, weight: .heavy, design: .serif))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal, 16)

            FlowLayout(spacing: 8) {
                ForEach(TrendingSearches.today(), id: \.self) { term in
                    Button {
                        vm.query = term
                    } label: {
                        Text(term)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(PepTheme.cardSurface)
                            )
                            .overlay(
                                Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Suggested for you")
            VStack(spacing: 0) {
                ForEach(suggestedExercises.prefix(2)) { ex in
                    Button { handleTap(.exercise(ex)) } label: {
                        suggestionRow(
                            title: ex.name,
                            subtitle: "\(ex.primaryMuscle.rawValue) • \(ex.equipment.rawValue)",
                            icon: ex.primaryMuscle.icon,
                            tint: PepSection.training
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                }
                ForEach(suggestedCompounds.prefix(2)) { c in
                    Button { handleTap(.compound(c)) } label: {
                        suggestionRow(
                            title: c.name,
                            subtitle: c.peptideType,
                            icon: "pills.fill",
                            tint: PepSection.compound
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                }
                ForEach(suggestedFoods.prefix(2)) { f in
                    Button { handleTap(.food(f)) } label: {
                        suggestionRow(
                            title: f.name,
                            subtitle: "\(f.calories) cal • \(f.servingSize)",
                            icon: "fork.knife",
                            tint: PepSection.nutrition
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PepTheme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
        }
    }

    private func suggestionRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("Recent searches")
                Spacer()
                Button("Clear") { vm.clearRecents() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.trailing, 16)
            }
            FlowLayout(spacing: 8) {
                ForEach(vm.recents, id: \.self) { q in
                    Button {
                        vm.query = q
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(q)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(PepTheme.elevated))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if shouldShowAskCard {
                    askEptiCard(hero: currentIntent == .question)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .padding(.horizontal, 16)
                }

                keepExploringSection

                let grouped = Dictionary(grouping: vm.results, by: { $0.scope })
                let orderedScopes: [GlobalSearchScope] = [.guides, .exercises, .foods, .compounds, .users, .circles, .posts]

                ForEach(orderedScopes, id: \.self) { scope in
                    if let items = grouped[scope], !items.isEmpty {
                        scopeSection(scope: scope, items: items)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: shouldShowAskCard)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func scopeSection(scope: GlobalSearchScope, items: [GlobalSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: scope.icon)
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
                Text(scope.rawValue.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .serif))
                    .tracking(0.7)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, result in
                    Button { handleTap(result) } label: {
                        resultRow(result)
                    }
                    .buttonStyle(.plain)
                    if idx < items.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
                if vm.scope == .all && items.count >= 3 {
                    Divider().padding(.leading, 16)
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            vm.scope = scope
                        }
                    } label: {
                        HStack {
                            Text("See all in \(scope.rawValue)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PepTheme.teal)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PepTheme.teal)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PepTheme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func resultRow(_ r: GlobalSearchResult) -> some View {
        HStack(spacing: 12) {
            iconBadge(for: r)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HighlightedText(text: r.title, query: vm.query)
                rowSubtitle(for: r)
            }
            Spacer(minLength: 8)

            if loadingPostId != nil, case .post(let id, _, _, _, _) = r, loadingPostId == id {
                ProgressView().controlSize(.small).tint(PepTheme.teal)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func rowSubtitle(for r: GlobalSearchResult) -> some View {
        switch r {
        case .exercise(let e):
            HStack(spacing: 6) {
                metaChip(text: e.primaryMuscle.rawValue, tint: PepSection.training)
                Text(e.equipment.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        case .food(let f):
            HStack(spacing: 6) {
                metaChip(text: "\(f.calories) cal", tint: PepSection.nutrition)
                Text(f.brand.isEmpty ? f.servingSize : "\(f.brand) • \(f.servingSize)")
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }
        case .compound(let c):
            HStack(spacing: 6) {
                Circle().fill(PepSection.compound).frame(width: 5, height: 5)
                Text(c.peptideType)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        case .user(let u):
            Text("@\(u.username)")
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.textSecondary)
        case .circle(let c):
            HStack(spacing: 6) {
                if c.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(PepTheme.amber)
                }
                Text("\(c.memberCount) members")
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        case .post(_, _, _, let snippet, let createdAt):
            HStack(spacing: 6) {
                Text(RelativeTimeFormatter.short(from: createdAt))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textTertiary)
                Text(snippet)
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }
        case .guide(let g):
            HStack(spacing: 6) {
                metaChip(text: "GUIDE", tint: PepTheme.teal)
                Text(g.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func metaChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.3)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    @ViewBuilder
    private func iconBadge(for r: GlobalSearchResult) -> some View {
        switch r {
        case .user(let u):
            ProfileAvatarView(avatarUrl: u.avatarURL, initials: u.avatarInitial, avatarColor: u.avatarColor, size: 36)
        case .post(_, _, let author, _, _):
            ProfileAvatarView(avatarUrl: author.avatarURL, initials: author.avatarInitial, avatarColor: author.avatarColor, size: 36)
        case .circle(let c):
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(c.accentColor.opacity(0.95))
                Image(systemName: "person.3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            }
        default:
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tintFor(r).opacity(0.14))
                Image(systemName: r.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tintFor(r))
            }
        }
    }

    private func tintFor(_ r: GlobalSearchResult) -> Color {
        switch r {
        case .exercise: return PepSection.training
        case .food: return PepSection.nutrition
        case .compound: return PepSection.compound
        case .user: return PepSection.community
        case .circle: return PepSection.community
        case .post: return PepSection.community
        case .guide: return PepTheme.teal
        }
    }

    // MARK: - Keep exploring (smart follow-ups)

    /// One of these gets rendered for each follow-up suggestion that resolves to a real
    /// thing the user can tap straight into.
    private enum SmartEntity: Hashable {
        case exercise(Exercise)
        case food(FoodItem)
        case compound(CompoundProfile)
        case guide(GuideEntry)

        // Custom Hashable/Equatable via stable key so we don't depend on every
        // payload type conforming.
        static func == (lhs: SmartEntity, rhs: SmartEntity) -> Bool {
            lhs.key == rhs.key
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        var key: String {
            switch self {
            case .exercise(let e): return "ex-\(e.id)"
            case .food(let f): return "food-\(f.id.uuidString)"
            case .compound(let c): return "cmp-\(c.id.uuidString)"
            case .guide(let g): return "guide-\(g.id)"
            }
        }

        var title: String {
            switch self {
            case .exercise(let e): return e.name
            case .food(let f): return f.name
            case .compound(let c): return c.name
            case .guide(let g): return g.title
            }
        }

        var icon: String {
            switch self {
            case .exercise(let e): return e.primaryMuscle.icon
            case .food: return "fork.knife"
            case .compound: return "pills.fill"
            case .guide(let g): return g.icon
            }
        }

        var tint: Color {
            switch self {
            case .exercise: return PepSection.training
            case .food: return PepSection.nutrition
            case .compound: return PepSection.compound
            case .guide: return PepTheme.teal
            }
        }

        var tag: String {
            switch self {
            case .exercise: return "EXERCISE"
            case .food: return "FOOD"
            case .compound: return "COMPOUND"
            case .guide: return "GUIDE"
            }
        }

        var subtitle: String {
            switch self {
            case .exercise(let e): return "\(e.primaryMuscle.rawValue) · \(e.equipment.rawValue)"
            case .food(let f): return f.brand.isEmpty ? "\(f.calories) cal · \(f.servingSize)" : "\(f.brand) · \(f.calories) cal"
            case .compound(let c): return c.peptideType
            case .guide(let g): return g.subtitle
            }
        }
    }

    /// Show the section whenever Pep has answered with at least one follow-up, or when
    /// follow-ups are still loading after an answer has landed.
    private var shouldShowKeepExploring: Bool {
        guard currentIntent != .lookup else { return false }
        guard ask.lastError == nil else { return false }
        return !ask.followUps.isEmpty || (ask.isLoading && !ask.answer.isEmpty)
    }

    @ViewBuilder
    private var keepExploringSection: some View {
        if shouldShowKeepExploring {
            let resolved = resolveFollowUps(ask.followUps)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(PepTheme.teal)
                    Text("KEEP EXPLORING")
                        .font(.system(size: 11, weight: .heavy, design: .serif))
                        .tracking(0.9)
                        .foregroundStyle(PepTheme.textPrimary)
                }
                .padding(.horizontal, 16)

                if !resolved.entities.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(resolved.entities.enumerated()), id: \.element.key) { idx, entity in
                            Button {
                                handleSmartEntityTap(entity)
                            } label: {
                                smartEntityRow(entity)
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.impact(weight: .light), trigger: entity.key)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                            if idx < resolved.entities.count - 1 {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(PepTheme.cardSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                }

                if !resolved.chips.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(resolved.chips, id: \.self) { chip in
                            Button {
                                vm.query = chip
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(PepTheme.teal)
                                    Text(chip)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(PepTheme.cardSurface))
                                .overlay(
                                    Capsule().strokeBorder(PepTheme.teal.opacity(0.4), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.selection, trigger: vm.query)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if ask.isLoading && resolved.entities.isEmpty && resolved.chips.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule()
                                .fill(PepTheme.cardSurface)
                                .frame(width: 110, height: 32)
                                .overlay(
                                    Capsule().strokeBorder(PepTheme.separatorColor, lineWidth: 0.5)
                                )
                                .overlay(ShimmerLine().padding(.horizontal, 10))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func smartEntityRow(_ entity: SmartEntity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(entity.tint.opacity(0.14))
                Image(systemName: entity.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(entity.tint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entity.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(1)
                    Text(entity.tag)
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(entity.tint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(entity.tint.opacity(0.12)))
                }
                Text(entity.subtitle)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func handleSmartEntityTap(_ entity: SmartEntity) {
        switch entity {
        case .exercise(let e): handleTap(.exercise(e))
        case .food(let f): handleTap(.food(f))
        case .compound(let c): handleTap(.compound(c))
        case .guide(let g): handleTap(.guide(g))
        }
    }

    /// Resolve raw follow-up strings into entity cards (when they map cleanly onto a
    /// library item the user can open directly) and free-form chips (when they don't).
    /// Dedupes against anything already showing in the main results list.
    private func resolveFollowUps(_ raw: [String]) -> (entities: [SmartEntity], chips: [String]) {
        var entities: [SmartEntity] = []
        var chips: [String] = []
        var seenEntityKeys = Set<String>()
        let existingResultTitles: Set<String> = Set(vm.results.map { $0.title.lowercased() })

        for raw in raw {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()

            var matched: SmartEntity? = nil

            // Compound: prefer exact-name match, then substring.
            if matched == nil,
               let c = CompoundDatabase.all.first(where: { $0.name.lowercased() == lower })
                    ?? CompoundDatabase.all.first(where: { lower.contains($0.name.lowercased()) && $0.name.count >= 3 }) {
                matched = .compound(c)
            }

            // Guide: keyword/title contains.
            if matched == nil,
               let g = GuideLibrary.all.first(where: { entry in
                   entry.rankableStrings.contains(where: { phrase in
                       let p = phrase.lowercased()
                       guard p.count >= 4 else { return false }
                       return lower.contains(p) || p.contains(lower)
                   })
               }) {
                matched = .guide(g)
            }

            // Exercise: exact or word-boundary contains.
            if matched == nil,
               let ex = ExerciseLibrary.all.first(where: { $0.name.lowercased() == lower })
                    ?? ExerciseLibrary.all.first(where: { lower.contains($0.name.lowercased()) && $0.name.count >= 5 }) {
                matched = .exercise(ex)
            }

            // Food: only count if the food name is a substantial chunk of the query.
            if matched == nil,
               let f = FoodDatabase.allFoods.prefix(800).first(where: { food in
                   let n = food.name.lowercased()
                   guard n.count >= 6 else { return false }
                   return n == lower || lower.contains(n)
               }) {
                matched = .food(f)
            }

            if let entity = matched, entities.count < 3 {
                if !seenEntityKeys.contains(entity.key),
                   !existingResultTitles.contains(entity.title.lowercased()) {
                    entities.append(entity)
                    seenEntityKeys.insert(entity.key)
                    continue
                }
            }

            if chips.count < 4,
               !chips.contains(where: { $0.lowercased() == lower }),
               !existingResultTitles.contains(lower) {
                chips.append(trimmed)
            }
        }

        return (entities, chips)
    }

    // MARK: - AI Card

    private var shouldShowAskCard: Bool {
        guard currentIntent != .lookup else { return false }
        // Sticky: any question keeps the card visible (thinking, answered, or errored).
        return !ask.answer.isEmpty || ask.isLoading || ask.lastError != nil || !ask.query.isEmpty
    }

    @ViewBuilder
    private func askEptiCard(hero: Bool) -> some View {
        Button {
            pepChatSeedQuestion = ask.query.isEmpty ? vm.query : ask.query
            showAskEptiChat = true
        } label: {
            VStack(alignment: .leading, spacing: hero ? 14 : 10) {
                HStack(spacing: 8) {
                    PulsingDot()
                    Text("ASK PEP")
                        .font(.system(size: hero ? 12 : 11, weight: .heavy, design: .serif))
                        .tracking(0.9)
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    if ask.isLoading {
                        ProgressView().controlSize(.small).tint(PepTheme.teal)
                    } else {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                if ask.answer.isEmpty {
                    if ask.lastError != nil {
                        Text("Couldn't reach Pep right now — tap to open chat and try again.")
                            .font(.system(size: hero ? 16 : 13, design: .serif))
                            .foregroundStyle(PepTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        HStack(spacing: 8) {
                            Text("Thinking…")
                                .font(.system(size: hero ? 17 : 14, design: .serif))
                                .foregroundStyle(PepTheme.textSecondary)
                            ShimmerLine()
                        }
                    }
                } else {
                    Text(ask.answer)
                        .font(.system(size: hero ? 17 : 15, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineSpacing(hero ? 4 : 2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Continue in chat")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(PepTheme.teal)
            }
            .padding(hero ? 20 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: hero ? 22 : 18, style: .continuous)
                    .fill(PepTheme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: hero ? 22 : 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: hero
                                ? [PepTheme.teal.opacity(0.6), PepTheme.success.opacity(0.35), PepTheme.violet.opacity(0.25)]
                                : [PepTheme.teal.opacity(0.45), PepTheme.success.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: hero ? 1.25 : 1
                    )
            )
            .shadow(color: hero ? PepTheme.teal.opacity(0.18) : .clear, radius: hero ? 18 : 0, y: hero ? 8 : 0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: showAskEptiChat)
    }

    // MARK: - No results

    @ViewBuilder
    private var noResultsWithAsk: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if shouldShowAskCard {
                    askEptiCard(hero: true)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                keepExploringSection
                if !pepHasAnswered {
                    noResults
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: shouldShowAskCard)
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: ask.followUps)
            .animation(.easeOut(duration: 0.2), value: ask.answer.isEmpty)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// True once Pep has produced a real answer for the current query. Used to hide
    /// the "No results for…" empty state so the screen never feels like a dead end.
    private var pepHasAnswered: Bool {
        !ask.answer.isEmpty
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 32)
            Image(systemName: vm.scope.emptyIcon)
                .font(.system(size: 42))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            Text("No results for \"\(vm.query)\"")
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            if let suggestion = nearestSuggestion {
                Button {
                    vm.query = suggestion
                } label: {
                    Text("Did you mean ").foregroundStyle(PepTheme.textSecondary) +
                    Text("\(suggestion)?").foregroundStyle(PepTheme.teal).bold()
                }
                .font(.subheadline)
                .buttonStyle(.plain)
            } else {
                Text("Try a different keyword or switch scopes.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private var nearestSuggestion: String? {
        let q = vm.query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 3, q.count <= 40 else { return nil }
        // Bound the candidate pool tightly so this stays cheap and safe.
        var pool: [String] = []
        pool.append(contentsOf: TrendingSearches.today())
        pool.append(contentsOf: ExerciseLibrary.all.prefix(40).map(\.name))
        pool.append(contentsOf: CompoundDatabase.all.prefix(30).map(\.name))
        let qLower = q.lowercased()
        var best: (String, Int)? = nil
        for candidate in pool {
            guard candidate.lowercased() != qLower else { continue }
            let s = SearchRanker.score(query: q, candidates: [candidate])
            if s > 250, s > (best?.1 ?? 0) {
                best = (candidate, s)
            }
        }
        return best?.0
    }

    private var suggestedExercises: [Exercise] {
        Array(ExerciseLibrary.all.prefix(40).shuffled().prefix(2))
    }

    private var suggestedCompounds: [CompoundProfile] {
        Array(CompoundDatabase.all.prefix(40).shuffled().prefix(2))
    }

    private var suggestedFoods: [FoodItem] {
        Array(FoodDatabase.allFoods.prefix(40).shuffled().prefix(2))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .serif))
            .tracking(0.7)
            .foregroundStyle(PepTheme.textSecondary)
            .padding(.horizontal, 16)
    }

    private func iconForKind(_ kind: RecentItemKind) -> String {
        switch kind {
        case .exercise: return "dumbbell.fill"
        case .food: return "fork.knife"
        case .compound: return "pills.fill"
        case .user: return "person.crop.circle"
        case .circle: return "person.3.fill"
        }
    }

    private func tintForKind(_ kind: RecentItemKind) -> Color {
        switch kind {
        case .exercise: return PepSection.training
        case .food: return PepSection.nutrition
        case .compound: return PepSection.compound
        case .user, .circle: return PepSection.community
        }
    }

    // MARK: - Tap handlers

    private func handleTap(_ r: GlobalSearchResult) {
        vm.commitRecent()
        recordRecent(r)
        switch r {
        case .exercise(let e):
            selectedExercise = e
        case .compound(let c):
            selectedCompound = c
        case .user(let u):
            selectedUser = u
        case .food(let f):
            selectedFood = f
        case .circle(let c):
            circlesViewModel.selectCircle(c)
            selectedFitCircle = c
        case .post(let id, _, _, _, _):
            openPost(postId: id)
        case .guide(let g):
            selectedGuide = g
        }
    }

    @ViewBuilder
    private func guideDestinationView(for guide: GuideEntry) -> some View {
        switch guide.destination {
        case .beginnersGuideBasics:
            BeginnersGuideView(initialSection: .whatArePeptides)
        case .beginnersGuideReconstitution:
            BeginnersGuideView(initialSection: .reconstitution)
        case .beginnersGuideInjection:
            BeginnersGuideView(initialSection: .injection)
        case .beginnersGuideStorage:
            BeginnersGuideView(initialSection: .storage)
        case .beginnersGuideCOA:
            BeginnersGuideView(initialSection: .coas)
        case .reconstitutionCalculator:
            NavigationStack { ReconstitutionCalculatorView() }
        }
    }

    private func handleTapRecent(_ item: RecentSearchItem) {
        switch item.kind {
        case .exercise:
            if let ex = ExerciseLibrary.all.first(where: { $0.id == item.referenceId }) {
                selectedExercise = ex
            }
        case .compound:
            if let c = CompoundDatabase.all.first(where: { $0.id.uuidString == item.referenceId }) {
                selectedCompound = c
            }
        case .food:
            if let f = FoodDatabase.allFoods.first(where: { $0.id.uuidString == item.referenceId }) {
                selectedFood = f
            }
        case .user, .circle:
            // Backed by remote data — drop into search by title to re-find.
            vm.query = item.title
        }
    }

    private func recordRecent(_ r: GlobalSearchResult) {
        let item: RecentSearchItem? = {
            switch r {
            case .guide:
                return nil
            case .exercise(let e):
                return RecentSearchItem(kind: .exercise, referenceId: e.id, title: e.name, subtitle: e.primaryMuscle.rawValue, viewedAt: Date())
            case .compound(let c):
                return RecentSearchItem(kind: .compound, referenceId: c.id.uuidString, title: c.name, subtitle: c.peptideType, viewedAt: Date())
            case .food(let f):
                return RecentSearchItem(kind: .food, referenceId: f.id.uuidString, title: f.name, subtitle: "\(f.calories) cal", viewedAt: Date())
            case .user(let u):
                return RecentSearchItem(kind: .user, referenceId: u.id.uuidString, title: u.name, subtitle: "@\(u.username)", viewedAt: Date())
            case .circle(let c):
                return RecentSearchItem(kind: .circle, referenceId: c.id.uuidString, title: c.name, subtitle: "\(c.memberCount) members", viewedAt: Date())
            case .post:
                return nil
            }
        }()
        if let item {
            RecentItemsStore.shared.record(item)
            recents = RecentItemsStore.shared.load()
        }
    }

    private func openPost(postId: String) {
        guard loadingPostId == nil else { return }
        loadingPostId = postId
        Task {
            defer { loadingPostId = nil }
            if let sp = try? await SocialService.shared.fetchPost(postId: postId),
               let post = socialViewModel.buildFeedPost(from: sp) {
                selectedFeedPost = post
            }
        }
    }

    private func triggerQuickAction(_ action: LinkedTaskQuickAction) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(
                name: .linkedTaskQuickAction,
                object: nil,
                userInfo: ["action": action.label]
            )
        }
    }

    // MARK: - Voice

    private func toggleVoice() {
        if recorder.isRecording {
            Task {
                if let final = await recorder.stopRecordingAndTranscribe() {
                    vm.query = final
                }
            }
        } else {
            Task {
                let granted = await recorder.requestPermission()
                if !granted {
                    showVoicePermissionAlert = true
                    return
                }
                do {
                    try recorder.startRecording()
                } catch {
                    showVoicePermissionAlert = true
                }
            }
        }
    }
}

// MARK: - Food quick-log sheet

private struct FoodQuickLogSheet: View {
    let food: FoodItem
    @Environment(\.dismiss) private var dismiss
    @State private var servings: Double = 1.0
    @State private var mealTime: MealTime = defaultMealTime()
    private var nutritionVM: NutritionViewModel { NutritionViewModel.shared }

    private static func defaultMealTime() -> MealTime {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 10 { return .breakfast }
        if hour < 14 { return .lunch }
        if hour < 17 { return .snacks }
        return .dinner
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(PepSection.nutrition)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(PepSection.nutrition.opacity(0.14)))
                    Text(food.name)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    if !food.brand.isEmpty {
                        Text(food.brand)
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .padding(.top, 12)

                HStack(spacing: 12) {
                    macroPill(label: "CAL", value: "\(Int(Double(food.calories) * servings))", tint: PepSection.nutrition)
                    macroPill(label: "P", value: "\(Int(food.protein * servings))g", tint: PepSection.training)
                    macroPill(label: "C", value: "\(Int(food.carbs * servings))g", tint: PepTheme.amber)
                    macroPill(label: "F", value: "\(Int(food.fat * servings))g", tint: PepTheme.coral)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Servings (\(food.servingSize))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Stepper(value: $servings, in: 0.25...10, step: 0.25) {
                        Text(String(format: "%.2f", servings))
                            .font(.headline)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(PepTheme.elevated))

                Picker("Meal", selection: $mealTime) {
                    ForEach(MealTime.allCases, id: \.self) { time in
                        Text(time.rawValue).tag(time)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    nutritionVM.logMeal(food: food, servings: servings, mealTime: mealTime)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Log to \(mealTime.rawValue)")
                    }
                    .font(.headline)
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(PepTheme.textPrimary))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: false)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Quick log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func macroPill(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.10)))
    }
}

// MARK: - Pulsing dot + shimmer (used by Ask Pep card)

struct PulsingDot: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            Circle()
                .fill(PepTheme.success.opacity(0.35))
                .frame(width: 14, height: 14)
                .scaleEffect(animate ? 1.6 : 0.9)
                .opacity(animate ? 0 : 0.7)
            Circle()
                .fill(PepTheme.success)
                .frame(width: 7, height: 7)
        }
        .frame(width: 14, height: 14)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

struct ShimmerLine: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    PepTheme.textSecondary.opacity(0.0),
                    PepTheme.teal.opacity(0.55),
                    PepTheme.textSecondary.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width)
            .mask(
                Capsule()
                    .frame(height: 4)
            )
            .offset(x: phase * geo.size.width)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
    }
}

