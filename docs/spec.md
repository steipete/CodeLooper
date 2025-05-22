
**Code Looper - Technical Specification**

**Version:** 1.0 (Derived from Iterative Revisions up to v26)
**Project Repository:** `https://github.com/steipete/CodeLooper`
**Project Domain:** `https://codelooper.app/`
**Bundle Identifier:** `me.steipete.CodeLooper`
**Target Platform:** macOS 15 (Sequoia) and later

**Primary Goal:** To supervise the "Cursor" application by automatically resolving common interruptions ("Connection Issues," "Cursor Stops," "Cursor Force-Stopped") and stuck states. It also assists users in configuring and managing Model Context Protocol (MCP) servers (Claude Code, macOS Automator, XcodeBuild) for use with AI agents like Cursor, enhancing developer productivity.

---

**1. Core Architecture & Setup**

*   **1.1. Application Type:**
    *   macOS Menu Bar Application.
    *   No Dock icon (`LSUIElement` = `YES` in `Info.plist`).
    *   Primary UI is a custom, non-activating `NSPopover` attached to the `NSStatusItem` in the menu bar.
*   **1.2. Language & UI Technologies:**
    *   **Primary Language:** Swift (latest version compatible with Xcode for macOS 15).
    *   **UI Technologies:**
        *   **SwiftUI:** For the `NSPopover` content (main UI), Settings panel, First Launch Welcome Guide, and About panel.
        *   **AppKit:** For `NSStatusItem`, `NSPopover` management, application lifecycle (`AppDelegate`), `NSRunningApplication` for process monitoring, `NSAlert` for system-style dialogs, and bridging/hosting SwiftUI views where necessary.
*   **1.3. Accessibility Engine (`AXorcist` Swift Library):**
    *   Code Looper will directly link against and import the `AXorcist` Swift library. This will be managed as a local Swift Package dependency.
    *   An instance of the `AXorcist` class (e.g., `let axController = AXorcist()`) will be created and used by Code Looper for all UI element queries and interactions within target applications.
    *   Code Looper will utilize `AXorcist`-defined `Codable` Swift structs (e.g., `CommandEnvelope`, `Locator`, `HandlerResponse`, `AXElement`) for constructing requests to and parsing responses from the `AXorcist` API.
    *   `AXorcist` API methods (e.g., `handleQuery`, `handlePerformAction`) are assumed to be marked `@MainActor`. Code Looper will call these from its background monitoring tasks via `await MainActor.run { ... }` to ensure thread safety and correct execution context.
*   **1.4. Key Dependencies:**
    *   `AXorcist.swift` (local Swift Package).
    *   Sparkle (`https://github.com/sparkle-project/Sparkle.git`) via Swift Package Manager for auto-updates.
    *   AppKit, SwiftUI, Foundation (provided by macOS SDK).
*   **1.5. Bundled Resources:**
    *   Custom application icon set for `NSStatusItem`, reflecting different states (see 1.6).
    *   `terminator.scpt`: AppleScript file for the "Terminator Terminal Controller" Cursor Rule Set.
    *   `terminator_rule.mdc`: MDC rule file for the "Terminator Terminal Controller" Cursor Rule Set.
    *   A subtle, short audio file (e.g., `.aiff`, `.wav`) for intervention feedback.
    *   Hardcoded default `AXorcist.Locator` definitions (as Swift struct initializers or JSON strings) for key Cursor UI elements. These serve as the baseline before user overrides.
*   **1.6. Menu Bar Icon Behavior (`NSStatusItem.button.image`):**
    *   **Green:** At least one monitored Cursor instance is in a "Generating..." state (confirmed by `AXorcist`), AND no instances are in a "Red" state (Persistent Error/Unrecoverable).
    *   **Black:** No instances are "Generating...", but all monitored instances are either "Idle" (running, no errors, responsive) or "Active" (e.g., recent sidebar activity detected), AND no instances are in a "Red" or "Yellow/Orange" state.
    *   **Gray:** Code Looper's main monitoring toggle (global) is disabled by the user.
    *   **Yellow/Orange:** At least one Cursor instance is in a "Recovering" state (Code Looper is actively attempting an automated fix), AND no instances are in a "Red" state.
    *   **Red:** At least one Cursor instance is in a "Persistent Error" state (multiple recovery cycles failed) OR an "Unrecoverable: UI Element Not Found" state for a critical action. This state takes precedence over Green/Black/Yellow if co-occurring.
    *   **Action Performed Flash:** Upon successful automated intervention, the icon will briefly change to a highlight variant (e.g., brighter current color or a distinct "success" color) for approximately 0.2-0.3 seconds, then revert to its current state-indicative color.
