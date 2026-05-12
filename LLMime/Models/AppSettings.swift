import Foundation
import Security
import Carbon

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var defaultModel: String {
        didSet { UserDefaults.standard.set(defaultModel, forKey: "defaultModel") }
    }

    @Published var hotkeyKeyCode: Int {
        didSet { UserDefaults.standard.set(hotkeyKeyCode, forKey: "hotkeyKeyCode") }
    }

    @Published var hotkeyModifiers: Int {
        didSet { UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers") }
    }

    @Published var eisuKanaEnabled: Bool {
        didSet { UserDefaults.standard.set(eisuKanaEnabled, forKey: "eisuKanaEnabled") }
    }

    var hotkeyDisplayName: String {
        var parts: [String] = []
        let mods = UInt32(hotkeyModifiers)
        if mods & UInt32(controlKey) != 0 { parts.append("⌃") }
        if mods & UInt32(optionKey) != 0 { parts.append("⌥") }
        if mods & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if mods & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: hotkeyKeyCode))
        return parts.joined()
    }

    private static func keyName(for keyCode: Int) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        default: return "Key\(keyCode)"
        }
    }

    private static let keychainService = "com.saltybullet.llmime"
    private static let keychainAccountGemini = "gemini-api-key"

    init() {
        self.defaultModel = UserDefaults.standard.string(forKey: "defaultModel") ?? "gemini-2.5-flash-lite"
        let defaults = UserDefaults.standard
        self.hotkeyKeyCode = defaults.object(forKey: "hotkeyKeyCode") as? Int ?? 49 // Space
        self.hotkeyModifiers = defaults.object(forKey: "hotkeyModifiers") as? Int ?? Int(controlKey | optionKey)
        self.eisuKanaEnabled = defaults.bool(forKey: "eisuKanaEnabled")
    }

    var geminiAPIKey: String {
        get { Self.readKeychain(account: Self.keychainAccountGemini) ?? "" }
        set {
            Self.writeKeychain(account: Self.keychainAccountGemini, value: newValue)
            objectWillChange.send()
        }
    }

    static let availableModels = [
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash",
        "gemini-2.5-pro",
    ]

    // MARK: - Keychain

    private static func writeKeychain(account: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func readKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
