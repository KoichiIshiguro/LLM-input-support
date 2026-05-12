import SwiftUI

@main
struct LLMimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var popupManager: PopupWindowManager!
    private let settings = AppSettings.shared
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.setupCrashHandler()
        Log.trimIfNeeded()
        setupMenuBar()
        requestPermissions()
        popupManager = PopupWindowManager()
        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleHotkeyTriggered()
        }
        hotkeyManager.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingChanged),
            name: .hotkeyChanged,
            object: nil
        )

        if settings.geminiAPIKey.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.openSettings()
            }
        }
    }

    // MARK: - 権限リクエスト

    private func requestPermissions() {
        // 1. アクセシビリティ権限（ダイアログ表示付き）
        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let axTrusted = AXIsProcessTrustedWithOptions(axOptions)
        Log.info("Accessibility: \(axTrusted ? "granted" : "requesting...")")


        // 3. アクセシビリティが未許可の場合はガイドを表示
        if !axTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showPermissionGuide()
            }
        }
    }

    private func showPermissionGuide() {
        let alert = NSAlert()
        alert.messageText = "LLMime に権限が必要です"
        alert.informativeText = """
        以下の権限を許可してください：

        1. アクセシビリティ
           → システム設定が開きます。LLMime を有効にしてください。

        2. 入力監視（「入力監視」に LLMime を追加）
           → ホットキー検知に必要です。

        権限を設定したら LLMime を再起動してください。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "後で")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "LLMime")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "設定…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "権限を確認…", action: #selector(checkPermissions), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "ログを開く", action: #selector(openLog), keyEquivalent: "l"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "LLMime を終了", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LLMime 設定"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            settingsWindow = nil
        }
    }

    @objc private func checkPermissions() {
        requestPermissions()
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: Log.logFilePath))
    }

    @objc private func quitApp() {
        Log.info("--- LLMime quit ---")
        NSApp.terminate(nil)
    }

    @objc private func hotkeySettingChanged() {
        hotkeyManager.start()
    }

    private func handleHotkeyTriggered() {
        let result = CaretLocator.locate()
        DispatchQueue.main.async { [weak self] in
            self?.popupManager.show(at: result.caretPosition, selectedText: result.selectedText)
        }
    }
}
