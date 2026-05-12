import SwiftUI

struct InputPopupView: View {
    @ObservedObject var viewModel: InputPopupViewModel
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if viewModel.isGenerating {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                    Text("生成中…")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if let ctx = viewModel.selectedText {
                Text(ctx.prefix(80) + (ctx.count > 80 ? "…" : ""))
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }

            TextField(viewModel.selectedText != nil ? "指示を入力（空欄で書き換え）…" : "書き換えるテキストを入力…",
                      text: $viewModel.promptText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...20)
                .focused($isPromptFocused)

            if !viewModel.responseText.isEmpty {
                Divider()

                ScrollView {
                    Text(viewModel.responseText)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 400)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .textSelection(.enabled)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(viewModel.responseText.isEmpty
                     ? "Enter: 送信  Esc: 閉じる"
                     : "Enter: 挿入  ⌘Enter: 再送信  Esc: 閉じる")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.6))
                Spacer()
            }
        }
        .padding(10)
        .frame(width: 480)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            isPromptFocused = true
        }
    }
}

@MainActor
final class InputPopupViewModel: ObservableObject {
    @Published var promptText = ""
    @Published var responseText = ""
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var statusMessage = ""
    @Published var selectedText: String?

    var onInsert: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let client = GeminiClient()
    private let settings = AppSettings.shared

    private static let systemPrompt = """
        You are a text rewriting assistant. \
        Your default behavior is to rewrite the given text to improve clarity and readability, \
        maintaining the original language, meaning and tone. \
        If the user provides specific instructions (e.g. "translate to English", "summarize", "make formal"), \
        follow those instructions instead of the default rewrite. \
        Output only the result text without explanation, preamble, or markdown formatting.
        """

    func send() {
        let hasContext = selectedText != nil && !(selectedText?.isEmpty ?? true)

        if promptText.isEmpty && !hasContext {
            errorMessage = "テキストを入力してください"
            return
        }
        let apiKey = settings.geminiAPIKey
        guard !apiKey.isEmpty else {
            errorMessage = "API キーが設定されていません（メニューバー → 設定）"
            return
        }

        isGenerating = true
        errorMessage = nil
        responseText = ""

        let model = settings.defaultModel
        statusMessage = "\(model) に送信中…"

        let contextText: String?
        let promptToSend: String

        if hasContext {
            contextText = selectedText
            promptToSend = promptText.isEmpty ? "この文章を書き換えてください。" : promptText
        } else {
            contextText = promptText
            promptToSend = "この文章を書き換えてください。"
        }

        NSLog("[LLMime] Sending to model: %@, hasContext: %d, prompt: %@",
              model, hasContext ? 1 : 0, String(promptToSend.prefix(50)))

        client.streamGenerate(
            prompt: promptToSend,
            context: contextText,
            model: model,
            systemPrompt: Self.systemPrompt,
            apiKey: apiKey,
            onToken: { [weak self] token in
                self?.responseText += token
                if self?.statusMessage.contains("送信中") == true {
                    self?.statusMessage = "生成中…"
                }
            },
            onComplete: { [weak self] in
                self?.isGenerating = false
                let chars = self?.responseText.count ?? 0
                self?.statusMessage = "完了（\(chars)文字）— Enter で挿入"
                NSLog("[LLMime] Generation complete: %d chars", chars)
            },
            onError: { [weak self] message in
                self?.isGenerating = false
                self?.errorMessage = message
                self?.statusMessage = ""
                NSLog("[LLMime] Error: %@", message)
            }
        )
    }

    func cancel() {
        client.cancel()
        isGenerating = false
    }

    func insertResult() {
        guard !responseText.isEmpty else { return }
        onInsert?(responseText)
    }
}
