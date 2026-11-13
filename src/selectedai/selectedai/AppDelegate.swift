//
//  AppDelegate.swift
//  selectedai
//

import AppKit
import AVFoundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var toggleMenuItem: NSMenuItem!

    private static let toolbarEnabledKey = "toolbarEnabled"

    var isToolbarEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.toolbarEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.toolbarEnabledKey)
            ToolbarController.shared.isGloballyEnabled = newValue
            updateToggleMenuItem()
            updateStatusItemIcon()
        }
    }

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.object(forKey: Self.toolbarEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.toolbarEnabledKey)
        }

        setupStatusItem()

        // Wire toolbar controller skill handler
        ToolbarController.shared.isGloballyEnabled = isToolbarEnabled
        ToolbarController.shared.onSkillSelected = { [weak self] skill, event in
            self?.handleSkill(skill, event: event)
        }

        // Check Accessibility permission on every launch; prompt if missing
        DispatchQueue.main.async {
            AccessibilityManager.shared.promptIfNeeded()
            self.updateToggleMenuItem()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityPermissionDidChange),
            name: .accessibilityPermissionGranted,
            object: nil
        )
    }

    // MARK: - Skill Handler

    private func handleSkill(_ skill: Skill, event: SelectionEvent) {
        switch skill.kind {
        case .builtIn(.copy):
            copyToClipboard(event.text)
        case .builtIn(.speak):
            speakText(event.text)
        case .builtIn(.translate), .preset, .custom:
            ResultPanelController.shared.show(skill: skill, event: event)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private let speechSynthesizer = AVSpeechSynthesizer()

    private func speakText(_ text: String) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        // Auto-detect language
        let recognizer = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        recognizer.string = String(text.prefix(200))
        let lang = recognizer.dominantLanguage ?? "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
        speechSynthesizer.speak(utterance)
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusItemIcon()

        let menu = NSMenu()

        toggleMenuItem = NSMenuItem(
            title: "启用划词工具栏",
            action: #selector(toggleToolbar),
            keyEquivalent: ""
        )
        toggleMenuItem.target = self
        updateToggleMenuItem()
        menu.addItem(toggleMenuItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "关于 SelectedAI",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 SelectedAI",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        let image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "SelectedAI")
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = !isToolbarEnabled
    }

    private func updateToggleMenuItem() {
        let hasPermission = AccessibilityManager.shared.isTrusted
        toggleMenuItem?.state = isToolbarEnabled ? .on : .off
        toggleMenuItem?.isEnabled = hasPermission
        toggleMenuItem?.title = hasPermission ? "启用划词工具栏" : "启用划词工具栏（需要辅助功能权限）"
    }

    // MARK: - Actions

    @objc private func toggleToolbar() {
        isToolbarEnabled.toggle()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showAndFocus()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func accessibilityPermissionDidChange() {
        // Re-register the AX observer for the current front app so the toolbar
        // starts working immediately after the user grants Accessibility permission,
        // instead of requiring an app switch first.
        if AccessibilityManager.shared.isTrusted {
            SelectionMonitor.shared.reregister()
        }
        updateToggleMenuItem()
        updateStatusItemIcon()
    }
}
