import Cocoa
import SwiftUI

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class PopupWindowManager {
    private var panel: NSPanel?
    private var viewModel: InputPopupViewModel?
    private var localMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var frameObserver: NSObjectProtocol?

    func show(at caretPosition: NSPoint?, selectedText: String?) {
        dismiss()

        let frontApp = NSWorkspace.shared.frontmostApplication
        if frontApp?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontApp
        }

        let vm = InputPopupViewModel()
        vm.selectedText = selectedText
        vm.onInsert = { [weak self] text in
            guard let self = self else { return }
            let targetApp = self.previousApp
            self.dismiss()
            TextInserter.insert(text, into: targetApp)
        }
        vm.onDismiss = { [weak self] in
            self?.dismiss()
        }
        self.viewModel = vm

        let hostView = NSHostingView(rootView: InputPopupView(viewModel: vm))
        hostView.frame.size = hostView.fittingSize

        let p = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: hostView.fittingSize),
            styleMask: [.borderless, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        p.contentView = hostView
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.hasShadow = true
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = false
        p.worksWhenModal = true

        centerOnScreen(panel: p, size: hostView.fittingSize)
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: hostView,
            queue: .main
        ) { [weak self, weak p] _ in
            guard let self = self, let p = p else { return }
            let newSize = hostView.fittingSize
            MainActor.assumeIsolated {
                self.centerOnScreen(panel: p, size: newSize)
            }
        }
        hostView.postsFrameChangedNotifications = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            p.makeKey()
            if let textField = self.findFirstTextField(in: hostView) {
                p.makeFirstResponder(textField)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak p] event in
            guard let self = self, let vm = self.viewModel else { return event }

            if event.keyCode == 53 { // Esc
                if vm.isGenerating {
                    vm.cancel()
                } else {
                    self.dismiss()
                }
                return nil
            }

            if event.keyCode == 36 { // Return/Enter
                if let responder = p?.firstResponder,
                   let textView = responder as? NSTextView,
                   textView.hasMarkedText() {
                    return event
                }

                NSLog("[LLMime] Enter pressed. generating=%d responseEmpty=%d promptEmpty=%d cmd=%d",
                      vm.isGenerating ? 1 : 0,
                      vm.responseText.isEmpty ? 1 : 0,
                      vm.promptText.isEmpty ? 1 : 0,
                      event.modifierFlags.contains(.command) ? 1 : 0)
                if vm.isGenerating {
                    return event
                }
                if !vm.responseText.isEmpty && !event.modifierFlags.contains(.command) {
                    NSLog("[LLMime] → calling insertResult")
                    vm.insertResult()
                    return nil
                }
                let hasContext = vm.selectedText != nil && !(vm.selectedText?.isEmpty ?? true)
                if !vm.promptText.isEmpty || hasContext {
                    NSLog("[LLMime] → calling send")
                    vm.send()
                    return nil
                }
            }

            return event
        }

        self.panel = p
    }

    func dismiss() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let obs = frameObserver {
            NotificationCenter.default.removeObserver(obs)
            frameObserver = nil
        }
        viewModel?.cancel()
        panel?.orderOut(nil)
        panel = nil
        viewModel = nil
    }

    private func findFirstTextField(in view: NSView) -> NSView? {
        for sub in view.subviews {
            if sub is NSTextField {
                return sub
            }
            if let found = findFirstTextField(in: sub) {
                return found
            }
        }
        return nil
    }

    private func showToast(_ message: String) {
        let toast = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 36),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.level = .floating
        toast.hasShadow = true

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 36))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.9).cgColor
        container.layer?.cornerRadius = 8

        label.frame = container.bounds
        container.addSubview(label)
        toast.contentView = container

        if let screen = NSScreen.main {
            let x = (screen.frame.width - 260) / 2
            let y = screen.frame.height * 0.15
            toast.setFrameOrigin(NSPoint(x: x, y: y))
        }

        toast.orderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                toast.animator().alphaValue = 0
            }, completionHandler: {
                toast.orderOut(nil)
            })
        }
    }

    private func centerOnScreen(panel: NSPanel, size: NSSize) {
        let clamped = NSSize(width: min(size.width, 960), height: size.height)
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - clamped.width / 2
        let y = visibleFrame.midY - clamped.height / 2
        panel.setFrame(
            NSRect(x: x, y: y, width: clamped.width, height: clamped.height),
            display: true,
            animate: false
        )
    }
}
