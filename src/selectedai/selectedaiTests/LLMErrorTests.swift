//
//  LLMErrorTests.swift
//  selectedaiTests
//

import XCTest
@testable import selectedai

final class LLMErrorTests: XCTestCase {

    func testAllErrorsHaveDescriptions() {
        let errors: [LLMError] = [
            .noActiveProvider,
            .invalidURL("bad"),
            .authenticationFailed("401"),
            .contextLimitExceeded,
            .networkError(URLError(.timedOut)),
            .timeout,
            .modelError("overloaded"),
            .protocolError("unexpected format"),
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testAuthErrorContainsDetail() {
        let detail = "Invalid API key"
        let error = LLMError.authenticationFailed(detail)
        XCTAssertTrue(error.errorDescription!.contains(detail))
    }

    func testNoProviderErrorMentionsSetting() {
        let error = LLMError.noActiveProvider
        XCTAssertTrue(error.errorDescription!.contains("设置"))
    }
}