*   **1.7. Logging Service (`SessionLogger`):**
    *   An `actor SessionLogger: ObservableObject` will be implemented as a singleton (`SessionLogger.shared`).
    *   **Storage:** `@Published private(set) var entries: [LogEntry] = []`. Max entries (e.g., 1000, configurable internally); oldest entries evicted (FIFO).
    *   **`LogEntry` Struct:** `id: UUID`, `timestamp: Date`, `level: LogLevel` (enum: Debug, Info, Warn, Error), `message: String`, `instancePID: pid_t?`.
    *   **API:** `func log(level: LogLevel, message: String, pid: pid_t? = nil)`, `func clearLog()`.
    *   `@Published entries` will be observed by SwiftUI views, with updates automatically marshaled to `MainActor` by SwiftUI.
*   **1.8. Element Locator Configuration & Cache:**
    *   Default `AXorcist.Locator` definitions are bundled with the app (hardcoded).
    *   User-overridable `Locator` definitions (as JSON strings) are stored in `UserDefaults` via the Advanced Settings panel.
    *   A global, session-only (not persisted across launches for V1) in-memory cache will store `AXorcist.Locator` objects that have *successfully worked* during the current session for critical elements. This cache is populated by successful dynamic discoveries.

---

**2. Core Functionality: Cursor Supervision & Automation**

*   **2.1. Process Monitoring:**
    *   Use `NSRunningApplication.runningApplications(withBundleIdentifier: "ai.cursor.Cursor")` to detect and track active Cursor instances.
    *   Maintain a list of `pid_t` for monitored instances. Handle launch and termination events to update this list and associated per-instance state.
*   **2.2. State Management (Per Monitored Cursor Instance, using Dictionaries keyed by `pid_t`):**
    *   `automaticInterventionsSincePositiveActivity: [pid_t: Int]`
    *   `connectionIssueResumeButtonClicks: [pid_t: Int]`
    *   `consecutiveRecoveryFailures: [pid_t: Int]`
    *   `lastKnownSidebarStateHash: [pid_t: String?]?` (Optional dictionary, value is optional string)
    *   `unrecoverableReason: [pid_t: String?]?` (Optional dictionary, value is optional string)
