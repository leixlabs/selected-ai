//
//  SelectionFilter.swift
//  selectedai
//

import Foundation

/// Decides whether a SelectionEvent should trigger the toolbar based on disabled rules.
@MainActor
final class SelectionFilter {
    static let shared = SelectionFilter()
    private init() {}

    /// Returns true if the toolbar should be shown for this event.
    func shouldShow(event: SelectionEvent, store: AppDataStore, isGloballyEnabled: Bool) -> Bool {
        guard isGloballyEnabled else { return false }

        let rules = store.disabledRules

        if let bundleID = event.sourceBundleID {
            // App-level check
            if rules.isAppDisabled(bundleID: bundleID) { return false }

            // Site-level check (only for Safari/Chrome)
            if let urlString = BrowserURLFetcher.currentURL(bundleID: bundleID) {
                if rules.isDomainDisabled(urlString: urlString) { return false }
            }
        }

        return true
    }
}
