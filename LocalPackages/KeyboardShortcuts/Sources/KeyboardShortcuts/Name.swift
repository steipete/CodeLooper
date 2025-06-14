#if os(macOS)
    public extension KeyboardShortcuts {
        /**
         The strongly-typed name of the keyboard shortcut.

         After registering it, you can use it in, for example, `KeyboardShortcut.Recorder` and `KeyboardShortcut.onKeyUp()`.

         ```swift
         import KeyboardShortcuts

         extension KeyboardShortcuts.Name {
         	static let toggleUnicornMode = Self("toggleUnicornMode")
         }
         ```
         */
        struct Name: Hashable, Sendable {
            // MARK: Lifecycle

            /**
             - Parameter name: Name of the shortcut.
             - Parameter initialShortcut: Optional default key combination. Do not set this unless it's essential. Users find it annoying when random apps steal their existing keyboard shortcuts. It's generally better to show a welcome screen on the first app launch that lets the user set the shortcut.
             */
            public init(_ name: String, default initialShortcut: Shortcut? = nil) {
                self.rawValue = name
                self.defaultShortcut = initialShortcut

                let nameForCapture = self

                if
                    let initialShortcut,
                    !userDefaultsContains(name: nameForCapture)
                {
                    Task { @MainActor in
                        setShortcut(initialShortcut, for: nameForCapture)
                        KeyboardShortcuts.initialize()
                    }
                } else {
                    Task { @MainActor in
                        KeyboardShortcuts.initialize()
                    }
                }
            }

            // MARK: Public

            // This makes it possible to use `Shortcut` without the namespace.
            /// :nodoc:
            public typealias Shortcut = KeyboardShortcuts.Shortcut

            public let rawValue: String
            public let defaultShortcut: Shortcut?

            /**
             The keyboard shortcut assigned to the name.
             */
            public var shortcut: Shortcut? {
                get { KeyboardShortcuts.getShortcut(for: self) }
                nonmutating set {
                    Task { @MainActor in
                        KeyboardShortcuts.setShortcut(newValue, for: self)
                    }
                }
            }
        }
    }

    extension KeyboardShortcuts.Name: RawRepresentable {
        /// :nodoc:
        public init?(rawValue: String) {
            self.init(rawValue)
        }
    }
#endif
