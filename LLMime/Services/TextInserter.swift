import Cocoa

enum TextInserter {

    static func insert(_ text: String, into app: NSRunningApplication?) {
        Log.info("insert() text=\(text.count) chars, target=\(app?.localizedName ?? "nil")")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        app?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let source = CGEventSource(stateID: .combinedSessionState)
            // 'v' = keyCode 9
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            Log.info("Inserted via CGEvent Cmd+V")
        }
    }
}
