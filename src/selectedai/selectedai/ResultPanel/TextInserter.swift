//
//  TextInserter.swift
//  selectedai
//

import AppKit
import OSLog

private let log = Logger(subsystem: "ai.selected", category: "TextInserter")

/// Writes text into the focused input of another app.
/// 1) Tries the Accessibility API (AXSelectedText) on the source app's focused element.
/// 2) Falls back to pasteboard + simulated Cmd+V after returning focus to the source app.
/// Requires Accessibility permission.
enum TextInserter {
    @MainActor
    static func insert(_ text: String, original: String, into bundleID: String?, replacingSelection: Bool) {
        guard !text.isEmpty else { return }
        guard AXIsProcessTrusted() else {
            log.error("Not trusted for Accessibility")
            AccessibilityManager.shared.requestPermission()
            return
        }
        guard let bundleID,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            log.error("Source app not found bundleID=\(bundleID ?? "nil")")
            return
        }

        // "Insert" = keep the original selection and append the translation after it.
        let newText = replacingSelection ? text : original + "\n" + text

        // 1) Accessibility API.
        if setSelectedText(newText, pid: app.processIdentifier) {
            log.info("Inserted via AX")
            return
        }

        // 2) Pasteboard + Cmd+V.
        log.info("AX insert failed, falling back to paste")
        let pb = NSPasteboard.general
        let saved: [[(NSPasteboard.PasteboardType, Data)]] = (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { t in item.data(forType: t).map { (t, $0) } }
        }
        pb.clearContents()
        pb.setString(newText, forType: .string)

        Task { @MainActor in
            // Hand keyboard focus back to the source app and wait until it is frontmost.
            NSApp.keyWindow?.resignKey()
            NSApp.deactivate()
            app.activate(from: NSRunningApplication.current, options: [])
            for _ in 0..<20 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { break }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
            log.info("Posting Cmd+V frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")")
            post(key: 0x09, flags: .maskCommand)
            try? await Task.sleep(nanoseconds: 500_000_000)

            pb.clearContents()
            let items: [NSPasteboardItem] = saved.map { entries in
                let item = NSPasteboardItem()
                for (t, d) in entries { item.setData(d, forType: t) }
                return item
            }
            if !items.isEmpty { pb.writeObjects(items) }
        }
    }

    private static func setSelectedText(_ text: String, pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return false }
        let element = focused as! AXUIElement // swiftlint:disable:this force_cast

        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }

    private static func post(key: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
