//
//  AccessibilityManager.swift
//  selectedai
//
//  Created by lei on 2026/7/31.
//

import AppKit
import Combine

/// Manages Accessibility API permission state detection and user guidance.
@MainActor
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    /// Whether the app currently has Accessibility permission.
    @Published private(set) var isTrusted: Bool = false

    private var pollingTimer: Timer?

    private init() {
        isTrusted = AXIsProcessTrusted()
    }

    // MARK: - Permission Check

    /// Checks if the process is trusted for Accessibility.
    func checkPermission() -> Bool {
        isTrusted = AXIsProcessTrusted()
        return isTrusted
    }

    /// Prompts the user to grant Accessibility permission.
    /// Shows the system dialog that directs the user to System Settings > Privacy & Security > Accessibility.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Polling

    /// Starts polling for permission changes (every 2 seconds).
    /// Useful after showing the permission prompt, so the app reacts when the user grants access.
    func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let wasTrusted = self.isTrusted
                self.isTrusted = AXIsProcessTrusted()
                if self.isTrusted && !wasTrusted {
                    // Permission was just granted — stop polling
                    self.stopPolling()
                    NotificationCenter.default.post(name: .accessibilityPermissionGranted, object: nil)
                }
            }
        }
    }

    /// Stops polling for permission changes.
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - First Launch Guidance

    private static let permissionPromptedKey = "accessibilityPermissionPrompted"

    /// Shows the Accessibility permission guidance dialog if not already trusted.
    /// Only shows once — subsequent calls without permission are silently skipped.
    /// Returns `true` if already trusted, `false` otherwise.
    @discardableResult
    func showPermissionGuideIfNeeded() -> Bool {
        if checkPermission() {
            return true
        }

        // Only prompt once; after that, the user can grant via the menu item or Settings
        if UserDefaults.standard.bool(forKey: Self.permissionPromptedKey) {
            return false
        }
        UserDefaults.standard.set(true, forKey: Self.permissionPromptedKey)

        let alert = NSAlert()
        alert.messageText = "SelectedAI 需要辅助功能权限"
        alert.informativeText = "SelectedAI 需要辅助功能权限来检测跨应用的文本选区。\n\n点击「打开系统设置」后，请在「隐私与安全性 > 辅助功能」中启用 SelectedAI。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestPermission()
            startPolling()
        }

        return false
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let accessibilityPermissionGranted = Notification.Name("accessibilityPermissionGranted")
}
