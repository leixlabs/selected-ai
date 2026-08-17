//
//  SelectionEvent.swift
//  selectedai
//

import Foundation
import AppKit

/// Represents a stable text selection from any app.
struct SelectionEvent {
    let text: String
    /// Screen-space bounding rect of the selected text (may be a fallback location).
    let screenRect: CGRect
    let sourceBundleID: String?
}
