//
//  ProviderSettingsView.swift
//  selectedai
//

import SwiftUI

struct ProviderSettingsView: View {
    @ObservedObject private var store = AppDataStore.shared
    @State private var editingProvider: Provider?
    @State private var showNewProvider = false

    var body: some View {
        HSplitView {
            // Provider list
            VStack(alignment: .leading, spacing: 0) {
                List(store.providers, selection: .constant(nil as UUID?)) { provider in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(provider.displayName)
                                    .fontWeight(provider.isActive ? .semibold : .regular)
                                if provider.isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                }
                            }
                            Text(provider.protocolType.displayName + " · " + provider.modelID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingProvider = provider }
                }
                .listStyle(.inset)

                Divider()
                Button("+ 新建 Provider") { showNewProvider = true }
                    .padding(8)
            }
            .frame(minWidth: 180)

            // Edit panel
            if let provider = editingProvider {
                ProviderEditView(provider: provider) {
                    editingProvider = store.providers.first(where: { $0.id == provider.id })
                }
            } else {
                ContentUnavailableView("选择一个 Provider", systemImage: "cpu")
            }
        }
        .sheet(isPresented: $showNewProvider) {
            ProviderEditView(provider: nil) {}
                .onDisappear { showNewProvider = false }
        }
    }
}

// MARK: - Provider Edit

struct ProviderEditView: View {
    let initialProvider: Provider?
    let onUpdate: () -> Void

    @ObservedObject private var store = AppDataStore.shared
    @State private var displayName: String
    @State private var protocolType: Provider.ProtocolType
    @State private var baseURL: String
    @State private var modelID: String
    @State private var token: String
    @State private var testResult: TestResult?
    @State private var isTesting = false
    @Environment(\.dismiss) private var dismiss

    enum TestResult {
        case success
        case failure(String)
    }

    init(provider: Provider?, onUpdate: @escaping () -> Void) {
        self.initialProvider = provider
        self.onUpdate = onUpdate
        _displayName = State(initialValue: provider?.displayName ?? "")
        _protocolType = State(initialValue: provider?.protocolType ?? .openAI)
        _baseURL = State(initialValue: provider?.baseURL ?? "https://api.openai.com")
        _modelID = State(initialValue: provider?.modelID ?? "gpt-4o")
        _token = State(initialValue: provider.flatMap { KeychainStore.loadToken(forProviderID: $0.id) } ?? "")
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("显示名称", text: $displayName)
                Picker("协议", selection: $protocolType) {
                    ForEach(Provider.ProtocolType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .onChange(of: protocolType) { _, new in
                    if baseURL.isEmpty || baseURL == "https://api.openai.com" || baseURL == "https://api.anthropic.com" {
                        baseURL = new == .openAI ? "https://api.openai.com" : "https://api.anthropic.com"
                        modelID = new == .openAI ? "gpt-4o" : "claude-sonnet-5"
                    }
                }
                TextField("API Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Model ID", text: $modelID)
            }

            Section("认证") {
                SecureField("API Token", text: $token)
            }

            Section {
                HStack {
                    Button(isTesting ? "测试中…" : "测试连接") {
                        testConnection()
                    }
                    .disabled(isTesting || baseURL.isEmpty || modelID.isEmpty)

                    if let result = testResult {
                        switch result {
                        case .success:
                            Label("连接成功", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let msg):
                            Label(msg, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            Section {
                HStack {
                    if let provider = initialProvider {
                        Button("删除", role: .destructive) {
                            store.deleteProvider(id: provider.id)
                            dismiss()
                        }
                        Spacer()
                        if !provider.isActive {
                            Button("设为活动") {
                                store.setActiveProvider(id: provider.id)
                                onUpdate()
                            }
                        }
                    } else {
                        Spacer()
                    }
                    Button("保存") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(displayName.isEmpty || baseURL.isEmpty || modelID.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 320)
    }

    private func save() {
        let id = initialProvider?.id ?? UUID()
        if !token.isEmpty {
            try? KeychainStore.saveToken(token, forProviderID: id)
        }
        var provider = Provider(
            id: id,
            displayName: displayName,
            protocolType: protocolType,
            baseURL: baseURL,
            modelID: modelID,
            isActive: initialProvider?.isActive ?? store.providers.isEmpty
        )
        if initialProvider != nil {
            store.updateProvider(provider)
        } else {
            if store.providers.isEmpty { provider.isActive = true }
            store.addProvider(provider)
            dismiss()
        }
        onUpdate()
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        let provider = Provider(
            id: initialProvider?.id ?? UUID(),
            displayName: displayName,
            protocolType: protocolType,
            baseURL: baseURL,
            modelID: modelID,
            isActive: false
        )
        // Temporarily store token for test
        if !token.isEmpty {
            try? KeychainStore.saveToken(token, forProviderID: provider.id)
        }
        Task {
            do {
                try await LLMClient.testConnection(provider: provider)
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
