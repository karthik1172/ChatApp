//
//  ContentView.swift
//  ChatApp
//
//  Created by Karthik Rashinkar on 28/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var wsManager = WebSocketManager()
    @StateObject private var chatManager: ChatManager
    
    init() {
        let wsManager = WebSocketManager()
        self._wsManager = StateObject(wrappedValue: wsManager)
        self._chatManager = StateObject(wrappedValue: ChatManager(wsManager: wsManager))
    }
    
    var body: some View {
        ZStack {
            if chatManager.chats.isEmpty {
                emptyState
            } else {
                //chatListView
                
                ChatDetailView(chat: chatManager.chats.last ?? Chat(id: "", messages: []), chatManager: chatManager)
                
            }
            
            if wsManager.isOffline {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("No Internet Connection")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    Spacer()
                }
            }
        }
        .alert("Status", isPresented: $chatManager.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(chatManager.alertMessage)
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Chats")
                .font(.headline)
            Text("Create a new chat to get started")
                .font(.subheadline)
                .foregroundColor(.gray)
            Button(action: createDefaultChat) {
                Text("Start New Chat")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
    }
    
    var chatListView: some View {
        NavigationStack {
            List {
                ForEach(chatManager.chats) { chat in
                    NavigationLink(destination: ChatDetailView(chat: chat, chatManager: chatManager)) {
                        ChatListRowView(chat: chat)
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createDefaultChat) {
                        Image(systemName: "plus.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", action: { chatManager.clearAllChats() })
                }
            }
        }
    }
    
    func createDefaultChat() {
        let chatId = UUID().uuidString
        _ = chatManager.createOrGetChat(id: chatId)
    }
}

#Preview {
    ContentView()
}
