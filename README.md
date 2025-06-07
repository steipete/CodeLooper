# CodeLooper 🔄

<p align="center">
  <img src="assets/banner.png" alt="CodeLooper Banner">
</p>

**A macOS menubar app that keeps your agents working in Cursor** 🔄

CodeLooper is a native macOS application that sits in your menubar, monitoring the status of each Cursor window.
When Cursor breaks out of its productive loop – getting stuck generating code, dropping connections, or hitting errors – CodeLooper loops back in to restore the flow using macOS accessibility APIs:

It resolves these situations:

- **Plain Stop:** Cursor just stops, even though the text indicates that there's more to do.<br>
  <img src="assets/cursor-stopped.png" alt="Cursor Stopped" width="600">

- **Connection Issues**: "We're having trouble connecting to the model provider."<br>
  <img src="assets/trouble.png" alt="Connection Trouble" width="600">

- **Stop after 25 loops**: It automatically presses resume.<br>
  <img src="assets/default-stop-25.png" alt="Default Stop at 25 loops" width="600">

- **Edited in another chat**: Automatically accepts if another tab edited a file.<br>
  <img src="assets/edited-another-chat.png" alt="File is being edited by another chat" width="600">

## Automatic MCP Installation

CodeLooper can install various MCP's that help Cursor to build with fewer manual interventions:

- 👻 [Peekaboo](https://github.com/steipete/Peekaboo): Enables your IDE to make screenshots and ask questions about images.
- 🤖 [Terminator](https://github.com/steipete/Terminator): Manages a Terminal outside of the loop, so processes that might get stuck don't break the loop.
- 🧠 [Claude Code](https://github.com/steipete/claude-code-mcp): A buddy for your IDE that your agent can ask if he's stuck. Can do coding task and offer "a pair of fresh eyes" that often un-stucks the loop.
- 🐱 [Conduit](https://github.com/steipete/conduit-mcp): Advanced file manipulation for faster refactoring.
- 🎯 [Automator](https://github.com/steipete/macos-automator-mcp): AppleScript for your IDE.

Warning: These tools give your agent full power over your system, so integrate at your own risk.

## System Requirements

- **macOS Version**: macOS 15 (Sequoia)
- **Architecture**: Apple Silicon
- **Accessibility**: Requires accessibility, automation and screen capture permissions for IDE automation

### Getting Started

Download one of the releases from GitHub's Release section.

Note: This is currently under active development and doesn't yet work.

## Development Setup

### Prerequisites

- Xcode 16.0 or later (for Swift 6.0)
- [mise](https://mise.jdx.dev/) (for tool version management)
- Homebrew (for additional tools)

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/steipete/CodeLooper2.git
   cd CodeLooper2
   ```

2. Install mise and dependencies:
   ```bash
   # Install mise
   curl https://mise.run | sh
   
   # Install tools via mise
   mise install
   
   # Generate Xcode project
   ./scripts/generate-xcproj.sh
   ```

3. Open in Xcode:
   ```bash
   open CodeLooper.xcworkspace
   ```

### Tool Versions

Tool versions are managed via `.mise.toml`:
- Tuist: 4.52.0

The CI/CD pipeline automatically uses mise to ensure consistent tool versions.
