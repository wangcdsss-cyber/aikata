import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthManager: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoading = true

    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration? = nil
    
    // For Phase 1, we might use a simple unique ID stored in UserDefaults 
    // to simulate a logged-in user if they haven't gone through full Auth yet.
    // But let's try to check if there's a Firebase user.
    
    init() {
        checkUser()
    }

    deinit {
        userListener?.remove()
        userListener = nil
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
        userListener?.remove()
        isLoading = true
        userListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadLocalUser()
                }
                return
            }
            guard let snapshot, snapshot.exists else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadLocalUser()
                }
                return
            }
            if var user = try? snapshot.data(as: AppUser.self) {
                user.id = snapshot.documentID
                DispatchQueue.main.async {
                    self.updateCurrentUser(user)
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadLocalUser()
                }
            }
        }
    }
    
    private func loadLocalUser() {
        if let data = UserDefaults.standard.data(forKey: "app_user"),
           let user = try? JSONDecoder().decode(AppUser.self, from: data) {
            self.currentUser = user
        }
    }
    
    func registerUser(name: String, gender: Gender) {
        if let firebaseUser = Auth.auth().currentUser {
            let newUser = AppUser(
                id: firebaseUser.uid,
                name: name,
                gender: gender,
                createdAt: Date()
            )
            let data: [String: Any] = [
                "userId": firebaseUser.uid,
                "name": name,
                "gender": gender.rawValue,
                "createdAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ]
            db.collection("users").document(firebaseUser.uid).setData(data, merge: true)
            updateCurrentUser(newUser)
            return
        }

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
