//
//  ResultPanelController.swift
//  selectedai
//

import AppKit
import SwiftUI
import Combine

@MainActor
final class ResultPanelController {
    static let shared = ResultPanelController()

    private struct Entry {
        let panel: ResultPanel
        let model: ResultPanelModel
        var cancellable: AnyCancellable?
    }

    private var entries: [Entry] = []

    private init() {}

    func show(skill: Skill, event: SelectionEvent) {
        // Close any non-pinned panel
        entries = entries.filter { entry in
            if !entry.model.isPinned {
                entry.panel.orderOut(nil)
                return false
            }
            return true
        }

        let model = ResultPanelModel()
        let panel = makePanel()

        // Sync pin state to panel
        var entry = Entry(panel: panel, model: model)
        entry.cancellable = model.$isPinned.sink { [weak panel] pinned in
            panel?.isPinned = pinned
        }
        entries.append(entry)

        let view = ResultPanelView(model: model) { [weak panel, weak self] in
            panel?.orderOut(nil)
            self?.entries.removeAll { $0.panel == panel }
        }
        panel.contentView = NSHostingView(rootView: AnyView(view))

        let size = CGSize(width: 420, height: 360)
        panel.setContentSize(size)
        panel.setFrameOrigin(panelOrigin(for: event.screenRect, size: size))
        panel.orderFrontRegardless()

        model.start(skill: skill, event: event)
    }

    func closeAll() {
        entries.forEach { $0.panel.orderOut(nil) }
        entries.removeAll()
    }

    private func makePanel() -> ResultPanel {
        let panel = ResultPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .titled, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isMovableByWindowBackground = true
        panel.minSize = CGSize(width: 280, height: 200)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] note in
            guard let self, let closedPanel = note.object as? ResultPanel else { return }
            self.entries.removeAll { $0.panel == closedPanel }
        }
        return panel
    }

    private func panelOrigin(for selectionRect: CGRect, size: CGSize) -> CGPoint {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(selectionRect.origin) })
            ?? NSScreen.main ?? NSScreen.screens[0]
        let margin: CGFloat = 8

        var origin = CGPoint(
            x: selectionRect.midX - size.width / 2,
            y: selectionRect.minY - size.height - margin
        )
        if origin.y < screen.visibleFrame.minY {
            origin.y = selectionRect.maxY + margin
        }
        origin.x = max(screen.visibleFrame.minX, min(origin.x, screen.visibleFrame.maxX - size.width))
        origin.y = max(screen.visibleFrame.minY, min(origin.y, screen.visibleFrame.maxY - size.height))
        return origin
    }
}
