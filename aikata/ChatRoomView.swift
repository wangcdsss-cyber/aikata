import SwiftUI
import FirebaseFirestore
import UIKit

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
    @State private var isLoadingOlder = false
    @State private var hasMoreOlder = true
    @State private var errorMessage: String?
    @State private var showingMoreActions = false
    @State private var showingReportView = false
    @State private var messageText = ""
    @State private var isSending = false
    @State private var listener: ListenerRegistration? = nil
    @State private var scrollTargetMessageId: String? = nil
    @FocusState private var isInputFocused: Bool

    private var chatRoomId: String {
        makeChatRoomId(userId1: currentUserId, userId2: chatPartnerId)
    }

    private var trimmedMessageText: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && messages.isEmpty {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Spacer()
            } else if let errorMessage = errorMessage, messages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Text("読み込みに失敗しました")
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if isLoadingOlder {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.vertical, 6)
                            }

                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                if shouldShowDateSeparator(at: index) {
                                    ChatDateSeparator(date: message.createdAt)
                                }

                                MessageBubble(
                                    message: message,
                                    isCurrentUser: message.senderId == currentUserId,
                                    chatPartnerImageUrl: chatPartnerImageUrl
                                )
                                .id(messageScrollId(message))
                                .onAppear {
                                    if index == 0 {
                                        Task {
                                            await loadOlderMessagesIfNeeded()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isInputFocused = false
                    }
                    .onChange(of: scrollTargetMessageId) { targetId in
                        guard let targetId = targetId else { return }
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(targetId, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            chatInputBar
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
            await loadInitialMessages()
            startRealtimeListener()
        }
        .onAppear {
            isChatRoomPresented = true
        }
        .onDisappear {
            isInputFocused = false
            isChatRoomPresented = false
            listener?.remove()
            listener = nil
        }
    }

    private var chatInputBar: some View {
        HStack(spacing: 10) {
            Button(action: {}) {
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 18))
            }
            .disabled(true)
            .opacity(0.7)

            TextField(
                "",
                text: $messageText,
                prompt: Text("メッセージ")
                    .foregroundColor(Color.white.opacity(0.65))
                    .font(.system(size: 16, weight: .medium)),
                axis: .vertical
            )
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(minHeight: 54, alignment: .center)
                .background(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(18)
                .foregroundColor(.white)
                .font(.system(size: messageText.isEmpty ? 17 : 26, weight: .medium))
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    Task {
                        await sendCurrentMessage()
                    }
                }

            if !trimmedMessageText.isEmpty {
                Button(action: {
                    Task {
                        await sendCurrentMessage()
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }
                .disabled(isSending)
                .opacity(isSending ? 0.5 : 1.0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.9))
    }

    @MainActor
    private func loadInitialMessages() async {
        guard !isLoading else { return }
        isLoading = true
        hasMoreOlder = true
        errorMessage = nil

        do {
            messages = try await firestoreService.fetchMessages(chatRoomId: chatRoomId, limit: 20)
            hasMoreOlder = messages.count == 20
            if let last = messages.last {
                scrollTargetMessageId = messageScrollId(last)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func startRealtimeListener() {
        listener?.remove()
        listener = firestoreService.observeNewMessages(
            chatRoomId: chatRoomId,
            after: messages.last?.createdAt
        ) { result in
            switch result {
            case .success(let newMessages):
                guard !newMessages.isEmpty else { return }
                Task { @MainActor in
                    mergeMessages(newMessages, scrollToBottom: true)
                }
            case .failure(let error):
                Task { @MainActor in
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func sendCurrentMessage() async {
        guard !trimmedMessageText.isEmpty, !isSending else { return }
        let textToSend = trimmedMessageText
        messageText = ""
        isSending = true

        do {
            try await firestoreService.sendMessage(
                chatRoomId: chatRoomId,
                senderId: currentUserId,
                receiverId: chatPartnerId,
                text: textToSend
            )
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        } catch {
            // Restore input text on failure so the user doesn't lose content.
            messageText = textToSend
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    @MainActor
    private func loadOlderMessagesIfNeeded() async {
        guard !isLoadingOlder, hasMoreOlder, let oldestDate = messages.first?.createdAt else { return }
        isLoadingOlder = true

        do {
            let older = try await firestoreService.fetchOlderMessages(
                chatRoomId: chatRoomId,
                before: oldestDate,
                limit: 20
            )
            if older.isEmpty {
                hasMoreOlder = false
            } else {
                mergeMessages(older, scrollToBottom: false, prependIfOlder: true)
                hasMoreOlder = older.count == 20
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingOlder = false
    }

    @MainActor
    private func mergeMessages(_ incoming: [Message], scrollToBottom: Bool, prependIfOlder: Bool = false) {
        var existing = messages
        let existingKeys = Set(existing.map(messageUniqueKey))
        let uniqueIncoming = incoming.filter { !existingKeys.contains(messageUniqueKey($0)) }
        guard !uniqueIncoming.isEmpty else { return }

        if prependIfOlder {
            existing.insert(contentsOf: uniqueIncoming, at: 0)
        } else {
            existing.append(contentsOf: uniqueIncoming)
        }

        existing.sort { $0.createdAt < $1.createdAt }
        messages = existing

        if scrollToBottom, let last = messages.last {
            scrollTargetMessageId = messageScrollId(last)
        }
    }

    private func messageUniqueKey(_ message: Message) -> String {
        if let id = message.id, !id.isEmpty {
            return id
        }
        return "\(message.senderId)|\(message.receiverId)|\(message.createdAt.timeIntervalSince1970)|\(message.text)"
    }

    private func messageScrollId(_ message: Message) -> String {
        if let id = message.id, !id.isEmpty {
            return id
        }
        return "message-\(message.senderId)-\(message.createdAt.timeIntervalSince1970)"
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index >= 0 && index < messages.count else { return false }
        if index == 0 { return true }
        return !Calendar.current.isDate(messages[index].createdAt, inSameDayAs: messages[index - 1].createdAt)
    }
}

private struct ChatDateSeparator: View {
    let date: Date

    var body: some View {
        HStack {
            Spacer()
            Text(date.chatDateSeparatorString())
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.75))
                .padding(.vertical, 3)
                .padding(.horizontal, 10)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let chatPartnerImageUrl: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isCurrentUser {
                Spacer(minLength: 42)

                Text(message.createdAt.chatTimestampString())
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.bottom, 2)

                Text(message.text)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(12)
            } else {
                AsyncImage(url: URL(string: chatPartnerImageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(Color.gray.opacity(0.6))
                }
                .frame(width: 26, height: 26)
                .clipShape(Circle())

                Text(message.text)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.4))
                    .cornerRadius(12)

                Text(message.createdAt.chatTimestampString())
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.bottom, 2)

                Spacer(minLength: 42)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
