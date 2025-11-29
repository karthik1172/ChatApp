//
//  ChatDetailView.swift
//  ChatApp
//
//  Created by Karthik Rashinkar on 28/11/25.
//

import SwiftUI

struct ChatDetailView: View {
    @State var chat: Chat
    @ObservedObject var chatManager: ChatManager
    @State private var messageText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chat.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                    .onChange(of: chat.messages.count) {
                        if let lastMessage = chat.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            HStack(spacing: 8) {
                TextField("Type message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        chatManager.sendMessage(trimmed, to: chat.id)
        messageText = ""
        isFocused = true
        
        if let index = chatManager.chats.firstIndex(where: { $0.id == chat.id }) {
            chat = chatManager.chats[index]
        }
    }
}
