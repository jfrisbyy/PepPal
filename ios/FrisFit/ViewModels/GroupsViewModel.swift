import SwiftUI
import Supabase

@Observable
@MainActor
final class GroupsViewModel {
    var myGroups: [FitGroup] = []
    var discoverGroups: [FitGroup] = []
    var searchQuery: String = ""
    var isSearching: Bool = false
    var isLoading: Bool = false
    var loadError: String?
    var pendingRequestGroupIDs: Set<UUID> = []

    var filteredMyGroups: [FitGroup] {
        if searchQuery.isEmpty { return myGroups }
        return myGroups.filter {
            $0.name.localizedStandardContains(searchQuery) ||
            $0.description.localizedStandardContains(searchQuery)
        }
    }

    var filteredDiscoverGroups: [FitGroup] {
        if searchQuery.isEmpty { return discoverGroups }
        return discoverGroups.filter {
            $0.name.localizedStandardContains(searchQuery) ||
            $0.description.localizedStandardContains(searchQuery)
        }
    }

    init() {
        Task { await self.refresh() }
    }

    var uploadingAttachment: Bool = false

    private var currentUserId: String? {
        try? AuthService.shared.currentUserId()
    }

    private func meSocialUser() async -> SocialUser {
        guard let uid = currentUserId else {
            return SocialUser(id: UUID(), name: "You", username: "me", avatarInitial: "Y", avatarColor: PepTheme.teal, activeProgramName: nil, streak: 0)
        }
        if let profile = try? await MessagingService.shared.fetchProfile(userId: uid) {
            return SocialService.shared.socialUserFromAuthor(profile)
        }
        return SocialUser(id: UUID(uuidString: uid) ?? UUID(), name: "You", username: "me", avatarInitial: "Y", avatarColor: PepTheme.teal, activeProgramName: nil, streak: 0)
    }

    // MARK: - Load

