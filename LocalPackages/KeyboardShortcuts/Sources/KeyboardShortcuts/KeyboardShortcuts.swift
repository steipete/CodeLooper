#if os(macOS)
    import AppKit.NSMenu

    /**
     Global keyboard shortcuts for your macOS app.
     */
    public enum KeyboardShortcuts {
        // MARK: Public

        /**
         Enable/disable monitoring of all keyboard shortcuts.

         The default is `true`.
         */
        @MainActor
        public static var isEnabled = true {
            didSet {
                guard isEnabled != oldValue else {
                    return
                }

                CarbonKeyboardShortcuts.updateEventHandler()
            }
        }

        /**
         Remove all handlers receiving keyboard shortcuts events.

         This can be used to reset the handlers before re-creating them to avoid having multiple handlers for the same shortcut.

         - Note: This method does not affect listeners using ``events(for:)``.
         */
        @MainActor
        public static func removeAllHandlers() {
            let shortcutsToUnregister = shortcutsForLegacyHandlers.subtracting(shortcutsForStreamHandlers)

            for shortcut in shortcutsToUnregister {
                unregister(shortcut)
            }

            legacyKeyDownHandlers = [:]
            legacyKeyUpHandlers = [:]
        }

        /**
         Remove the keyboard shortcut handler for the given name.

         This can be used to reset the handler before re-creating it to avoid having multiple handlers for the same shortcut.

         - Parameter name: The name of the keyboard shortcut to remove handlers for.

         - Note: This method does not affect listeners using ``events(for:)``.
         */
        @MainActor
        public static func removeHandler(for name: Name) {
            legacyKeyDownHandlers[name] = nil
            legacyKeyUpHandlers[name] = nil

            // Make sure not to unregister stream handlers.
            guard
                let shortcut = getShortcut(for: name),
                !shortcutsForStreamHandlers.contains(shortcut)
            else {
                return
            }

            unregister(shortcut)
        }

        /**
         Returns whether the keyboard shortcut for the given name is enabled.

         This checks if the shortcut is registered and will trigger handlers. It respects the global ``isEnabled``.

         ```swift
         let isEnabled = KeyboardShortcuts.isEnabled(for: .toggleUnicornMode)
         ```

         - Tip: Use ``disable(_:)-(Name...)`` and ``enable(_:)-(Name...)`` to change the status.
         */
        @MainActor
        public static func isEnabled(for name: Name) -> Bool {
            guard
                isEnabled,
                let shortcut = getShortcut(for: name)
            else {
                return false
            }

            return registeredShortcuts.contains(shortcut)
        }

        /**
         Disable the keyboard shortcut for one or more names.
         */
        @MainActor
        public static func disable(_ names: [Name]) {
            for name in names {
                guard let shortcut = getShortcut(for: name) else {
                    continue
                }

                unregister(shortcut)
            }
        }

        /**
         Disable the keyboard shortcut for one or more names.
         */
        @MainActor
        public static func disable(_ names: Name...) {
            disable(names)
        }

        /**
         Enable the keyboard shortcut for one or more names.
         */
        @MainActor
        public static func enable(_ names: [Name]) {
            for name in names {
                guard let shortcut = getShortcut(for: name) else {
                    continue
                }

                register(shortcut)
            }
        }

        /**
         Enable the keyboard shortcut for one or more names.
         */
        @MainActor
        public static func enable(_ names: Name...) {
            enable(names)
        }

        /**
         Reset the keyboard shortcut for one or more names.

         If the `Name` has a default shortcut, it will reset to that.

         - Note: This overload exists as Swift doesn't support splatting.

         ```swift
         import SwiftUI
         import KeyboardShortcuts

         struct SettingsScreen: View {
         	var body: some View {
         		VStack {
         			// …
         			Button("Reset") {
         				KeyboardShortcuts.reset(.toggleUnicornMode)
         			}
         		}
         	}
         }
         ```
         */
        @MainActor
        public static func reset(_ names: [Name]) {
            for name in names {
                setShortcut(name.defaultShortcut, for: name)
            }
        }

        /**
         Reset the keyboard shortcut for one or more names.

         If the `Name` has a default shortcut, it will reset to that.

         ```swift
         import SwiftUI
         import KeyboardShortcuts

         struct SettingsScreen: View {
         	var body: some View {
         		VStack {
         			// …
         			Button("Reset") {
         				KeyboardShortcuts.reset(.toggleUnicornMode)
         			}
         		}
         	}
         }
         ```
         */
        @MainActor
        public static func reset(_ names: Name...) {
            reset(names)
        }

        /**
         Reset the keyboard shortcut for all the names.

         Unlike `reset(…)`, this resets all the shortcuts to `nil`, not the `defaultValue`.

         ```swift
         import SwiftUI
         import KeyboardShortcuts

         struct SettingsScreen: View {
         	var body: some View {
         		VStack {
         			// …
         			Button("Reset All") {
         				KeyboardShortcuts.resetAll()
         			}
         		}
         	}
         }
         ```
         */
        @MainActor
        public static func resetAll() {
            reset(allNames.toArray())
        }

        /**
         Set the keyboard shortcut for a name.

         Setting it to `nil` removes the shortcut, even if the `Name` has a default shortcut defined. Use `.reset()` if you want it to respect the default shortcut.

         You would usually not need this as the user would be the one setting the shortcut in a settings user-interface, but it can be useful when, for example, migrating from a different keyboard shortcuts package.
         */
        @MainActor
        public static func setShortcut(_ shortcut: Shortcut?, for name: Name) {
            if let shortcut {
                userDefaultsSet(name: name, shortcut: shortcut)
            } else {
                if name.defaultShortcut != nil {
                    userDefaultsDisable(name: name)
                } else {
                    userDefaultsRemove(name: name)
                }
            }
        }

        /**
         Get the keyboard shortcut for a name.
         */
        public static func getShortcut(for name: Name) -> Shortcut? {
            guard
                let data = UserDefaults.standard.string(forKey: userDefaultsKey(for: name))?.data(using: .utf8),
                let decoded = try? JSONDecoder().decode(Shortcut.self, from: data)
            else {
                return nil
            }

            return decoded
        }

        /**
         Listen to the keyboard shortcut with the given name being pressed.

         You can register multiple listeners.

         You can safely call this even if the user has not yet set a keyboard shortcut. It will just be inactive until they do.

         - Important: This will be deprecated in the future. Prefer ``events(for:)`` for new code.

         ```swift
         import AppKit
         import KeyboardShortcuts

         @main
         final class AppDelegate: NSObject, NSApplicationDelegate {
         	func applicationDidFinishLaunching(_ notification: Notification) {
         		KeyboardShortcuts.onKeyDown(for: .toggleUnicornMode) { [self] in
         			isUnicornMode.toggle()
         		}
         	}
         }
         ```
         */
        @MainActor
        public static func onKeyDown(for name: Name, action: @escaping () -> Void) {
            legacyKeyDownHandlers[name, default: []].append(action)
            registerShortcutIfNeeded(for: name)
        }

        /**
         Listen to the keyboard shortcut with the given name being pressed.

         You can register multiple listeners.

         You can safely call this even if the user has not yet set a keyboard shortcut. It will just be inactive until they do.

         - Important: This will be deprecated in the future. Prefer ``events(for:)`` for new code.

         ```swift
         import AppKit
         import KeyboardShortcuts

         @main
         final class AppDelegate: NSObject, NSApplicationDelegate {
         	func applicationDidFinishLaunching(_ notification: Notification) {
         		KeyboardShortcuts.onKeyUp(for: .toggleUnicornMode) { [self] in
         			isUnicornMode.toggle()
         		}
         	}
         }
         ```
         */
        @MainActor
        public static func onKeyUp(for name: Name, action: @escaping () -> Void) {
            legacyKeyUpHandlers[name, default: []].append(action)
            registerShortcutIfNeeded(for: name)
        }

        // MARK: Internal

        /**
         When `true`, event handlers will not be called for registered keyboard shortcuts.
         */
        @MainActor
        static var isPaused = false

        static var allNames: Set<Name> {
            UserDefaults.standard.dictionaryRepresentation()
                .compactMap { key, _ in
                    guard key.hasPrefix(userDefaultsPrefix) else {
                        return nil
                    }

                    let name = key.replacingPrefix(userDefaultsPrefix, with: "")
                    return .init(name)
                }
                .toSet()
        }

        /**
         Enable keyboard shortcuts to work even when an `NSMenu` is open by setting this property when the menu opens and closes.

         `NSMenu` runs in a tracking run mode that blocks keyboard shortcuts events. When you set this property to `true`, it switches to a different kind of event handler, which does work when the menu is open.

         The main use-case for this is toggling the menu of a menu bar app with a keyboard shortcut.
         */
        @MainActor
        private(set) static var isMenuOpen = false {
            didSet {
                guard isMenuOpen != oldValue else {
                    return
                }

                CarbonKeyboardShortcuts.updateEventHandler()
            }
        }

        @MainActor
        static func initialize() {
            guard !isInitialized else {
                return
            }

            openMenuObserver = NotificationCenter.default.addObserver(
                forName: NSMenu.didBeginTrackingNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    isMenuOpen = true
                }
            }

            closeMenuObserver = NotificationCenter.default.addObserver(
                forName: NSMenu.didEndTrackingNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    isMenuOpen = false
                }
            }

            isInitialized = true
        }

        @MainActor
        static func userDefaultsDidChange(name: Name) {
            // TODO: Use proper UserDefaults observation instead of this.
            NotificationCenter.default.post(name: .shortcutByNameDidChange, object: nil, userInfo: ["name": name])
        }

        @MainActor
        static func userDefaultsSet(name: Name, shortcut: Shortcut) {
            guard let encoded = try? JSONEncoder().encode(shortcut).toString else {
                return
            }

            if let oldShortcut = getShortcut(for: name) {
                unregister(oldShortcut)
            }

            register(shortcut)
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey(for: name))
            userDefaultsDidChange(name: name)
        }

        @MainActor
        static func userDefaultsDisable(name: Name) {
            guard let shortcut = getShortcut(for: name) else {
                return
            }

            UserDefaults.standard.set(false, forKey: userDefaultsKey(for: name))
            unregister(shortcut)
            userDefaultsDidChange(name: name)
        }

        @MainActor
        static func userDefaultsRemove(name: Name) {
            guard let shortcut = getShortcut(for: name) else {
                return
            }

            UserDefaults.standard.removeObject(forKey: userDefaultsKey(for: name))
            unregister(shortcut)
            userDefaultsDidChange(name: name)
        }

        static func userDefaultsContains(name: Name) -> Bool {
            UserDefaults.standard.object(forKey: userDefaultsKey(for: name)) != nil
        }

        // MARK: Private

        @MainActor
        private static var registeredShortcuts = Set<Shortcut>()

        @MainActor
        private static var legacyKeyDownHandlers = [Name: [() -> Void]]()
        @MainActor
        private static var legacyKeyUpHandlers = [Name: [() -> Void]]()

        @MainActor
        private static var streamKeyDownHandlers = [Name: [UUID: () -> Void]]()
        @MainActor
        private static var streamKeyUpHandlers = [Name: [UUID: () -> Void]]()

        @MainActor
        private static var isInitialized = false

        @MainActor
        private static var openMenuObserver: NSObjectProtocol?
        @MainActor
        private static var closeMenuObserver: NSObjectProtocol?

        private static let userDefaultsPrefix = "KeyboardShortcuts_"

        @MainActor
        private static var shortcutsForLegacyHandlers: Set<Shortcut> {
            let shortcuts = [legacyKeyDownHandlers.keys, legacyKeyUpHandlers.keys]
                .flatMap(\.self)
                .compactMap(\.shortcut)

            return Set(shortcuts)
        }

        @MainActor
        private static var shortcutsForStreamHandlers: Set<Shortcut> {
            let shortcuts = [streamKeyDownHandlers.keys, streamKeyUpHandlers.keys]
                .flatMap(\.self)
                .compactMap(\.shortcut)

            return Set(shortcuts)
        }

        @MainActor
        private static var shortcutsForHandlers: Set<Shortcut> {
            shortcutsForLegacyHandlers.union(shortcutsForStreamHandlers)
        }

        @MainActor
        private static func register(_ shortcut: Shortcut) {
            guard !registeredShortcuts.contains(shortcut) else {
                return
            }

            CarbonKeyboardShortcuts.register(
                shortcut,
                onKeyDown: handleOnKeyDown,
                onKeyUp: handleOnKeyUp
            )

            registeredShortcuts.insert(shortcut)
        }

        /**
         Register the shortcut for the given name if it has a shortcut.
         */
        @MainActor
        private static func registerShortcutIfNeeded(for name: Name) {
            guard let shortcut = getShortcut(for: name) else {
                return
            }

            register(shortcut)
        }

        @MainActor
        private static func unregister(_ shortcut: Shortcut) {
            CarbonKeyboardShortcuts.unregister(shortcut)
            registeredShortcuts.remove(shortcut)
        }

        /**
         Unregister the given shortcut if it has no handlers.
         */
        @MainActor
        private static func unregisterIfNeeded(_ shortcut: Shortcut) {
            guard !shortcutsForHandlers.contains(shortcut) else {
                return
            }

            unregister(shortcut)
        }

        /**
         Unregister the shortcut for the given name if it has no handlers.
         */
        @MainActor
        private static func unregisterShortcutIfNeeded(for name: Name) {
            guard let shortcut = name.shortcut else {
                return
            }

            unregisterIfNeeded(shortcut)
        }

        @MainActor
        private static func unregisterAll() {
            CarbonKeyboardShortcuts.unregisterAll()
            registeredShortcuts.removeAll()

            // TODO: Should remove user defaults too.
        }

        @MainActor
        private static func handleOnKeyDown(_ shortcut: Shortcut) {
            guard !isPaused else {
                return
            }

            for (name, handlers) in legacyKeyDownHandlers {
                guard getShortcut(for: name) == shortcut else {
                    continue
                }

                for handler in handlers {
                    handler()
                }
            }

            for (name, handlers) in streamKeyDownHandlers {
                guard getShortcut(for: name) == shortcut else {
                    continue
                }

                for handler in handlers.values {
                    handler()
                }
            }
        }

        @MainActor
        private static func handleOnKeyUp(_ shortcut: Shortcut) {
            guard !isPaused else {
                return
            }

            for (name, handlers) in legacyKeyUpHandlers {
                guard getShortcut(for: name) == shortcut else {
                    continue
                }

                for handler in handlers {
                    handler()
                }
            }

            for (name, handlers) in streamKeyUpHandlers {
                guard getShortcut(for: name) == shortcut else {
                    continue
                }

                for handler in handlers.values {
                    handler()
                }
            }
        }

        private static func userDefaultsKey(for shortcutName: Name)
            -> String
        { "\(userDefaultsPrefix)\(shortcutName.rawValue)"
        }
    }

    public extension KeyboardShortcuts {
        enum EventType: Sendable {
            case keyDown
            case keyUp
        }

        /**
         Listen to the keyboard shortcut with the given name being pressed.

         You can register multiple listeners.

         You can safely call this even if the user has not yet set a keyboard shortcut. It will just be inactive until they do.

         Ending the async sequence will stop the listener. For example, in the below example, the listener will stop when the view disappears.

         ```swift
         import SwiftUI
         import KeyboardShortcuts

         struct ContentView: View {
         	@State private var isUnicornMode = false

         	var body: some View {
         		Text(isUnicornMode ? "🦄" : "🐴")
         			.task {
         				for await event in KeyboardShortcuts.events(for: .toggleUnicornMode) where event == .keyUp {
         					isUnicornMode.toggle()
         				}
         			}
         	}
         }
         ```

         - Note: This method is not affected by `.removeAllHandlers()`.
         */
        static func events(for name: Name) -> AsyncStream<KeyboardShortcuts.EventType> {
            AsyncStream { continuation in
                let id = UUID()

                Task { @MainActor in
                    streamKeyDownHandlers[name, default: [:]][id] = {
                        continuation.yield(.keyDown)
                    }

                    streamKeyUpHandlers[name, default: [:]][id] = {
                        continuation.yield(.keyUp)
                    }

                    registerShortcutIfNeeded(for: name)
                }

                continuation.onTermination = { _ in
                    Task { @MainActor in
                        streamKeyDownHandlers[name]?[id] = nil
                        streamKeyUpHandlers[name]?[id] = nil

                        unregisterShortcutIfNeeded(for: name)
                    }
                }
            }
        }

        /**
         Listen to keyboard shortcut events with the given name and type.

         You can register multiple listeners.

         You can safely call this even if the user has not yet set a keyboard shortcut. It will just be inactive until they do.

         Ending the async sequence will stop the listener. For example, in the below example, the listener will stop when the view disappears.

         ```swift
         import SwiftUI
         import KeyboardShortcuts

         struct ContentView: View {
         	@State private var isUnicornMode = false

         	var body: some View {
         		Text(isUnicornMode ? "🦄" : "🐴")
         			.task {
         				for await event in KeyboardShortcuts.events(for: .toggleUnicornMode) where event == .keyUp {
         					isUnicornMode.toggle()
         				}
         			}
         	}
         }
         ```

         - Note: This method is not affected by `.removeAllHandlers()`.
         */
        static func events(_ type: EventType, for name: Name) -> AsyncFilterSequence<AsyncStream<EventType>> {
            events(for: name).filter { $0 == type }
        }
    }

    extension Notification.Name {
        static let shortcutByNameDidChange = Self("KeyboardShortcuts_shortcutByNameDidChange")
    }
#endif
