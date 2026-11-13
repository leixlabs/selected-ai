//
//  GeneralSettingsView.swift
//  selectedai
//

import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @ObservedObject private var store = AppDataStore.shared
    @ObservedObject private var launchManager = LaunchAtLoginManager.shared
    @State private var showAppPicker = false

    private var isToolbarEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "toolbarEnabled") }
    }

    var body: some View {
        Form {
            // MARK: - Global Toggle
            Section("功能") {
                Toggle("启用划词工具栏", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "toolbarEnabled") },
                    set: { newValue in
                        UserDefaults.standard.set(newValue, forKey: "toolbarEnabled")
                        ToolbarController.shared.isGloballyEnabled = newValue
                    }
                ))

                Toggle("登录时启动", isOn: $launchManager.isEnabled)
            }

            // MARK: - Disabled Apps
            Section("禁用的应用") {
                if store.disabledRules.disabledBundleIDs.isEmpty {
                    Text("暂无禁用的应用")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.disabledRules.disabledBundleIDs, id: \.self) { bundleID in
                        HStack {
                            AppIcon(bundleID: bundleID)
                            Text(appName(for: bundleID))
                            Spacer()
                            Button {
                                store.removeDisabledBundleID(bundleID)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button("添加应用…") {
                    showAppPicker = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showAppPicker) {
            AppPickerView { bundleID in
                store.addDisabledBundleID(bundleID)
                showAppPicker = false
            }
        }
    }

    private func appName(for bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleName") as? String }
            ?? bundleID
    }
}

// MARK: - App Icon

private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
               let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app")
                    .frame(width: 20, height: 20)
            }
        }
    }
}

// MARK: - App Picker

private struct AppPickerView: View {
    let onSelect: (String) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var apps: [NSRunningApplication] {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
        if searchText.isEmpty { return running }
        return running.filter {
            ($0.localizedName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(apps, id: \.processIdentifier) { app in
                Button {
                    if let bid = app.bundleIdentifier {
                        onSelect(bid)
                    }
                } label: {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "搜索应用")
            .navigationTitle("选择应用")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .frame(width: 340, height: 420)
    }
}
