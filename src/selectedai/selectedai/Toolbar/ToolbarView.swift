//
//  ToolbarView.swift
//  selectedai
//

import SwiftUI

/// The capsule-shaped selection toolbar rendered inside ToolbarPanel.
struct ToolbarView: View {
    let skills: [Skill]
    let sourceBundleID: String?
    let onSkillTapped: (Skill) -> Void
    let onDisableApp: (() -> Void)?

    private let maxVisible = 5

    private var visibleSkills: [Skill] { Array(skills.prefix(maxVisible)) }
    private var overflowSkills: [Skill] { Array(skills.dropFirst(maxVisible)) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleSkills) { skill in
                SkillButton(skill: skill, onTap: { onSkillTapped(skill) })
                if skill.id != visibleSkills.last?.id || !overflowSkills.isEmpty || needsOverflow {
                    separator
                }
            }

            OverflowMenuButton(
                skills: overflowSkills,
                sourceBundleID: sourceBundleID,
                onSkillTapped: onSkillTapped,
                onDisableApp: onDisableApp
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
        .fixedSize()
    }

    private var needsOverflow: Bool {
        !overflowSkills.isEmpty || onDisableApp != nil
    }

    private var separator: some View {
        Divider()
            .background(Color.primary.opacity(0.15))
            .frame(height: 20)
    }
}

// MARK: - Skill Button

private struct SkillButton: View {
    let skill: Skill
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: skill.iconName)
                    .font(.system(size: 12, weight: .medium))
                Text(skill.name)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Overflow Menu Button

private struct OverflowMenuButton: View {
    let skills: [Skill]
    let sourceBundleID: String?
    let onSkillTapped: (Skill) -> Void
    let onDisableApp: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Menu {
            ForEach(skills) { skill in
                Button {
                    onSkillTapped(skill)
                } label: {
                    Label(skill.name, systemImage: skill.iconName)
                }
            }

            if !skills.isEmpty && onDisableApp != nil {
                Divider()
            }

            if let onDisableApp {
                Button("在此应用中禁用", action: onDisableApp)
            }

            Divider()
            Button("更多设置…") {
                SettingsWindowController.shared.showAndFocus()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { isHovered = $0 }
    }
}

#Preview {
    ToolbarView(
        skills: Skill.defaultSkills,
        sourceBundleID: nil,
        onSkillTapped: { _ in },
        onDisableApp: {}
    )
    .padding()
    .background(Color.gray)
}
