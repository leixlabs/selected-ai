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
            panel.hide()
            return
        }
        guard filter.shouldShow(event: event, store: store, isGloballyEnabled: isGloballyEnabled) else {
            panel.hide()
            return
        }
        let sorted = store.skills.sorted { $0.sortOrder < $1.sortOrder }
        panel.show(event: event, skills: sorted)
    }
}
