import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoading = true

    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration? = nil
    private var authHandle: AuthStateDidChangeListenerHandle? = nil
    
    init() {
        observeAuthState()
    }

    deinit {
        userListener?.remove()
        userListener = nil
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }
    
    private func observeAuthState() {
        isLoading = true
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                self.fetchAppUser(uid: user.uid)
            } else {
                self.userListener?.remove()
                self.userListener = nil
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isLoading = false
                }
            }
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
                    self.currentUser = nil
                }
                return
            }
            guard let snapshot, snapshot.exists else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.currentUser = nil
                }
                return
            }
            if var user = try? snapshot.data(as: AppUser.self) {
                user.id = snapshot.documentID
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.currentUser = nil
                }
            }
        }
    }
    
    func signOut() {
        try? Auth.auth().signOut()
        userListener?.remove()
        userListener = nil
        currentUser = nil
    }

    func updateCurrentUser(_ user: AppUser) {
        DispatchQueue.main.async {
            self.currentUser = user
        }
    }

    @MainActor
    func signIn(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "メールアドレスを入力してください。"])
        }
        guard !password.isEmpty else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "パスワードを入力してください。"])
        }
        isLoading = true
        do {
            _ = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
        } catch {
            isLoading = false
            throw error
        }
    }

    @MainActor
    func signUp(
        name: String,
        email: String,
        birthday: Date,
        gender: Gender,
        password: String
    ) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "姓名を入力してください。"])
        }
        guard !trimmedEmail.isEmpty else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "メールアドレスを入力してください。"])
        }
        guard password.count >= 6 else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "パスワードは6文字以上にしてください。"])
        }

        isLoading = true

        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
        } catch {
            isLoading = false
            throw error
        }

        let uid = authResult.user.uid
        let computedAge = Self.age(from: birthday)

        let data: [String: Any] = [
            "userId": uid,
            "name": trimmedName,
            "gender": gender.rawValue,
            "email": trimmedEmail,
            "birthday": Timestamp(date: birthday),
            "age": computedAge as Any,
            "profileImageUrl": "",
            "profileImage": "",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]

        do {
            try await db.collection("users").document(uid).setData(data, merge: true)
        } catch {
            try? await authResult.user.delete()
            isLoading = false
            throw error
        }
    }

    private static func age(from birthday: Date) -> Int? {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: birthday, to: now)
        guard let year = components.year else { return nil }
        return max(0, year)
    }
}
