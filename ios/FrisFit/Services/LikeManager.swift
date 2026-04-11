import SwiftUI

@Observable
final class LikeManager {
    static let shared = LikeManager()

    private(set) var likedPostIds: Set<String> = []
    private(set) var likeCounts: [String: Int] = [:]

    private let socialService = SocialService.shared

    private init() {}

    func isLiked(postId: String) -> Bool {
        likedPostIds.contains(postId)
    }

    func likeCount(postId: String, fallback: Int = 0) -> Int {
        likeCounts[postId] ?? fallback
    }

    func setInitialState(postId: String, isLiked: Bool, count: Int) {
        if isLiked {
            likedPostIds.insert(postId)
        } else {
            likedPostIds.remove(postId)
        }
        likeCounts[postId] = count
    }

    func bulkSetState(likedIds: Set<String>, counts: [String: Int]) {
        for id in likedIds {
            likedPostIds.insert(id)
        }
        for (id, count) in counts {
            likeCounts[id] = count
        }
    }

    func toggleLike(postId: String) {
        let wasLiked = likedPostIds.contains(postId)
        let currentCount = likeCounts[postId] ?? 0

        if wasLiked {
            likedPostIds.remove(postId)
            likeCounts[postId] = max(0, currentCount - 1)
        } else {
            likedPostIds.insert(postId)
            likeCounts[postId] = currentCount + 1
        }

        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                if wasLiked {
                    try await socialService.unlikePost(postId: postId, userId: userId)
                } else {
                    try await socialService.likePost(postId: postId, userId: userId)
                }
            } catch {
                if wasLiked {
                    likedPostIds.insert(postId)
                    likeCounts[postId] = currentCount
                } else {
                    likedPostIds.remove(postId)
                    likeCounts[postId] = currentCount
                }
            }
        }
    }
}
