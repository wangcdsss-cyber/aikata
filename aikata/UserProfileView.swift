import SwiftUI

struct UserProfileView: View {
    @StateObject private var firestoreService = FirestoreService()
    let userId: String

    @State private var user: AppUser? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if let user {
                ProfileContentView(user: user, showsEditButton: false, onEditTapped: nil)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Text("読み込みに失敗しました")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                    Text(errorMessage)
                        .foregroundColor(Color.white.opacity(0.75))
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            } else {
                Text("ユーザーが見つかりません")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    @MainActor
    private func load() async {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "ユーザーIDが無効です。"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await firestoreService.fetchUser(userId: trimmed)
            user = fetched
            errorMessage = nil
        } catch {
            user = nil
            errorMessage = error.localizedDescription
        }
    }
}

