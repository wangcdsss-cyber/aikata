import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firestoreService: FirestoreService
    let user: AppUser
    
    @State private var content = ""
    @State private var isUploading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $content)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                    .overlay(
                        Group {
                            if content.isEmpty {
                                Text("ここに投稿内容を入力...")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 25)
                                    .padding(.top, 25)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            .navigationTitle("新規投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        uploadPost()
                    }) {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("投稿")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(content.isEmpty || isUploading)
                }
            }
        }
    }
    
    private func uploadPost() {
        isUploading = true
        errorMessage = nil
        
        Task {
            do {
                try await firestoreService.createPost(content: content, user: user)
                await MainActor.run {
                    isUploading = false
                    dismiss()
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
    CreatePostView(user: AppUser(name: "テスト", gender: .female, createdAt: Date()))
        .environmentObject(FirestoreService())
}
