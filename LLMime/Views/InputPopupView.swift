import SwiftUI

struct InputPopupView: View {
    @ObservedObject var viewModel: InputPopupViewModel
    @FocusState private var isPromptFocused: Bool

    private var maxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) * 0.8
    }

    var body: some View {
        ScrollView {
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

                TextField(viewModel.selectedText != nil ? "指示を入力（空欄で書き換え）…" : "何でも聞いてください…",
                          text: $viewModel.promptText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(3...50)
                    .focused($isPromptFocused)

                if !viewModel.responseText.isEmpty {
                    Divider()

                    Text(viewModel.responseText)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        }
        .frame(width: 520)
        .frame(maxHeight: maxHeight)
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
        You are a versatile AI assistant. \
        Respond in the same language as the user's input. \
        If the user asks a question, answer it directly. \
        If the user asks you to create, write, or generate text (email, code, summary, etc.), \
        output only the generated text without explanation or preamble. \
        If context text is provided with an instruction, apply the instruction to that context. \
        If context text is provided without an instruction, rewrite it to improve clarity and readability. \
        Never use markdown formatting unless explicitly requested.
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

        let modelOption = settings.selectedModelOption
        statusMessage = "\(modelOption.displayName) に送信中…"

        let userMessage: String

        if hasContext && !promptText.isEmpty {
            userMessage = "Context:\n\(selectedText!)\n\nInstruction:\n\(promptText)"
        } else if hasContext {
            userMessage = "以下のテキストを書き換えてください:\n\(selectedText!)"
        } else {
            userMessage = promptText
        }

        Log.info("Sending to model: \(modelOption.apiModel) thinking=\(modelOption.thinking), hasContext: \(hasContext), message: \(userMessage.prefix(80))")

        client.streamGenerate(
            prompt: userMessage,
            context: nil,
            model: modelOption.apiModel,
            thinking: modelOption.thinking,
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
                Log.info("Generation complete: \(chars) chars")
            },
            onError: { [weak self] message in
                self?.isGenerating = false
                self?.errorMessage = message
                self?.statusMessage = ""
                Log.error("API error: \(message)")
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
