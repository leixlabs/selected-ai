//
//  SkillTests.swift
//  selectedaiTests
//

import XCTest
@testable import selectedai

final class SkillTests: XCTestCase {

    // MARK: - Default skills

    func testDefaultSkillsCount() {
        XCTAssertEqual(Skill.defaultSkills.count, 5)
    }

    func testDefaultSkillsHaveUniqueIDs() {
        let ids = Skill.defaultSkills.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testBuiltInSkillsAreBuiltIn() {
        let builtIn = Skill.defaultSkills.filter(\.isBuiltIn)
        XCTAssertEqual(builtIn.count, 3) // translate, copy, speak
    }

    func testPresetSkillsHavePrompts() {
        let presets = Skill.defaultSkills.filter { !$0.isBuiltIn }
        for skill in presets {
            XCTAssertNotNil(skill.prompt, "\(skill.name) should have a prompt")
            XCTAssertTrue(skill.prompt!.contains("{selection}"),
                          "\(skill.name) prompt must contain {selection}")
        }
    }

    // MARK: - Prompt placeholder validation

    func testPromptWithSelectionIsValid() {
        let prompt = "Summarize: {selection}"
        XCTAssertTrue(prompt.contains("{selection}"))
    }

    func testPromptWithoutSelectionIsInvalid() {
        let prompt = "Summarize this text"
        XCTAssertFalse(prompt.contains("{selection}"))
    }

    func testSelectionSubstitution() {
        let prompt = "Translate {selection} to English"
        let text = "こんにちは"
        let result = prompt.replacingOccurrences(of: "{selection}", with: text)
        XCTAssertEqual(result, "Translate こんにちは to English")
    }

    // MARK: - Skill ordering

    func testSortOrderPreserved() {
        let skills = Skill.defaultSkills.sorted { $0.sortOrder < $1.sortOrder }
        for (i, skill) in skills.enumerated() {
            XCTAssertEqual(skill.sortOrder, i)
        }
    }

    // MARK: - Built-in skills cannot be deleted (logic test)

    func testBuiltInSkillCannotBeDeleted() {
        var skills = Skill.defaultSkills
        let copySkill = skills.first { skill in
            if case .builtIn(.copy) = skill.kind { return true }
            return false
        }!
        // Simulate AppDataStore.deleteSkill filtering
        skills.removeAll { $0.id == copySkill.id && !$0.isBuiltIn }
        XCTAssertTrue(skills.contains(where: { $0.id == copySkill.id }),
                      "Built-in skill should not be deleted")
    }
}
