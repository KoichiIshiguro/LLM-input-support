import SwiftUI
import Carbon

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var apiKeyInput: String = ""
    @State private var showKey = false
    @State private var saved = false
    @State private var isRecordingHotkey = false

    var body: some View {
        Form {
            Section("API 設定") {
                HStack {
                    if showKey {
                        TextField("Gemini API キー", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Gemini API キー", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(showKey ? "隠す" : "表示") {
                        showKey.toggle()
                    }
                    .frame(width: 50)
                }

                HStack {
                    Button("保存") {
                        settings.geminiAPIKey = apiKeyInput
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                    }
                    .disabled(apiKeyInput.isEmpty)

                    if saved {
                        Text("✓ 保存しました")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else if !settings.geminiAPIKey.isEmpty {
                        Text("✓ APIキー設定済み")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }

            Section("モデル") {
                Picker("デフォルトモデル", selection: $settings.defaultModel) {
                    ForEach(AppSettings.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }

            Section("ホットキー") {
                HStack {
                    Text("起動キー:")
                    Spacer()
                    if isRecordingHotkey {
                        Text("キーを押してください…")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                    } else {
                        Text(settings.hotkeyDisplayName)
                            .font(.system(size: 13, design: .monospaced))
                    }
                    Button(isRecordingHotkey ? "キャンセル" : "変更") {
                        if isRecordingHotkey {
                            isRecordingHotkey = false
                        } else {
                            isRecordingHotkey = true
                        }
                    }
                    .frame(width: 80)
                }

                Toggle("英数 / かな 長押しでも起動", isOn: $settings.eisuKanaEnabled)
                    .onChange(of: settings.eisuKanaEnabled) {
                        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                    }

                if settings.eisuKanaEnabled {
                    HStack {
                        Text("長押し秒数:")
                        TextField("", value: $settings.eisuKanaHoldDuration, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .onChange(of: settings.eisuKanaHoldDuration) {
                                NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                            }
                        Text("秒")
                            .foregroundColor(.secondary)
                    }
                }

                Text("変更後すぐに反映されます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onHotkeyRecord(isRecording: $isRecordingHotkey) { keyCode, modifiers in
                settings.hotkeyKeyCode = Int(keyCode)
                settings.hotkeyModifiers = Int(modifiers)
                isRecordingHotkey = false
                NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
            }

            Section("情報") {
                Text("LLMime v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 400)
        .onAppear {
            apiKeyInput = settings.geminiAPIKey
        }
    }
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("hotkeyChanged")
}

private struct HotkeyRecorderModifier: ViewModifier {
    @Binding var isRecording: Bool
    let onRecord: (_ keyCode: UInt16, _ modifiers: UInt32) -> Void

    func body(content: Content) -> some View {
        content.background(
            HotkeyRecorderView(isRecording: $isRecording, onRecord: onRecord)
                .frame(width: 0, height: 0)
        )
    }
}

extension View {
    func onHotkeyRecord(isRecording: Binding<Bool>, onRecord: @escaping (_ keyCode: UInt16, _ modifiers: UInt32) -> Void) -> some View {
        modifier(HotkeyRecorderModifier(isRecording: isRecording, onRecord: onRecord))
    }
}

private struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (_ keyCode: UInt16, _ modifiers: UInt32) -> Void

    func makeNSView(context: Context) -> HotkeyCapture {
        let view = HotkeyCapture()
        view.onRecord = onRecord
        return view
    }

    func updateNSView(_ nsView: HotkeyCapture, context: Context) {
        nsView.onRecord = onRecord
        if isRecording {
            nsView.startMonitoring()
        } else {
            nsView.stopMonitoring()
        }
    }
}

final class HotkeyCapture: NSView {
    var onRecord: ((_ keyCode: UInt16, _ modifiers: UInt32) -> Void)?
    private var monitor: Any?

    func startMonitoring() {
        stopMonitoring()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let carbonMods = Self.cocoaToCarbonModifiers(event.modifierFlags)
            if carbonMods != 0 {
                self?.onRecord?(event.keyCode, carbonMods)
            }
            return nil
        }
    }

    func stopMonitoring() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private static func cocoaToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    deinit {
        stopMonitoring()
    }
}
