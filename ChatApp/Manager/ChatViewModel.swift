////
////  ChatViewModel.swift
////  ChatApp
////
////  Created by Karthik Rashinkar on 28/11/25.
////
//
//import Foundation
//import Combine
//
//final class ChatViewModel: ObservableObject {
//    @Published private(set) var chats: [Chat] = []
//    @Published var selectedChatId: String?
//    @Published var isConnected: Bool = false
//    @Published var debugForceFailSends: Bool = false // to simulate failed sends
//    
//    private let wsManager: WebSocketManager
//    private var cancellables = Set<AnyCancellable>()
//    private let queuedKey = "queuedMessages_v1"
//    
//    // queued messages persisted so retry works across connectivity changes
//    // Using simple storage for demo; for production use a more robust store.
//    private var queuedMessages: [QueuedMessage] = [] {
//        didSet { saveQueue() }
//    }
//    
//    init(wsURL: URL) {
//        wsManager = WebSocketManager(url: wsURL)
//        setupWebSocketCallbacks()
//        NetworkMonitor.shared.$isConnected
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] connected in
//                self?.isConnected = connected
//                if connected { self?.retryQueuedMessages() }
//            }
//            .store(in: &cancellables)
//        loadQueue()
//        // create sample bot chats
//        createSampleChats()
//    }
//    
//    // Call this from App lifecycle to connect
//    func connect() {
//        wsManager.connect()
//    }
//    
//    func disconnect() {
//        wsManager.disconnect()
//    }
//    
//    private func setupWebSocketCallbacks() {
//        wsManager.onConnected = { [weak self] in
//            DispatchQueue.main.async { self?.isConnected = true }
//            self?.retryQueuedMessages()
//        }
//        wsManager.onDisconnected = { [weak self] in
//            DispatchQueue.main.async { self?.isConnected = false }
//        }
//        wsManager.onError = { err in
//            print("WS ERROR", err.localizedDescription)
//        }
//        wsManager.onReceive = { [weak self] text in
//            self?.handleIncoming(raw: text)
//        }
//    }
//    
//    // simple JSON envelope
//    struct WireMessage: Codable {
//        let chatId: String
//        let id: String
//        let content: String
//        let timestamp: Date
//        let sender: String
//    }
//    
//    private func handleIncoming(raw: String) {
//        // try parse JSON, else treat as plain text and put into a default chat
//        if let data = raw.data(using: .utf8),
//           let msg = try? JSONDecoder().decode(WireMessage.self, from: data) {
//            addIncomingMessage(to: msg.chatId, content: msg.content, id: msg.id, timestamp: msg.timestamp)
//        } else {
//            // fallback - to first chat
//            if let first = chats.first {
//                addIncomingMessage(to: first.id, content: raw, id: UUID().uuidString, timestamp: Date())
//            }
//        }
//    }
//    
//    // public send
//    func sendMessage(_ content: String, to chatId: String) {
//        let id = UUID().uuidString
//        let now = Date()
//        let outgoing = ChatMessage(id: id, content: content, timestamp: now, isOutgoing: true, isRead: true)
//        appendMessage(outgoing, to: chatId)
//        
//        // prepare wire message JSON
//        let wire = WireMessage(chatId: chatId, id: id, content: content, timestamp: now, sender: "me")
//        guard let data = try? JSONEncoder().encode(wire),
//              let txt = String(data: data, encoding: .utf8) else { return }
//        
//        // simulate forced failure when debug toggle is on
//        if debugForceFailSends {
//            enqueueMessage(chatId: chatId, wireText: txt, localMessage: outgoing)
//            return
//        }
//        
//        wsManager.send(text: txt) { [weak self] result in
//            switch result {
//            case .success:
//                // sent ok
//                break
//            case .failure:
//                // queue for retry
//                self?.enqueueMessage(chatId: chatId, wireText: txt, localMessage: outgoing)
//            }
//        }
//    }
//    
//    // Append to local chat
//    private func appendMessage(_ message: ChatMessage, to chatId: String) {
//        DispatchQueue.main.async {
//            if let idx = self.chats.firstIndex(where: { $0.id == chatId }) {
//                self.chats[idx].messages.append(message)
//            } else {
//                // create chat if missing
//                var c = Chat(id: chatId, title: "Bot \(self.chats.count + 1)", messages: [message])
//                self.chats.insert(c, at: 0)
//            }
//        }
//    }
//    
//    private func addIncomingMessage(to chatId: String, content: String, id: String, timestamp: Date) {
//        let msg = ChatMessage(id: id, content: content, timestamp: timestamp, isOutgoing: false, isRead: false)
//        appendMessage(msg, to: chatId)
//    }
//    
//    // MARK: - Queueing failed sends
//    struct QueuedMessage: Codable, Identifiable {
//        var id: String { localId }
//        let localId: String
//        let chatId: String
//        let wireText: String
//        let timestamp: Date
//    }
//    
//    private func enqueueMessage(chatId: String, wireText: String, localMessage: ChatMessage) {
//        let q = QueuedMessage(localId: localMessage.id, chatId: chatId, wireText: wireText, timestamp: Date())
//        queuedMessages.append(q)
//        // ensure message appears queued locally (already appended as outgoing)
//    }
//    
//    private func retryQueuedMessages() {
//        guard isConnected else { return }
//        guard !queuedMessages.isEmpty else { return }
//        // attempt to send all queued messages
//        let queueCopy = queuedMessages
//        for qm in queueCopy {
//            wsManager.send(text: qm.wireText) { [weak self] result in
//                switch result {
//                case .success:
//                    DispatchQueue.main.async {
//                        // remove from queue
//                        self?.queuedMessages.removeAll(where: { $0.localId == qm.localId })
//                    }
//                case .failure:
//                    // keep it queued
//                    break
//                }
//            }
//        }
//    }
//    
//    // Persistence of queue
//    private func saveQueue() {
//        if let data = try? JSONEncoder().encode(queuedMessages) {
//            UserDefaults.standard.set(data, forKey: queuedKey)
//        }
//    }
//    private func loadQueue() {
//        if let data = UserDefaults.standard.data(forKey: queuedKey),
//           let arr = try? JSONDecoder().decode([QueuedMessage].self, from: data) {
//            queuedMessages = arr
//        }
//    }
//    
//    // App spec: chats cleared on app close.
//    // We'll expose a method to clear local chats - call from AppDelegate or scene phase .background
//    func clearChatsOnAppClose() {
//        // Keep queued messages (so retries can be attempted), but clear UI chats
//        // If you prefer clearing queued messages too, change this.
//        DispatchQueue.main.async {
//            self.chats.removeAll()
//            self.selectedChatId = nil
//        }
//    }
//    
//    // convenience - sample chats
//    private func createSampleChats() {
//        let bot1 = Chat(id: "bot_1", title: "Weather Bot", messages: [
//            ChatMessage(id: UUID().uuidString, content: "Hi! Ask me about the weather.", timestamp: Date().addingTimeInterval(-3600), isOutgoing: false, isRead: true)
//        ])
//        let bot2 = Chat(id: "bot_2", title: "News Bot", messages: [
//            ChatMessage(id: UUID().uuidString, content: "Welcome! Get daily news summaries.", timestamp: Date().addingTimeInterval(-7200), isOutgoing: false, isRead: true)
//        ])
//        self.chats = [bot1, bot2]
//    }
//}
