---
description:
globs:
alwaysApply: false
---
## 6. Future Steps (Integration into CodeLooper)

-   Translate successful `axorc` commands into `AXorcist` Swift library calls.
-   Develop a robust method for locating the target element.
-   Implement path/identifier caching if feasible.

## 7. Session Learnings & `axorc` Refinements (YYYY-MM-DD)

This section details insights gained during an interactive session aimed at finding Cursor's chat input field.

### 7.1. `axorc` Command Execution & Quoting

*   **`terminator.scpt` Invocation**: When using `osascript` with `terminator.scpt` to run `axorc` commands, ensure the full, absolute path to `terminator.scpt` is used (e.g., `/Users/steipete/Projects/CodeLooper/.cursor/scripts/terminator.scpt`).
*   **JSON Payload Quoting**: The `axorc --json '...'` command structure requires careful quoting, especially for the JSON payload when passed as an argument through multiple layers of shell/script execution.
    *   The method of wrapping the JSON string in `''' ... '''` (triple single quotes within the single-quoted shell command argument) was eventually successful for complex JSON payloads passed to `axorc` via `terminator.scpt`.
    *   Simpler commands like direct `jq` calls sometimes had quoting issues when passed through `terminator.scpt`, highlighting the complexity. Debugging `jq` syntax itself was easier by running commands directly in the terminal first.

### 7.2. `axorc` JSON Command Structure & Behavior

*   **Mandatory `criteria` in Locator**: A key finding was that `axorc`'s JSON command parser strictly requires a `criteria: {}` field within the `locator` object, even if the locator `type` (e.g., `application`, `focusedElement`, `path`) doesn't logically need criteria. Omitting this leads to a JSON decoding error (`keyNotFound: criteria`).
    *   *Example (Corrected for `focusedElement`)*:
        ```json
        {
          "commandId": "query_focused_element_002",
          "command": "query",
          "application": "com.todesktop.230313mzl4w4u92",
          "locator": {
            "type": "focusedElement",
            "criteria": {} // Mandatory empty criteria
          }
        }
        ```

*   **`focusedElement` Locator Behavior**:
    *   When `locator: {"type": "focusedElement", "criteria": {}}` was used with the `query` command targeting an application, `axorc` returned attributes of the *application element itself*, not the specific focused UI control within a window. It did include an `AXFocusedWindow` attribute, pointing to the window that likely contained the focus.
    *   An attempt to use `command: getAttributes` on the application element to retrieve `kAXFocusedUIElementAttribute` resulted in this attribute being `null`. This suggests `axorc` might not easily expose the system-wide focused element this way, or it's problematic for web-based views.

### 7.3. Handling `axorc` Output

*   **Mixed Log Lines and JSON**: `axorc` commands (like `collectAll`, `query`, `getAttributes`) often prefix their main JSON output with numerous log lines in stdout (e.g., `[PRINT Element.children] ...`, `[DEBUG] ...`, build messages).
*   **Pre-processing for JSON Parsers**: This mixed output means the raw stdout from `axorc` cannot be directly piped to JSON tools like `jq`.
    *   **Claude for Cleaning**: Using an MCP agent (Claude) to read the raw output file and extract only the valid JSON object into a new file proved to be a reliable method.
    *   **Manual Log Skipping (Less Reliable)**: Initial attempts to use `grep` to find the start of the JSON (e.g., the first `{`) and then `tail -n +LINE_NUMBER` were prone to errors because the exact start line of the JSON object could vary and `grep` results could be misinterpreted. `od -c` was useful for identifying that `tail` was not working as expected due to incorrect line number assumptions.

### 7.4. Using `jq` for Analysis

*   **Indispensable for Large UI Trees**: `jq` is crucial for filtering and inspecting the potentially very large JSON arrays produced by `axorc collectAll`.
*   **Requires Clean JSON Input**: As noted above, `jq` will fail if it receives non-JSON log lines.
*   **Correct `jq` Syntax**: Ensure `jq` filter expressions use correct syntax, especially for string comparisons (e.g., `.attributes.AXRole == "AXTextArea"`). Escaping quotes correctly is also vital if the `jq` command is embedded within another script or command.

### 7.5. Element Identification Strategies & Iteration

*   **Initial Broad Scans & Filtering**:
    *   `collectAll` on a targeted `AXWebArea` (using window title for criteria) even with `maxDepth: 15` did not reveal the chat input when filtering for common roles (`AXTextArea`, `AXTextField`) or attributes (`AXPlaceholderValue`, `AXDOMIdentifier`).
    *   `collectAll` on the parent `AXWindow` (with `maxDepth: 10`) followed by the same `jq` filters also yielded no direct matches for these common identifiers.
    *   This strongly suggests Cursor's chat input is not a standard accessibility element but likely a custom web component (e.g., `contenteditable div`).
*   **Alternative `jq` Filters**: A broader `jq` filter looking for `AXGroup` elements with some indication of text content (non-empty `AXValue`, `AXDescription`, or non-null `AXSelectedText`, `AXVisibleCharacterRange`) did return some generic `AXGroup` candidates, but none were definitively the input field from static properties alone.
*   **Interactive Identification (Most Promising Path Forward)**:
    *   The most effective strategy appears to be:
        1.  User manually focuses the target UI element in the application (and types sample text).
        2.  Use `axorc` to query the properties of this *specific* focused element.
    *   The challenge remains in crafting the correct `axorc` command to pinpoint this deeply focused element. Direct `locator: {"type": "focusedElement"}` was insufficient by itself.
    *   **Leveraging Accessibility Inspector**: The ground truth provided by macOS's Accessibility Inspector is invaluable. If the Inspector can see the element's path and attributes (e.g., `Role`, `Value` containing the typed text), this information can be used to construct a highly specific `axorc` command with a `path` locator or a `firstMatch` locator using a unique combination of attributes observed in the Inspector.

### 7.6. Next Steps for Debug Loop

1.  User focuses the target input field in Cursor and types sample text.
2.  User provides a detailed description of the element from Accessibility Inspector:
    *   Its full **hierarchy/path** from the Application down to the element.
    *   Its key **attributes** (Role, Subrole, Title, Value, Description, Identifier, DOMIdentifier, etc.).
3.  Use this precise information from Accessibility Inspector to craft a targeted `axorc` `query` or `getAttributes` command, likely using `locator: {"type": "path", "path": ["...", "..."]}` or `locator: {"type": "firstMatch", "criteria": {...}}`.
4.  Analyze the result to confirm the element.
5.  Once confirmed, identify stable attributes/path for reliable future targeting.
6.  Proceed to test actions like `setValue` or `focus`.
