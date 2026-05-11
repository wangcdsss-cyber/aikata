import Foundation

enum AvatarSync {
    static func updatedPosts(_ posts: [Post], userId: String, profileImageUrl: String) -> [Post] {
        guard !userId.isEmpty else { return posts }
        return posts.map { post in
            guard post.userId == userId else { return post }
            var next = post
            next.userProfileImageUrl = profileImageUrl
            return next
        }
    }

    static func updatedChatRooms(_ rooms: [ChatRoomSummary], userId: String, profileImageUrl: String) -> [ChatRoomSummary] {
        guard !userId.isEmpty else { return rooms }
        return rooms.map { room in
            guard room.memberImageUrls[userId] != nil else { return room }
            var next = room
            next.memberImageUrls[userId] = profileImageUrl
            return next
        }
    }
}
