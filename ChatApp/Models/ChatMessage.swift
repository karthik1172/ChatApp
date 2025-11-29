//
//  ChatMessage.swift
//  ChatApp
//
//  Created by Karthik Rashinkar on 28/11/25.
//


import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: String
    let content: String
    let timestamp: Date
    let isOutgoing: Bool
    var isFailed: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, content, timestamp, isOutgoing, isFailed
    }
}

struct Chat: Identifiable, Codable {
    let id: String
    var messages: [ChatMessage]
    var lastMessage: ChatMessage? {
        messages.last
    }
    
    var unreadCount: Int = 0
}