*   **2.3. Main Monitoring Loop (The "Looper"):**
    *   An `async` loop running on a background `Task`. Configurable interval (default 1s, via Settings).
    *   The loop iterates through all detected active Cursor PIDs.
    *   **For each Cursor instance (identified by `pid`):**
        1.  **Unrecoverable State Check:** If `unrecoverableReason[pid]` is non-nil, log details, update UI for this instance to "Unrecoverable: [reason]", and skip active interventions for this instance during this tick. This state is cleared if "Generating..." state is detected or if the user manually resumes interventions for this instance via Code Looper's UI.
        2.  **Intervention Limit Check:** If `automaticInterventionsSincePositiveActivity[pid, default: 0]` >= "Max Auto-Interventions Per Instance" (global config from Settings), log limit reached for PID, update UI for this instance to "Paused (Limit Reached)", and skip active interventions for this PID. This is reset by positive work detection or manual resume.
        3.  **Positive Working Check (via `AXorcist`):**
            *   Construct `Locator` (default/user-config) to find text elements containing "Generating", "Thinking", or "Processing" (hardcoded V1 list).
            *   Execute `await MainActor.run { axController.handleQuery(...) }`.
            *   If successful and element found:
                *   `unrecoverableReason[pid] = nil`.
                *   Reset `automaticInterventionsSincePositiveActivity[pid] = 0`, `connectionIssueResumeButtonClicks[pid] = 0`, `consecutiveRecoveryFailures[pid] = 0`.
                *   Update instance UI status to "Working (Generating)". Update global icon to Green (if conditions met). Log success.
                *   `continue` to the next Cursor instance or next loop tick.
        4.  **Sidebar Activity Check (via `AXorcist` - if "Monitor Sidebar Activity" enabled):**
            *   Use `Locator` (default/user-config) to find primary sidebar element.
            *   If found, query its state (hash of `AXTitle`/`AXValue` of first N (e.g., 5-10, internal V1 default) visible children).
            *   If current sidebar state hash differs from `lastKnownSidebarStateHash[pid, default: nil]` AND `unrecoverableReason[pid]` is nil (i.e., not currently in an unrecoverable state that might prevent sidebar updates):
                *   Log "Sidebar activity detected for PID \(pid)".
                *   `unrecoverableReason[pid] = nil`.
                *   Reset `automaticInterventionsSincePositiveActivity[pid] = 0`, `connectionIssueResumeButtonClicks[pid] = 0`, `consecutiveRecoveryFailures[pid] = 0`.
                *   Update instance UI status to "Working (Recent Activity)". Update global icon to Black (if conditions met).
                *   `lastKnownSidebarStateHash[pid] = newHash`.
                *   `continue` to the next Cursor instance or next loop tick.
            *   Else (no change or sidebar not found), update `lastKnownSidebarStateHash[pid]` if sidebar was found but static.
        5.  **Error Checks & Automated Interventions (if not in positive working state, not unrecoverable for the *specific problem*, and not paused by limit):**
            *   **Target Application Identifier for `AXorcist` calls:** Use the specific `pid_t` of the current Cursor instance.
            *   **A. "Connection Issues":**
                *   Detect error text ("We're having trouble connecting...") via `AXorcist.handleQuery` using appropriate `Locator`.
                *   If detected: Update instance UI to "Recovering (Connection Issue)".
                *   If `connectionIssueResumeButtonClicks[pid, default: 0]` < "Max 'Resume' clicks..." (config):
                    *   Increment `connectionIssueResumeButtonClicks[pid]`.
                    *   Attempt to find "Resume" button via adaptive location strategy (see 2.4) using `AXorcist`.
                    *   If button found: `await MainActor.run { axController.handlePerformAction(locator: resumeButtonLocator, actionName: kAXPressAction, ...) }`. Log success/failure.
                    *   If button NOT found after discovery: `unrecoverableReason[pid] = "Connection Issue: 'Resume' button not found"`. Log. Update instance UI.
                *   Else (click limit reached): Log escalation. Perform "Cursor Stops" recovery (type custom text). Reset `connectionIssueResumeButtonClicks[pid] = 0`.
            *   **B. "Cursor Force-Stopped (Loop Limit)":**
                *   Detect state (e.g., presence of "resume the conversation" text) via `AXorcist.handleQuery`.
                *   If detected: Update instance UI to "Recovering (Force-Stop)". Attempt to find "resume the conversation" element via adaptive location strategy.
                *   If element found: `await MainActor.run { axController.handlePerformAction(locator: resumeLinkLocator, actionName: kAXPressAction, ...) }`. Log success/failure. Reset `connectionIssueResumeButtonClicks[pid]`.
                *   If element NOT found: `unrecoverableReason[pid] = "Force-Stop: 'Resume conversation' element not found"`. Log. Update instance UI.
            *   **C. "Cursor Stops" (General Idle/Stuck):**
                *   If no specific errors, not generating/active, and appears idle for "Stuck Detection Timeout" (config).
                *   If detected: Update instance UI to "Recovering (Stopped)". Attempt to find main input field via adaptive location strategy.
                *   If field found: `await MainActor.run { axController.handlePerformAction(locator: inputFieldLocator, actionName: kAXSetValueAttribute, actionValue: AnyCodable(customRecoveryText), ...) }`, then another `handlePerformAction` for Enter/Confirm. Log success/failure. Reset `connectionIssueResumeButtonClicks[pid]`.
                *   If field NOT found: `unrecoverableReason[pid] = "Cursor Stops: Main input field not found"`. Log. Update instance UI.
            *   **Post-Intervention:** If any of the above interventions were attempted and `AXorcist` reported success for the action:
                *   `automaticInterventionsSincePositiveActivity[pid, default: 0] += 1`.
                *   Play sound effect (if enabled in Settings).
                *   Log the specific action to `SessionLogger`.
                *   Trigger menu bar icon flash.
        6.  **Idle State (No Errors, No Positive Work):** If no errors detected, not generating, no recent sidebar activity, and no interventions made: Update instance UI to "Idle (Monitoring)". Global icon Black (if conditions met).
        7.  **Persistent Failure Cycle Detection:**
            *   If an intervention was performed (step 5) but neither "Positive Working Check" (step 3) nor "Sidebar Activity Check" (step 4) succeeded for this PID within the next "Post-Intervention Observation Window" (configurable, e.g., 2-3 ticks/seconds): Increment `consecutiveRecoveryFailures[pid, default: 0]`.
            *   If `consecutiveRecoveryFailures[pid]` > "Max Consecutive Recovery Failures Before Red State" (configurable):
                *   `unrecoverableReason[pid] = "Persistent recovery failures after multiple attempts."`
                *   Update instance UI to "Persistent Error 🆘". Update global icon to Red.
                *   Log critical failure to `SessionLogger`.
                *   Automatically pause interventions for this PID until manually resumed via Code Looper UI or Cursor self-recovers (detected by positive work).
                *   If "Send Notification on Persistent Error" enabled in Settings, send a `NSUserNotification`.
