//
//  Skill.swift
//  selectedai
//

import Foundation

/// A skill shown in the selection toolbar.
struct Skill: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var iconName: String   // SF Symbol name
    var kind: Kind
    var sortOrder: Int

    enum Kind: Codable, Equatable {
        /// Built-in, cannot be edited or deleted.
        case builtIn(BuiltInType)
        /// User-editable preset (summary, explain, etc.).
        case preset(prompt: String)
        /// Fully user-created.
        case custom(prompt: String)

        enum BuiltInType: String, Codable {
            case copy
            case speak
            case translate
        }
    }

    /// Whether this skill is built-in and cannot be removed.
    var isBuiltIn: Bool {
        if case .builtIn = kind { return true }
        return false
    }

    /// The prompt associated with this skill, if any.
    var prompt: String? {
        switch kind {
        case .builtIn: return nil
        case .preset(let p), .custom(let p): return p
        }
    }
}

// MARK: - Default Skills

extension Skill {
    static let defaultSkills: [Skill] = [
        Skill(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "翻译",
            iconName: "globe",
            kind: .builtIn(.translate),
            sortOrder: 0
        ),
        Skill(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "复制",
            iconName: "doc.on.doc",
            kind: .builtIn(.copy),
            sortOrder: 1
        ),
        Skill(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "朗读",
            iconName: "speaker.wave.2",
            kind: .builtIn(.speak),
            sortOrder: 2
        ),
        Skill(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "总结",
            iconName: "text.alignleft",
            kind: .preset(prompt: "请将以下内容总结为简洁的要点：\n\n{selection}"),
            sortOrder: 3
        ),
        Skill(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "解释",
            iconName: "questionmark.circle",
            kind: .preset(prompt: "请用简单易懂的语言解释以下内容：\n\n{selection}"),
            sortOrder: 4
        ),
    ]
}
