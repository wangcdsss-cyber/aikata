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
    func fetchPosts(for gender: Gender, isRefresh: Bool = false) async {
        guard !isFetching else { return }
        
        isFetching = true
        errorMessage = nil
        
        do {
            let query = db.collection("posts")
                .whereField("gender", isEqualTo: gender.rawValue)
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
            
            let snapshot = try await query.getDocuments()
            
            let fetchedPosts = snapshot.documents.compactMap { document -> Post? in
                var post = try? document.data(as: Post.self)
                post?.id = document.documentID
                return post
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
    func fetchMorePosts(for gender: Gender) async {
        guard !isFetchingMore && hasMore, let lastDoc = lastDocument else { return }
        
        isFetchingMore = true
        
        do {
            let query = db.collection("posts")
                .whereField("gender", isEqualTo: gender.rawValue)
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastDoc)
                .limit(to: pageSize)
            
            let snapshot = try await query.getDocuments()
            
            let fetchedPosts = snapshot.documents.compactMap { document -> Post? in
                var post = try? document.data(as: Post.self)
                post?.id = document.documentID
                return post
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
}
