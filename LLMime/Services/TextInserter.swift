import Cocoa

enum TextInserter {

    static func insert(_ text: String, into app: NSRunningApplication?) {
        let pid = app?.processIdentifier ?? 0
        Log.info("insert() text=\(text.count) chars, target=\(app?.localizedName ?? "nil") pid=\(pid)")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        app?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let source = CGEventSource(stateID: .privateState)
            source?.localEventsSuppressionInterval = 0.0

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                Log.error("Failed to create CGEvent")
                return
            }
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand

            if pid != 0 {
                keyDown.postToPid(pid)
                keyUp.postToPid(pid)
                Log.info("Inserted via CGEvent postToPid(\(pid))")
            } else {
                keyDown.post(tap: .cgSessionEventTap)
                keyUp.post(tap: .cgSessionEventTap)
                Log.info("Inserted via CGEvent cgSessionEventTap")
            }
        }
    }
}
