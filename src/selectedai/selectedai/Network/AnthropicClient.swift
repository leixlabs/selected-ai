//
//  AnthropicClient.swift
//  selectedai
//

import Foundation
import OSLog

private let log = Logger(subsystem: "ai.selected", category: "AnthropicClient")

/// Streams messages from an Anthropic-compatible API.
struct AnthropicClient {
    let provider: Provider
    let token: String

    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let max_tokens: Int
        let system: String?
        let messages: [Message]
        let stream: Bool = true
    }

    func stream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = try makeURL()
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue(token, forHTTPHeaderField: "x-api-key")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.timeoutInterval = 10

                    let body = buildBody(messages: messages)
                    request.httpBody = try JSONEncoder().encode(body)

                    log.info("POST \(url.absoluteString) model=\(provider.modelID)")
                    let session = URLSession(configuration: .ephemeral)
                    let (byteStream, response) = try await session.bytes(for: request)

                    if let http = response as? HTTPURLResponse {
                        log.info("HTTP \(http.statusCode)")
                        guard http.statusCode == 200 else {
                            var bodyLines: [String] = []
                            for try await line in byteStream.lines { bodyLines.append(line) }
                            let body = bodyLines.joined(separator: "\n")
                            log.error("API error body: \(body)")
                            let detail = extractErrorMessage(data: Data(body.utf8)) ?? "HTTP \(http.statusCode)"
                            continuation.finish(throwing: httpError(statusCode: http.statusCode, detail: detail))
                            return
                        }
                    }

                    var tokenCount = 0
                    for try await line in byteStream.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if data.isEmpty || data == "[DONE]" { continue }
                        guard let jsonData = data.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                        else { continue }

                        if let errObj = obj["error"] as? [String: Any],
                           let msg = errObj["message"] as? String {
                            log.error("Stream error: \(msg)")
                            continuation.finish(throwing: classifyAnthropicError(msg, type: errObj["type"] as? String))
                            return
                        }
                        let eventType = obj["type"] as? String
                        if eventType == "content_block_delta",
                           let delta = obj["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            tokenCount += 1
                            continuation.yield(text)
                        } else if eventType == "message_stop" {
                            break
                        }
                    }
                    log.info("Stream done tokenChunks=\(tokenCount)")
                    continuation.finish()
                } catch let error as LLMError {
                    log.error("LLMError: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                } catch {
                    log.error("NetworkError: \(error.localizedDescription)")
                    continuation.finish(throwing: LLMError.networkError(error))
                }
            }
        }
    }

    func testConnection() async throws {
        let url = try makeURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10

        let body = buildBody(messages: [LLMMessage(role: .user, content: "Hi")])
        var nonStream = body
        // Override stream to false for test
        struct NonStreamBody: Encodable {
            let model: String
            let max_tokens: Int
            let messages: [RequestBody.Message]
            let stream: Bool = false
        }
        let testBody = NonStreamBody(
            model: provider.modelID,
            max_tokens: 5,
            messages: [.init(role: "user", content: "Hi")]
        )
        request.httpBody = try JSONEncoder().encode(testBody)
        _ = nonStream

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let detail = extractErrorMessage(data: data) ?? "HTTP \(http.statusCode)"
            throw httpError(statusCode: http.statusCode, detail: detail)
        }
    }

    // MARK: - Private

    private func makeURL() throws -> URL {
        let base = provider.normalizedBaseURL
        guard let url = URL(string: base + "/messages") else {
            throw LLMError.invalidURL(base)
        }
        return url
    }

    private func buildBody(messages: [LLMMessage]) -> RequestBody {
        let systemMessage = messages.first(where: { $0.role == .system })?.content
        let chatMessages = messages.filter { $0.role != .system }.map {
            RequestBody.Message(role: $0.role.rawValue, content: $0.content)
        }
        return RequestBody(
            model: provider.modelID,
            max_tokens: 4096,
            system: systemMessage,
            messages: chatMessages
        )
    }

    private func httpError(statusCode: Int, detail: String = "") -> LLMError {
        switch statusCode {
        case 401: return .authenticationFailed(detail.isEmpty ? "API key 无效" : detail)
        case 403: return .authenticationFailed(detail.isEmpty ? "无访问权限" : detail)
        case 429: return .modelError("请求频率超限，请稍后重试。")
        default: return .modelError(detail.isEmpty ? "HTTP \(statusCode)" : detail)
        }
    }

    private func classifyAnthropicError(_ message: String, type: String?) -> LLMError {
        if type == "authentication_error" { return .authenticationFailed(message) }
        if type == "overloaded_error" { return .modelError(message) }
        if message.lowercased().contains("context") { return .contextLimitExceeded }
        return .modelError(message)
    }

    private func extractErrorMessage(data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any],
              let msg = error["message"] as? String else { return nil }
        return msg
    }
}
