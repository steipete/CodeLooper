import Foundation
import Carbon
import Defaults
import OSLog

class GlobalShortcutManager {
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "GlobalShortcutManager")
    private var eventHotKeyRef: EventHotKeyRef? = nil
    private var currentShortcutString: String? = nil

    // The shared event handler for all hotkeys registered by this application instance.
    // This needs to be a global function or a static method that can be passed as a C function pointer.
    private static let hotKeyHandler: EventHandlerUPP = {
        // Define the C-style event handler function.
        // This function will be called by the system when the hotkey is pressed.
        // Explicitly define the C function pointer type for EventHandlerProc
        let handler: @convention(c) (EventHandlerCallRef?, EventRef?, UnsafeMutableRawPointer?) -> OSStatus = { (nextHandler, event, userData) -> OSStatus in
            // We don't need userData if the handler itself knows what to do or accesses shared state.
            // However, if we were to manage multiple distinct hotkeys with this single manager instance,
            // userData could point to an identifier for which hotkey was pressed.

            // Here, we know the action is to toggle global monitoring.
            Defaults[.isGlobalMonitoringEnabled].toggle()
            let newMonitoringState = Defaults[.isGlobalMonitoringEnabled]
            print("Global shortcut pressed. Toggled monitoring to: \(newMonitoringState)")
            
            // Post a notification if other parts of the app need to react
            NotificationCenter.default.post(name: .globalMonitoringStateChangedByShortcut, object: newMonitoringState)
            
            // We have handled the event.
            return noErr
        }
        return NewEventHandlerUPP(handler)
    }()

    init() {
        // Setup the event type for hotkey events.
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        // Install the application-wide event handler for hotkey presses.
        InstallApplicationEventHandler(GlobalShortcutManager.hotKeyHandler, 1, &eventType, nil, nil)
    }

    func register(shortcut: String?) {
        unregister()
        currentShortcutString = shortcut
        guard let shortcutString = shortcut, !shortcutString.isEmpty else {
            logger.info("No shortcut string provided or empty. No global shortcut will be registered.")
            return
        }

        var (keyCode, modifiers) = parseShortcutString(shortcutString)

        guard let unwrappedKeyCode = keyCode else {
            logger.error("Failed to parse key code from shortcut: \(shortcutString)")
            return
        }
        
        logger.info("Attempting to register shortcut: '\(shortcutString)' (KeyCode: \(unwrappedKeyCode), Modifiers: \(modifiers ?? 0))")

        var hotKeyID = EventHotKeyID(signature: OSType(truncatingIfNeeded: "CLGS".unicodeScalars.reduce(0) { ($0 << 8) + $1.value }), id: 1)
        let hotKeyModifiers = UInt32(modifiers ?? 0)
        
        let status = RegisterEventHotKey(UInt32(unwrappedKeyCode), hotKeyModifiers, hotKeyID, GetApplicationEventTarget(), 0, &eventHotKeyRef)

        if status == noErr {
            logger.info("Successfully registered global shortcut: \(shortcutString)")
        } else {
            eventHotKeyRef = nil
            logger.error("Failed to register global shortcut: \(shortcutString). Carbon Error: \(status)")
            if status == -9878 {
                 logger.error("Error -9878: The key combination '\(shortcutString)' is likely already in use by another application or system service.")
            }
        }
    }

    func unregister() {
        if let hotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            eventHotKeyRef = nil
            logger.info("Successfully unregistered previous global shortcut: \(currentShortcutString ?? "N/A")")
        }
        currentShortcutString = nil
    }
    
    private func parseShortcutString(_ shortcutString: String) -> (keyCode: UInt16?, modifiers: Int?) {
        let trimmed = shortcutString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.warning("Empty shortcut string provided")
            return (nil, nil)
        }
        
        var modifiersValue: Int = 0 // Renamed to avoid conflict with module
        var keyString: String?
        
        let parts: [String]
        if trimmed.contains("+") {
            parts = trimmed.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            parts = parseModifierSymbols(from: trimmed)
        }
        
        for part in parts {
            let lowercased = part.lowercased()
            
            switch lowercased {
            case "⌘", "command", "cmd":
                modifiersValue |= cmdKey
            case "⌥", "option", "alt", "opt":
                modifiersValue |= optionKey
            case "⇧", "shift":
                modifiersValue |= shiftKey
            case "⌃", "control", "ctrl":
                modifiersValue |= controlKey
            default:
                if keyString == nil {
                    keyString = part
                } else {
                    logger.warning("Multiple non-modifier keys found in shortcut: \(shortcutString)")
                    return (nil, nil)
                }
            }
        }
        
        guard let key = keyString else {
            logger.warning("No main key found in shortcut: \(shortcutString)")
            return (nil, modifiersValue == 0 ? nil : modifiersValue)
        }
        
        let keyCode = parseKeyCode(from: key)
        if keyCode == nil {
            logger.warning("Unrecognized key: \(key) in shortcut: \(shortcutString)")
        }
        
        return (keyCode, modifiersValue == 0 ? nil : modifiersValue)
    }
    
    private func parseModifierSymbols(from string: String) -> [String] {
        var parts: [String] = []
        var currentPart = ""
        
        for char in string {
            let charString = String(char)
            switch charString {
            case "⌘", "⌥", "⇧", "⌃":
                if !currentPart.isEmpty {
                    parts.append(currentPart)
                    currentPart = ""
                }
                parts.append(charString)
            default:
                currentPart += charString
            }
        }
        
        if !currentPart.isEmpty {
            parts.append(currentPart)
        }
        
        return parts
    }
    
    private func parseKeyCode(from keyString: String) -> UInt16? {
        let lowercased = keyString.lowercased()
        
        switch lowercased {
        case "space": return UInt16(kVK_Space)
        case "enter", "return": return UInt16(kVK_Return)
        case "escape", "esc": return UInt16(kVK_Escape)
        case "delete", "backspace": return UInt16(kVK_Delete)
        case "tab": return UInt16(kVK_Tab)
        case "uparrow", "up": return UInt16(kVK_UpArrow)
        case "downarrow", "down": return UInt16(kVK_DownArrow)
        case "leftarrow", "left": return UInt16(kVK_LeftArrow)
        case "rightarrow", "right": return UInt16(kVK_RightArrow)
        case "f1": return UInt16(kVK_F1)
        case "f2": return UInt16(kVK_F2)
        case "f3": return UInt16(kVK_F3)
        case "f4": return UInt16(kVK_F4)
        case "f5": return UInt16(kVK_F5)
        case "f6": return UInt16(kVK_F6)
        case "f7": return UInt16(kVK_F7)
        case "f8": return UInt16(kVK_F8)
        case "f9": return UInt16(kVK_F9)
        case "f10": return UInt16(kVK_F10)
        case "f11": return UInt16(kVK_F11)
        case "f12": return UInt16(kVK_F12)
        default: break
        }
        
        if keyString.count == 1 {
            let char = keyString.uppercased().first!
            if char >= "A" && char <= "Z" {
                switch char {
                    case "A": return UInt16(kVK_ANSI_A)
                    case "B": return UInt16(kVK_ANSI_B)
                    case "C": return UInt16(kVK_ANSI_C)
                    case "D": return UInt16(kVK_ANSI_D)
                    case "E": return UInt16(kVK_ANSI_E)
                    case "F": return UInt16(kVK_ANSI_F)
                    case "G": return UInt16(kVK_ANSI_G)
                    case "H": return UInt16(kVK_ANSI_H)
                    case "I": return UInt16(kVK_ANSI_I)
                    case "J": return UInt16(kVK_ANSI_J)
                    case "K": return UInt16(kVK_ANSI_K)
                    case "L": return UInt16(kVK_ANSI_L)
                    case "M": return UInt16(kVK_ANSI_M)
                    case "N": return UInt16(kVK_ANSI_N)
                    case "O": return UInt16(kVK_ANSI_O)
                    case "P": return UInt16(kVK_ANSI_P)
                    case "Q": return UInt16(kVK_ANSI_Q)
                    case "R": return UInt16(kVK_ANSI_R)
                    case "S": return UInt16(kVK_ANSI_S)
                    case "T": return UInt16(kVK_ANSI_T)
                    case "U": return UInt16(kVK_ANSI_U)
                    case "V": return UInt16(kVK_ANSI_V)
                    case "W": return UInt16(kVK_ANSI_W)
                    case "X": return UInt16(kVK_ANSI_X)
                    case "Y": return UInt16(kVK_ANSI_Y)
                    case "Z": return UInt16(kVK_ANSI_Z)
                    default: break
                }
            }
            if char >= "0" && char <= "9" {
                switch char {
                case "0": return UInt16(kVK_ANSI_0)
                case "1": return UInt16(kVK_ANSI_1)
                case "2": return UInt16(kVK_ANSI_2)
                case "3": return UInt16(kVK_ANSI_3)
                case "4": return UInt16(kVK_ANSI_4)
                case "5": return UInt16(kVK_ANSI_5)
                case "6": return UInt16(kVK_ANSI_6)
                case "7": return UInt16(kVK_ANSI_7)
                case "8": return UInt16(kVK_ANSI_8)
                case "9": return UInt16(kVK_ANSI_9)
                default: break
                }
            }
            switch char {
                case "=": return UInt16(kVK_ANSI_Equal)
                case "-": return UInt16(kVK_ANSI_Minus)
                case "]": return UInt16(kVK_ANSI_RightBracket)
                case "[": return UInt16(kVK_ANSI_LeftBracket)
                case "\'": return UInt16(kVK_ANSI_Quote)
                case ";": return UInt16(kVK_ANSI_Semicolon)
                case "\\": return UInt16(kVK_ANSI_Backslash)
                case "`": return UInt16(kVK_ANSI_Grave)
                case ",": return UInt16(kVK_ANSI_Comma)
                case ".": return UInt16(kVK_ANSI_Period)
                case "/": return UInt16(kVK_ANSI_Slash)
                default: break
            }
        }
        return nil
    }

    deinit {
        unregister()
        // The application event handler should be removed if it was specific to this instance,
        // but if it's a general application handler, it might persist until app termination.
        // For a shared static handler like this, explicit removal might not be strictly necessary
        // or could be handled at a higher level if the app supports dynamic plugin/unplugin of this manager.
    }
}

extension Notification.Name {
    static let globalMonitoringStateChangedByShortcut = Notification.Name("globalMonitoringStateChangedByShortcut")
} 