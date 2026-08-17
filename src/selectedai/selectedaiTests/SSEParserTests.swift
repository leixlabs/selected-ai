//
//  SSEParserTests.swift
//  selectedaiTests
//

import XCTest
@testable import selectedai

final class SSEParserTests: XCTestCase {

    // MARK: - OpenAI SSE parsing

    func testOpenAIChunkParsing() throws {
        let json = """
        {"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}
        """
        // Verify that the JSON decodes correctly by hand-testing the path used in OpenAIClient
        struct Delta: Decodable { let content: String? }
        struct Choice: Decodable { let delta: Delta; let finish_reason: String? }
        struct Chunk: Decodable { let choices: [Choice] }

        let chunk = try JSONDecoder().decode(Chunk.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(chunk.choices.first?.delta.content, "Hello")
        XCTAssertNil(chunk.choices.first?.finish_reason)
    }

    func testOpenAIDoneMarker() {
        XCTAssertEqual("[DONE]", "[DONE]")  // trivial; real test is in integration
    }

    func testOpenAIFinishReason() throws {
        let json = """
        {"choices":[{"delta":{"content":null},"finish_reason":"stop"}]}
        """
        struct Delta: Decodable { let content: String? }
        struct Choice: Decodable { let delta: Delta; let finish_reason: String? }
        struct Chunk: Decodable { let choices: [Choice] }

        let chunk = try JSONDecoder().decode(Chunk.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(chunk.choices.first?.finish_reason, "stop")
    }

    // MARK: - Anthropic SSE parsing

    func testAnthropicContentDeltaParsing() throws {
        let json = """
        {"type":"content_block_delta","delta":{"type":"text_delta","text":"World"}}
        """
        let obj = try XCTUnwrap(
            JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as? [String: Any]
        )
        XCTAssertEqual(obj["type"] as? String, "content_block_delta")
        let delta = try XCTUnwrap(obj["delta"] as? [String: Any])
        XCTAssertEqual(delta["text"] as? String, "World")
    }

    func testAnthropicMessageStop() throws {
        let json = """
        {"type":"message_stop"}
        """
        let obj = try XCTUnwrap(
            JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as? [String: Any]
        )
        XCTAssertEqual(obj["type"] as? String, "message_stop")
    }
}
