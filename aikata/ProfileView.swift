import SwiftUI
import Foundation

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firestoreService = FirestoreService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let user = authManager.currentUser {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            profileHeader(user: user)

                            Divider()
                                .background(Color.white.opacity(0.15))

                            introSection(user: user)

                            detailSection(user: user)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                } else {
                    Text("プロフィール情報がありません")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func profileHeader(user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(Color.gray.opacity(0.6))
            }
            .frame(width: 92, height: 92)
            .clipShape(Circle())

            HStack(alignment: .center, spacing: 12) {
                Text(user.name)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                NavigationLink {
                    ProfileEditView(user: user)
                        .environmentObject(firestoreService)
                } label: {
                    Text("プロフィールを編集")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                }
            }

            Text(ageAndJobText(user: user))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white.opacity(0.9))
        }
    }

    private func introSection(user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自己紹介")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(introText(user: user))
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailSection(user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("詳細情報")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 4)

            detailRow(title: "職業", value: user.job)
            detailRow(title: "最終学歴", value: user.education)
            detailRow(title: "身長", value: user.height)
            detailRow(title: "体型", value: user.bodyType)
            detailRow(title: "年収", value: user.annualIncome)
            detailRow(title: "MBTI", value: user.mbti)
            detailRow(title: "出身地", value: user.birthplace)
            detailRow(title: "勤務地", value: user.workplace ?? user.residence)
            detailRow(title: "よく飲む地域", value: user.frequentDrinkingArea)
        }
    }

    private func detailRow(title: String, value: String?) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.white.opacity(0.82))
                .frame(width: 90, alignment: .leading)

            Text(displayValue(value))
                .font(.system(size: 15))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.vertical, 8)
        .overlay(
            Divider().background(Color.white.opacity(0.12)),
            alignment: .bottom
        )
    }

    private func ageAndJobText(user: AppUser) -> String {
        let ageText = user.age.map { "\($0)歳" } ?? "年齢非公開"
        let jobText = displayValue(user.job)
        return "\(ageText)・\(jobText)"
    }

    private func introText(user: AppUser) -> String {
        let text = user.selfIntroduction?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        if text.isEmpty { return "未設定" }
        return String(text.prefix(500))
    }

    private func displayValue(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "未設定" : trimmed
    }
}
