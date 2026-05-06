import SwiftUI
import FirebaseFirestore
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isFetchingMore = false
    @Published var newMessageText = ""
    @Published var hasMore = true
    
    private let firestoreService = FirestoreService()
    private var listenerRegistration: ListenerRegistration?
    
    let currentUserId: String
    let partnerId: String
    let chatRoomId: String
    
    private let cacheKey: String
    
    init(currentUserId: String, partnerId: String) {
        self.currentUserId = currentUserId
        self.partnerId = partnerId
        
        // Ensure consistent chat room ID regardless of who started the chat
        let ids = [currentUserId, partnerId].sorted()
        self.chatRoomId = "\(ids[0])_\(ids[1])"
        self.cacheKey = "chat_cache_\(self.chatRoomId)"
    }
    
    func onAppear() {
        if messages.isEmpty {
            loadCachedMessages()
        }
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    // Load from UserDefaults cache
    private func loadCachedMessages() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([Message].self, from: data) {
            self.messages = cached
        }
    }
    
    // Save to UserDefaults cache
    private func saveMessagesToCache() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    @MainActor
    func fetchInitialMessages() async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            let fetchedMessages = try await firestoreService.fetchInitialMessages(chatRoomId: chatRoomId)
            self.messages = fetchedMessages
            self.hasMore = fetchedMessages.count == 30
            self.saveMessagesToCache()
            
            // Start listening for new messages after the latest fetched message
            // If no messages, listen from now
            let lastDate = fetchedMessages.last?.createdAt ?? Date()
            setupRealTimeListener(after: lastDate)
            
        } catch {
            print("Error fetching initial messages: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func fetchOlderMessages() async {
        guard !isFetchingMore, hasMore, let firstMessage = messages.first else { return }
        
        isFetchingMore = true
        
        do {
            let olderMessages = try await firestoreService.fetchOlderMessages(chatRoomId: chatRoomId, before: firstMessage.createdAt)
            
            if !olderMessages.isEmpty {
                // Prepend older messages
                self.messages.insert(contentsOf: olderMessages, at: 0)
                self.hasMore = olderMessages.count == 30
                self.saveMessagesToCache()
            } else {
                self.hasMore = false
            }
        } catch {
            print("Error fetching older messages: \(error.localizedDescription)")
        }
        
        isFetchingMore = false
    }
    
    func sendMessage() {
        let text = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let messageToSend = text
        newMessageText = "" // Clear input immediately for better UX
        
        Task {
            do {
                let _ = try await firestoreService.sendMessage(
                    chatRoomId: chatRoomId,
                    senderId: currentUserId,
                    receiverId: partnerId,
                    content: messageToSend
                )
                // We rely on the snapshot listener to append this message to the list to ensure consistency,
                // but we could also do optimistic UI updates here.
            } catch {
                print("Error sending message: \(error.localizedDescription)")
                // Revert or show error (simplified for now)
            }
        }
    }
    
    private func setupRealTimeListener(after date: Date) {
        listenerRegistration?.remove()
        listenerRegistration = firestoreService.listenForNewMessages(chatRoomId: chatRoomId, after: date) { [weak self] newMessages in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Deduplicate before appending
                let existingIds = Set(self.messages.compactMap { $0.id })
                let uniqueNewMessages = newMessages.filter { !existingIds.contains($0.id ?? "") }
                
                if !uniqueNewMessages.isEmpty {
                    self.messages.append(contentsOf: uniqueNewMessages)
                    self.saveMessagesToCache()
                }
            }
        }
    }
}

public struct ChatRoomView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    let partnerId: String
    let partnerName: String
    let partnerImageUrl: String?
    
    @StateObject private var viewModel: ChatViewModel
    
    public init(partnerId: String, partnerName: String, partnerImageUrl: String?) {
        self.partnerId = partnerId
        self.partnerName = partnerName
        self.partnerImageUrl = partnerImageUrl
        
        // Initialize view model with dummy currentUserId, will be updated in onAppear if needed,
        // but better to initialize with UserDefaults app_user if available
        let currentUserId = UserDefaults.standard.string(forKey: "current_user_id") ?? "" 
        
        var userId = currentUserId // Use currentUserId if available
        if userId.isEmpty, let data = UserDefaults.standard.data(forKey: "app_user"),
           let user = try? JSONDecoder().decode(AppUser.self, from: data),
           let id = user.id {
            userId = id
        }
        
        // Use a deferred initialization for StateObject to prevent unnecessary heavy initialization during list rendering
        _viewModel = StateObject(wrappedValue: ChatViewModel(currentUserId: userId, partnerId: partnerId))
    }
    
    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Messages List
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if viewModel.messages.isEmpty {
                    Spacer()
                    Text("メッセージありません")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Pagination Loader
                                if viewModel.hasMore {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding()
                                        .onAppear {
                                            Task {
                                                await viewModel.fetchOlderMessages()
                                            }
                                        }
                                }
                                
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message, isCurrentUser: message.senderId == viewModel.currentUserId, partnerImageUrl: partnerImageUrl)
                                        .id(message.id)
                                }
                            }
                            .padding(.vertical, 16)
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let lastId = viewModel.messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                        .onAppear {
                            if let lastId = viewModel.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Field
                ChatInputView(text: $viewModel.newMessageText) {
                    viewModel.sendMessage()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        
                        AsyncImage(url: URL(string: partnerImageUrl ?? "")) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        Text(partnerName)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
            Task {
                await viewModel.fetchInitialMessages()
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let partnerImageUrl: String?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isCurrentUser {
                AsyncImage(url: URL(string: partnerImageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? Color(hex: "#3182F6") : Color(hex: "#333333"))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            if isCurrentUser {
                // Current user doesn't show avatar next to message
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
}

struct ChatInputView: View {
    @Binding var text: String
    var onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(hex: "#333333"))
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField("メッセージを入力...", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(20)
                    .foregroundColor(.white)
                
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: onSend) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#3182F6"))
                            .frame(width: 40, height: 40)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black)
        }
        .animation(.easeInOut, value: text)
    }
}
