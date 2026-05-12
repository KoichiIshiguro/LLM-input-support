import Foundation

struct Preset: Identifiable, Codable {
    var id: String { name }
    let name: String
    let systemPrompt: String
    let model: String?
    let temperature: Double?

    static let builtIn: [Preset] = [
        Preset(
            name: "自由生成",
            systemPrompt: "You are a helpful assistant. Respond concisely and directly.",
            model: nil,
            temperature: nil
        ),
        Preset(
            name: "書き換え",
            systemPrompt: "Rewrite the given text to improve clarity and readability. Maintain the original meaning and tone. Output only the rewritten text.",
            model: nil,
            temperature: nil
        ),
        Preset(
            name: "要約",
            systemPrompt: "Summarize the given text concisely. Output only the summary.",
            model: nil,
            temperature: nil
        ),
        Preset(
            name: "翻訳 JP↔EN",
            systemPrompt: "Translate the given text. If it is Japanese, translate to English. If it is English, translate to Japanese. Output only the translation.",
            model: nil,
            temperature: nil
        ),
        Preset(
            name: "コード生成",
            systemPrompt: "Generate code based on the given description. Output only the code without explanation or markdown fences.",
            model: nil,
            temperature: nil
        ),
    ]
}
