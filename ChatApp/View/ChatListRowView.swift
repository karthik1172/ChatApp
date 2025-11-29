//
//  ChatListRowView.swift
//  ChatApp
//
//  Created by Karthik Rashinkar on 28/11/25.
//

import SwiftUI

struct ChatListRowView: View {
    let chat: Chat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Chat: \(chat.id.prefix(8))")
                    .font(.headline)
                Spacer()
                Text(chat.lastMessage?.timestamp.formatted(date: .omitted, time: .shortened) ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            if let lastMessage = chat.lastMessage {
                HStack {
                    Text(lastMessage.content)
                        .lineLimit(1)
                        .foregroundColor(.gray)
                    Spacer()
                    if lastMessage.isFailed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}
