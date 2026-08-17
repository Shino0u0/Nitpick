import AppKit
import Carbon.HIToolbox
import Foundation

/// Global shortcuts via Carbon RegisterEventHotKey: works without the
/// Accessibility permission an event tap would need.
@MainActor
final class HotkeyManager {
    struct Shortcut: Equatable, Sendable {
        var keyCode: UInt32
        /// Carbon modifier mask (cmdKey, optionKey, controlKey, shiftKey).
        var carbonModifiers: UInt32

        static let defaultDictate = Shortcut(
            keyCode: UInt32(kVK_ANSI_D),
            carbonModifiers: UInt32(cmdKey | optionKey)
        )
        static let defaultAsk = Shortcut(
            keyCode: UInt32(kVK_ANSI_A),
            carbonModifiers: UInt32(cmdKey | optionKey)
        )

        /// Serialized as "keyCode:carbonModifiers".
        var serialized: String { "\(keyCode):\(carbonModifiers)" }

        init(keyCode: UInt32, carbonModifiers: UInt32) {
            self.keyCode = keyCode
            self.carbonModifiers = carbonModifiers
        }

        init?(_ serialized: String) {
            let parts = serialized.split(separator: ":")
            guard parts.count == 2, let key = UInt32(parts[0]),
                let mods = UInt32(parts[1])
            else { return nil }
            self.init(keyCode: key, carbonModifiers: mods)
        }

        init?(event: NSEvent) {
            var mods: UInt32 = 0
            if event.modifierFlags.contains(.command) { mods |= UInt32(cmdKey) }
            if event.modifierFlags.contains(.option) { mods |= UInt32(optionKey) }
            if event.modifierFlags.contains(.control) { mods |= UInt32(controlKey) }
            if event.modifierFlags.contains(.shift) { mods |= UInt32(shiftKey) }
            guard mods != 0 else { return nil }
            self.init(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
        }

        var display: String {
            var parts = ""
            if carbonModifiers & UInt32(controlKey) != 0 { parts += "⌃" }
            if carbonModifiers & UInt32(optionKey) != 0 { parts += "⌥" }
            if carbonModifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
            if carbonModifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
            return parts + Self.keyName(for: keyCode)
        }

        private static func keyName(for keyCode: UInt32) -> String {
            let map: [UInt32: String] = [
                UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B",
                UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
                UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
                UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
                UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J",
                UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
                UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N",
                UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
                UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
                UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
                UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V",
                UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
                UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
                UInt32(kVK_Space): "Space", UInt32(kVK_Return): "Return",
            ]
            return map[keyCode] ?? "Key\(keyCode)"
        }
    }

    private var handlers: [UInt32: () -> Void] = [:]
    private var registered: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    /// Registers (or re-registers) a shortcut for a stable id. Returns false
    /// when the system rejects it (typically a conflict with another app).
    func register(_ shortcut: Shortcut, id: UInt32, handler: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        if let existing = registered.removeValue(forKey: id) {
            UnregisterEventHotKey(existing)
        }
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E504B31), id: id)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return false }
        registered[id] = ref
        handlers[id] = handler
        return true
    }

    func unregister(id: UInt32) {
        if let ref = registered.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        handlers[id] = nil
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                let manager = Unmanaged<HotkeyManager>
                    .fromOpaque(userData).takeUnretainedValue()
                // Carbon delivers on the main thread; hop formally anyway.
                let id = hotKeyID.id
                Task { @MainActor in
                    manager.handlers[id]?()
                }
                return noErr
            },
            1, &eventType, selfPointer, &eventHandler
        )
    }
}
