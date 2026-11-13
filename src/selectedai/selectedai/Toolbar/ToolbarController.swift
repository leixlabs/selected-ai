//
//  ToolbarController.swift
//  selectedai
//

import AppKit
import Combine

/// Wires SelectionMonitor → SelectionFilter → ToolbarPanel.
@MainActor
final class ToolbarController {
    static let shared = ToolbarController()

    private let panel = ToolbarPanel()
    private let store = AppDataStore.shared
    private let filter = SelectionFilter.shared
    private var cancellables = Set<AnyCancellable>()
    private var shownText: String?

    var isGloballyEnabled: Bool = true {
        didSet { if !isGloballyEnabled { panel.hide() } }
    }

    var onSkillSelected: ((Skill, SelectionEvent) -> Void)? {
        get { panel.onSkillSelected }
        set { panel.onSkillSelected = newValue }
    }

    private init() {
        SelectionMonitor.shared.selectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleSelectionEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleSelectionEvent(_ event: SelectionEvent?) {
        guard let event else {
            shownText = nil
            panel.hide()
            return
        }
        guard filter.shouldShow(event: event, store: store, isGloballyEnabled: isGloballyEnabled) else {
            shownText = nil
            panel.hide()
            return
        }
        // Clipboard fallback and AX path can report the same selection back to back.
        if panel.isVisible, shownText == event.text { return }
        shownText = event.text
        let sorted = store.skills.sorted { $0.sortOrder < $1.sortOrder }
        panel.show(event: event, skills: sorted)
    }
}
