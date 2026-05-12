import Cocoa
import ApplicationServices

enum CaretLocator {

    struct Result {
        let caretPosition: NSPoint?
        let selectedText: String?
    }

    static func locate() -> Result {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return Result(caretPosition: nil, selectedText: nil)
        }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return Result(caretPosition: nil, selectedText: nil)
        }

        let element = focusedElement as! AXUIElement

        let selectedText = getSelectedText(from: element)
        let caretPosition = getCaretPosition(from: element)

        return Result(caretPosition: caretPosition, selectedText: selectedText)
    }

    private static func getCaretPosition(from element: AXUIElement) -> NSPoint? {
        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success else {
            return nil
        }

        var bounds: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue!,
            &bounds
        ) == .success else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(bounds as! AXValue, .cgRect, &rect) else {
            return nil
        }

        // AX座標は画面左上原点 → NSWindow座標（画面左下原点）に変換
        guard let screen = NSScreen.main else { return nil }
        let screenHeight = screen.frame.height
        let flippedY = screenHeight - (rect.origin.y + rect.size.height)

        return NSPoint(x: rect.origin.x, y: flippedY)
    }

    private static func getSelectedText(from element: AXUIElement) -> String? {
        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText) == .success else {
            return nil
        }
        let text = selectedText as? String
        return (text?.isEmpty == false) ? text : nil
    }
}
