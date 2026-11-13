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

        if let bundleID = event.sourceBundleID, rules.isAppDisabled(bundleID: bundleID) {
            return false
        }

        return true
    }
}
