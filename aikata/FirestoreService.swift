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
    
    // Fetch initial posts or pull-to-refresh
    @MainActor
    func fetchPosts(for gender: Gender, filter: PostFilter? = nil, currentUserId: String? = nil, isRefresh: Bool = false) async {
        guard !isFetching else { return }
        
        isFetching = true
        errorMessage = nil
        
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
            
            // Use TaskGroup to add a timeout for fetching in case simulator network is unreachable
            let snapshot = try await withThrowingTaskGroup(of: QuerySnapshot.self) { group in
                group.addTask {
                    return try await query.getDocuments()
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
                    throw NSError(domain: "NetworkTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "ネットワークに接続できません。通信環境を確認してください。"])
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            
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
            self.isFetching = false
        } catch {
            print("🚨 Error fetching posts: \(error.localizedDescription)")
            self.errorMessage = "読み込みに失敗しました: \(error.localizedDescription)"
            self.isFetching = false
        }
    }
    
    // Fetch more posts (Infinite scrolling)
    @MainActor
    func fetchMorePosts(for gender: Gender, filter: PostFilter? = nil, currentUserId: String? = nil) async {
        guard !isFetchingMore && hasMore, let lastDoc = lastDocument else { return }
        
        isFetchingMore = true
        
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
            
            let snapshot = try await withThrowingTaskGroup(of: QuerySnapshot.self) { group in
                group.addTask {
                    return try await query.getDocuments()
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    throw NSError(domain: "NetworkTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "ネットワークに接続できません。通信環境を確認してください。"])
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            
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
            self.isFetchingMore = false
        } catch {
            print("🚨 Error fetching more posts: \(error.localizedDescription)")
            self.isFetchingMore = false
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
    
    // MARK: - Chat Methods
    
    // Fetch initial chat messages (30 items)
    func fetchInitialMessages(chatRoomId: String) async throws -> [Message] {
        let query = db.collection("messages")
            .whereField("chatRoomId", isEqualTo: chatRoomId)
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
        
        let snapshot = try await query.getDocuments()
        let messages = snapshot.documents.compactMap { document -> Message? in
            var message = try? document.data(as: Message.self)
            message?.id = document.documentID
            return message
        }
        
        // Reverse to chronological order (oldest first, newest at bottom)
        return messages.reversed()
    }
    
    // Fetch older chat messages (Pagination)
    func fetchOlderMessages(chatRoomId: String, before timestamp: Date) async throws -> [Message] {
        let query = db.collection("messages")
            .whereField("chatRoomId", isEqualTo: chatRoomId)
            .order(by: "createdAt", descending: true)
            .start(after: [timestamp])
            .limit(to: 30)
        
        let snapshot = try await query.getDocuments()
        let messages = snapshot.documents.compactMap { document -> Message? in
            var message = try? document.data(as: Message.self)
            message?.id = document.documentID
            return message
        }
        
        return messages.reversed()
    }
    
    // Send a message
    func sendMessage(chatRoomId: String, senderId: String, receiverId: String, content: String) async throws -> Message {
        var message = Message(
            id: UUID().uuidString, // Temporary ID, will be replaced by Firestore ID
            chatRoomId: chatRoomId,
            senderId: senderId,
            receiverId: receiverId,
            content: content,
            createdAt: Date()
        )
        
        let docRef = db.collection("messages").document()
        message.id = docRef.documentID
        
        try docRef.setData(from: message)
        return message
    }
    
    // Listen for new messages (Real-time updates)
    func listenForNewMessages(chatRoomId: String, after timestamp: Date, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
        let query = db.collection("messages")
            .whereField("chatRoomId", isEqualTo: chatRoomId)
            .order(by: "createdAt", descending: true)
            .end(before: [timestamp]) // Fetch only messages newer than the given timestamp
        
        return query.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                print("Error listening for new messages: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            var newMessages: [Message] = []
            for change in snapshot.documentChanges {
                if change.type == .added {
                    if var message = try? change.document.data(as: Message.self) {
                        message.id = change.document.documentID
                        newMessages.append(message)
                    }
                }
            }
            
            if !newMessages.isEmpty {
                // Reverse to chronological order
                completion(newMessages.reversed())
            }
        }
    }
}
