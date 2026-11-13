//
//  SelectionMonitor.swift
//  selectedai
//

import AppKit
import Combine
import OSLog

private let log = Logger(subsystem: "ai.selected", category: "SelectionMonitor")

/// Monitors text selection changes across all apps using the Accessibility API.
@MainActor
final class SelectionMonitor {
    static let shared = SelectionMonitor()

    /// Emits stable selection events (debounced, filtered).
    let selectionPublisher = PassthroughSubject<SelectionEvent?, Never>()

    private var axObserver: AXObserver?
    private var observedPID: pid_t = 0
    private var debounceTask: Task<Void, Never>?

    private let minCharCount = 2
    private let debounceInterval: Duration = .milliseconds(200)

    private var mouseDownLocation: NSPoint = .zero
    private var mouseMonitors: [Any] = []

    private init() {
        startFrontAppMonitoring()
        startMouseMonitoring()
    }

    // MARK: - Clipboard Fallback (apps that don't expose AXSelectedText, e.g. Google Docs)

    private func startMouseMonitoring() {
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            let loc = NSEvent.mouseLocation
            Task { @MainActor in self?.mouseDownLocation = loc }
        }) { mouseMonitors.append(m) }

        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] event in
            let loc = NSEvent.mouseLocation
            let clicks = event.clickCount
            Task { @MainActor in self?.handleMouseUp(at: loc, clickCount: clicks) }
        }) { mouseMonitors.append(m) }
    }

    private func handleMouseUp(at location: NSPoint, clickCount: Int) {
        guard AXIsProcessTrusted() else { return }
        let dragged = hypot(location.x - mouseDownLocation.x, location.y - mouseDownLocation.y) > 5
        guard dragged || clickCount >= 2 else { return }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            // AX path already produced a selection; nothing to do.
            if self.readCurrentSelection() != nil { return }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
            guard let text = await Self.copySelectionViaClipboard(), text.count >= self.minCharCount else { return }
            log.info("Selection via clipboard fallback bundleID=\(bundleID ?? "unknown")")
            let rect = CGRect(x: location.x - 50, y: location.y, width: 100, height: 20)
            self.selectionPublisher.send(SelectionEvent(text: text, screenRect: rect, sourceBundleID: bundleID))
        }
    }

    /// Simulates Cmd+C, reads the copied text, then restores the previous clipboard contents.
    private static func copySelectionViaClipboard() async -> String? {
        let pb = NSPasteboard.general
        let saved: [[(NSPasteboard.PasteboardType, Data)]] = (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
        let before = pb.changeCount

        let src = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 8
        let down = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        var text: String?
        for _ in 0..<15 {
            try? await Task.sleep(for: .milliseconds(20))
            if pb.changeCount != before {
                text = pb.string(forType: .string)
                break
            }
        }

        if pb.changeCount != before {
            pb.clearContents()
            let items: [NSPasteboardItem] = saved.map { entries in
                let item = NSPasteboardItem()
                for (type, data) in entries { item.setData(data, forType: type) }
                return item
            }
            if !items.isEmpty { pb.writeObjects(items) }
        }
        return text
    }

    // MARK: - Front App Monitoring

    private func startFrontAppMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontAppDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // Register for current front app
        if let app = NSWorkspace.shared.frontmostApplication {
            registerObserver(for: app.processIdentifier)
        }
    }

    @objc private func frontAppDidChange(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        registerObserver(for: app.processIdentifier)
    }

    /// Re-registers the AX observer for the current frontmost app.
    /// Call this after Accessibility permission is granted — otherwise the observer
    /// (created at launch while untrusted) keeps delivering nothing until the user
    /// switches apps. Making this public lets AppDelegate trigger it on permission change.
    func reregister() {
        teardownObserver()
        if let app = NSWorkspace.shared.frontmostApplication {
            registerObserver(for: app.processIdentifier)
        }
    }

    private func teardownObserver() {
        if let old = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(old), .defaultMode)
        }
        axObserver = nil
        observedPID = 0
    }

    // MARK: - AXObserver

    private func registerObserver(for pid: pid_t) {
        guard pid != observedPID else { return }
        // Tear down previous observer
        if let old = axObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(old),
                .defaultMode
            )
        }
        axObserver = nil
        observedPID = 0

        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<SelectionMonitor>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in
                monitor.handleSelectionChanged()
            }
        }
        let status = AXObserverCreate(pid, callback, &observer)
        guard status == .success, let obs = observer else { return }

        let appElement = AXUIElementCreateApplication(pid)
        // Ask Chromium/Electron apps to build their web accessibility tree.
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        let result = AXObserverAddNotification(
            obs,
            appElement,
            kAXSelectedTextChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        guard result == .success else {
            log.error("AXObserverAddNotification failed for pid=\(pid) result=\(result.rawValue)")
            return
        }
        log.info("AX observer registered for pid=\(pid)")

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        axObserver = obs
        observedPID = pid
    }

    // MARK: - Selection Handler

    private func handleSelectionChanged() {
        debounceTask?.cancel()

        let quick = readCurrentSelection()
        if quick == nil {
                selectionPublisher.send(nil)
            return
        }

        debounceTask = Task {
            do {
                try await Task.sleep(for: debounceInterval)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let event = readCurrentSelection()
            if let event {
                log.info("Selection: \(event.text.prefix(60), privacy: .private) rect=\(event.screenRect.debugDescription)")
            }
            selectionPublisher.send(event)
        }
    }

    private func readCurrentSelection() -> SelectionEvent? {
        guard observedPID != 0 else { return nil }
        let appElement = AXUIElementCreateApplication(observedPID)

        // Get focused element
        var focusedValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedElement = focusedValue else { return nil }
        let element = focusedElement as! AXUIElement // swiftlint:disable:this force_cast

        // Read selected text
        var textValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &textValue) == .success,
              let text = textValue as? String,
              text.count >= minCharCount else {
            return nil
        }

        let rect = readSelectionRect(element: element)
        let app = NSRunningApplication(processIdentifier: observedPID)
        return SelectionEvent(
            text: text,
            screenRect: rect,
            sourceBundleID: app?.bundleIdentifier
        )
    }

    // MARK: - Rect Reading with Fallback

    private func readSelectionRect(element: AXUIElement) -> CGRect {
        if let rect = selectionBoundsViaRange(element: element), isReasonableRect(rect) {
            return rect
        }
        var boundsValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, "AXInsertionPointBounds" as CFString, &boundsValue) == .success,
           let boundsDict = boundsValue,
           let rect = cgRectFromAXValue(boundsDict as AnyObject),
           isReasonableRect(rect) {
            return rect
        }
        let mouse = NSEvent.mouseLocation
        if NSScreen.screens.contains(where: { $0.frame.contains(mouse) }) {
            return CGRect(x: mouse.x - 50, y: mouse.y, width: 100, height: 20)
        }
        log.info("Rect source: window center fallback")
        return windowCenterRect(element: element)
    }

    private func isReasonableRect(_ rect: CGRect) -> Bool {
        guard rect.width > 0 || rect.height > 0 else { return false }
        return NSScreen.screens.contains(where: { $0.frame.intersects(rect) })
    }

    private func selectionBoundsViaRange(element: AXUIElement) -> CGRect? {
        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeAX = rangeValue else { return nil }

        var boundsValue: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeAX,
            &boundsValue
        ) == .success, let bv = boundsValue else { return nil }

        return cgRectFromAXValue(bv)
    }

    private func cgRectFromAXValue(_ value: AnyObject) -> CGRect? {
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil } // swiftlint:disable:this force_cast
        // AX rects use top-left origin in screen space (flipped Y from AppKit)
        return NSScreen.convertFromAXCoordinates(rect)
    }

    private func windowCenterRect(element: AXUIElement) -> CGRect {
        // Walk up to window
        var current: AXUIElement = element
        for _ in 0..<10 {
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleValue)
            if (roleValue as? String) == kAXWindowRole { break }
            var parentValue: AnyObject?
            if AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentValue) == .success,
               let parent = parentValue {
                current = parent as! AXUIElement // swiftlint:disable:this force_cast
            } else { break }
        }
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        AXUIElementCopyAttributeValue(current, kAXPositionAttribute as CFString, &posValue)
        AXUIElementCopyAttributeValue(current, kAXSizeAttribute as CFString, &sizeValue)
        var position = CGPoint.zero
        var size = CGSize(width: 400, height: 300)
        if let pv = posValue { AXValueGetValue(pv as! AXValue, .cgPoint, &position) } // swiftlint:disable:this force_cast
        if let sv = sizeValue { AXValueGetValue(sv as! AXValue, .cgSize, &size) } // swiftlint:disable:this force_cast
        // AX uses top-left origin; convert the window rect to AppKit coordinates before computing center
        let axRect = CGRect(origin: position, size: size)
        let appKitRect = NSScreen.convertFromAXCoordinates(axRect)
        let center = CGPoint(x: appKitRect.midX, y: appKitRect.midY)
        return CGRect(x: center.x - 50, y: center.y - 10, width: 100, height: 20)
    }
}

// MARK: - Coordinate Conversion

private extension NSScreen {
    /// Converts an AX (top-left origin, screen coordinates) rect to AppKit screen coordinates.
    static func convertFromAXCoordinates(_ rect: CGRect) -> CGRect {
        guard let screen = NSScreen.screens.first else { return rect }
        let screenHeight = screen.frame.height
        return CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
