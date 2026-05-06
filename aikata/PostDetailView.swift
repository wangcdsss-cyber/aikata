import SwiftUI

struct PostDetailView: View {
    let post: Post
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header: Avatar + User Info + Time
                    HStack(alignment: .top, spacing: 12) {
                        // Avatar
                        AsyncImage(url: URL(string: post.userProfileImageUrl ?? "")) { image in
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
                                Text(post.userName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(post.createdAt.relativeTimeString())
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.gray)
                            }
                            
                            Text("\(post.userAge.map { "\($0)歳" } ?? "年齢非公開")   \(post.userJob ?? "職業非公開")")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 16)
                    
                    // Regions
                    if !post.regions.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Text("希望地域:")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(post.regions.joined(separator: ", "))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Content
                    Text(post.content)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineSpacing(6)
                    
                    Spacer(minLength: 40)
                    
                    if let currentUser = authManager.currentUser, post.userId != currentUser.id {
                        // Message Button
                        HStack {
                            Spacer()
                            NavigationLink(destination: LazyView(ChatRoomView(partnerId: post.userId, partnerName: post.userName, partnerImageUrl: post.userProfileImageUrl))) {
                                Text("メッセージ")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: "#3182F6"))
                                    .cornerRadius(20)
                            }
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
