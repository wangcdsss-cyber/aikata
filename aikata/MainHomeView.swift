import SwiftUI

struct MainHomeView: View {
    enum Tab {
        case board
        case messages
        case profile
    }

    @State private var selectedTab: Tab = .board

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                PostListView()
                    .opacity(selectedTab == .board ? 1 : 0)
                    .allowsHitTesting(selectedTab == .board)

                MessageListView()
                    .opacity(selectedTab == .messages ? 1 : 0)
                    .allowsHitTesting(selectedTab == .messages)

                ProfileView()
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                tabButton(
                    icon: "house.fill",
                    title: "掲示板",
                    isActive: selectedTab == .board
                ) {
                    selectedTab = .board
                }
                Spacer()
                tabButton(
                    icon: "envelope.fill",
                    title: "メッセージ",
                    isActive: selectedTab == .messages
                ) {
                    selectedTab = .messages
                }
                Spacer()
                tabButton(
                    icon: "person.crop.circle.fill",
                    title: "プロフィール",
                    isActive: selectedTab == .profile
                ) {
                    selectedTab = .profile
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(
                Color.black
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(
                        Divider().background(Color.white.opacity(0.18)),
                        alignment: .top
                    )
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func tabButton(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isActive ? .white : Color.white.opacity(0.7))
            .frame(width: 120)
        }
    }
}
