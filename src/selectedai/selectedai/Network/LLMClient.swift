//
//  LLMClient.swift
//  selectedai
//

import Foundation

/// Unified LLM client that dispatches to the correct protocol implementation.
struct LLMClient {

    /// Returns a streaming token sequence for the given messages using the active provider.
    static func stream(
        messages: [LLMMessage],
        provider: Provider
    ) -> AsyncThrowingStream<String, Error> {
        let token = KeychainStore.loadToken(forProviderID: provider.id) ?? ""
        switch provider.protocolType {
        case .openAI:
            return OpenAIClient(provider: provider, token: token).stream(messages: messages)
        case .anthropic:
            return AnthropicClient(provider: provider, token: token).stream(messages: messages)
        }
    }

    /// Non-streaming connectivity test. Throws LLMError on failure.
    static func testConnection(provider: Provider) async throws {
        let token = KeychainStore.loadToken(forProviderID: provider.id) ?? ""
        switch provider.protocolType {
        case .openAI:
            try await OpenAIClient(provider: provider, token: token).testConnection()
        case .anthropic:
            try await AnthropicClient(provider: provider, token: token).testConnection()
        }
    }
}
