import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import UIKit
import PhotosUI

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
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isUploadingImages = false
    @State private var uploadStatusMessage: String? = nil
    @State private var alertMessage: String? = nil
    @State private var didInitialScrollToBottom = false

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
                                    if index == 0 && didInitialScrollToBottom {
                                        Task {
                                            await loadOlderMessagesIfNeeded()
                                        }
                                    }
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("chat-bottom-anchor")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .padding(.bottom, 120)
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
                    .onAppear {
                        // Double-scroll after layout settles so newest message is always visible.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                proxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                proxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
                            }
                            didInitialScrollToBottom = true
                        }
                    }
                }
            }

            if isUploadingImages, let uploadStatusMessage {
                Text(uploadStatusMessage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 4)
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
        .onChange(of: selectedPhotoItems) { items in
            guard !items.isEmpty else { return }
            Task {
                await uploadSelectedPhotos(items)
            }
        }
        .alert("メッセージ", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
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
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 6,
                matching: .images
            ) {
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.85))
                    .font(.system(size: 18))
            }
            .disabled(isUploadingImages || isSending)
            .opacity((isUploadingImages || isSending) ? 0.5 : 1.0)

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
            scrollTargetMessageId = "chat-bottom-anchor"
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
                text: textToSend,
                senderName: currentUser?.name,
                senderImageUrl: currentUser?.profileImageUrl,
                receiverName: chatPartnerName,
                receiverImageUrl: chatPartnerImageUrl
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

        if scrollToBottom {
            scrollTargetMessageId = "chat-bottom-anchor"
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

    @MainActor
    private func uploadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !isUploadingImages else { return }
        guard !chatRoomId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "チャットルーム情報が不正です。画面を閉じて再度お試しください。"
            selectedPhotoItems = []
            return
        }
        guard !currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "ユーザー情報が未取得のため送信できません。再ログインしてください。"
            selectedPhotoItems = []
            return
        }
        isUploadingImages = true
        isInputFocused = false
        uploadStatusMessage = "画像を準備中..."
        defer {
            isUploadingImages = false
            selectedPhotoItems = []
            uploadStatusMessage = nil
        }

        var uiImages: [UIImage] = []
        uiImages.reserveCapacity(items.count)

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                    continue
                }
                uiImages.append(image)
            } catch {
                alertMessage = "画像の読み込みに失敗しました。再度お試しください。"
                return
            }
        }

        guard !uiImages.isEmpty else {
            alertMessage = "有効な画像を選択できませんでした。"
            return
        }

        do {
            uploadStatusMessage = "画像を送信中..."
            try await firestoreService.sendImageMessage(
                chatRoomId: chatRoomId,
                senderId: currentUserId,
                receiverId: chatPartnerId,
                images: uiImages,
                senderName: currentUser?.name,
                senderImageUrl: currentUser?.profileImageUrl,
                receiverName: chatPartnerName,
                receiverImageUrl: chatPartnerImageUrl
            )
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        } catch {
            alertMessage = "画像送信に失敗しました: \(error.localizedDescription)"
        }
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

                MessageContent(message: message, isCurrentUser: isCurrentUser)
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

                MessageContent(message: message, isCurrentUser: isCurrentUser)

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

private struct MessageContent: View {
    let message: Message
    let isCurrentUser: Bool

    var body: some View {
        Group {
            if message.type == .image, let imageUrls = message.imageUrls, !imageUrls.isEmpty {
                ChatImageGrid(imageUrls: imageUrls)
            } else {
                Text(makeLinkAttributedString(from: message.text))
                    .multilineTextAlignment(.leading)
                    .tint(Color.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.4))
                    .cornerRadius(12)
            }
        }
    }

    private func makeLinkAttributedString(from text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.font = .system(size: 17, weight: .medium)
        attributed.foregroundColor = .white

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }

        let nsText = text as NSString
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            guard
                let url = match.url,
                let range = Range(match.range, in: attributed)
            else { continue }

            attributed[range].link = url
            attributed[range].underlineStyle = .single
        }

        return attributed
    }
}

private struct ChatImageGrid: View {
    let imageUrls: [String]

    var body: some View {
        let columns = imageUrls.count == 1
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]

        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(imageUrls, id: \.self) { url in
                RemoteChatImageView(urlString: url)
            }
        }
        .frame(maxWidth: 220)
    }
}

private final class ChatImageMemoryCache {
    static let shared = ChatImageMemoryCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

private struct RemoteChatImageView: View {
    let urlString: String
    @State private var image: UIImage? = nil
    @State private var isLoading = false
    @State private var loadError: Error? = nil
    @State private var showingPreview = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .onTapGesture {
                        showingPreview = true
                    }
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.white.opacity(0.8))
                    Button("再試行") {
                        Task {
                            await loadImage(force: true)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                }
            }
        }
        .frame(width: 102, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            guard image == nil && !isLoading else { return }
            Task {
                await loadImage(force: false)
            }
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let image {
                ChatImagePreviewView(image: image)
            }
        }
    }

    @MainActor
    private func loadImage(force: Bool) async {
        if urlString.hasPrefix("storage://") {
            await loadImageFromStoragePath(force: force)
            return
        }

        guard let url = URL(string: urlString) else { return }
        if !force, let cached = ChatImageMemoryCache.shared.image(forKey: urlString) {
            image = cached
            loadError = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let request = URLRequest(
                url: url,
                cachePolicy: .returnCacheDataElseLoad,
                timeoutInterval: 20
            )
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let loadedImage = UIImage(data: data) else {
                throw NSError(domain: "ChatImage", code: 1003, userInfo: [NSLocalizedDescriptionKey: "画像データが不正です。"])
            }
            image = loadedImage
            ChatImageMemoryCache.shared.set(loadedImage, forKey: urlString)
            loadError = nil
        } catch {
            loadError = error
        }
    }

    @MainActor
    private func loadImageFromStoragePath(force: Bool) async {
        let path = urlString.replacingOccurrences(of: "storage://", with: "")
        guard !path.isEmpty else { return }
        if !force, let cached = ChatImageMemoryCache.shared.image(forKey: urlString) {
            image = cached
            loadError = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        var lastError: Error?
        for attempt in 0...2 {
            do {
                let ref = Storage.storage().reference().child(path)
                let data = try await ref.data(maxSize: 10 * 1024 * 1024)
                guard let loadedImage = UIImage(data: data) else {
                    throw NSError(domain: "ChatImage", code: 1003, userInfo: [NSLocalizedDescriptionKey: "画像データが不正です。"])
                }
                image = loadedImage
                ChatImageMemoryCache.shared.set(loadedImage, forKey: urlString)
                loadError = nil
                return
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 300_000_000))
                }
            }
        }
        loadError = lastError
    }
}

private struct ChatImagePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .onTapGesture(count: 2) {
                    if scale > 1 {
                        scale = 1
                        lastScale = 1
                    } else {
                        scale = 2
                        lastScale = 2
                    }
                }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(.top, 16)
            .padding(.leading, 16)
        }
    }
}
