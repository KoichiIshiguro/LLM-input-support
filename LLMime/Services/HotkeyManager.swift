import Cocoa
import Carbon

final class HotkeyManager {
    private let onTrigger: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var carbonHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private var longPressKeyCode: Int64 = 0
    private var longPressTimer: DispatchWorkItem?

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func start() {
        stop()
        let settings = AppSettings.shared
        let mods = UInt32(settings.hotkeyModifiers)
        let key = UInt32(settings.hotkeyKeyCode)
        startCarbonHotKey(modifiers: mods, keyCode: key)

        if settings.eisuKanaEnabled {
            startEventTap()
        }
    }

    func stop() {
        stopEventTap()
        stopCarbonHotKey()
    }

    // MARK: - Carbon Hot Key (reliable standard hotkeys)

    private func startCarbonHotKey(modifiers: UInt32? = nil, keyCode: UInt32? = nil) {
        let mods = modifiers ?? UInt32(controlKey | optionKey)
        let key = keyCode ?? UInt32(kVK_Space)

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4C4C4D49) // "LLMI"
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerBlock: EventHandlerUPP = { _, event, refcon -> OSStatus in
            guard let refcon = refcon else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.triggerActivation()
            return noErr
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handlerBlock, 1, &eventType, refcon, &eventHandlerRef)
        RegisterEventHotKey(key, mods, hotKeyID, GetApplicationEventTarget(), 0, &carbonHotKeyRef)
    }

    private func stopCarbonHotKey() {
        if let ref = carbonHotKeyRef {
            UnregisterEventHotKey(ref)
            carbonHotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    // MARK: - CGEventTap (for 英数+かな chord)

    private func startEventTap() {
        let allKeyEvents: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            return manager.handleEisuKanaEvent(type: type, event: event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: allKeyEvents,
            callback: callback,
            userInfo: refcon
        ) else {
            NSLog("[LLMime] CGEventTap 作成失敗 — アクセシビリティ権限を確認")
            promptAccessibilityPermission()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEisuKanaEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isEisuOrKana = keyCode == Int64(kVK_JIS_Eisu) || keyCode == Int64(kVK_JIS_Kana)
        guard isEisuOrKana else {
            cancelLongPress()
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown || type == .flagsChanged {
            if longPressKeyCode != keyCode {
                cancelLongPress()
                longPressKeyCode = keyCode
                let item = DispatchWorkItem { [weak self] in
                    self?.longPressKeyCode = 0
                    self?.triggerActivation()
                }
                longPressTimer = item
                let duration = max(0.1, AppSettings.shared.eisuKanaHoldDuration)
                DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
            }
        } else if type == .keyUp {
            if longPressKeyCode == keyCode {
                cancelLongPress()
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func cancelLongPress() {
        longPressTimer?.cancel()
        longPressTimer = nil
        longPressKeyCode = 0
    }

    private func triggerActivation() {
        cancelLongPress()
        DispatchQueue.main.async { [weak self] in
            self?.onTrigger()
        }
    }

    private func promptAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    deinit {
        stop()
    }
}
