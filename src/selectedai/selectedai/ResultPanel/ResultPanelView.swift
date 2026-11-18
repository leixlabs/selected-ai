//
//  ResultPanelView.swift
//  selectedai
//

import SwiftUI
import AVFoundation

struct ResultPanelView: View {
    @ObservedObject var model: ResultPanelModel
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header drag handle + pin
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)

                Button {
                    model.isPinned.toggle()
                } label: {
                    Image(systemName: model.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(model.isPinned ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help(model.isPinned ? "取消固定" : "固定")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())

            Divider()

            // MARK: - Translate language picker
            if case .builtIn(.translate) = model.skill?.kind {
                TranslateLanguagePicker(model: model)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            // MARK: - Content
            if let errorMsg = model.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(errorMsg)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    if errorMsg.contains("Provider") {
                        Button("打开设置") {
                            SettingsWindowController.shared.showAndFocus()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                MarkdownWebView(markdownText: $model.markdownText, colorScheme: colorScheme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            // MARK: - Toolbar
            HStack(spacing: 12) {
                // Left: speak + copy
                Button {
                    toggleSpeak()
                } label: {
                    Image(systemName: isSpeaking ? "stop.circle" : "speaker.wave.2")
                }
                .buttonStyle(.plain)
                .help(isSpeaking ? "停止朗读" : "朗读结果")
                .disabled(model.markdownText.isEmpty)

                Button {
                    copyResult()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("复制结果")
                .disabled(model.markdownText.isEmpty)

                if case .builtIn(.translate) = model.skill?.kind {
                    Button("替换") { insertResult(replace: true) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("用译文替换原选中文本")
                        .disabled(model.markdownText.isEmpty || model.isStreaming)
                    Button("插入") { insertResult(replace: false) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("在原选中文本之后插入译文")
                        .disabled(model.markdownText.isEmpty || model.isStreaming)
                }

                Spacer()

                // Right: stop / retry
                if model.isStreaming {
                    Button {
                        model.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.plain)
                    .help("停止生成")
                } else if model.isFinished || model.error != nil {
                    Button {
                        model.retry()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("重试")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // MARK: - Follow-up input
            HStack {
                TextField("继续追问…", text: $model.followUpInput)
                    .textFieldStyle(.plain)
                    .onSubmit { model.sendFollowUp() }

                Button {
                    model.sendFollowUp()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(model.followUpInput.isEmpty ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .disabled(model.followUpInput.isEmpty || model.isStreaming)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
    }

    private func toggleSpeak() {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        } else {
            let utterance = AVSpeechUtterance(string: model.markdownText)
            let recognizer = NSLinguisticTagger(tagSchemes: [.language], options: 0)
            recognizer.string = String(model.markdownText.prefix(200))
            let lang = recognizer.dominantLanguage ?? "en-US"
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
            synthesizer.speak(utterance)
            isSpeaking = true
        }
    }

    private func insertResult(replace: Bool) {
        TextInserter.insert(model.markdownText,
                            original: model.selectionEvent?.text ?? "",
                            into: model.selectionEvent?.sourceBundleID,
                            replacingSelection: replace)
    }

    private func copyResult() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.markdownText, forType: .string)
    }
}

// MARK: - Translate Language Picker

private struct TranslateLanguagePicker: View {
    @ObservedObject var model: ResultPanelModel

    private let options = ["自动", "中文", "英文"]

    var body: some View {
        HStack {
            Text("翻译成：")
                .foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: { model.translateTarget },
                set: { model.changeTranslateTarget($0) }
            )) {
                ForEach(options, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            Spacer()
        }
    }
}
