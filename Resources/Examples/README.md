# FriendshipAI AppleScript Support

FriendshipAI supports automation through AppleScript, allowing you to control window positioning, trigger actions, and automate workflows.

## Available Commands

### Window Control

- **Center Window**: `center window`
  Centers the main application window on screen.

- **Move Window**: `move window to x and y`
  Moves the main window to specific coordinates (x, y).

- **Resize Window**: `resize window to width and height`
  Resizes the main window to the specified dimensions.

- **Save Window Position**: `save window position with name "position-name"`
  Saves the current window position with a name for later use.

- **Restore Window Position**: `restore window position with name "position-name"`
  Restores a previously saved window position.

### Application Control

- **Show Welcome Window**: `show welcome window for scripting`
  Shows the welcome/onboarding window.

- **Show Settings Window**: `show settings window for scripting`
  Shows the application settings window.

- **Sync Contacts**: `sync contacts for scripting`
  Triggers a manual contacts synchronization.

## Example Usage

```applescript
tell application "FriendshipAI"
    -- Show the settings window
    show settings window for scripting

    -- Position it nicely
    move window to 100 and 100
    resize window to 800 and 600

    -- Save this position
    save window position with name "my-settings-position"
end tell
```

## Sample Scripts

- `WindowControl.applescript`: Demonstrates basic window control functionality.
- `WorkflowAutomation.applescript`: Shows a more complete workflow automation example.

## Tips for Use

1. Make sure FriendshipAI is running before executing scripts.
2. Include small delays (`delay 0.5`) between commands to allow the UI to update.
3. Use a script editor with dictionary support to explore all available commands.
4. Window positions are saved to user defaults and persist between application restarts.

## Troubleshooting

If commands aren't working as expected:

1. Check that the application is fully launched and responsive.
2. Ensure you're using the correct command syntax.
3. Try adding small delays between commands to ensure the application has time to process each action.
4. Verify that the window you're trying to control is actually open.
