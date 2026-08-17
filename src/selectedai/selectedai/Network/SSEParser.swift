//
//  SSEParser.swift
//  selectedai
//

import Foundation

/// Parses Server-Sent Events from URLSession.AsyncBytes, yielding each "data:" field value.
func parseSSE(byteStream: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            var buffer: [String] = []
            do {
                for try await line in byteStream.lines {
                    if line.isEmpty {
                        if let dataLine = buffer.first(where: { $0.hasPrefix("data:") }) {
                            let value = String(dataLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            continuation.yield(value)
                        }
                        buffer.removeAll()
                    } else {
                        buffer.append(line)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
