import SwiftUI

nonisolated struct CommunityPoll: Identifiable, Sendable {
    let id: UUID
    let question: String
    let options: [PollOption]
    let createdAt: Date
    let expiresAt: Date?
    var totalVotes: Int
    var userVotedOptionId: UUID?
    let isAnonymous: Bool
    let tags: [FeedTag]

    init(
        question: String,
        options: [PollOption],
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        totalVotes: Int = 0,
        userVotedOptionId: UUID? = nil,
        isAnonymous: Bool = true,
        tags: [FeedTag] = []
    ) {
        self.id = UUID()
        self.question = question
        self.options = options
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.totalVotes = totalVotes
        self.userVotedOptionId = userVotedOptionId
        self.isAnonymous = isAnonymous
        self.tags = tags
    }
}

nonisolated struct PollOption: Identifiable, Sendable {
    let id: UUID
    let text: String
    var voteCount: Int

    init(text: String, voteCount: Int = 0) {
        self.id = UUID()
        self.text = text
        self.voteCount = voteCount
    }

    var percentage: Double {
        0
    }
}

nonisolated struct PeptideProgressPhoto: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let imageData: Data?
    let isShared: Bool
    let notes: String

    init(date: Date = Date(), imageData: Data? = nil, isShared: Bool = false, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.imageData = imageData
        self.isShared = isShared
        self.notes = notes
    }
}
