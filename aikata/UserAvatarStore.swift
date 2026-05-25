import Foundation
import FirebaseFirestore
import Combine

final class UserAvatarStore: ObservableObject {
    @Published private(set) var profileImageUrlByUserId: [String: String] = [:]
    @Published private(set) var nameByUserId: [String: String] = [:]
    @Published private(set) var ageByUserId: [String: Int] = [:]
    @Published private(set) var occupationByUserId: [String: String] = [:]
    @Published private(set) var workLocationByUserId: [String: String] = [:]

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

    func age(userId: String) -> Int? {
        ageByUserId[userId]
    }

    func occupation(userId: String) -> String? {
        occupationByUserId[userId]
    }

    func workLocation(userId: String) -> String? {
        workLocationByUserId[userId]
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
                let age = data["age"] as? Int
                let occupation =
                    (data["occupation"] as? String) ??
                    (data["job"] as? String) ??
                    ""
                let workLocation =
                    (data["workLocation"] as? String) ??
                    (data["workplace"] as? String) ??
                    (data["residence"] as? String) ??
                    ""
                DispatchQueue.main.async {
                    self.profileImageUrlByUserId[id] = url.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        self.nameByUserId[id] = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let age, age > 0 {
                        self.ageByUserId[id] = age
                    }
                    let occupationTrimmed = occupation.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !occupationTrimmed.isEmpty {
                        self.occupationByUserId[id] = occupationTrimmed
                    }
                    let workLocationTrimmed = workLocation.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !workLocationTrimmed.isEmpty {
                        self.workLocationByUserId[id] = workLocationTrimmed
                    }
                }
            }
        }
    }
}
