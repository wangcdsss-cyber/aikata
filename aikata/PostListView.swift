import SwiftUI
import UIKit

struct PostListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firestoreService = FirestoreService()
    @State private var isShowingCreatePost = false
    
    // For Report View
    @State private var selectedPostToReport: Post? = nil
    
    let showReportPublisher = NotificationCenter.default.publisher(for: NSNotification.Name("ShowReportView"))
    
    var body: some View {
        // Read screen width to pass down instead of using GeometryReader inside each row
        GeometryReader { mainGeometry in
            NavigationView {
                Group {
                    if firestoreService.posts.isEmpty && !firestoreService.isFetching {
                        VStack(spacing: 12) {
                            Text("投稿がありません")
                                .foregroundColor(.secondary)
                            Text("最初の投稿をしてみましょう！")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("再読み込み") {
                                if let user = authManager.currentUser {
                                    Task {
                                        await firestoreService.fetchPosts(for: user.gender, isRefresh: true)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    } else if firestoreService.posts.isEmpty && firestoreService.isFetching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        List {
                            ForEach(firestoreService.posts) { post in
                                PostRow(post: post, screenWidth: mainGeometry.size.width)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.black)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                            }
                            
                            // Infinite Scroll Loading Indicator
                            if firestoreService.hasMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .onAppear {
                                            if let user = authManager.currentUser {
                                                Task {
                                                    await firestoreService.fetchMorePosts(for: user.gender)
                                                }
                                            }
                                        }
                                    Spacer()
                                }
                                .listRowBackground(Color.black)
                                .listRowInsets(EdgeInsets())
                                .padding(.vertical, 20)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.black)
                        .refreshable {
                            if let user = authManager.currentUser {
                                await firestoreService.fetchPosts(for: user.gender, isRefresh: true)
                            }
                        }
                    }
                }
                .background(Color.black.edgesIgnoringSafeArea(.all))
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
                // Set UIRefreshControl tint color to white globally for this view
                UIRefreshControl.appearance().tintColor = UIColor.white
                
                if let user = authManager.currentUser {
                    Task {
                        await firestoreService.fetchPosts(for: user.gender)
                    }
                }
            }
            .onReceive(showReportPublisher) { notification in
                if let userInfo = notification.userInfo, let post = userInfo["post"] as? Post {
                    self.selectedPostToReport = post
                }
            }
            .sheet(item: $selectedPostToReport) { post in
                if let currentUser = authManager.currentUser {
                    ReportView(
                        postId: post.id ?? "",
                        reportedUserId: post.userId,
                        currentUser: currentUser
                    )
                    .environmentObject(firestoreService)
                }
            }
        }
    }
}

struct PostRow: View {
    let post: Post
    let screenWidth: CGFloat
    @State private var isExpanded = false
    
    var body: some View {
        let isSmallScreen = screenWidth <= 375
        let horizontalPadding: CGFloat = isSmallScreen ? 12 : 16
        let avatarSize: CGFloat = isSmallScreen ? 48 : 64
        
        VStack(alignment: .leading, spacing: 12) {
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
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .padding(.bottom, 8) // Align with right info
                    
                    // User Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text(post.userName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#1A1A1A"))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Relative Time
                            HStack(spacing: 4) {
                                Text(post.createdAt.relativeTimeString())
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Color(hex: "#999999"))
                                
                                Menu {
                                    Button(role: .destructive, action: {
                                        // Set state to show report view
                                        NotificationCenter.default.post(name: NSNotification.Name("ShowReportView"), object: nil, userInfo: ["post": post])
                                    }) {
                                        Label("違反を報告する", systemImage: "exclamationmark.triangle")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(Color(hex: "#999999"))
                                        .padding(4)
                                }
                            }
                        }
                        
                        Text("\(post.userAge.map { "\($0)歳" } ?? "年齢非公開")・\(post.userJob ?? "職業非公開")")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "#666666"))
                            .lineSpacing(6) // Approx line height 20
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                
                // Regions
                if !post.regions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("募集中のエリア")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#999999"))
                            .kerning(0.5)
                        
                        FlowLayout(spacing: 6) {
                            ForEach(post.regions, id: \.self) { region in
                                Text(region)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "#3182F6"))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text("募集内容")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    
                    Text(post.content)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#333333"))
                        .lineSpacing(4) // Approx 1.6 line height
                        .lineLimit(isExpanded ? nil : 3)
                        .truncationMode(.tail)
                    
                    if !isExpanded && post.content.count > 100 { // Simple heuristic for now
                        Button(action: {
                            isExpanded = true
                            // Log expansion event here
                        }) {
                            Text("…続きを見る")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            .frame(maxWidth: 640)
        }
    }
}

#Preview {
    PostListView()
        .environmentObject(AuthManager())
}
