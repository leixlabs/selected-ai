//
//  DisabledRule.swift
//  selectedai
//

import Foundation

/// Rules for disabling the toolbar in specific apps or websites.
struct DisabledRules: Codable, Equatable {
    /// Bundle IDs of apps where the toolbar is disabled.
    var disabledBundleIDs: [String]
    /// Normalized domains where the toolbar is disabled (includes all subdomains).
    var disabledDomains: [String]

    static let empty = DisabledRules(disabledBundleIDs: [], disabledDomains: [])
}

extension DisabledRules {
    /// Returns true if the given bundle ID is in the disabled list.
    func isAppDisabled(bundleID: String) -> Bool {
        disabledBundleIDs.contains(bundleID)
    }

    /// Returns true if the given URL's host matches any disabled domain (including subdomains).
    func isDomainDisabled(urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
        return disabledDomains.contains { domain in
            host == domain || host.hasSuffix("." + domain)
        }
    }

    /// Normalizes a user-entered domain or URL string to a bare domain.
    static func normalizeDomain(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // If it looks like a URL, parse it
        if trimmed.contains("://"), let host = URL(string: trimmed)?.host {
            return host
        }
        // Strip www prefix for convenience
        let domain = trimmed.hasPrefix("www.") ? String(trimmed.dropFirst(4)) : trimmed
        // Basic validation: must contain a dot and no spaces
        guard domain.contains("."), !domain.contains(" ") else { return nil }
        return domain
    }
}
