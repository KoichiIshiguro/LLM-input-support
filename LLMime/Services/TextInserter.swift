import Cocoa

enum TextInserter {

    static func insert(_ text: String, into app: NSRunningApplication?) {
        NSLog("[LLMime] insert() text=%d chars, target=%@",
              text.count, app?.localizedName ?? "nil")

        // クリップボードにセット
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 元アプリをアクティベート
        app?.activate()

        // NSAppleScript で Cmd+V を送信（LLMime のオートメーション権限を使用）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let script = NSAppleScript(source: """
                tell application "System Events"
                    keystroke "v" using command down
                end tell
            """)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)

            if let error = error {
                NSLog("[LLMime] AppleScript failed: %@", error)
            } else {
                NSLog("[LLMime] Inserted via NSAppleScript")
            }
        }
    }
}
