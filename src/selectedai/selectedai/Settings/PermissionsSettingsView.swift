//
//  PermissionsSettingsView.swift
//  selectedai
//

import SwiftUI
import AppKit
import Combine

enum PermissionStatus {
    case granted
    case denied
    case notDetermined

    var label: String {
        switch self {
        case .granted: return "已授权"
        case .denied: return "已拒绝"
        case .notDetermined: return "未授权"
        }
    }

    var color: Color {
        switch self {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        }
    }

    var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        }
    }
}

@MainActor
final class PermissionsModel: ObservableObject {
    @Published var accessibility: PermissionStatus = .notDetermined

    private var timer: Timer?

    func refresh() {
        accessibility = AXIsProcessTrusted() ? .granted : .denied
    }

    func startPolling() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func requestAccessibility() {
        AccessibilityManager.shared.requestPermission()
        AccessibilityManager.shared.startPolling()
        refresh()
    }

    static func openSettings(anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct PermissionsSettingsView: View {
    @StateObject private var model = PermissionsModel()

    var body: some View {
        Form {
            Section {
                Text("核对 SelectedAI 所需的系统权限。未授权的权限可点击「申请授权」，或前往系统设置手动开启。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("辅助功能") {
                row(
                    title: "辅助功能",
                    detail: "检测跨应用的文本选区并显示工具栏",
                    status: model.accessibility,
                    request: { model.requestAccessibility() },
                    openSettings: { PermissionsModel.openSettings(anchor: "Privacy_Accessibility") }
                )
            }

            Section {
                Button("重新检测") { model.refresh() }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
    }

    @ViewBuilder
    private func row(
        title: String,
        detail: String,
        status: PermissionStatus,
        request: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: status.icon)
                .foregroundStyle(status.color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                Text(status.label).font(.caption).foregroundStyle(status.color)
            }
            Spacer()
            if status != .granted {
                Button("申请授权", action: request)
            }
            Button("系统设置", action: openSettings)
        }
    }
}
