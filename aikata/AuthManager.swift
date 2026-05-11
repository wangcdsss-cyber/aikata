import Foundation
import FirebaseAuth
import Combine

class AuthManager: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoading = true
    
    // For Phase 1, we might use a simple unique ID stored in UserDefaults 
    // to simulate a logged-in user if they haven't gone through full Auth yet.
    // But let's try to check if there's a Firebase user.
    
    init() {
        checkUser()
    }
    
    func checkUser() {
        if let firebaseUser = Auth.auth().currentUser {
            // Fetch AppUser from Firestore
            fetchAppUser(uid: firebaseUser.uid)
        } else {
            // Try to use a local mock user for Phase 1 if needed, 
            // or just show onboarding.
            loadLocalUser()
            isLoading = false
        }
    }
    
    private func fetchAppUser(uid: String) {
        // Fetch from Firestore (logic would go here)
        // For Phase 1 simplicity, if no Firestore user, we show onboarding.
        isLoading = false
    }
    
    private func loadLocalUser() {
        if let data = UserDefaults.standard.data(forKey: "app_user"),
           let user = try? JSONDecoder().decode(AppUser.self, from: data) {
            self.currentUser = user
        }
    }
    
    func registerUser(name: String, gender: Gender) {
        let newUser = AppUser(
            id: UUID().uuidString, // Phase 1: local ID
            name: name,
            gender: gender,
            createdAt: Date()
        )
        
        // Save locally
        if let encoded = try? JSONEncoder().encode(newUser) {
            UserDefaults.standard.set(encoded, forKey: "app_user")
        }
        
        self.currentUser = newUser
    }

    func updateCurrentUser(_ user: AppUser) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "app_user")
        }
        self.currentUser = user
    }
}
