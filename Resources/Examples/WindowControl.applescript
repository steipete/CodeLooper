-- Sample AppleScript for FriendshipAI Window Control
-- This script demonstrates various window manipulation commands

-- Make sure FriendshipAI is running
tell application "FriendshipAI"
    activate
end tell

-- Wait a bit for the app to fully launch
delay 1

-- Basic window control commands
tell application "FriendshipAI"
    -- Center the main window
    center window
    delay 1
    
    -- Move window to a specific position (x: 100, y: 100)
    move window to 100 and 100
    delay 1
    
    -- Resize window (width: 800, height: 600)
    resize window to 800 and 600
    delay 1
    
    -- Save the current window position with a name
    save window position with name "center-screen"
    delay 1
    
    -- Move window to another position
    move window to 300 and 200
    delay 1
    
    -- Restore the saved window position
    restore window position with name "center-screen"
    delay 1
end tell

-- Show a notification when the script has completed
display notification "Window control script completed" with title "FriendshipAI"