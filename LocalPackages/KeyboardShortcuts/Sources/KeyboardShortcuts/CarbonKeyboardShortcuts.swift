#if os(macOS)
    import Carbon.HIToolbox

    extension EventRef: @retroactive @unchecked Sendable {}

    private func carbonKeyboardShortcutsEventHandler(
        eventHandlerCall _: EventHandlerCallRef?,
        event: EventRef?,
        userData _: UnsafeMutableRawPointer?
    ) -> OSStatus {
        // Need to handle the event synchronously since this is a Carbon callback
        CarbonKeyboardShortcuts.handleEventSynchronously(event)
    }

    enum CarbonKeyboardShortcuts {
        // MARK: Internal

        @MainActor
        static func updateEventHandler() {
            guard eventHandler != nil else {
                return
            }

            if KeyboardShortcuts.isEnabled {
                if KeyboardShortcuts.isMenuOpen {
                    softUnregisterAll()
                    RemoveEventTypesFromHandler(eventHandler, hotKeyEventTypes.count, hotKeyEventTypes)

                    if #available(macOS 14, *) {
                        keyEventMonitor.start()
                    } else {
                        AddEventTypesToHandler(eventHandler, rawKeyEventTypes.count, rawKeyEventTypes)
                    }
                } else {
                    softRegisterAll()

                    if #available(macOS 14, *) {
                        keyEventMonitor.stop()
                    } else {
                        RemoveEventTypesFromHandler(eventHandler, rawKeyEventTypes.count, rawKeyEventTypes)
                    }

                    AddEventTypesToHandler(eventHandler, hotKeyEventTypes.count, hotKeyEventTypes)
                }
            } else {
                softUnregisterAll()
                RemoveEventTypesFromHandler(eventHandler, hotKeyEventTypes.count, hotKeyEventTypes)

                if #available(macOS 14, *) {
                    keyEventMonitor.stop()
                } else {
                    RemoveEventTypesFromHandler(eventHandler, rawKeyEventTypes.count, rawKeyEventTypes)
                }
            }
        }

        @MainActor
        static func register(
            _ shortcut: KeyboardShortcuts.Shortcut,
            onKeyDown: @escaping (KeyboardShortcuts.Shortcut) -> Void,
            onKeyUp: @escaping (KeyboardShortcuts.Shortcut) -> Void
        ) {
            hotKeyId += 1

            var eventHotKey: EventHotKeyRef?
            let registerError = RegisterEventHotKey(
                UInt32(shortcut.carbonKeyCode),
                UInt32(shortcut.carbonModifiers),
                EventHotKeyID(signature: hotKeySignature, id: UInt32(hotKeyId)),
                GetEventDispatcherTarget(),
                0,
                &eventHotKey
            )

            guard
                registerError == noErr,
                let carbonHotKey = eventHotKey
            else {
                print("Error registering hotkey \(shortcut):", registerError)
                return
            }

            hotKeys[hotKeyId] = HotKey(
                shortcut: shortcut,
                carbonHotKeyID: hotKeyId,
                carbonHotKey: carbonHotKey,
                onKeyDown: onKeyDown,
                onKeyUp: onKeyUp
            )

            setUpEventHandlerIfNeeded()
        }

        @MainActor
        static func unregister(_ shortcut: KeyboardShortcuts.Shortcut) {
            for hotKey in hotKeys.values where hotKey.shortcut == shortcut {
                unregisterHotKey(hotKey)
            }
        }

        @MainActor
        static func unregisterAll() {
            for hotKey in hotKeys.values {
                unregisterHotKey(hotKey)
            }
        }

        // MARK: Fileprivate

        // Synchronous wrapper for Carbon callback
        fileprivate static func handleEventSynchronously(_ event: EventRef?) -> OSStatus {
            // EventRef is a C pointer type which is safe to pass across actor boundaries
            guard let event else {
                return OSStatus(eventNotHandledErr)
            }

            return MainActor.assumeIsolated {
                handleEvent(event)
            }
        }

        @MainActor
        fileprivate static func handleEvent(_ event: EventRef?) -> OSStatus {
            guard let event else {
                return OSStatus(eventNotHandledErr)
            }

            switch Int(GetEventKind(event)) {
            case kEventHotKeyPressed, kEventHotKeyReleased:
                return handleHotKeyEvent(event)
            case kEventRawKeyDown, kEventRawKeyUp:
                return handleRawKeyEvent(event)
            default:
                break
            }

            return OSStatus(eventNotHandledErr)
        }

        // MARK: Private

        private final class HotKey {
            // MARK: Lifecycle

            init(
                shortcut: KeyboardShortcuts.Shortcut,
                carbonHotKeyID: Int,
                carbonHotKey: EventHotKeyRef,
                onKeyDown: @escaping (KeyboardShortcuts.Shortcut) -> Void,
                onKeyUp: @escaping (KeyboardShortcuts.Shortcut) -> Void
            ) {
                self.shortcut = shortcut
                self.carbonHotKeyId = carbonHotKeyID
                self.carbonHotKey = carbonHotKey
                self.onKeyDown = onKeyDown
                self.onKeyUp = onKeyUp
            }

            // MARK: Internal

            let shortcut: KeyboardShortcuts.Shortcut
            let carbonHotKeyId: Int
            var carbonHotKey: EventHotKeyRef?
            let onKeyDown: (KeyboardShortcuts.Shortcut) -> Void
            let onKeyUp: (KeyboardShortcuts.Shortcut) -> Void
        }

        @MainActor
        private static var hotKeys = [Int: HotKey]()

        // `SSKS` is just short for `Sindre Sorhus Keyboard Shortcuts`.
        // Using an integer now that `UTGetOSTypeFromString("SSKS" as CFString)` is deprecated.
        // swiftlint:disable:next number_separator
        private static let hotKeySignature: UInt32 = 1_397_967_699 // OSType => "SSKS"

        @MainActor
        private static var hotKeyId = 0
        @MainActor
        private static var eventHandler: EventHandlerRef?

        private static let hotKeyEventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        private static let rawKeyEventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventRawKeyDown)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventRawKeyUp)),
        ]

        @MainActor
        private static let keyEventMonitor = RunLoopLocalEventMonitor(
            events: [.keyDown, .keyUp],
            runLoopMode: .eventTracking
        ) { event in
            guard
                let eventRef = OpaquePointer(event.eventRef),
                handleRawKeyEvent(eventRef) == noErr
            else {
                return event
            }

            return nil
        }

        @MainActor
        private static func setUpEventHandlerIfNeeded() {
            guard
                eventHandler == nil,
                let dispatcher = GetEventDispatcherTarget()
            else {
                return
            }

            var handler: EventHandlerRef?
            let error = InstallEventHandler(
                dispatcher,
                carbonKeyboardShortcutsEventHandler,
                0,
                nil,
                nil,
                &handler
            )

            guard
                error == noErr,
                let handler
            else {
                return
            }

            eventHandler = handler

            updateEventHandler()
        }

        @MainActor
        private static func softRegisterAll() {
            for hotKey in hotKeys.values {
                guard hotKey.carbonHotKey == nil else {
                    continue
                }

                var eventHotKey: EventHotKeyRef?
                let error = RegisterEventHotKey(
                    UInt32(hotKey.shortcut.carbonKeyCode),
                    UInt32(hotKey.shortcut.carbonModifiers),
                    EventHotKeyID(signature: hotKeySignature, id: UInt32(hotKey.carbonHotKeyId)),
                    GetEventDispatcherTarget(),
                    0,
                    &eventHotKey
                )

                guard
                    error == noErr,
                    let eventHotKey
                else {
                    print("Error registering hotkey \(hotKey.shortcut):", error)
                    hotKeys.removeValue(forKey: hotKey.carbonHotKeyId)
                    continue
                }

                hotKey.carbonHotKey = eventHotKey
            }
        }

        @MainActor
        private static func unregisterHotKey(_ hotKey: HotKey) {
            UnregisterEventHotKey(hotKey.carbonHotKey)
            hotKeys.removeValue(forKey: hotKey.carbonHotKeyId)
        }

        @MainActor
        private static func softUnregisterAll() {
            for hotKey in hotKeys.values {
                UnregisterEventHotKey(hotKey.carbonHotKey)
                hotKey.carbonHotKey = nil
            }
        }

        @MainActor
        private static func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
            var eventHotKeyId = EventHotKeyID()
            let error = GetEventParameter(
                event,
                UInt32(kEventParamDirectObject),
                UInt32(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &eventHotKeyId
            )

            guard error == noErr else {
                return error
            }

            guard
                eventHotKeyId.signature == hotKeySignature,
                let hotKey = hotKeys[Int(eventHotKeyId.id)]
            else {
                return OSStatus(eventNotHandledErr)
            }

            switch Int(GetEventKind(event)) {
            case kEventHotKeyPressed:
                hotKey.onKeyDown(hotKey.shortcut)
                return noErr
            case kEventHotKeyReleased:
                hotKey.onKeyUp(hotKey.shortcut)
                return noErr
            default:
                break
            }

            return OSStatus(eventNotHandledErr)
        }

        @MainActor
        private static func handleRawKeyEvent(_ event: EventRef) -> OSStatus {
            var eventKeyCode = UInt32()
            let keyCodeError = GetEventParameter(
                event,
                UInt32(kEventParamKeyCode),
                typeUInt32,
                nil,
                MemoryLayout<UInt32>.size,
                nil,
                &eventKeyCode
            )

            guard keyCodeError == noErr else {
                return keyCodeError
            }

            var eventKeyModifiers = UInt32()
            let keyModifiersError = GetEventParameter(
                event,
                UInt32(kEventParamKeyModifiers),
                typeUInt32,
                nil,
                MemoryLayout<UInt32>.size,
                nil,
                &eventKeyModifiers
            )

            guard keyModifiersError == noErr else {
                return keyModifiersError
            }

            let shortcut = KeyboardShortcuts.Shortcut(
                carbonKeyCode: Int(eventKeyCode),
                carbonModifiers: Int(eventKeyModifiers)
            )

            guard let hotKey = (hotKeys.values.first { $0.shortcut == shortcut }) else {
                return OSStatus(eventNotHandledErr)
            }

            switch Int(GetEventKind(event)) {
            case kEventRawKeyDown:
                hotKey.onKeyDown(hotKey.shortcut)
                return noErr
            case kEventRawKeyUp:
                hotKey.onKeyUp(hotKey.shortcut)
                return noErr
            default:
                break
            }

            return OSStatus(eventNotHandledErr)
        }
    }

    extension CarbonKeyboardShortcuts {
        static var system: [KeyboardShortcuts.Shortcut] {
            var shortcutsUnmanaged: Unmanaged<CFArray>?
            guard
                CopySymbolicHotKeys(&shortcutsUnmanaged) == noErr,
                let shortcuts = shortcutsUnmanaged?.takeRetainedValue() as? [[String: Any]]
            else {
                assertionFailure("Could not get system keyboard shortcuts")
                return []
            }

            return shortcuts.compactMap {
                guard
                    ($0[kHISymbolicHotKeyEnabled] as? Bool) == true,
                    let carbonKeyCode = $0[kHISymbolicHotKeyCode] as? Int,
                    let carbonModifiers = $0[kHISymbolicHotKeyModifiers] as? Int
                else {
                    return nil
                }

                return KeyboardShortcuts.Shortcut(
                    carbonKeyCode: carbonKeyCode,
                    carbonModifiers: carbonModifiers
                )
            }
        }
    }
#endif
