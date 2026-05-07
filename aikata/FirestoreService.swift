import Foundation
import FirebaseFirestore
import Combine

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var posts: [Post] = []
    @Published var isFetching = false
    @Published var isFetchingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String? = nil
    
    private var lastDocument: DocumentSnapshot? = nil
    private let pageSize = 35
    private let fetchTimeoutNanoseconds: UInt64 = 15_000_000_000
    
    // Fetch initial posts or pull-to-refresh
    @MainActor
    func fetchPosts(for gender: Gender, filter: PostFilter? = nil, currentUserId: String? = nil, isRefresh: Bool = false) async {
        guard !isFetching else { return }
        
        isFetching = true
        errorMessage = nil
        let timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.fetchTimeoutNanoseconds ?? 15_000_000_000)
            await MainActor.run {
                guard let self = self else { return }
                if self.isFetching {
                    self.errorMessage = "読み込みがタイムアウトしました。ネットワーク接続を確認して再試行してください。"
                    self.isFetching = false
                }
            }
        }
        defer {
            timeoutTask.cancel()
            isFetching = false
        }
        
        do {
            var query: Query = db.collection("posts")
                .whereField("gender", isEqualTo: gender.rawValue)
            
            if let filter = filter {
                if filter.onlyMyPosts, let userId = currentUserId {
                    query = query.whereField("userId", isEqualTo: userId)
                }
                if !filter.regions.isEmpty {
                    query = query.whereField("regions", arrayContainsAny: filter.regions)
                }
            }
            
            query = query.order(by: "createdAt", descending: true).limit(to: pageSize)
            
            let snapshot = try await query.getDocuments()
            
            var fetchedPosts = snapshot.documents.compactMap { document -> Post? in
                var post = try? document.data(as: Post.self)
                post?.id = document.documentID
                return post
            }
            
            // Client-side filtering for age to avoid complex composite indexes and preserve chronological order
            if let filter = filter {
                fetchedPosts = fetchedPosts.filter { post in
                    let age = post.userAge ?? 0
                    if age == 0 { return true } // Include if age is unknown, or adjust logic as needed
                    return age >= filter.minAge && age <= filter.maxAge
                }
            }
            
            self.posts = fetchedPosts
            self.lastDocument = snapshot.documents.last
            self.hasMore = snapshot.documents.count == pageSize
        } catch {
            print("🚨 Error fetching posts: \(error.localizedDescription)")
            self.errorMessage = "読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // Fetch more posts (Infinite scrolling)
    @MainActor
    func fetchMorePosts(for gender: Gender, filter: PostFilter? = nil, currentUserId: String? = nil) async {
        guard !isFetchingMore && hasMore, let lastDoc = lastDocument else { return }
        
        isFetchingMore = true
        defer { isFetchingMore = false }
        
        do {
            var query: Query = db.collection("posts")
                .whereField("gender", isEqualTo: gender.rawValue)
            
            if let filter = filter {
                if filter.onlyMyPosts, let userId = currentUserId {
                    query = query.whereField("userId", isEqualTo: userId)
                }
                if !filter.regions.isEmpty {
                    query = query.whereField("regions", arrayContainsAny: filter.regions)
                }
            }
            
            query = query.order(by: "createdAt", descending: true)
                .start(afterDocument: lastDoc)
                .limit(to: pageSize)
            
            let snapshot = try await query.getDocuments()
            
            var fetchedPosts = snapshot.documents.compactMap { document -> Post? in
                var post = try? document.data(as: Post.self)
                post?.id = document.documentID
                return post
            }
            
            if let filter = filter {
                fetchedPosts = fetchedPosts.filter { post in
                    let age = post.userAge ?? 0
                    if age == 0 { return true }
                    return age >= filter.minAge && age <= filter.maxAge
                }
            }
            
            // Deduplicate
            let existingIds = Set(self.posts.compactMap { $0.id })
            let uniqueNewPosts = fetchedPosts.filter { !existingIds.contains($0.id ?? "") }
            
            self.posts.append(contentsOf: uniqueNewPosts)
            self.lastDocument = snapshot.documents.last
            self.hasMore = snapshot.documents.count == pageSize
        } catch {
            print("🚨 Error fetching more posts: \(error.localizedDescription)")
        }
    }
    
    // Create a new post (Optimistic UI)
    @MainActor
    func createPost(regions: [String], content: String, user: AppUser) async throws {
        let tempId = UUID().uuidString
        var post = Post(
            id: tempId,
            userId: user.id ?? "unknown",
            userName: user.name,
            userAge: user.age,
            userJob: user.job,
            userProfileImageUrl: user.profileImageUrl,
            content: content,
            gender: user.gender,
            regions: regions,
            createdAt: Date()
        )
        
        // Optimistic UI Update
        self.posts.insert(post, at: 0)
        
        do {
            let docRef = db.collection("posts").document()
            post.id = docRef.documentID
            
            try docRef.setData(from: post)
            
            // Update temporary ID with real ID
            if let index = self.posts.firstIndex(where: { $0.id == tempId }) {
                self.posts[index] = post
            }
        } catch {
            // Revert on failure
            self.posts.removeAll { $0.id == tempId }
            throw error
        }
    }
    
    // Save user profile
    func saveUser(_ user: AppUser) async throws {
        guard let id = user.id else { return }
        try db.collection("users").document(id).setData(from: user)
    }

    // Fetch latest chat history for a room and return in chronological order
    func fetchMessages(chatRoomId: String, limit: Int = 20) async throws -> [Message] {
        let snapshot = try await db.collection("messages")
            .whereField("chatRoomId", isEqualTo: chatRoomId)
            .order(by: "createdAt", descending: false)
            .limit(toLast: limit)
            .getDocuments()

        let fetchedMessages: [Message] = snapshot.documents.compactMap { document in
            self.decodeMessage(document: document, fallbackChatRoomId: chatRoomId)
        }
        return fetchedMessages
    }

    func fetchOlderMessages(chatRoomId: String, before oldestDate: Date, limit: Int = 20) async throws -> [Message] {
        let snapshot = try await db.collection("messages")
            .whereField("chatRoomId", isEqualTo: chatRoomId)
            .order(by: "createdAt", descending: false)
            .end(before: [Timestamp(date: oldestDate)])
            .limit(toLast: limit)
            .getDocuments()

        let fetchedMessages: [Message] = snapshot.documents.compactMap { document in
            self.decodeMessage(document: document, fallbackChatRoomId: chatRoomId)
        }
        return fetchedMessages
    }

    func sendMessage(chatRoomId: String, senderId: String, receiverId: String, text: String) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let data: [String: Any] = [
            "chatRoomId": chatRoomId,
            "senderId": senderId,
            "receiverId": receiverId,
            "text": trimmedText,
            "createdAt": Timestamp(date: Date())
        ]

        try await db.collection("messages").document().setData(data)
    }

    func observeNewMessages(
        chatRoomId: String,
        after latestDate: Date?,
        onChange: @escaping (Result<[Message], Error>) -> Void
    ) -> ListenerRegistration {
        var query: Query = db.collection("messages")
            .whereField("chatRoomId", isEqualTo: chatRoomId)
            .order(by: "createdAt", descending: false)

        if let latestDate = latestDate {
            query = query.start(after: [Timestamp(date: latestDate)])
        }

        return query.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }

            guard let snapshot = snapshot, let self = self else {
                onChange(.success([]))
                return
            }

            let messages = snapshot.documents.compactMap { document in
                self.decodeMessage(document: document, fallbackChatRoomId: chatRoomId)
            }
            onChange(.success(messages))
        }
    }

    private func decodeMessage(document: DocumentSnapshot, fallbackChatRoomId: String) -> Message? {
        let data = document.data() ?? [:]

        guard
            let senderId = data["senderId"] as? String,
            let receiverId = data["receiverId"] as? String,
            let text = data["text"] as? String
        else {
            return nil
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let roomId = (data["chatRoomId"] as? String) ?? fallbackChatRoomId

        return Message(
            id: document.documentID,
            chatRoomId: roomId,
            senderId: senderId,
            receiverId: receiverId,
            text: text,
            createdAt: createdAt
        )
    }
    
    // Submit a report
    func submitReport(postId: String, reportedUserId: String, reporter: AppUser, reportType: String, description: String) async throws {
        let report = Report(
            postId: postId,
            reportedUserId: reportedUserId,
            reporterId: reporter.id ?? "unknown",
            reporterName: reporter.name,
            reportType: reportType,
            description: description,
            createdAt: Date()
        )
        
        let docRef = db.collection("report").document()
        var reportToSave = report
        reportToSave.id = docRef.documentID
        
        try docRef.setData(from: reportToSave)
    }
}
