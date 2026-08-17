//
//  BrowserURLFetcher.swift
//  selectedai
//

import AppKit

/// Fetches the current URL from Safari or Chrome via AppleScript.
enum BrowserURLFetcher {
    enum SupportedBrowser: String {
        case safari = "com.apple.Safari"
        case chrome = "com.google.Chrome"
    }

    /// Returns the current tab URL for the given browser bundle ID, or nil if unsupported / failed.
    static func currentURL(bundleID: String) -> String? {
        guard let browser = SupportedBrowser(rawValue: bundleID) else { return nil }
        let script: String
        switch browser {
        case .safari:
            script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    get URL of current tab of front window
                end if
            end tell
            """
        case .chrome:
            script = """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    get URL of active tab of front window
                end if
            end tell
            """
        }
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result.stringValue
    }
}
