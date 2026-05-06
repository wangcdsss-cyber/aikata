import Foundation
import FirebaseFirestore

enum Gender: String, Codable, CaseIterable {
    case male = "男性"
    case female = "女性"
    
    var icon: String {
        switch self {
        case .male: return "figure.walk"
        case .female: return "figure.dress.line.vertical"
        }
    }
}

struct AppUser: Codable, Identifiable {
    var id: String?
    var name: String
    var gender: Gender
    var profileImageUrl: String?
    var createdAt: Date
}

struct Post: Codable, Identifiable {
    var id: String?
    var userId: String
    var userName: String
    var content: String
    var gender: Gender // The gender of the poster and the target audience
    var createdAt: Date
}
