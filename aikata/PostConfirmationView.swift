import SwiftUI

struct PostConfirmationView: View {
    let user: AppUser
    let regions: [String]
    let content: String
    let rootDismiss: DismissAction
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firestoreService: FirestoreService
    
    @State private var isUploading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 30) {
                    // User Info
                    HStack(alignment: .top, spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(user.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text("\(user.age ?? 0)歳")
                                Text(user.job ?? "未設定")
                                Text(user.residence ?? "未設定")
                            }
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            
                            Text(regions.joined(separator: "、"))
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    // Content
                    VStack(alignment: .leading) {
                        Text(content)
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(Color(.darkGray))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 40)
                    
                    // Confirmation Section
                    VStack(spacing: 20) {
                        Text("この内容で投稿しますか？")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button(action: {
                            uploadPost()
                        }) {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(25)
                            } else {
                                Text("投稿")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(25)
                            }
                        }
                        .disabled(isUploading)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("投稿内容を確認")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
    
    private func uploadPost() {
        isUploading = true
        errorMessage = nil
        
        Task {
            do {
                try await firestoreService.createPost(
                    regions: regions,
                    content: content,
                    user: user
                )
                await MainActor.run {
                    isUploading = false
                    rootDismiss() // Dismiss all the way back
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = "投稿に失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        PostConfirmationView(
            user: AppUser(name: "テスト", gender: .male, createdAt: Date()),
            regions: ["東京都", "埼玉県"],
            content: "楽しく飲みたいです。よろしくお願いします。",
            rootDismiss: Environment(\.dismiss).wrappedValue
        )
        .environmentObject(FirestoreService())
    }
}
