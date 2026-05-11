import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine
import UIKit

struct ChatRoomPage {
    var rooms: [ChatRoomSummary]
    var lastDocument: DocumentSnapshot?
    var hasMore: Bool
}

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
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

    func observePosts(
        for gender: Gender,
        filter: PostFilter? = nil,
        currentUserId: String? = nil,
        limit: Int = 50,
        onChange: @escaping (Result<[Post], Error>) -> Void
    ) -> ListenerRegistration {
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

        query = query.order(by: "createdAt", descending: true).limit(to: limit)

        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }
            guard let snapshot = snapshot else {
                onChange(.success([]))
                return
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
            onChange(.success(fetchedPosts))
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

    func uploadProfileImage(userId: String, image: UIImage) async throws -> String {
        guard let data = ChatImageCompressor.compressForUpload(image) else {
            throw NSError(domain: "ProfileImage", code: 2001, userInfo: [NSLocalizedDescriptionKey: "プロフィール画像の圧縮に失敗しました。"])
        }
        let path = "profile_images/\(userId)/\(UUID().uuidString).jpg"
        let uploaded = try await uploadImageDataWithRetry(data: data, path: path, retryCount: 2)
        if uploaded.hasPrefix("storage://") {
            let ref = storage.reference().child(path)
            let url = try await downloadURLWithRetry(ref: ref, retryCount: 3)
            return url.absoluteString
        }
        return uploaded
    }

    func saveUserProfile(
        userId: String,
        profileImageURL: String?,
        mbti: String,
        workLocation: String,
        occupation: String,
        selfIntroduction: String,
        education: String,
        height: String,
        bodyType: String,
        annualIncome: String,
        birthplace: String,
        frequentDrinkingArea: String
    ) async throws {
        let introTrimmed = selfIntroduction.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard introTrimmed.count <= 500 else {
            throw NSError(domain: "ProfileValidation", code: 2002, userInfo: [NSLocalizedDescriptionKey: "自己紹介は500文字以内で入力してください。"])
        }

        let data: [String: Any] = [
            "profileImage": profileImageURL ?? "",
            "mbti": mbti,
            "workLocation": workLocation,
            "occupation": occupation,
            "updatedAt": Timestamp(date: Date()),
            "userId": userId,
            "selfIntroduction": introTrimmed,
            "education": education,
            "height": height,
            "bodyType": bodyType,
            "annualIncome": annualIncome,
            "birthplace": birthplace,
            "frequentDrinkingArea": frequentDrinkingArea
        ]
        try await db.collection("users").document(userId).setData(data, merge: true)
    }

    func propagateProfileImageUpdate(userId: String, profileImageURL: String) async throws {
        try await updatePostProfileImages(userId: userId, profileImageURL: profileImageURL)
        try await updateChatRoomProfileImages(userId: userId, profileImageURL: profileImageURL)
    }

    private func updatePostProfileImages(userId: String, profileImageURL: String) async throws {
        var lastDoc: DocumentSnapshot?
        while true {
            var query = db.collection("posts")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 400)
            if let lastDoc {
                query = query.start(afterDocument: lastDoc)
            }
            let snapshot = try await query.getDocuments()
            if snapshot.documents.isEmpty { break }
            let batch = db.batch()
            snapshot.documents.forEach { doc in
                batch.updateData(["userProfileImageUrl": profileImageURL], forDocument: doc.reference)
            }
            try await batch.commit()
            lastDoc = snapshot.documents.last
            if snapshot.documents.count < 400 { break }
        }
    }

    private func updateChatRoomProfileImages(userId: String, profileImageURL: String) async throws {
        let snapshot = try await db.collection("chatRooms")
            .whereField("members", arrayContains: userId)
            .getDocuments()
        if snapshot.documents.isEmpty { return }

        var startIndex = 0
        let docs = snapshot.documents
        while startIndex < docs.count {
            let endIndex = min(startIndex + 400, docs.count)
            let batch = db.batch()
            for i in startIndex..<endIndex {
                let ref = docs[i].reference
                let path = FieldPath(["memberImageUrls", userId])
                batch.updateData([path: profileImageURL], forDocument: ref)
            }
            try await batch.commit()
            startIndex = endIndex
        }
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

    func sendMessage(
        chatRoomId: String,
        senderId: String,
        receiverId: String,
        text: String,
        senderName: String? = nil,
        senderImageUrl: String? = nil,
        receiverName: String? = nil,
        receiverImageUrl: String? = nil
    ) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let data: [String: Any] = [
            "chatRoomId": chatRoomId,
            "senderId": senderId,
            "receiverId": receiverId,
            "text": trimmedText,
            "messageType": MessageType.text.rawValue,
            "createdAt": Timestamp(date: Date())
        ]

        try await db.collection("messages").document().setData(data)
        try await upsertChatRoomMetadata(
            chatRoomId: chatRoomId,
            senderId: senderId,
            receiverId: receiverId,
            senderName: senderName,
            senderImageUrl: senderImageUrl,
            receiverName: receiverName,
            receiverImageUrl: receiverImageUrl,
            lastMessageText: trimmedText,
            lastMessageType: MessageType.text.rawValue
        )
    }

    func sendImageMessage(
        chatRoomId: String,
        senderId: String,
        receiverId: String,
        images: [UIImage],
        senderName: String? = nil,
        senderImageUrl: String? = nil,
        receiverName: String? = nil,
        receiverImageUrl: String? = nil
    ) async throws {
        guard !images.isEmpty else { return }
        guard !chatRoomId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "ChatImage", code: 1004, userInfo: [NSLocalizedDescriptionKey: "チャットルームIDが無効です。"])
        }
        guard !senderId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "ChatImage", code: 1005, userInfo: [NSLocalizedDescriptionKey: "送信者IDが無効です。"])
        }
        guard !receiverId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "ChatImage", code: 1006, userInfo: [NSLocalizedDescriptionKey: "受信者IDが無効です。"])
        }

        var uploadedUrls: [String] = []
        uploadedUrls.reserveCapacity(images.count)

        for image in images {
            guard let data = ChatImageCompressor.compressForUpload(image) else {
                throw NSError(domain: "ChatImage", code: 1001, userInfo: [NSLocalizedDescriptionKey: "画像の圧縮に失敗しました。"])
            }

            let fileName = "\(UUID().uuidString).jpg"
            let path = "chat_images/\(chatRoomId)/\(fileName)"
            let url = try await uploadImageDataWithRetry(data: data, path: path, retryCount: 2)
            uploadedUrls.append(url)
        }

        let data: [String: Any] = [
            "chatRoomId": chatRoomId,
            "senderId": senderId,
            "receiverId": receiverId,
            "text": "",
            "messageType": MessageType.image.rawValue,
            "imageUrls": uploadedUrls,
            "createdAt": Timestamp(date: Date())
        ]

        try await db.collection("messages").document().setData(data)
        try await upsertChatRoomMetadata(
            chatRoomId: chatRoomId,
            senderId: senderId,
            receiverId: receiverId,
            senderName: senderName,
            senderImageUrl: senderImageUrl,
            receiverName: receiverName,
            receiverImageUrl: receiverImageUrl,
            lastMessageText: "",
            lastMessageType: MessageType.image.rawValue
        )
    }

    func fetchChatRooms(userId: String, limit: Int = 20) async throws -> ChatRoomPage {
        let snapshot = try await db.collection("chatRooms")
            .whereField("members", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        let rooms = snapshot.documents.compactMap { decodeChatRoom(document: $0) }
        return ChatRoomPage(
            rooms: rooms,
            lastDocument: snapshot.documents.last,
            hasMore: snapshot.documents.count == limit
        )
    }

    func observeChatRooms(
        userId: String,
        limit: Int = 50,
        onChange: @escaping (Result<[ChatRoomSummary], Error>) -> Void
    ) -> ListenerRegistration {
        let query = db.collection("chatRooms")
            .whereField("members", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: limit)

        return query.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }
            guard let snapshot = snapshot, let self = self else {
                onChange(.success([]))
                return
            }
            let rooms = snapshot.documents.compactMap { self.decodeChatRoom(document: $0) }
            onChange(.success(rooms))
        }
    }

    func observeChatRoomSummary(
        chatRoomId: String,
        onChange: @escaping (Result<ChatRoomSummary?, Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("chatRooms").document(chatRoomId).addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                onChange(.failure(error))
                return
            }
            guard let snapshot, let self = self else {
                onChange(.success(nil))
                return
            }
            if !snapshot.exists {
                onChange(.success(nil))
                return
            }
            onChange(.success(self.decodeChatRoom(document: snapshot)))
        }
    }

    func fetchMoreChatRooms(userId: String, lastDocument: DocumentSnapshot, limit: Int = 20) async throws -> ChatRoomPage {
        let snapshot = try await db.collection("chatRooms")
            .whereField("members", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .start(afterDocument: lastDocument)
            .limit(to: limit)
            .getDocuments()

        let rooms = snapshot.documents.compactMap { decodeChatRoom(document: $0) }
        return ChatRoomPage(
            rooms: rooms,
            lastDocument: snapshot.documents.last,
            hasMore: snapshot.documents.count == limit
        )
    }

    func deleteChatRoom(chatRoomId: String) async throws {
        let messagesRef = db.collection("messages")
        while true {
            let snapshot = try await messagesRef
                .whereField("chatRoomId", isEqualTo: chatRoomId)
                .limit(to: 200)
                .getDocuments()

            if snapshot.documents.isEmpty {
                break
            }

            let batch = db.batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }

        try await db.collection("chatRooms").document(chatRoomId).delete()
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
            let receiverId = data["receiverId"] as? String
        else {
            return nil
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let roomId = (data["chatRoomId"] as? String) ?? fallbackChatRoomId
        let text = (data["text"] as? String) ?? ""
        let messageType = (data["messageType"] as? String) ?? MessageType.text.rawValue
        let imageUrls = data["imageUrls"] as? [String]

        return Message(
            id: document.documentID,
            chatRoomId: roomId,
            senderId: senderId,
            receiverId: receiverId,
            text: text,
            messageType: messageType,
            imageUrls: imageUrls,
            createdAt: createdAt
        )
    }

    private func decodeChatRoom(document: DocumentSnapshot) -> ChatRoomSummary? {
        let data = document.data() ?? [:]
        guard
            let members = data["members"] as? [String],
            let lastMessageAt = (data["lastMessageAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }

        return ChatRoomSummary(
            id: document.documentID,
            members: members,
            memberNames: data["memberNames"] as? [String: String] ?? [:],
            memberImageUrls: data["memberImageUrls"] as? [String: String] ?? [:],
            lastMessageText: (data["lastMessageText"] as? String) ?? "",
            lastMessageType: (data["lastMessageType"] as? String) ?? MessageType.text.rawValue,
            lastMessageAt: lastMessageAt
        )
    }

    private func upsertChatRoomMetadata(
        chatRoomId: String,
        senderId: String,
        receiverId: String,
        senderName: String?,
        senderImageUrl: String?,
        receiverName: String?,
        receiverImageUrl: String?,
        lastMessageText: String,
        lastMessageType: String
    ) async throws {
        var memberNames: [String: String] = [:]
        var memberImageUrls: [String: String] = [:]
        if let senderName { memberNames[senderId] = senderName }
        if let receiverName { memberNames[receiverId] = receiverName }
        if let senderImageUrl { memberImageUrls[senderId] = senderImageUrl }
        if let receiverImageUrl { memberImageUrls[receiverId] = receiverImageUrl }

        let data: [String: Any] = [
            "members": [senderId, receiverId],
            "memberNames": memberNames,
            "memberImageUrls": memberImageUrls,
            "lastMessageText": lastMessageText,
            "lastMessageType": lastMessageType,
            "lastMessageAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        try await db.collection("chatRooms").document(chatRoomId).setData(data, merge: true)
    }

    private func uploadImageDataWithRetry(data: Data, path: String, retryCount: Int) async throws -> String {
        var lastError: Error?
        for attempt in 0...retryCount {
            do {
                let ref = storage.reference().child(path)
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                _ = try await ref.putDataAsync(data, metadata: metadata)
                do {
                    let downloadURL = try await downloadURLWithRetry(ref: ref, retryCount: 3)
                    return downloadURL.absoluteString
                } catch {
                    // Fallback: keep sending message with storage path even if download URL cannot be issued immediately.
                    return "storage://\(path)"
                }
            } catch {
                lastError = error
                if attempt < retryCount {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 400_000_000))
                }
            }
        }
        if let nsError = lastError as NSError?, nsError.domain == StorageErrorDomain {
            throw NSError(domain: "ChatImage", code: 1102, userInfo: [NSLocalizedDescriptionKey: "画像アップロードに失敗しました。Firebase Storage Rulesとバケット設定を確認してください。"])
        }
        throw lastError ?? NSError(domain: "ChatImage", code: 1002, userInfo: [NSLocalizedDescriptionKey: "画像アップロードに失敗しました。"])
    }

    private func downloadURLWithRetry(ref: StorageReference, retryCount: Int) async throws -> URL {
        var lastError: Error?
        for attempt in 0...retryCount {
            do {
                return try await ref.downloadURL()
            } catch {
                lastError = error
                if attempt < retryCount {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 300_000_000))
                }
            }
        }
        throw lastError ?? NSError(domain: "ChatImage", code: 1007, userInfo: [NSLocalizedDescriptionKey: "ダウンロードURLの取得に失敗しました。"])
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
