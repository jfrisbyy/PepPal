import SwiftUI

struct FakeAccountSwitcherView: View {
    @State private var items: [FakeUserItem] = []
    @State private var isLoading: Bool = false
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false
    @State private var showCreateSheet: Bool = false
    @State private var workingUserId: String?

    private var stash = OriginalSessionStash.shared

    var body: some View {
        List {
            if FakeAccountService.shared.isImpersonating {
                Section {
                    impersonatingBanner
                }
            }

            Section {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("Create new fake account", systemImage: "person.crop.circle.badge.plus")
                }

                Button {
                    Task { await refresh() }
                } label: {
                    Label(isLoading ? "Refreshing…" : "Refresh list", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            } header: {
                Text("Actions")
            } footer: {
                Text("Fake accounts are real Supabase auth users tagged is_test_user=true. They can post, message, and log everything a real user can.")
            }

            if let msg = statusMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(statusIsError ? .red : .green)
                        Text(msg).font(.caption)
                    }
                }
            }

            Section("\(items.count) fake account\(items.count == 1 ? "" : "s")") {
                if items.isEmpty {
                    if isLoading {
                        HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) }
                    } else {
                        Text("No fake accounts yet. Create one above or run “Seed 25 fake personas”.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(items) { user in
                        userRow(user)
                    }
                }
            }
        }
        .navigationTitle("Fake Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .sheet(isPresented: $showCreateSheet) {
            CreateFakeAccountSheet { result in
                Task { await applyCreated(result) }
            }
            .presentationDetents([.medium])
        }
    }

    private var impersonatingBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "theatermasks.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Impersonating a fake account")
                        .font(.subheadline.weight(.semibold))
                    if let email = FakeAccountService.shared.stashedOriginalEmail {
                        Text("Your real account: \(email)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                Task { await switchBack() }
            } label: {
                Label("Switch back to my account", systemImage: "arrow.uturn.backward.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.vertical, 6)
    }

    private func userRow(_ user: FakeUserItem) -> some View {
        let isWorking = workingUserId == user.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: user.avatar_url ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color(.tertiarySystemFill)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(.circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.display_name ?? "Untitled")
                        .font(.subheadline.weight(.semibold))
                    if let handle = user.username {
                        Text("@\(handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isWorking { ProgressView().controlSize(.small) }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await switchTo(user) }
                } label: {
                    Label("Sign in as", systemImage: "arrow.right.circle.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isWorking)

                Button {
                    Task { await generateActivity(for: user) }
                } label: {
                    Label("Generate posts", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isWorking)

                Spacer()

                Button(role: .destructive) {
                    Task { await deleteUser(user) }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isWorking)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await FakeAccountService.shared.list()
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func switchTo(_ user: FakeUserItem) async {
        workingUserId = user.id
        defer { workingUserId = nil }
        do {
            try await FakeAccountService.shared.switchTo(userId: user.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            setStatus("Signed in as \(user.display_name ?? user.username ?? "fake user")", isError: false)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func switchBack() async {
        do {
            try await FakeAccountService.shared.switchBackToOriginal()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            setStatus("Back to your real account.", isError: false)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func generateActivity(for user: FakeUserItem) async {
        workingUserId = user.id
        defer { workingUserId = nil }
        do {
            let n = try await FakeAccountService.shared.generateActivity(userId: user.id, count: 3, daysBack: 7)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            setStatus("Inserted \(n) posts for \(user.display_name ?? user.username ?? "user").", isError: false)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func deleteUser(_ user: FakeUserItem) async {
        workingUserId = user.id
        defer { workingUserId = nil }
        do {
            try await FakeAccountService.shared.deleteFake(userId: user.id)
            items.removeAll { $0.id == user.id }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            setStatus("Deleted \(user.display_name ?? "fake user").", isError: false)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func applyCreated(_ res: FakeUserCreateResponse) async {
        if let err = res.error, !err.isEmpty {
            setStatus(err, isError: true)
            return
        }
        let label = res.display_name ?? res.username ?? "fake user"
        setStatus("Created \(label). Refreshing list…", isError: false)
        await refresh()
    }

    private func setStatus(_ msg: String, isError: Bool) {
        statusMessage = msg
        statusIsError = isError
    }
}

// MARK: - Create sheet

struct CreateFakeAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: (FakeUserCreateResponse) -> Void

    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var followCaller: Bool = true
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name (optional)", text: $displayName)
                        .textInputAutocapitalization(.words)
                    TextField("Username (optional)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Mutually follow my account", isOn: $followCaller)
                } footer: {
                    Text("Leave blank to randomize from the persona pool. Created accounts are full Supabase auth users — they can post, DM, and log just like a real one.")
                }

                if let resultMessage {
                    Section {
                        Text(resultMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await create() }
                    } label: {
                        HStack {
                            if isCreating { ProgressView().controlSize(.small) }
                            Text(isCreating ? "Creating…" : "Create fake account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isCreating)
                }
            }
            .navigationTitle("New fake account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            let res = try await FakeAccountService.shared.create(
                displayName: displayName,
                username: username,
                followCaller: followCaller
            )
            resultMessage = "Created \(res.display_name ?? res.username ?? "fake user")."
            onCreated(res)
            try? await Task.sleep(for: .milliseconds(450))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
