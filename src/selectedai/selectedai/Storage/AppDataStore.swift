//
//  AppDataStore.swift
//  selectedai
//

import Foundation
import Combine
import SwiftUI

/// Central observable store for all persisted app data.
@MainActor
final class AppDataStore: ObservableObject {
    static let shared = AppDataStore()

    // MARK: - Published State

    @Published var skills: [Skill] = []
    @Published var providers: [Provider] = []
    @Published var disabledRules: DisabledRules = .empty

    // MARK: - Private Stores

    private let skillsStore = JSONStore<[Skill]>(filename: "skills.json")
    private let providersStore = JSONStore<[Provider]>(filename: "providers.json")
    private let rulesStore = JSONStore<DisabledRules>(filename: "disabled_rules.json")

    private init() {
        loadAll()
    }

    // MARK: - Load

    private func loadAll() {
        skills = (try? skillsStore.load()) ?? Skill.defaultSkills
        providers = (try? providersStore.load()) ?? []
        disabledRules = (try? rulesStore.load()) ?? .empty
    }

    // MARK: - Skills

    func saveSkills() {
        try? skillsStore.save(skills)
    }

    func addSkill(_ skill: Skill) {
        var s = skill
        s.sortOrder = (skills.map(\.sortOrder).max() ?? -1) + 1
        skills.append(s)
        saveSkills()
    }

    func updateSkill(_ skill: Skill) {
        guard let idx = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        skills[idx] = skill
        saveSkills()
    }

    func deleteSkill(id: UUID) {
        skills.removeAll { $0.id == id && !$0.isBuiltIn }
        saveSkills()
    }

    func moveSkills(fromOffsets: IndexSet, toOffset: Int) {
        skills.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (i, _) in skills.enumerated() {
            skills[i].sortOrder = i
        }
        saveSkills()
    }

    // MARK: - Providers

    func saveProviders() {
        try? providersStore.save(providers)
    }

    func addProvider(_ provider: Provider) {
        providers.append(provider)
        saveProviders()
    }

    func updateProvider(_ provider: Provider) {
        guard let idx = providers.firstIndex(where: { $0.id == provider.id }) else { return }
        providers[idx] = provider
        saveProviders()
    }

    func deleteProvider(id: UUID) {
        KeychainStore.deleteToken(forProviderID: id)
        providers.removeAll { $0.id == id }
        // If we deleted the active provider, activate the first remaining one
        if !providers.isEmpty && !providers.contains(where: { $0.isActive }) {
            providers[0].isActive = true
        }
        saveProviders()
    }

    func setActiveProvider(id: UUID) {
        for i in providers.indices {
            providers[i].isActive = providers[i].id == id
        }
        saveProviders()
    }

    var activeProvider: Provider? {
        providers.first(where: { $0.isActive })
    }

    // MARK: - Disabled Rules

    func saveDisabledRules() {
        try? rulesStore.save(disabledRules)
    }

    func addDisabledBundleID(_ bundleID: String) {
        guard !disabledRules.disabledBundleIDs.contains(bundleID) else { return }
        disabledRules.disabledBundleIDs.append(bundleID)
        saveDisabledRules()
    }

    func removeDisabledBundleID(_ bundleID: String) {
        disabledRules.disabledBundleIDs.removeAll { $0 == bundleID }
        saveDisabledRules()
    }

    func addDisabledDomain(_ rawInput: String) {
        guard let domain = DisabledRules.normalizeDomain(rawInput),
              !disabledRules.disabledDomains.contains(domain) else { return }
        disabledRules.disabledDomains.append(domain)
        saveDisabledRules()
    }

    func removeDisabledDomain(_ domain: String) {
        disabledRules.disabledDomains.removeAll { $0 == domain }
        saveDisabledRules()
    }
}
