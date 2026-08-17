//
//  ResultPanel.swift
//  selectedai
//

import AppKit

/// NSPanel subclass that closes on Esc / click-outside when not pinned, and supports resizing.
final class ResultPanel: NSPanel {
    var isPinned: Bool = false
    private var mouseDownMonitor: Any?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 && !isPinned { // Esc
            close()
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }

    override func orderFrontRegardless() {
        super.orderFrontRegardless()
        startMouseMonitor()
    }

    override func close() {
        stopMouseMonitor()
        super.close()
    }

    override func orderOut(_ sender: Any?) {
        stopMouseMonitor()
        super.orderOut(sender)
    }

    private func startMouseMonitor() {
        guard mouseDownMonitor == nil else { return }
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.isVisible, !self.isPinned else { return }
            let loc = NSEvent.mouseLocation
            if !self.frame.contains(loc) {
                Task { @MainActor in self.close() }
            }
        }
    }

    private func stopMouseMonitor() {
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
    }
}
