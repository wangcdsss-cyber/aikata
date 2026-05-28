import SwiftUI
import Foundation

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firestoreService = FirestoreService()
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let user = authManager.currentUser {
                    ProfileContentView(
                        user: user,
                        showsEditButton: true,
                        onEditTapped: { showEdit = true }
                    )
                } else {
                    Text("プロフィール情報がありません")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showEdit) {
                if let user = authManager.currentUser {
                    ProfileEditView(user: user)
                        .environmentObject(firestoreService)
                }
            }
        }
    }
}