    func refresh() async {
        guard let uid = currentUserId else {
            myGroups = []
            discoverGroups = []
            return
        }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            async let mineTask = GroupsService.shared.fetchMyGroups(userId: uid)
            let mine = try await mineTask
            let myIds = Set(mine.map { $0.id.uuidString.lowercased() })
            let discover = (try? await GroupsService.shared.fetchPublicGroups(userId: uid, excludingMyIds: myIds)) ?? []
            myGroups = mine
            discoverGroups = discover
        } catch {
            loadError = "Couldn't load groups. Pull to retry."
            print("GroupsViewModel.refresh error: \(error)")
        }
    }

    // MARK: - Messages

    func sendMessage(to groupID: UUID, text: String, attachments: [DirectMessageAttachment] = []) {
        guard let uid = currentUserId else { return }
        let gid = groupID.uuidString.lowercased()
        Task {
            let me = await self.meSocialUser()
            let optimistic = GroupMessage(sender: me, text: text, attachments: attachments)
            if let index = myGroups.firstIndex(where: { $0.id == groupID }) {
                myGroups[index].messages.append(optimistic)
            }
            do {
                _ = try await GroupsService.shared.sendMessage(groupId: gid, senderId: uid, text: text, attachments: attachments)
            } catch {
                print("Group send failed: \(error)")
            }
        }
    }

    func sendImage(to groupID: UUID, data: Data) async {
        guard currentUserId != nil else { return }
        let gid = groupID.uuidString.lowercased()
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        do {
            let att = try await GroupsService.shared.uploadGroupImage(data: data, groupId: gid)
            sendMessage(to: groupID, text: "", attachments: [att])
        } catch {
            print("Group image upload failed: \(error)")
        }
    }

    func sendVideo(to groupID: UUID, data: Data, duration: Double?) async {
        let gid = groupID.uuidString.lowercased()
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        do {
            let att = try await GroupsService.shared.uploadGroupVideo(data: data, groupId: gid, durationSeconds: duration)
            sendMessage(to: groupID, text: "", attachments: [att])
        } catch {
            print("Group video upload failed: \(error)")
        }
    }

    func sendVoice(to groupID: UUID, data: Data, duration: Double?) async {
        let gid = groupID.uuidString.lowercased()
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        do {
            let att = try await GroupsService.shared.uploadGroupVoice(data: data, groupId: gid, durationSeconds: duration)
            sendMessage(to: groupID, text: "", attachments: [att])
        } catch {
            print("Group voice upload failed: \(error)")
        }
    }

    func toggleMessageLike(groupID: UUID, messageID: UUID) {
        guard let gIndex = myGroups.firstIndex(where: { $0.id == groupID }),
              let mIndex = myGroups[gIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        myGroups[gIndex].messages[mIndex].isLiked.toggle()
        myGroups[gIndex].messages[mIndex].likeCount += myGroups[gIndex].messages[mIndex].isLiked ? 1 : -1
        // TODO: persist like via group_message_likes table
    }

    // MARK: - Membership

    func joinGroup(_ group: FitGroup) {
        guard let uid = currentUserId else { return }
        let gid = group.id.uuidString.lowercased()
        if group.privacy == .privateGroup {
            pendingRequestGroupIDs.insert(group.id)
            sendJoinRequestNotification(for: group)
        } else {
            Task {
                do {
                    try await GroupsService.shared.joinGroup(groupId: gid, userId: uid)
                    await self.refresh()
                } catch {
                    print("Group join failed: \(error)")
                }
            }
        }
    }

    func isRequestPending(for groupID: UUID) -> Bool {
        pendingRequestGroupIDs.contains(groupID)
    }

    private func sendJoinRequestNotification(for group: FitGroup) {
        Task {
            do {
                let _ = try AuthService.shared.currentUserId()
                let payload = CreateGroupJoinRequestNotification(
                    user_id: group.creatorID.uuidString.lowercased(),
                    type: "group_join_request",
                    title: "Group Join Request",
                    body: "Someone has requested to join \(group.name)"
                )
                try await SupabaseService.shared.client
                    .from("notifications")
                    .insert(payload)
                    .execute()
            } catch {}
        }
    }

    func updateStatsConfig(groupID: UUID, config: GroupStatsConfig) {
        guard let index = myGroups.firstIndex(where: { $0.id == groupID }) else { return }
        myGroups[index].statsConfig = config
    }

    func toggleStatsEnabled(groupID: UUID) {
        guard let index = myGroups.firstIndex(where: { $0.id == groupID }) else { return }
        myGroups[index].statsConfig.isEnabled.toggle()
        if myGroups[index].statsConfig.isEnabled && myGroups[index].statsConfig.enabledMetrics.isEmpty {
            myGroups[index].statsConfig.enabledMetrics = [.steps, .workouts]
        }
    }

    func toggleStatsMetric(groupID: UUID, metric: GroupStatMetric) {
        guard let index = myGroups.firstIndex(where: { $0.id == groupID }) else { return }
        if myGroups[index].statsConfig.enabledMetrics.contains(metric) {
            myGroups[index].statsConfig.enabledMetrics.remove(metric)
        } else {
            myGroups[index].statsConfig.enabledMetrics.insert(metric)
        }
    }

    func setStatsPeriod(groupID: UUID, period: GroupStatsPeriod) {
        guard let index = myGroups.firstIndex(where: { $0.id == groupID }) else { return }
        myGroups[index].statsConfig.period = period
    }

    func toggleMyStatsSharing(groupID: UUID) {
        guard let uid = currentUserId else { return }
        guard let gIndex = myGroups.firstIndex(where: { $0.id == groupID }),
              let mIndex = myGroups[gIndex].members.firstIndex(where: { $0.user.id.uuidString.lowercased() == uid }) else { return }
        myGroups[gIndex].members[mIndex].isSharingStats.toggle()
    }

    func isCurrentUserAdmin(groupID: UUID) -> Bool {
        guard let uid = currentUserId else { return false }
        guard let group = myGroups.first(where: { $0.id == groupID }),
              let member = group.members.first(where: { $0.user.id.uuidString.lowercased() == uid }) else { return false }
        return member.role == .owner || member.role == .admin
    }

    func leaveGroup(_ groupID: UUID) {
        guard let uid = currentUserId else { return }
        let gid = groupID.uuidString.lowercased()
        myGroups.removeAll { $0.id == groupID }
        Task {
            do {
                try await GroupsService.shared.leaveGroup(groupId: gid, userId: uid)
                await self.refresh()
            } catch {
                print("Leave group failed: \(error)")
            }
        }
    }

    func createGroup(name: String, description: String, privacy: GroupPrivacy, iconName: String, accentColor: Color) {
        guard let uid = currentUserId else { return }
        let hex = colorToHex(accentColor)
        Task {
            do {
                let created = try await GroupsService.shared.createGroup(
                    creatorId: uid,
                    name: name,
                    description: description,
                    privacy: privacy,
                    accentColorHex: hex,
                    iconName: iconName
                )
                myGroups.insert(created, at: 0)
            } catch {
                print("Group create failed: \(error)")
                loadError = "Couldn't create group. Try again."
            }
        }
    }

    func group(for id: UUID) -> FitGroup? {
        myGroups.first { $0.id == id }
    }

    private func colorToHex(_ color: Color) -> String {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(r * 255)), gi = Int(round(g * 255)), bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
        #else
        return "#5AC8B0"
        #endif
    }
}
