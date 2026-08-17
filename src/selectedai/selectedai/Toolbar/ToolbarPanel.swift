//
//  ToolbarPanel.swift
//  selectedai
//

import AppKit
import SwiftUI
import OSLog

private let log = Logger(subsystem: "ai.selected", category: "ToolbarPanel")

/// The floating selection toolbar panel.
@MainActor
final class ToolbarPanel: NSPanel {

    var onSkillSelected: ((Skill, SelectionEvent) -> Void)?
    private var mouseDownMonitor: Any?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isMovableByWindowBackground = false
    }

    func show(event: SelectionEvent, skills: [Skill]) {
        log.info("Show toolbar bundleID=\(event.sourceBundleID ?? "unknown") rect=\(event.screenRect.debugDescription)")
        startMouseMonitor()
        let store = AppDataStore.shared
        let browserURL = event.sourceBundleID.flatMap { BrowserURLFetcher.currentURL(bundleID: $0) }

        let disableApp: (() -> Void)? = event.sourceBundleID.map { bid in
            { [weak self] in
                store.addDisabledBundleID(bid)
                self?.hide()
            }
        }
        let disableSite: (() -> Void)? = browserURL.flatMap { url in
            guard DisabledRules.normalizeDomain(url) != nil else { return nil }
            return { [weak self] in
                store.addDisabledDomain(url)
                self?.hide()
            }
        }

        let view = ToolbarView(
            skills: skills,
            sourceBundleID: event.sourceBundleID,
            browserURL: browserURL,
            onSkillTapped: { [weak self] skill in
                self?.hide()
                self?.onSkillSelected?(skill, event)
            },
            onDisableApp: disableApp,
            onDisableSite: disableSite
        )
        contentView = NSHostingView(rootView: view)

        let size = (contentView as? NSHostingView<ToolbarView>)?.fittingSize ?? CGSize(width: 300, height: 44)
        let origin = toolbarOrigin(for: event.screenRect, size: size)
        setContentSize(size)
        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    func hide() {
        stopMouseMonitor()
        orderOut(nil)
    }

    private func startMouseMonitor() {
        guard mouseDownMonitor == nil else { return }
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.isVisible else { return }
            let loc = NSEvent.mouseLocation
            if !self.frame.contains(loc) {
                Task { @MainActor in self.hide() }
            }
        }
    }

    private func stopMouseMonitor() {
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
    }

    // MARK: - Esc to close

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            hide()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Positioning

    private func toolbarOrigin(for selectionRect: CGRect, size: CGSize) -> CGPoint {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(selectionRect.origin) })
            ?? NSScreen.main ?? NSScreen.screens[0]
        let margin: CGFloat = 8

        var origin = CGPoint(
            x: selectionRect.midX - size.width / 2,
            y: selectionRect.maxY + margin
        )
        if origin.y + size.height > screen.visibleFrame.maxY {
            origin.y = selectionRect.minY - size.height - margin
        }
        origin.x = max(screen.visibleFrame.minX, min(origin.x, screen.visibleFrame.maxX - size.width))
        origin.y = max(screen.visibleFrame.minY, min(origin.y, screen.visibleFrame.maxY - size.height))
        return origin
    }
}
