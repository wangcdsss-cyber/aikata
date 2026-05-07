import SwiftUI

struct ChatRoomView: View {
    @Environment(\.dismiss) private var dismiss

    let currentUserId: String
    let chatPartnerId: String
    let chatPartnerName: String
    let chatPartnerImageUrl: String?
    let sourcePostId: String
    let currentUser: AppUser?
    @Binding var isChatRoomPresented: Bool

    @StateObject private var firestoreService = FirestoreService()
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingMoreActions = false
    @State private var showingReportView = false

    private var chatRoomId: String {
        makeChatRoomId(userId1: currentUserId, userId2: chatPartnerId)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if let errorMessage = errorMessage {
                VStack(spacing: 12) {
                    Text("読み込みに失敗しました")
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            } else if messages.isEmpty {
                Text("メッセージありません")
                    .foregroundColor(.gray)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                MessageBubble(
                                    message: message,
                                    isCurrentUser: message.senderId == currentUserId
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: messages.count) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    AsyncImage(url: URL(string: chatPartnerImageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(Color.gray.opacity(0.6))
                    }
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())

                    Text(chatPartnerName)
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .semibold))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingMoreActions = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .confirmationDialog(
            "メニュー",
            isPresented: $showingMoreActions,
            titleVisibility: .visible
        ) {
            Button("違反を報告する", role: .destructive) {
                showingReportView = true
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showingReportView) {
            if let currentUser = currentUser {
                ReportView(
                    postId: sourcePostId,
                    reportedUserId: chatPartnerId,
                    currentUser: currentUser
                )
                .environmentObject(firestoreService)
            }
        }
        .task {
            await loadMessages()
        }
        .onAppear {
            isChatRoomPresented = true
        }
        .onDisappear {
            isChatRoomPresented = false
        }
    }

    @MainActor
    private func loadMessages() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            messages = try await firestoreService.fetchMessages(chatRoomId: chatRoomId, limit: 20)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard !messages.isEmpty else { return }
        let anchorId = messages.count - 1
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(anchorId, anchor: .bottom)
            }
        }
    }
}

private struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

                Text(message.createdAt.relativeTimeString())
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.4))
            .cornerRadius(12)

            if !isCurrentUser { Spacer() }
        }
    }
}
