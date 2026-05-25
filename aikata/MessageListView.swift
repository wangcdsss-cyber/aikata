import SwiftUI
import FirebaseFirestore

struct MessageListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firestoreService = FirestoreService()
    @StateObject private var avatarStore = UserAvatarStore()

    @State private var chatRooms: [ChatRoomSummary] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var lastDocument: DocumentSnapshot? = nil

    @State private var roomToDelete: ChatRoomSummary? = nil
    @State private var rollbackRoom: ChatRoomSummary? = nil
    @State private var rollbackIndex: Int? = nil
    @State private var selectedRoomToReport: ChatRoomSummary? = nil
    @State private var alertMessage: String? = nil
    @State private var chatRoomsListener: ListenerRegistration? = nil

    private let pageSize = 20

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading && chatRooms.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { _ in
                                ChatRoomSkeletonRow()
                                Divider().background(Color(hex: "#333333"))
                            }
                        }
                    }
                } else if chatRooms.isEmpty {
                    VStack(spacing: 8) {
                        Text("メッセージがありません")
                            .foregroundColor(.gray)
                        Text("投稿からメッセージを送ってみましょう")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.85))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(chatRooms.enumerated()), id: \.element.id) { index, room in
                                NavigationLink(
                                    destination: ChatRoomView(
                                        currentUserId: authManager.currentUser?.id ?? "",
                                        chatPartnerId: room.partnerId(currentUserId: authManager.currentUser?.id ?? ""),
                                        chatPartnerName: room.partnerName(currentUserId: authManager.currentUser?.id ?? ""),
                                        chatPartnerImageUrl: room.partnerImageUrl(currentUserId: authManager.currentUser?.id ?? ""),
                                        sourcePostId: room.id,
                                        currentUser: authManager.currentUser,
                                        isChatRoomPresented: .constant(false)
                                    )
                                ) {
                                    ChatRoomRow(
                                        room: room,
                                        currentUserId: authManager.currentUser?.id ?? "",
                                        avatarStore: avatarStore,
                                        onDeleteTapped: { roomToDelete = room },
                                        onReportTapped: { selectedRoomToReport = room }
                                    )
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if index == chatRooms.count - 1 {
                                        Task { await loadMoreIfNeeded() }
                                    }
                                }

                                Divider().background(Color(hex: "#333333"))
                            }

                            if isLoadingMore {
                                VStack(spacing: 0) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        ChatRoomSkeletonRow()
                                        Divider().background(Color(hex: "#333333"))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("メッセージ")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadInitial()
                startChatRoomsListener()
            }
            .onChange(of: chatRooms) { _, rooms in
                let currentUserId = authManager.currentUser?.id ?? ""
                let partnerIds = rooms.map { $0.partnerId(currentUserId: currentUserId) }
                avatarStore.observeIfNeeded(userIds: partnerIds)
            }
            .onReceive(NotificationCenter.default.publisher(for: .userAvatarDidUpdate)) { notification in
                guard
                    let userInfo = notification.userInfo,
                    let userId = userInfo["userId"] as? String,
                    let profileImageUrl = userInfo["profileImageUrl"] as? String
                else { return }
                chatRooms = AvatarSync.updatedChatRooms(chatRooms, userId: userId, profileImageUrl: profileImageUrl)
            }
            .onReceive(NotificationCenter.default.publisher(for: .userNameDidUpdate)) { notification in
                guard
                    let userInfo = notification.userInfo,
                    let userId = userInfo["userId"] as? String,
                    let name = userInfo["name"] as? String
                else { return }
                chatRooms = chatRooms.map { room in
                    guard room.memberNames[userId] != nil else { return room }
                    var next = room
                    next.memberNames[userId] = name
                    return next
                }
            }
        }
        .onDisappear {
            chatRoomsListener?.remove()
            chatRoomsListener = nil
        }
        .alert("削除確認", isPresented: Binding(
            get: { roomToDelete != nil },
            set: { if !$0 { roomToDelete = nil } }
        )) {
            Button("キャンセル", role: .cancel) {
                roomToDelete = nil
            }
            Button("削除", role: .destructive) {
                guard let room = roomToDelete else { return }
                roomToDelete = nil
                Task {
                    await deleteRoom(room)
                }
            }
        } message: {
            Text("この会話を削除しますか？")
        }
        .alert("メッセージ", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(item: $selectedRoomToReport) { room in
            if let currentUser = authManager.currentUser {
                ReportView(
                    postId: room.id,
                    reportedUserId: room.partnerId(currentUserId: currentUser.id ?? ""),
                    currentUser: currentUser
                )
                .environmentObject(firestoreService)
            }
        }
    }

    @MainActor
    private func loadInitial() async {
        guard !isLoading, let userId = authManager.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await firestoreService.fetchChatRooms(userId: userId, limit: pageSize)
            chatRooms = page.rooms
            lastDocument = page.lastDocument
            hasMore = page.hasMore
        } catch {
            alertMessage = "読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func startChatRoomsListener() {
        guard let userId = authManager.currentUser?.id else { return }
        chatRoomsListener?.remove()
        chatRoomsListener = firestoreService.observeChatRooms(userId: userId, limit: 60) { result in
            Task { @MainActor in
                switch result {
                case .success(let rooms):
                    chatRooms = rooms
                    hasMore = false
                    lastDocument = nil
                case .failure(let error):
                    alertMessage = "読み込みに失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }

    @MainActor
    private func loadMoreIfNeeded() async {
        guard
            !isLoadingMore,
            hasMore,
            let userId = authManager.currentUser?.id,
            let lastDocument
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await firestoreService.fetchMoreChatRooms(
                userId: userId,
                lastDocument: lastDocument,
                limit: pageSize
            )
            let existingIds = Set(chatRooms.map(\.id))
            chatRooms.append(contentsOf: page.rooms.filter { !existingIds.contains($0.id) })
            self.lastDocument = page.lastDocument
            hasMore = page.hasMore
        } catch {
            alertMessage = "追加読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func deleteRoom(_ room: ChatRoomSummary) async {
        guard let index = chatRooms.firstIndex(where: { $0.id == room.id }) else { return }
        rollbackRoom = room
        rollbackIndex = index
        chatRooms.remove(at: index)

        do {
            try await firestoreService.deleteChatRoom(chatRoomId: room.id)
            rollbackRoom = nil
            rollbackIndex = nil
        } catch {
            if let rollbackRoom, let rollbackIndex {
                chatRooms.insert(rollbackRoom, at: min(rollbackIndex, chatRooms.count))
            }
            self.rollbackRoom = nil
            self.rollbackIndex = nil
            alertMessage = "削除に失敗しました: \(error.localizedDescription)"
        }
    }
}

private struct ChatRoomRow: View {
    let room: ChatRoomSummary
    let currentUserId: String
    let avatarStore: UserAvatarStore
    let onDeleteTapped: () -> Void
    let onReportTapped: () -> Void

    var body: some View {
        let partnerId = room.partnerId(currentUserId: currentUserId)
        let displayedName = avatarStore.name(userId: partnerId) ?? room.partnerName(currentUserId: currentUserId)
        let ageText = avatarStore.age(userId: partnerId).map { "\($0)歳" }
        let occupationText = avatarStore.occupation(userId: partnerId)
        let workLocationText = avatarStore.workLocation(userId: partnerId)
        let profileParts = [ageText, occupationText, workLocationText].compactMap { value -> String? in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        let profileLine = profileParts.joined(separator: "  ")
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: avatarStore.profileImageUrl(userId: partnerId) ?? room.partnerImageUrl(currentUserId: currentUserId) ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(Color.gray.opacity(0.6))
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(displayedName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    Text(room.lastMessageAt.chatRoomListDateString())
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#9E9E9E"))
                        .lineLimit(1)

                    Menu {
                        Button("報告", action: onReportTapped)
                        Button("削除", role: .destructive, action: onDeleteTapped)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                if !profileLine.isEmpty {
                    Text(profileLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(room.previewText)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#C9C9C9"))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(minHeight: 94, alignment: .center)
        .background(Color.black)
    }
}

private struct ChatRoomSkeletonRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 120, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 180, height: 12)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.12))
                .frame(width: 80, height: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(minHeight: 94, alignment: .center)
        .redacted(reason: .placeholder)
    }
}
