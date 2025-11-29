//
//  MessageBubbleView.swift
//  ChatApp
//
//  Created by Karthik Rashinkar on 28/11/25.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isOutgoing {
                Spacer()
            }
            
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.isOutgoing ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isOutgoing ? .white : .black)
                    .cornerRadius(12)
                
                if message.isFailed {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption)
                        Text("Failed to send")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                }
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !message.isOutgoing {
                Spacer()
            }
        }
    }
}
