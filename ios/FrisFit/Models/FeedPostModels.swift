import SwiftUI

nonisolated enum FeedFilter: String, CaseIterable, Sendable {
    case all = "All"
    case following = "Following"
    case tags = "Tags"
}

nonisolated enum FeedTag: String, CaseIterable, Identifiable, Sendable {
    case bpc157 = "BPC-157"
    case tb500 = "TB-500"
    case glp1 = "GLP-1"
    case growthHormone = "Growth Hormone"
    case bloodwork = "Bloodwork"
    case vendors = "Vendors"
    case reconstitution = "Reconstitution"
    case sideEffects = "Side Effects"
    case healing = "Healing"
    case cognitive = "Cognitive"
    case tanning = "Tanning"
    case basketball = "Basketball"
    case running = "Running"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case soccer = "Soccer"
    case tennis = "Tennis"
    case bodybuilding = "Bodybuilding"
    case progress = "Progress"
    case nutrition = "Nutrition"
    case prAlert = "PR Alert"
    case motivation = "Motivation"
    case program = "Program"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bpc157: return "cross.case.fill"
        case .tb500: return "bandage.fill"
        case .glp1: return "scalemass.fill"
        case .growthHormone: return "arrow.up.right"
        case .bloodwork: return "drop.fill"
        case .vendors: return "building.2.fill"
        case .reconstitution: return "flask.fill"
        case .sideEffects: return "exclamationmark.triangle.fill"
        case .healing: return "heart.fill"
        case .cognitive: return "brain.head.profile"
        case .tanning: return "sun.max.fill"
        case .basketball: return "basketball.fill"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .soccer: return "soccerball"
        case .tennis: return "tennis.racket"
        case .bodybuilding: return "figure.strengthtraining.traditional"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .nutrition: return "fork.knife"
        case .prAlert: return "trophy.fill"
        case .motivation: return "flame.fill"
        case .program: return "list.clipboard.fill"
        }
    }
}

nonisolated enum TagCategory: String, CaseIterable, Identifiable, Sendable {
    case peptides = "Peptides"
    case sports = "Sports"
    case research = "Research"
    case fitness = "Fitness"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .peptides: return "syringe.fill"
        case .sports: return "sportscourt.fill"
        case .research: return "flask.fill"
        case .fitness: return "dumbbell.fill"
        }
    }

    var tags: [FeedTag] {
        switch self {
        case .peptides:
            return [.bpc157, .tb500, .glp1, .growthHormone, .healing, .cognitive, .tanning]
        case .sports:
            return [.basketball, .running, .cycling, .swimming, .soccer, .tennis]
        case .research:
            return [.bloodwork, .vendors, .reconstitution, .sideEffects]
        case .fitness:
            return [.bodybuilding, .progress, .nutrition, .prAlert, .motivation, .program]
        }
    }
}

nonisolated enum FeedPostMediaType: String, Sendable {
    case text
    case photo
    case video
    case voice
    case marketLink
    case workoutLog
    case poll
}

nonisolated struct FeedMediaItem: Identifiable, Sendable {
    let id: UUID
    let type: FeedPostMediaType
    let imageURL: String?
    let videoURL: String?
    let voiceDuration: TimeInterval?
    let marketProgram: MarketProgram?
    let workoutLog: WorkoutLogAttachment?
    let poll: CommunityPoll?

    init(
        id: UUID = UUID(),
        type: FeedPostMediaType,
        imageURL: String? = nil,
        videoURL: String? = nil,
        voiceDuration: TimeInterval? = nil,
        marketProgram: MarketProgram? = nil,
        workoutLog: WorkoutLogAttachment? = nil,
        poll: CommunityPoll? = nil
    ) {
        self.id = id
        self.type = type
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.voiceDuration = voiceDuration
        self.marketProgram = marketProgram
        self.workoutLog = workoutLog
        self.poll = poll
    }
}

nonisolated struct WorkoutLogAttachment: Sendable {
    let workoutName: String
    let duration: Int
    let exerciseCount: Int
    let totalVolume: Int
    let fpEarned: Int
    let date: Date
}

nonisolated struct FeedPost: Identifiable, Hashable, Sendable {
    nonisolated static func == (lhs: FeedPost, rhs: FeedPost) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    let user: SocialUser
    let timestamp: Date
    let textContent: String
    let media: [FeedMediaItem]
    var highFiveCount: Int
    var isHighFived: Bool
    var comments: [PostComment]
    var repostCount: Int
    var isReposted: Bool

    let tags: [FeedTag]
    let isFollowing: Bool
    let supabaseId: String?

    init(
        id: UUID = UUID(),
        user: SocialUser,
        timestamp: Date = Date(),
        textContent: String = "",
        media: [FeedMediaItem] = [],
        highFiveCount: Int = 0,
        isHighFived: Bool = false,
        comments: [PostComment] = [],
        repostCount: Int = 0,
        isReposted: Bool = false,
        tags: [FeedTag] = [],
        isFollowing: Bool = false,
        supabaseId: String? = nil
    ) {
        self.id = id
        self.user = user
        self.timestamp = timestamp
        self.textContent = textContent
        self.media = media
        self.highFiveCount = highFiveCount
        self.isHighFived = isHighFived
        self.comments = comments
        self.repostCount = repostCount
        self.isReposted = isReposted
        self.tags = tags
        self.isFollowing = isFollowing
        self.supabaseId = supabaseId
    }

    var hasMedia: Bool { !media.isEmpty }
    var photoMedia: [FeedMediaItem] { media.filter { $0.type == .photo } }
    var videoMedia: [FeedMediaItem] { media.filter { $0.type == .video } }
    var voiceMedia: FeedMediaItem? { media.first { $0.type == .voice } }
    var marketLink: FeedMediaItem? { media.first { $0.type == .marketLink } }
    var workoutAttachment: FeedMediaItem? { media.first { $0.type == .workoutLog } }
    var pollAttachment: FeedMediaItem? { media.first { $0.type == .poll } }
}
