//
//  LaunchAtLoginManager.swift
//  selectedai
//
//  Created by lei on 2026/7/31.
//

import ServiceManagement
import Combine

/// Manages the "Launch at Login" feature using `SMAppService`.
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    private static let userDefaultsKey = "launchAtLogin"

    /// Whether launch-at-login is currently enabled.
    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: Self.userDefaultsKey)
            applyState()
        }
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.userDefaultsKey)
        // Sync actual system state on init
        applyState()
    }

    /// Toggles launch-at-login on/off.
    func toggle() {
        isEnabled.toggle()
    }

    // MARK: - Private

    private func applyState() {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[LaunchAtLoginManager] Failed to \(isEnabled ? "register" : "unregister"): \(error)")
        }
    }
}
