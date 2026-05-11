import Foundation
import FirebaseFirestore
import UIKit

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
    var age: Int?
    var job: String?
    var residence: String?
    var selfIntroduction: String?
    var education: String?
    var height: String?
    var bodyType: String?
    var annualIncome: String?
    var mbti: String?
    var birthplace: String?
    var workplace: String?
    var frequentDrinkingArea: String?
    var createdAt: Date
}

struct Post: Codable, Identifiable {
    var id: String?
    var userId: String
    var userName: String
    var userAge: Int?
    var userJob: String?
    var userProfileImageUrl: String?
    var content: String
    var gender: Gender // The gender of the poster and the target audience
    var regions: [String]
    var createdAt: Date
}

struct Report: Codable, Identifiable {
    var id: String?
    var postId: String
    var reportedUserId: String
    var reporterId: String
    var reporterName: String
    var reportType: String
    var description: String
    var createdAt: Date
}

struct PostFilter: Equatable {
    var regions: [String] = []
    var minAge: Int = 18
    var maxAge: Int = 100
    var onlyMyPosts: Bool = false
    
    var isActive: Bool {
        return !regions.isEmpty || minAge > 18 || maxAge < 100 || onlyMyPosts
    }
}

struct Message: Codable, Identifiable {
    var id: String?
    var chatRoomId: String
    var senderId: String
    var receiverId: String
    var text: String
    var messageType: String = MessageType.text.rawValue
    var imageUrls: [String]? = nil
    var createdAt: Date

    var type: MessageType {
        MessageType(rawValue: messageType) ?? .text
    }
}

enum MessageType: String, Codable {
    case text
    case image
}

func makeChatRoomId(userId1: String, userId2: String) -> String {
    [userId1, userId2].sorted().joined(separator: "_")
}

enum ChatImageCompressor {
    static func compressForUpload(
        _ image: UIImage,
        maxDimension: CGFloat = 1080,
        maxBytes: Int = 2 * 1024 * 1024
    ) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        var quality: CGFloat = 0.9
        var data = resized.jpegData(compressionQuality: quality)

        while let currentData = data, currentData.count > maxBytes, quality > 0.1 {
            quality -= 0.1
            data = resized.jpegData(compressionQuality: quality)
        }
        return data
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrentDimension = max(size.width, size.height)
        guard maxCurrentDimension > maxDimension else { return image }

        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
