import Carbon.HIToolbox

/// A system-wide keyboard shortcut via Carbon's RegisterEventHotKey: needs no Accessibility or
/// Input Monitoring permission, and fails cleanly if another app already registered the combination.
@MainActor
final class GlobalHotKey {
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// ⌃⌥⌘S
    static func soundfork(action: @escaping () -> Void) -> GlobalHotKey {
        GlobalHotKey(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey | cmdKey), action: action)
    }

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
    }

    var isRegistered: Bool { hotKeyRef != nil }

    /// Returns false if the combination is taken.
    @discardableResult
    func register() -> Bool {
        guard hotKeyRef == nil else { return true }
        if handlerRef == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let userData = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
                // Carbon delivers hot-key events on the main thread.
                nonisolated(unsafe) let userData = userData
                MainActor.assumeIsolated {
                    guard let userData else { return }
                    Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().action()
                }
                return noErr
            }, 1, &spec, userData, &handlerRef)
        }
        let id = EventHotKeyID(signature: OSType(0x5346_524B), id: 1) // 'SFRK'
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr { hotKeyRef = nil }
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }
}
