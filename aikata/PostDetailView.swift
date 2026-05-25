import SwiftUI

struct PostDetailView: View {
    let post: Post
    @Environment(\.dismiss) var dismiss
    @State private var currentPost: Post
    @StateObject private var avatarStore = UserAvatarStore()

    init(post: Post) {
        self.post = post
        _currentPost = State(initialValue: post)
    }
    
    var body: some View {
        let displayedName = avatarStore.name(userId: currentPost.userId) ?? currentPost.userName
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header: Avatar + User Info + Time
                    HStack(alignment: .top, spacing: 12) {
                        // Avatar
                        AsyncImage(url: URL(string: avatarStore.profileImageUrl(userId: currentPost.userId) ?? currentPost.userProfileImageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        
                        // User Info
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(displayedName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(currentPost.createdAt.relativeTimeString())
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.gray)
                            }
                            
                            Text("\(currentPost.userAge.map { "\($0)歳" } ?? "年齢非公開")   \(currentPost.userJob ?? "職業非公開")")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 16)
                    
                    // Regions
                    if !currentPost.regions.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Text("希望地域:")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(currentPost.regions.joined(separator: ", "))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Content
                    Text(currentPost.content)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineSpacing(6)
                    
                    Spacer(minLength: 40)
                    
                    // Message Button (Placeholder for Phase 2)
                    HStack {
                        Spacer()
                        Button(action: {
                            // TODO: Open chat
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("メッセージ")
                            }
                            .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .onAppear {
            avatarStore.observeIfNeeded(userIds: [currentPost.userId])
        }
        .onReceive(NotificationCenter.default.publisher(for: .userAvatarDidUpdate)) { notification in
            guard
                let userInfo = notification.userInfo,
                let userId = userInfo["userId"] as? String,
                let profileImageUrl = userInfo["profileImageUrl"] as? String
            else { return }
            guard currentPost.userId == userId else { return }
            currentPost.userProfileImageUrl = profileImageUrl
        }
        .onReceive(NotificationCenter.default.publisher(for: .userNameDidUpdate)) { notification in
            guard
                let userInfo = notification.userInfo,
                let userId = userInfo["userId"] as? String,
                let name = userInfo["name"] as? String
            else { return }
            guard currentPost.userId == userId else { return }
            currentPost.userName = name
        }
    }
}

#Preview {
    NavigationView {
        PostDetailView(post: Post(
            id: "1",
            userId: "user1",
            userName: "SHO",
            userAge: 31,
            userJob: "コンサル",
            userProfileImageUrl: nil,
            content: "週末新宿で過激\nオトナ出会い飲み会\nドタキャン禁止\n予約制\n\n女子が積極的なので\n受け身でもOK\n連れ出し狙いも可能\nお金余裕あるかたのみ",
            gender: .male,
            regions: ["埼玉県", "群馬県", "栃木県"],
            createdAt: Date()
        ))
    }
}
