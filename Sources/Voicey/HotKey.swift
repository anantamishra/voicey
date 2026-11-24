import Carbon.HIToolbox

/// Global hotkey via Carbon; needs no extra permission.
final class HotKey {
    private var ref: EventHotKeyRef?
    private static var onPress: (() -> Void)?
    private static var onRelease: (() -> Void)?

    init(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        HotKey.onPress = onPress
        HotKey.onRelease = onRelease
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            switch GetEventKind(event) {
            case UInt32(kEventHotKeyPressed): HotKey.onPress?()
            case UInt32(kEventHotKeyReleased): HotKey.onRelease?()
            default: break
            }
            return noErr
        }, specs.count, &specs, nil, nil)
    }

    func register(keyCode: Int, modifiers: Int) {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x56434559), id: 1)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref)
    }

    /// True if macOS lets us claim this combination (some are reserved by the system or other apps).
    static func canRegister(keyCode: Int, modifiers: Int) -> Bool {
        var probe: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x56434559), id: 99)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &probe)
        if let probe { UnregisterEventHotKey(probe) }
        return status == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}
