//
//  OpenAIClient.swift
//  selectedai
//

import Foundation
import OSLog

private let log = Logger(subsystem: "ai.selected", category: "OpenAIClient")

/// Streams chat completions from an OpenAI-compatible API.
struct OpenAIClient {
    let provider: Provider
    let token: String

    private struct RequestBody: Encodable {
        let model: String
        let messages: [LLMMessage]
        let stream: Bool = true
    }

    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
            }
            let delta: Delta
            let finish_reason: String?
        }
        let choices: [Choice]
        let error: APIError?
    }

    private struct APIError: Decodable {
        let message: String
        let type: String?
        let code: String?
    }

    private struct ErrorResponse: Decodable {
        let error: APIError
    }

    func stream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = try makeURL()
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 10

                    let body = RequestBody(model: provider.modelID, messages: messages)
                    request.httpBody = try JSONEncoder().encode(body)

                    log.info("POST \(url.absoluteString) model=\(provider.modelID)")
                    let session = URLSession(configuration: .ephemeral)
                    let (byteStream, response) = try await session.bytes(for: request)

                    if let http = response as? HTTPURLResponse {
                        log.info("HTTP \(http.statusCode)")
                        guard http.statusCode == 200 else {
                            // Collect error body for diagnosis
                            var bodyLines: [String] = []
                            for try await line in byteStream.lines { bodyLines.append(line) }
                            let body = bodyLines.joined(separator: "\n")
                            log.error("API error body: \(body)")
                            let detail = (try? JSONDecoder().decode(ErrorResponse.self, from: Data(body.utf8)))?.error.message ?? "HTTP \(http.statusCode)"
                            continuation.finish(throwing: httpError(statusCode: http.statusCode, detail: detail))
                            return
                        }
                    }

                    var tokenCount = 0
                    for try await line in byteStream.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if data.isEmpty || data == "[DONE]" { continue }
                        guard let chunk = try? JSONDecoder().decode(StreamChunk.self, from: Data(data.utf8)) else {
                            continue
                        }
                        if let errMsg = chunk.error?.message {
                            log.error("Stream chunk error: \(errMsg)")
                            continuation.finish(throwing: LLMError.modelError(errMsg))
                            return
                        }
                        if let text = chunk.choices.first?.delta.content {
                            tokenCount += 1
                            continuation.yield(text)
                        }
                        if chunk.choices.first?.finish_reason != nil { break }
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

    /// Non-streaming connectivity test.
    func testConnection() async throws {
        struct NonStreamBody: Encodable {
            let model: String
            let messages: [LLMMessage]
            let max_tokens: Int
        }
        let url = try makeURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = NonStreamBody(
            model: provider.modelID,
            messages: [LLMMessage(role: .user, content: "Hi")],
            max_tokens: 5
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            try handleHTTPError(statusCode: http.statusCode, data: data)
        }
    }

    // MARK: - Private

    private func makeURL() throws -> URL {
        let base = provider.normalizedBaseURL
        guard let url = URL(string: base + "/chat/completions") else {
            throw LLMError.invalidURL(base)
        }
        return url
    }

    private func handleHTTPError(statusCode: Int, data: Data) throws {
        guard statusCode != 200 else { return }
        let detail = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error.message
            ?? "HTTP \(statusCode)"
        throw httpError(statusCode: statusCode, detail: detail)
    }

    private func httpError(statusCode: Int, detail: String) -> LLMError {
        switch statusCode {
        case 401, 403: return .authenticationFailed(detail)
        case 429: return .modelError("请求频率超限，请稍后重试。")
        case 400 where detail.lowercased().contains("context"):
            return .contextLimitExceeded
        default: return .modelError(detail)
        }
    }
}
