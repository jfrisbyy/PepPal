import SwiftUI

@Observable
final class MessagesViewModel {
    var conversations: [Conversation] = []
    var searchQuery: String = ""
    var searchResults: [SocialUser] = []
    var isSearching: Bool = false

    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var filteredConversations: [Conversation] {
        if searchQuery.isEmpty { return conversations }
        return conversations.filter {
            $0.participant.name.localizedStandardContains(searchQuery) ||
            $0.participant.username.localizedStandardContains(searchQuery)
        }
    }

    private let allUsers: [SocialUser] = [
        SocialUser(id: UUID(), name: "Alex Martinez", username: "alexm_fit", avatarInitial: "A", avatarColor: Color(red: 0.2, green: 0.6, blue: 0.9), activeProgramName: "Push Pull Legs", streak: 14, totalFP: 8420),
        SocialUser(id: UUID(), name: "Jordan Kim", username: "jkim_lifts", avatarInitial: "J", avatarColor: Color(red: 0.9, green: 0.4, blue: 0.3), activeProgramName: "Upper Lower", streak: 21, totalFP: 12350),
        SocialUser(id: UUID(), name: "Sam Taylor", username: "samtaylor", avatarInitial: "S", avatarColor: Color(red: 0.4, green: 0.8, blue: 0.5), activeProgramName: nil, streak: 7, totalFP: 5680),
        SocialUser(id: UUID(), name: "Riley Chen", username: "rileyc", avatarInitial: "R", avatarColor: Color(red: 0.8, green: 0.5, blue: 0.9), activeProgramName: "5/3/1", streak: 45, totalFP: 18900),
        SocialUser(id: UUID(), name: "Casey Nguyen", username: "casey_ng", avatarInitial: "C", avatarColor: Color(red: 0.9, green: 0.7, blue: 0.2), activeProgramName: "GZCLP", streak: 10, totalFP: 6750),
        SocialUser(id: UUID(), name: "Morgan Davis", username: "morgfit", avatarInitial: "M", avatarColor: Color(red: 0.3, green: 0.7, blue: 0.8), activeProgramName: "Full Body 3x", streak: 33, totalFP: 15200),
        SocialUser(id: UUID(), name: "Taylor Swift", username: "tswift_gym", avatarInitial: "T", avatarColor: .pink, activeProgramName: nil, streak: 3, totalFP: 1200),
        SocialUser(id: UUID(), name: "Chris Evans", username: "capfit", avatarInitial: "C", avatarColor: .blue, activeProgramName: "Superhero Split", streak: 60, totalFP: 25000),
        SocialUser(id: UUID(), name: "Jamie Lee", username: "jamielifts", avatarInitial: "J", avatarColor: .orange, activeProgramName: "Starting Strength", streak: 8, totalFP: 3400),
    ]

    private let myID = UUID()

    init() {
        loadMockConversations()
    }

    func searchUsers(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        let conversationUserIDs = Set(conversations.map { $0.participant.id })
        searchResults = allUsers.filter {
            !conversationUserIDs.contains($0.id) &&
            ($0.name.localizedStandardContains(query) || $0.username.localizedStandardContains(query))
        }
        isSearching = false
    }

    func sendMessage(to conversationID: UUID, text: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let message = DirectMessage(senderID: myID, text: text, timestamp: Date(), isRead: true)
        conversations[index].messages.append(message)
    }

    func startConversation(with user: SocialUser) -> UUID {
        if let existing = conversations.first(where: { $0.participant.id == user.id }) {
            return existing.id
        }
        let conversation = Conversation(participant: user)
        conversations.insert(conversation, at: 0)
        return conversation.id
    }

    func markAsRead(conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        for i in conversations[index].messages.indices {
            if conversations[index].messages[i].senderID == conversations[index].participant.id {
                conversations[index].messages[i].isRead = true
            }
        }
    }

    func conversation(for id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    private func loadMockConversations() {
        let now = Date()
        conversations = [
            Conversation(
                participant: allUsers[0],
                messages: [
                    DirectMessage(senderID: allUsers[0].id, text: "Hey! Nice PR on bench today 💪", timestamp: now.addingTimeInterval(-3600), isRead: true),
                    DirectMessage(senderID: myID, text: "Thanks! Finally hit 225", timestamp: now.addingTimeInterval(-3500), isRead: true),
                    DirectMessage(senderID: allUsers[0].id, text: "That's insane, we should train together sometime", timestamp: now.addingTimeInterval(-1800), isRead: false),
                ]
            ),
            Conversation(
                participant: allUsers[1],
                messages: [
                    DirectMessage(senderID: myID, text: "What program are you running rn?", timestamp: now.addingTimeInterval(-86400), isRead: true),
                    DirectMessage(senderID: allUsers[1].id, text: "Upper lower split, 4 days a week. Loving it so far", timestamp: now.addingTimeInterval(-82800), isRead: true),
                    DirectMessage(senderID: allUsers[1].id, text: "Want me to share the template?", timestamp: now.addingTimeInterval(-82000), isRead: false),
                ]
            ),
            Conversation(
                participant: allUsers[3],
                messages: [
                    DirectMessage(senderID: allUsers[3].id, text: "Squat day tomorrow, you in?", timestamp: now.addingTimeInterval(-7200), isRead: false),
                ]
            ),
            Conversation(
                participant: allUsers[5],
                messages: [
                    DirectMessage(senderID: myID, text: "Good session today!", timestamp: now.addingTimeInterval(-172800), isRead: true),
                    DirectMessage(senderID: allUsers[5].id, text: "For sure! Let's keep the streak going 🔥", timestamp: now.addingTimeInterval(-170000), isRead: true),
                ]
            ),
        ]
    }
}
