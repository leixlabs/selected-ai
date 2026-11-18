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
    var onSizeChange: ((CGSize) -> Void)? = nil

    private let maxVisible = 5

    /// Index of the first visible skill; changed by scrolling while hovering the toolbar.
    @State private var offset = 0
    @State private var scrollMonitor: Any?
    @State private var scrollAccum: CGFloat = 0

    private var maxOffset: Int { max(0, skills.count - maxVisible) }
    private var clampedOffset: Int { min(max(offset, 0), maxOffset) }
    private var visibleSkills: [Skill] { Array(skills.dropFirst(clampedOffset).prefix(maxVisible)) }
    /// Everything not currently shown in the bar (before and after the window).
    private var overflowSkills: [Skill] {
        Array(skills.prefix(clampedOffset)) + Array(skills.dropFirst(clampedOffset + maxVisible))
    }

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
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { onSizeChange?(geo.size) }
                .onChange(of: geo.size) { _, new in onSizeChange?(new) }
        })
        .onHover { hovering in
            if hovering { startScrollMonitor() } else { stopScrollMonitor() }
        }
        .onDisappear { stopScrollMonitor() }
    }

    // MARK: - Scroll to switch skills

    private func startScrollMonitor() {
        guard scrollMonitor == nil, maxOffset > 0 else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            handleScroll(event)
            return nil
        }
    }

    private func stopScrollMonitor() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m) }
        scrollMonitor = nil
        scrollAccum = 0
    }

    private func handleScroll(_ event: NSEvent) {
        let dy = event.scrollingDeltaY, dx = event.scrollingDeltaX
        let delta = abs(dy) >= abs(dx) ? dy : -dx
        // Trackpads report many small precise deltas; a wheel reports one per notch.
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 12 : 1
        scrollAccum += delta
        while abs(scrollAccum) >= threshold {
            // Scroll down (negative delta) / right moves forward.
            let step = scrollAccum < 0 ? 1 : -1
            scrollAccum += CGFloat(step) * threshold
            offset = min(max(clampedOffset + step, 0), maxOffset)
        }
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
