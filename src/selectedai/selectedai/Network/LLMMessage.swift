//
//  LLMMessage.swift
//  selectedai
//

import Foundation

struct LLMMessage: Codable {
    enum Role: String, Codable {
        case system, user, assistant
    }
    let role: Role
    let content: String
}
