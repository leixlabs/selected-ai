//
//  ResultPanelModel.swift
//  selectedai
//

import Foundation
import Combine
import OSLog

private let log = Logger(subsystem: "ai.selected", category: "ResultPanelModel")

@MainActor
final class ResultPanelModel: ObservableObject {
    @Published var markdownText = ""
    @Published var isStreaming = false
    @Published var isFinished = false
    @Published var error: String?
    @Published var isPinned = false
    @Published var followUpInput = ""

    private var messages: [LLMMessage] = []
    private var streamTask: Task<Void, Never>?

    var skill: Skill?
    var selectionEvent: SelectionEvent?

    // MARK: - Start

    func start(skill: Skill, event: SelectionEvent) {
        self.skill = skill
        self.selectionEvent = event
        messages = []
        run(prompt: nil)
    }

    func retry() {
        guard !messages.isEmpty else { return }
        // Remove last assistant turn
        if messages.last?.role == .assistant { messages.removeLast() }
        markdownText = ""
        error = nil
        stream()
    }

    func sendFollowUp() {
        let text = followUpInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        followUpInput = ""
        messages.append(LLMMessage(role: .user, content: text))
        markdownText = ""
        error = nil
        stream()
    }

    func stop() {
        streamTask?.cancel()
        isStreaming = false
    }

    // MARK: - Private

    private static func detectTargetLanguage(_ text: String) -> String {
        let sample = text.prefix(200)
        var chineseCount = 0
        for scalar in sample.unicodeScalars {
            if (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value) {
                chineseCount += 1
            }
        }
        // If >30% of characters are Chinese, translate to English; otherwise to Chinese
        let ratio = Double(chineseCount) / Double(max(sample.count, 1))
        return ratio > 0.3 ? "英文" : "中文"
    }

    private func run(prompt: String?) {
        guard let skill, let event = selectionEvent else { return }

        if messages.isEmpty {
            // Build initial messages
            let systemPrompt: String
            if let p = skill.prompt {
                systemPrompt = p.replacingOccurrences(of: "{selection}", with: event.text)
            } else if case .builtIn(.translate) = skill.kind {
                let targetLang = Self.detectTargetLanguage(event.text)
                systemPrompt = "请将以下内容翻译成\(targetLang)，只输出译文：\n\n\(event.text)"
            } else {
                systemPrompt = event.text
            }
            messages.append(LLMMessage(role: .system, content: systemPrompt))
            messages.append(LLMMessage(role: .user, content: event.text))
        }

        stream()
    }

    private func stream() {
        guard let provider = AppDataStore.shared.activeProvider else {
            error = LLMError.noActiveProvider.localizedDescription
            log.error("No active provider configured")
            return
        }

        log.info("Streaming start provider=\(provider.displayName) model=\(provider.modelID)")
        isStreaming = true
        isFinished = false
        error = nil

        let capturedMessages = messages
        streamTask = Task {
            var accumulated = ""
            do {
                for try await chunk in LLMClient.stream(messages: capturedMessages, provider: provider) {
                    guard !Task.isCancelled else { break }
                    accumulated += chunk
                    markdownText = accumulated
                }
                if !Task.isCancelled {
                    log.info("Stream finished totalChars=\(accumulated.count)")
                    messages.append(LLMMessage(role: .assistant, content: accumulated))
                    isFinished = true
                }
            } catch {
                log.error("Stream error: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
            isStreaming = false
        }
    }
}