*   **2.4. Adaptive Element Location Strategy:**
    *   **Locator Priority:**
        1.  User-configured `Locator` (from Advanced Settings JSON string, parsed to `AXorcist.Locator`).
        2.  Cached last-known-good `Locator` (from current session's successful dynamic discovery).
        3.  Code Looper's bundled default `Locator` definition (hardcoded).
    *   **Dynamic Discovery Process:** If the prioritized locator fails to find an element when queried via `AXorcist`:
        *   Code Looper executes a sequence of predefined internal heuristics. A heuristic is a chain of `AXorcist` queries. Example for a button:
            *   Query for an anchor text element near the expected button.
            *   If anchor found, query for child/sibling elements of the anchor matching the button's role and other known attributes.
            *   If still not found, broaden search within the window.
        *   The exact heuristics are internal to Code Looper and specific to each element type it needs.
    *   **Cache Update:** If dynamic discovery successfully finds the element and the subsequent action succeeds, the `Locator` (or its key identifying components) that led to this success is updated in the session cache.
    *   **Failure:** If all discovery heuristics fail for a critical element, the intervention requiring that element sets the `unrecoverableReason[pid]` for the instance.

---

**3. Main User Interface (SwiftUI & AppKit)**

*   **3.1. Startup & Onboarding:**
    *   **First Launch Welcome Guide:** Modal SwiftUI window shown once (`UserDefaults` flag). Explains purpose, key features (auto-recovery types, MCP assistance), highlights need for Accessibility permissions. "Let's Get Started!" button.
    *   **Permissions:** After guide, if Accessibility permissions not granted, prompts user with instructions and button to open System Settings (using `AXorcist.checkAccessibilityPermissions()` or similar).
    *   Cursor supervision features are **enabled by default**.
*   **3.2. Custom Menu Bar Window (Primary UI - `NSPopover`):**
    *   Non-activating. Attached to `NSStatusItem`.
    *   **Header:** Code Looper Logo, App Name ("Code Looper"). Global "Enable Code Looper Monitoring" `Toggle` (master on/off).
    *   **Cursor Instances Section (Scrollable `List`):**
        *   Iterates through `NSRunningApplication` instances of Cursor.
        *   **For each instance:**
            *   Displays: Icon indicating status, Cursor App Icon, Process Name (e.g., "Cursor"), PID.
            *   **Status Message (Text):** "Working (Generating) 🚀", "Working (Recent Activity) ✅", "Idle (Monitoring) ☕", "Recovering (Connection Issue) 🛠️", "Unrecoverable: '[specific reason from unrecoverableReason]' 🆘", "Paused (Intervention Limit) 🚫", "Persistent Error 🆘".
            *   **Action Buttons (contextual):**
                *   If Paused/Unrecoverable/Persistent Error: "Resume Interventions" button (clears `unrecoverableReason[pid]`, resets `automaticInterventionsSincePositiveActivity[pid]` and `consecutiveRecoveryFailures[pid]`).
                *   "Nudge Now" button: Triggers "Cursor Stops" recovery (types custom text into input field) for this instance.
    *   **Global Actions/Status Footer:**
        *   Text: "Session auto-interventions: [Total Count]".
        *   Button: "Reset All Instance Counters & Resume Paused".
    *   **Settings Cogwheel Icon Button:** Opens the main Settings Panel.
*   **3.3. Settings Panel (SwiftUI - Modal Window or Sheet from Popover):**
    *   Organized with a `TabView` or sectioned `List`.
    *   **A. General Tab:**
        *   `[x]` Launch Code Looper at Login (`SMAppService`).
        *   "Monitoring Interval:" `Stepper` or `TextField` (seconds, default: 1s, range: 0.5s-5s).
        *   "Max Auto-Interventions Per Instance (before pause):" `Stepper` (default: 5, range: 1-25, "Unlimited" option with warning).
        *   `[x]` Play Sound on Intervention.
        *   "Text for 'Cursor Stops' Recovery:" Multi-line `TextEditor` with scroll, pre-filled with detailed default prompt.
        *   **Updates (Sparkle):**
            *   `[x]` Automatically Check for Updates.
            *   "Check for Updates Now" Button.
            *   Display: "Code Looper Version: [app_version]".
    *   **B. Cursor Supervision Tab:**
        *   `[x]` Enable "Connection Issues" Recovery.
        *   `[x]` Enable "Cursor Force-Stopped (Loop Limit)" Recovery.
        *   `[x]` Enable "Cursor Stops" (Custom Text) Recovery.
        *   `[x]` Monitor Sidebar Activity as positive work indicator (Default ON).
    *   **C. Cursor Rule Sets Tab:**
        *   Section Title: "Manage Cursor Project Rule Sets". Info text.
        *   **Terminator Terminal Controller Rule Set:**
            *   Label, description. Status: "Not Installed", "Installed", "Update Available".
            *   Button: "Install/Update/Verify".
                *   Prompts user to select project root directory.
                *   "Install/Update": Copies bundled `terminator.scpt` to `PROJECT/.cursor/scripts/` and `codelooper_terminator_rule.mdc` to `PROJECT/.cursor/rules/`. Creates dirs if needed. Prompts to overwrite if files exist.
                *   "Verify": Checks existence of files. (Content check V1.1+).
    *   **D. External MCPs Tab:**
        *   Display path: `~/.cursor/mcp.json` (non-editable for V1).
        *   For each supported MCP (Claude Code, macOS Automator, XcodeBuild):
            *   Row with: MCP Icon, Name.
            *   **Enable/Disable `Toggle`:** State reflects presence in `mcp.json`. Toggling ON triggers setup flow if new, adds entry to `mcpServers`. Toggling OFF removes entry. Creates `mcp.json` with `{"mcpServers": {}}` if non-existent.
            *   **Warning Alert (on enable):** For powerful MCPs (Claude Code, macOS Automator), modal alert requiring user confirmation ("I understand and accept the risk").
            *   **Configuration Status/Warning Area:** Text next to toggle. Detects user-pinned old versions in `mcp.json` or non-standard installations (e.g., local path vs. npx/mise) and offers "Update to Recommended [version/method]" button.
            *   **Configure/Details Button (`...`):** Opens sheet/sub-view for MCP-specific parameters (XcodeBuildMCP version string & env var toggles like `INCREMENTAL_BUILDS_ENABLED`, `SENTRY_DISABLED`; Claude Code custom CLI name input). Pre-fills from current `mcp.json`. Shows first-time setup instructions (e.g., Claude CLI manual run). User choices here are stored in Code Looper's `UserDefaults` to pre-fill UI next time, but actual config written to `mcp.json`.
    *   **E. Advanced Tab:**
        *   Section: "Supervision Tuning".
        *   Connection Issue Recovery: "Max 'Resume' clicks before typing text:" `Stepper` (default: 3, range 1-5).
        *   Persistent Failure Detection: "Max recovery cycles before 'Persistent Error':" `Stepper` (default: 3, range 1-5). "Observation window after intervention (seconds):" `Stepper` (default: 3s, range 1-10s).
        *   `[x]` Send macOS User Notification on Persistent Error.
        *   Section: "Custom Element Locators (Use with Caution!)". Info text.
        *   For each key element (Connection Issue Text, Resume Button (Connection), Force-Stop Resume Link, Main Input Field, Generating Indicator Text, Primary Sidebar):
            *   Label for element name.
            *   Multi-line `TextEditor` bound to `UserDefaults` string for the `AXorcist.Locator` JSON. Pre-filled with Code Looper's bundled default if no user override.
            *   "Reset to Default" button for that specific locator.
        *   Button: "Reset All Locators to Defaults".
    *   **F. Log Tab:**
        *   Section Title: "Session Activity Log". Info text.
        *   Scrollable `List` displaying `SessionLogger.entries` (Timestamp, PID, Level icon/color, Message). Auto-scrolls to bottom.
        *   Buttons: "Clear Log", "Copy Log to Clipboard".
    *   **Footer (Common to all tabs):** Links: "CodeLooper.app", "Follow @CodeLoopApp on X", "View on GitHub".
*   **3.4. Help Menu (If traditional menu needed for accessibility or convention):**
    *   "About Code Looper..." (Opens SwiftUI About Panel: App info, version, build, copyright, links).
    *   "Check for Updates..." (Triggers Sparkle check).

---

**4. Sparkle Auto-Updater Integration**

*   `Info.plist`: `SUFeedURL` (e.g., `https://codelooper.app/appcast.xml`), `SUPublicEDKey`. Optional `SUEnableAutomaticChecks: YES`, `SUScheduledCheckInterval`.
*   `AppDelegate`: Initialize `SPUStandardUpdaterController`.
*   UI controls in "General" Settings tab.
*   Developer process: Create/host `appcast.xml`, sign update archives (`.zip`) with private EdDSA key, host archives.

---

**5. AXorcist Library Interaction Details**

*   Code Looper instantiates `AXorcist`.
*   All UI element interactions use `AXorcist` API methods (e.g., `handleQuery`, `handlePerformAction`, `handleBatchCommands`), passing `CommandEnvelope` / `Locator` structs.
*   `AXorcist` calls are wrapped in `await MainActor.run { ... }` from Code Looper's background tasks.
*   `HandlerResponse.error` string is checked for failures. `HandlerResponse.debug_logs` (returned, not `inout`) are passed to `SessionLogger`.
*   Code Looper's `AXorcistClient` equivalent (internal service class) manages construction of `CommandEnvelope`s and interpretation of `HandlerResponse`.

---

**6. Error Handling & Resilience**

*   Graceful handling of `AXorcist` errors (logging to `SessionLogger`, updating instance UI status).
*   Descriptive `NSAlert`s (SwiftUI `.alert()` modifier) for critical file operation failures (e.g., writing `mcp.json`, copying rule files).
*   "Unrecoverable: Element Not Found" state per instance (with specific reason message in UI).
*   "Persistent Error" state per instance (after multiple failed recovery cycles).
*   User can manually "Resume Interventions" for instances in Paused/Unrecoverable/Persistent Error states via Popover UI, resetting relevant counters for that PID.

---

**7. `mcp.json` File Handling**

*   Target file: `~/.cursor/mcp.json` (tilde expanded).
*   **Reading:** Read raw JSON into `[String: Any]`. Extract `mcpServers` dictionary and `globalShortcut` string.
*   **Modification:** Only modify/add/remove entries in `mcpServers` that Code Looper explicitly manages (Claude Code, macOS Automator, XcodeBuild). Other MCP entries and other top-level keys are preserved.
*   **Writing:** Serialize the modified top-level `[String: Any]` dictionary back to JSON, pretty-printed.
*   Creates `mcp.json` with `{"mcpServers": {}, "globalShortcut": ""}` if it doesn't exist when an MCP is first enabled by Code Looper.