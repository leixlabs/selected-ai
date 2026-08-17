//
//  Provider.swift
//  selectedai
//

import Foundation

/// An LLM provider configuration.
struct Provider: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var protocolType: ProtocolType
    var baseURL: String
    var modelID: String
    var isActive: Bool

    enum ProtocolType: String, Codable, CaseIterable {
        case openAI = "openai"
        case anthropic = "anthropic"

        var displayName: String {
            switch self {
            case .openAI: return "OpenAI"
            case .anthropic: return "Anthropic"
            }
        }
    }

    /// Returns a normalized base URL: trimmed, no trailing slash, with /v1 appended if missing.
    var normalizedBaseURL: String {
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        url = url.hasSuffix("/") ? String(url.dropLast()) : url
        if !url.hasSuffix("/v1") {
            url += "/v1"
        }
        return url
    }
}
