//
//  DisabledRulesTests.swift
//  selectedaiTests
//

import XCTest
@testable import selectedai

final class DisabledRulesTests: XCTestCase {

    // MARK: - Domain normalization

    func testNormalizePlainDomain() {
        XCTAssertEqual(DisabledRules.normalizeDomain("example.com"), "example.com")
    }

    func testNormalizeURLToDomain() {
        XCTAssertEqual(DisabledRules.normalizeDomain("https://example.com/path?q=1"), "example.com")
    }

    func testNormalizeStripsWWW() {
        XCTAssertEqual(DisabledRules.normalizeDomain("www.example.com"), "example.com")
    }

    func testNormalizeLowercase() {
        XCTAssertEqual(DisabledRules.normalizeDomain("EXAMPLE.COM"), "example.com")
    }

    func testNormalizeInvalidReturnsNil() {
        XCTAssertNil(DisabledRules.normalizeDomain("not a domain"))
        XCTAssertNil(DisabledRules.normalizeDomain("nodot"))
    }

    // MARK: - Domain matching

    func testExactDomainMatch() {
        var rules = DisabledRules.empty
        rules.disabledDomains = ["example.com"]
        XCTAssertTrue(rules.isDomainDisabled(urlString: "https://example.com/page"))
    }

    func testSubdomainMatch() {
        var rules = DisabledRules.empty
        rules.disabledDomains = ["example.com"]
        XCTAssertTrue(rules.isDomainDisabled(urlString: "https://news.example.com/article"))
        XCTAssertTrue(rules.isDomainDisabled(urlString: "https://a.b.example.com"))
    }

    func testNonMatchingDomain() {
        var rules = DisabledRules.empty
        rules.disabledDomains = ["example.com"]
        XCTAssertFalse(rules.isDomainDisabled(urlString: "https://other.com"))
        XCTAssertFalse(rules.isDomainDisabled(urlString: "https://notexample.com"))
    }

    func testEmptyRulesNeverDisable() {
        let rules = DisabledRules.empty
        XCTAssertFalse(rules.isDomainDisabled(urlString: "https://anything.com"))
        XCTAssertFalse(rules.isAppDisabled(bundleID: "com.apple.Safari"))
    }

    // MARK: - App bundle ID matching

    func testBundleIDMatch() {
        var rules = DisabledRules.empty
        rules.disabledBundleIDs = ["com.example.App"]
        XCTAssertTrue(rules.isAppDisabled(bundleID: "com.example.App"))
        XCTAssertFalse(rules.isAppDisabled(bundleID: "com.example.Other"))
    }
}
