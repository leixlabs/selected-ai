//
//  SkillsSettingsView.swift
//  selectedai
//

import SwiftUI

struct SkillsSettingsView: View {
    @ObservedObject private var store = AppDataStore.shared
    @State private var editingSkill: Skill?
    @State private var showNewSkill = false
    @State private var undoSkill: Skill?
    @State private var showUndoToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(store.skills.sorted(by: { $0.sortOrder < $1.sortOrder })) { skill in
                    HStack {
                        Image(systemName: skill.iconName)
                            .frame(width: 24)
                            .foregroundStyle(.secondary)
                        Text(skill.name)
                        if skill.isBuiltIn {
                            Text("内置")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.15), in: Capsule())
                        }
                        Spacer()
                        if !skill.isBuiltIn {
                            Button {
                                editingSkill = skill
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)

                            Button {
                                deleteSkill(skill)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onMove { from, to in
                    store.moveSkills(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                if showUndoToast, let deleted = undoSkill {
                    Text("已删除「\(deleted.name)」")
                        .foregroundStyle(.secondary)
                    Button("撤销") {
                        store.addSkill(deleted)
                        showUndoToast = false
                        undoSkill = nil
                    }
                    .buttonStyle(.link)
                }
                Spacer()
                Button("+ 新建技能") { showNewSkill = true }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .sheet(item: $editingSkill) { skill in
            SkillEditView(skill: skill) { updated in
                store.updateSkill(updated)
                editingSkill = nil
            } onCancel: {
                editingSkill = nil
            }
        }
        .sheet(isPresented: $showNewSkill) {
            SkillEditView(skill: nil) { newSkill in
                store.addSkill(newSkill)
                showNewSkill = false
            } onCancel: {
                showNewSkill = false
            }
        }
    }

    private func deleteSkill(_ skill: Skill) {
        undoSkill = skill
        store.deleteSkill(id: skill.id)
        showUndoToast = true
        // Auto-hide undo toast after 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            if showUndoToast { showUndoToast = false }
        }
    }
}

// MARK: - Skill Edit / Create View

struct SkillEditView: View {
    let initialSkill: Skill?
    let onSave: (Skill) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var iconName: String
    @State private var prompt: String

    private let promptPlaceholder = "在此输入 Prompt，使用 {selection} 代表选中文本"

    private static let iconOptions: [String] = [
        "star", "heart", "bookmark", "tag", "flag",
        "lightbulb", "brain", "wand.and.stars", "pencil", "doc.text",
        "text.alignleft", "list.bullet", "checkmark.circle", "questionmark.circle",
        "magnifyingglass", "arrow.triangle.2.circlepath", "globe", "link",
        "hammer", "paintbrush", "scissors", "camera",
    ]

    init(skill: Skill?, onSave: @escaping (Skill) -> Void, onCancel: @escaping () -> Void) {
        self.initialSkill = skill
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: skill?.name ?? "")
        _iconName = State(initialValue: skill?.iconName ?? "star")
        _prompt = State(initialValue: skill?.prompt ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && name.count <= 20
            && prompt.contains("{selection}")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text(initialSkill == nil ? "新建技能" : "编辑技能")
                .font(.title3.bold())

            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("名称")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("技能名称", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: name) { _, new in
                        if new.count > 20 { name = String(new.prefix(20)) }
                    }
                Text("\(name.count)/20")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Icon
            VStack(alignment: .leading, spacing: 8) {
                Text("图标")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: .init(.fixed(36)), count: 11), spacing: 6) {
                    ForEach(Self.iconOptions, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                            .background(
                                iconName == icon
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(iconName == icon ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                            .onTapGesture { iconName = icon }
                    }
                }
            }

            // Prompt
            VStack(alignment: .leading, spacing: 6) {
                Text("Prompt")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $prompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
                    if prompt.isEmpty {
                        Text("使用 {selection} 代表选中文本")
                            .foregroundStyle(.tertiary)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                if !prompt.contains("{selection}") && !prompt.isEmpty {
                    Label("Prompt 必须包含 {selection}", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            // Buttons
            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    let skill = Skill(
                        id: initialSkill?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespaces),
                        iconName: iconName,
                        kind: initialSkill?.isBuiltIn == true
                            ? initialSkill!.kind
                            : .custom(prompt: prompt),
                        sortOrder: initialSkill?.sortOrder ?? 999
                    )
                    onSave(skill)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
