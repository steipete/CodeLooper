-- FriendshipAI Workflow Automation Example
-- This script demonstrates how to automate common workflows

-- Make sure FriendshipAI is running
tell application "FriendshipAI"
    activate
end tell

-- Wait for the app to fully launch
delay 1

-- Start a complete workflow
tell application "FriendshipAI"
    -- First, position and size the window nicely
    move window to 50 and 50
    resize window to 1000 and 700
    
    -- Show the welcome window if it's not already visible
    show welcome window for scripting
    
    -- Wait for the window to appear
    delay 0.5
    
    -- Center the window for better visibility
    center window
    
    -- Wait briefly
    delay 2
    
    -- Now show the settings window
    show settings window for scripting
    
    -- Wait for settings to appear
    delay 0.5
    
    -- Position it on the right side of the screen
    move window to 400 and 100
    resize window to 800 and 600
    
    -- Save this position for later
    save window position with name "settings-position"
    
    -- Wait briefly
    delay 2
    
    -- Trigger a contacts sync
    sync contacts for scripting
    
    -- Wait for sync to complete (this is a placeholder - in real usage you might
    -- need to poll for status or use a different mechanism to detect completion)
    delay 3
    
    -- Restore the settings window position
    restore window position with name "settings-position"
end tell

-- Display a notification when completed
display notification "Workflow automation completed" with title "FriendshipAI"