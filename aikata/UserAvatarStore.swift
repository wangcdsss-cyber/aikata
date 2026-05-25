import Foundation
import FirebaseFirestore
import Combine

final class UserAvatarStore: ObservableObject {
    @Published private(set) var profileImageUrlByUserId: [String: String] = [:]
    @Published private(set) var nameByUserId: [String: String] = [:]

    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]

    deinit {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }

    func profileImageUrl(userId: String) -> String? {
        profileImageUrlByUserId[userId]
    }

    func name(userId: String) -> String? {
        nameByUserId[userId]
    }

    func observeIfNeeded(userIds: [String]) {
        let ids = Set(userIds.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        for id in ids {
            if listeners[id] != nil { continue }
            listeners[id] = db.collection("users").document(id).addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let data = snapshot?.data() ?? [:]
                let url =
                    (data["profileImageUrl"] as? String) ??
                    (data["profileImage"] as? String) ??
                    ""
                let name = (data["name"] as? String) ?? ""
                DispatchQueue.main.async {
                    self.profileImageUrlByUserId[id] = url.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        self.nameByUserId[id] = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
    }
}
