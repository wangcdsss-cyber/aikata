import Foundation
import FirebaseFirestore
import Combine

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var posts: [Post] = []
    
    // Fetch posts based on gender
    func fetchPosts(for gender: Gender) {
        db.collection("posts")
            .whereField("gender", isEqualTo: gender.rawValue)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("🚨 Error fetching posts: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("⚠️ No posts found or snapshot is nil.")
                    return
                }
                
                print("✅ Found \(documents.count) posts for gender: \(gender.rawValue)")
                
                self.posts = documents.compactMap { document in
                    do {
                        var post = try document.data(as: Post.self)
                        post.id = document.documentID
                        return post
                    } catch {
                        print("❌ Error decoding post \(document.documentID): \(error)")
                        return nil
                    }
                }
            }
    }
    
    // Create a new post
    func createPost(content: String, user: AppUser) async throws {
        let post = Post(
            userId: user.id ?? "unknown",
            userName: user.name,
            content: content,
            gender: user.gender,
            createdAt: Date()
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                _ = try db.collection("posts").addDocument(from: post) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // Save user profile
    func saveUser(_ user: AppUser) async throws {
        guard let id = user.id else { return }
        try db.collection("users").document(id).setData(from: user)
    }
}
