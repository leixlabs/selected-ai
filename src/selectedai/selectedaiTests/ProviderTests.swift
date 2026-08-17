//
//  ProviderTests.swift
//  selectedaiTests
//

import XCTest
@testable import selectedai

final class ProviderTests: XCTestCase {

    // MARK: - URL normalization

    func testNormalizationAddsV1() {
        let p = makeProvider(baseURL: "https://api.openai.com")
        XCTAssertEqual(p.normalizedBaseURL, "https://api.openai.com/v1")
    }

    func testNormalizationStripsTrailingSlash() {
        let p = makeProvider(baseURL: "https://api.openai.com/")
        XCTAssertEqual(p.normalizedBaseURL, "https://api.openai.com/v1")
    }

    func testNormalizationKeepsExistingV1() {
        let p = makeProvider(baseURL: "https://api.openai.com/v1")
        XCTAssertEqual(p.normalizedBaseURL, "https://api.openai.com/v1")
    }

    func testNormalizationStripsSlashBeforeV1() {
        let p = makeProvider(baseURL: "https://custom.api.com/v1/")
        XCTAssertEqual(p.normalizedBaseURL, "https://custom.api.com/v1")
    }

    func testNormalizationTrimsWhitespace() {
        let p = makeProvider(baseURL: "  https://api.openai.com  ")
        XCTAssertEqual(p.normalizedBaseURL, "https://api.openai.com/v1")
    }

    // MARK: - Protocol types

    func testAllProtocolTypesHaveDisplayNames() {
        for type_ in Provider.ProtocolType.allCases {
            XCTAssertFalse(type_.displayName.isEmpty)
        }
    }

    // MARK: - Helper

    private func makeProvider(baseURL: String) -> Provider {
        Provider(id: UUID(), displayName: "Test", protocolType: .openAI,
                 baseURL: baseURL, modelID: "gpt-4o", isActive: true)
    }
}
