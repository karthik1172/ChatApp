import Foundation
import Combine

class ChatManager: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var selectedChat: Chat?
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private var offlineQueue: [ChatMessage] = []
    private var wsManager: WebSocketManager
    
    init(wsManager: WebSocketManager) {
        self.wsManager = wsManager
        setupNotifications()
        loadChatsFromStorage()
        
        // Create default chat if none exist
        if chats.isEmpty {
            _ = createOrGetChat(id: "default_chat")
        }
        
        wsManager.connect()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WebSocketMessageReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let content = notification.object as? String {
                print("ChatManager received message: \(content)")
                self?.receiveMessage(content: content)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UIApplicationDidEnterBackground"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.wsManager.disconnect()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UIApplicationWillEnterForeground"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.wsManager.connect()
            self?.retryOfflineMessages()
        }
    }
    
    func createOrGetChat(id: String) -> Chat {
        if let existing = chats.first(where: { $0.id == id }) {
            return existing
        }
        let newChat = Chat(id: id, messages: [])
        chats.append(newChat)
        print("Created new chat with ID: \(id)")
        return newChat
    }
    
    func sendMessage(_ content: String, to chatId: String) {
        let chatMessage = ChatMessage(
            id: UUID().uuidString,
            content: content,
            timestamp: Date(),
            isOutgoing: true,
            isFailed: false
        )
        
        addMessageToChat(chatMessage, chatId: chatId)
        wsManager.send(message: content)
    }
    
    private func receiveMessage(content: String) {
        let chatId = "default_chat"
        
        // Ensure chat exists
        let _ = createOrGetChat(id: chatId)
        
        let message = ChatMessage(
            id: UUID().uuidString,
            content: content,
            timestamp: Date(),
            isOutgoing: false,
            isFailed: false
        )
        
        addMessageToChat(message, chatId: chatId)
    }
    
    private func addMessageToChat(_ message: ChatMessage, chatId: String) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else {
            print("Chat not found for ID: \(chatId)")
            return
        }
        
        chats[index].messages.append(message)
        print("Added message to chat. Total messages: \(chats[index].messages.count)")
        saveChatsToStorage()
        
        // Force UI update
        objectWillChange.send()
    }
    
    private func handleFailedMessage(_ message: ChatMessage, chatId: String) {
        DispatchQueue.main.async {
            self.alertMessage = "Message failed to send. Will retry when online."
            self.showAlert = true
            self.offlineQueue.append(message)
        }
        
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            if let msgIndex = chats[index].messages.firstIndex(where: { $0.id == message.id }) {
                chats[index].messages[msgIndex].isFailed = true
            }
        }
    }
    
    private func retryOfflineMessages() {
        for message in offlineQueue {
            wsManager.send(message: message.content)
        }
        offlineQueue.removeAll()
    }
    
    private func saveChatsToStorage() {
        if let encoded = try? JSONEncoder().encode(chats) {
            UserDefaults.standard.set(encoded, forKey: "savedChats")
        }
    }
    
    private func loadChatsFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "savedChats"),
           let decoded = try? JSONDecoder().decode([Chat].self, from: data) {
            chats = decoded
        }
    }
    
    func clearAllChats() {
        chats.removeAll()
        selectedChat = nil
        UserDefaults.standard.removeObject(forKey: "savedChats")
    }
}
