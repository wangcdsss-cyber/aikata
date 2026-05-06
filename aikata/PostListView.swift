import SwiftUI

struct PostListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firestoreService = FirestoreService()
    @State private var isShowingCreatePost = false
    
    var body: some View {
        NavigationView {
            Group {
                if firestoreService.posts.isEmpty {
                    VStack {
                        Text("投稿がありません")
                            .foregroundColor(.secondary)
                        Text("最初の投稿をしてみましょう！")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(firestoreService.posts) { post in
                        PostRow(post: post)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("\(authManager.currentUser?.gender.rawValue ?? "")掲示板")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingCreatePost = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Logout or Reset for testing
                        UserDefaults.standard.removeObject(forKey: "app_user")
                        authManager.currentUser = nil
                    }) {
                        Text("リセット")
                            .font(.caption)
                    }
                }
            }
            .sheet(isPresented: $isShowingCreatePost) {
                if let user = authManager.currentUser {
                    CreatePostView(user: user)
                        .environmentObject(firestoreService)
                }
            }
            .onAppear {
                if let user = authManager.currentUser {
                    firestoreService.fetchPosts(for: user.gender)
                }
            }
        }
    }
}

struct PostRow: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading) {
                    Text(post.userName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(post.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(post.content)
                .font(.body)
                .padding(.vertical, 5)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PostListView()
        .environmentObject(AuthManager())
}
