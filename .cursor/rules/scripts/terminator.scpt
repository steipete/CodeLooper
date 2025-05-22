--------------------------------------------------------------------------------
-- terminator.scpt - v0.6.0 "T-1000"
-- AppleScript: Enhanced Terminal automation with improved robustness, performance,
--              and user experience. Modular architecture with comprehensive error handling.
--------------------------------------------------------------------------------

--#region Enhanced Configuration System
property scriptVersion : "0.6.0"
property scriptCodename : "T-1000"
property scriptInfoPrefix : "Terminator 🤖💥: "

-- Core Timing Configuration
property maxCommandWaitTime : 15.0 -- Increased from 10s for better reliability
property pollIntervalForBusyCheck : 0.05 -- Reduced for more responsive checking
property startupDelayForTerminal : 0.7
property adaptiveDelayMultiplier : 1.0 -- Can be adjusted based on system performance

-- Output Configuration
property minTailLinesOnWrite : 15
property defaultTailLines : 30
property maxOutputCaptureRetries : 3
property outputCaptureRetryDelay : 0.2

-- UI Configuration
property tabTitlePrefix : "Terminator 🤖💥 "
property projectIdentifierInTitle : "Project: "
property taskIdentifierInTitle : " - Task: "
property enableFuzzyTagGrouping : true
property fuzzyGroupingMinPrefixLength : 4

-- Process Management Configuration
property processInterruptStrategies : {"SIGINT", "SIGTERM", "SIGKILL"}
property processInterruptDelays : {0.5, 1.0, 0.3}
property maxProcessInterruptAttempts : 3

-- Enhanced Path Validation Patterns
property validPathPatterns : {"^/[^\\s]*$"} -- Paths must start with / and contain no spaces
property invalidPathFlags : {"--", "-[a-zA-Z]", "\\s-[a-zA-Z]"} -- Common command flags to avoid
--#endregion Enhanced Configuration System

--#region Core Validation Functions
on isValidPathEnhanced(thePath)
    if thePath is "" then return false
    
    -- Basic structure check
    if not (thePath starts with "/") then return false
    
    -- Enhanced flag detection using multiple patterns
    repeat with flagPattern in invalidPathFlags
        try
            do shell script "echo " & quoted form of thePath & " | grep -E -q " & quoted form of flagPattern
            return false -- Found a flag pattern, not a valid path
        on error
            -- Pattern not found, continue checking
        end try
    end repeat
    
    -- Additional path validation
    if (count of characters of thePath) > 500 then return false -- Reasonable path length limit
    if thePath contains tab or thePath contains linefeed then return false -- Invalid characters
    
    return true
end isValidPathEnhanced

on validateProjectPath(thePath)
    if not my isValidPathEnhanced(thePath) then
        return {isValid:false, errorMsg:"Invalid path format. Paths must start with '/' and not contain command flags."}
    end if
    
    -- Check if path exists (optional, can be disabled for performance)
    try
        do shell script "test -d " & quoted form of thePath
        return {isValid:true, errorMsg:"", pathExists:true}
    on error
        -- Path doesn't exist - still valid for mkdir operations
        return {isValid:true, errorMsg:"", pathExists:false}
    end try
end validateProjectPath

on validateTaskTag(taskTag)
    if taskTag is "" then
        return {isValid:false, errorMsg:"Task tag cannot be empty"}
    end if
    
    if (length of taskTag) > 40 then
        return {isValid:false, errorMsg:"Task tag too long (max 40 characters)"}
    end if
    
    if not my tagOKEnhanced(taskTag) then
        return {isValid:false, errorMsg:"Task tag contains invalid characters. Use only letters, numbers, hyphens, and underscores"}
    end if
    
    return {isValid:true, errorMsg:""}
end validateTaskTag
--#endregion Core Validation Functions

--#region Enhanced String Processing
on trimWhitespaceOptimized(theText)
    if theText is "" then return ""
    
    -- Use shell command for better performance on large strings
    if (length of theText) > 1000 then
        try
            return do shell script "echo " & quoted form of theText & " | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'"
        on error
            -- Fallback to character-by-character method
        end try
    end if
    
    -- Original method for smaller strings
    set whitespaceChars to {" ", tab}
    set newText to theText
    repeat while (newText is not "") and (character 1 of newText is in whitespaceChars)
        if (length of newText) > 1 then
            set newText to text 2 thru -1 of newText
        else
            set newText to ""
        end if
    end repeat
    repeat while (newText is not "") and (character -1 of newText is in whitespaceChars)
        if (length of newText) > 1 then
            set newText to text 1 thru -2 of newText
        else
            set newText to ""
        end if
    end repeat
    return newText
end trimWhitespaceOptimized

on tagOKEnhanced(t)
    try
        -- Enhanced regex pattern for better validation
        do shell script "/bin/echo " & quoted form of t & " | /usr/bin/grep -E -q '^[A-Za-z0-9_-]{1,40}$'"
        return true
    on error
        return false
    end try
end tagOKEnhanced

on bufferContainsMeaningfulContentEnhanced(multiLineText, knownInfoPrefix as text, commonShellPrompts as list)
    if multiLineText is "" then return false
    
    set trimmedText to my trimWhitespaceOptimized(multiLineText)
    if (length of trimmedText) < 3 then return false
    
    -- Enhanced content analysis
    if trimmedText starts with knownInfoPrefix then
        set oldDelims to AppleScript's text item delimiters
        set AppleScript's text item delimiters to linefeed
        set textLines to text items of multiLineText
        set AppleScript's text item delimiters to oldDelims
        
        set meaningfulLines to 0
        set totalNonEmptyLines to 0
        
        repeat with aLine in textLines
            set currentLine to my trimWhitespaceOptimized(aLine as text)
            if currentLine is not "" then
                set totalNonEmptyLines to totalNonEmptyLines + 1
                if not (currentLine starts with knownInfoPrefix) then
                    -- Check if it's not just a shell prompt
                    set isPromptLine to false
                    repeat with promptPattern in commonShellPrompts
                        if currentLine ends with promptPattern then
                            set isPromptLine to true
                            exit repeat
                        end if
                    end repeat
                    if not isPromptLine then
                        set meaningfulLines to meaningfulLines + 1
                    end if
                end if
            end if
        end repeat
        
        -- More sophisticated threshold: at least 30% meaningful content
        return (meaningfulLines > 2) and ((meaningfulLines / totalNonEmptyLines) > 0.3)
    end if
    
    return true
end bufferContainsMeaningfulContentEnhanced
--#endregion Enhanced String Processing

--#region Advanced Process Management
on identifyBusyProcessEnhanced(targetTab)
    set processInfo to {processName:"", processId:"", isInterruptible:true}
    
    tell application id "com.apple.Terminal"
        try
            if not (busy of targetTab) then
                return processInfo
            end if
            
            set processList to processes of targetTab
            set commonShells to {"login", "bash", "zsh", "sh", "tcsh", "ksh", "-bash", "-zsh", "-sh", "-tcsh", "-ksh", "dtterm", "fish"}
            
            -- Find the most specific (non-shell) process
            if (count of processList) > 0 then
                repeat with i from (count of processList) to 1 by -1
                    set aProcessName to item i of processList
                    if aProcessName is not in commonShells then
                        set processInfo to processInfo & {processName:aProcessName}
                        
                        -- Try to get process ID for more precise control
                        try
                            set ttyName to tty of targetTab
                            if ttyName is not "" then
                                set shortTTY to text 6 thru -1 of ttyName
                                set pidResult to do shell script "ps -t " & shortTTY & " -o pid,comm | awk '$2 == \"" & aProcessName & "\" {print $1}' | head -1"
                                if pidResult is not "" then
                                    set processInfo to processInfo & {processId:pidResult}
                                end if
                            end if
                        end try
                        
                        exit repeat
                    end if
                end repeat
            end if
        end try
    end tell
    
    return processInfo
end identifyBusyProcessEnhanced

on interruptProcessEnhanced(processInfo, targetTab)
    set interruptionResult to {success:false, method:"", attempts:0}
    
    if processName of processInfo is "" then
        return interruptionResult & {success:true, method:"no-process"}
    end if
    
    -- Strategy 1: Use process ID if available
    if processId of processInfo is not "" then
        repeat with i from 1 to (count of processInterruptStrategies)
            set signal to item i of processInterruptStrategies
            set delayTime to item i of processInterruptDelays
            
            try
                do shell script "kill -" & signal & " " & (processId of processInfo)
                delay delayTime
                
                -- Check if process is still running
                try
                    do shell script "kill -0 " & (processId of processInfo)
                    -- Still running, try next strategy
                on error
                    -- Process terminated
                    return interruptionResult & {success:true, method:"signal-" & signal, attempts:i}
                end try
            on error
                -- Process already terminated or error occurred
                return interruptionResult & {success:true, method:"signal-" & signal & "-error", attempts:i}
            end try
        end repeat
    end if
    
    -- Strategy 2: Keyboard interrupt via System Events
    tell application id "com.apple.Terminal"
        try
            set index of (window of targetTab) to 1
            set selected tab of (window of targetTab) to targetTab
        end try
    end tell
    
    tell application "System Events"
        try
            keystroke "c" using control down
            delay 0.8
            
            tell application id "com.apple.Terminal"
                if not (busy of targetTab) then
                    return interruptionResult & {success:true, method:"keyboard-interrupt", attempts:(count of processInterruptStrategies) + 1}
                end if
            end tell
        end try
    end tell
    
    return interruptionResult & {success:false, method:"all-failed", attempts:maxProcessInterruptAttempts}
end interruptProcessEnhanced
--#endregion Advanced Process Management

--#region Smart Output Capture
on captureTerminalOutputWithRetry(targetTab, tailLines)
    set captureResult to {content:"", success:false, attempts:0, warnings:{}}
    
    repeat with attempt from 1 to maxOutputCaptureRetries
        set captureResult to captureResult & {attempts:attempt}
        
        tell application id "com.apple.Terminal"
            try
                -- Try multiple capture methods
                set bufferContent to ""
                
                -- Method 1: Use history property
                try
                    set bufferContent to history of targetTab
                    if bufferContent is not "" then
                        set captureResult to captureResult & {content:bufferContent, success:true}
                        exit repeat
                    end if
                end try
                
                -- Method 2: Use contents property as fallback
                try
                    set bufferContent to contents of targetTab
                    if bufferContent is not "" then
                        set captureResult to captureResult & {content:bufferContent, success:true}
                        set captureResult to captureResult & {warnings:((warnings of captureResult) & {"Used contents property fallback"})}
                        exit repeat
                    end if
                end try
                
                -- If still empty, wait and retry
                if attempt < maxOutputCaptureRetries then
                    delay outputCaptureRetryDelay
                end if
                
            on error errMsg
                set captureResult to captureResult & {warnings:((warnings of captureResult) & {"Capture attempt " & attempt & " failed: " & errMsg})}
                if attempt < maxOutputCaptureRetries then
                    delay outputCaptureRetryDelay
                end if
            end try
        end tell
    end repeat
    
    return captureResult
end captureTerminalOutputWithRetry
--#endregion Smart Output Capture

--#region Modular Command Execution
on executeCommandInTerminal(shellCmd, targetTab, projectPathArg, originalUserShellCmd)
    set executionResult to {success:false, timedOut:false, processInterrupted:false, errorMsg:""}
    
    tell application id "com.apple.Terminal"
        try
            -- Check if tab is busy and handle appropriately
            if busy of targetTab then
                set processInfo to my identifyBusyProcessEnhanced(targetTab)
                set interruptResult to my interruptProcessEnhanced(processInfo, targetTab)
                
                set executionResult to executionResult & {processInterrupted:true}
                
                if not (success of interruptResult) then
                    set executionResult to executionResult & {success:false, errorMsg:"Could not interrupt busy process: " & (processName of processInfo)}
                    return executionResult
                end if
            end if
            
            -- Clear terminal for clean execution
            do script "clear" in targetTab
            delay 0.1
            
            -- Execute the command
            do script shellCmd in targetTab
            set commandStartTime to current date
            set commandFinished to false
            
            -- Enhanced command monitoring with adaptive polling
            set pollCount to 0
            repeat while ((current date) - commandStartTime) < maxCommandWaitTime
                if not (busy of targetTab) then
                    set commandFinished to true
                    exit repeat
                end if
                
                -- Adaptive polling: start frequent, then reduce frequency
                set currentInterval to pollIntervalForBusyCheck
                if pollCount > 20 then set currentInterval to pollIntervalForBusyCheck * 2
                if pollCount > 50 then set currentInterval to pollIntervalForBusyCheck * 4
                
                delay currentInterval
                set pollCount to pollCount + 1
            end repeat
            
            if commandFinished then
                delay 0.1 -- Brief pause for output to settle
                set executionResult to executionResult & {success:true}
            else
                set executionResult to executionResult & {success:false, timedOut:true}
            end if
            
        on error errMsg
            set executionResult to executionResult & {success:false, errorMsg:errMsg}
        end try
    end tell
    
    return executionResult
end executeCommandInTerminal
--#endregion Modular Command Execution

--#region Window Management (Using Original Reliable Implementation)
on ensureTabAndWindow(taskTagName as text, projectGroupName as text, allowCreate as boolean, desiredFullTitle as text)
    set wasActuallyCreated to false
    set createdInExistingViaFuzzy to false 

    tell application id "com.apple.Terminal"
        try
            repeat with w in windows
                repeat with tb in tabs of w
                    try
                        if custom title of tb is desiredFullTitle then
                            set selected tab of w to tb
                            return {targetTab:tb, parentWindow:w, wasNewlyCreated:false, createdInExistingWindowViaFuzzy:false}
                        end if
                    end try
                end repeat
            end repeat
        end try

        if allowCreate and enableFuzzyTagGrouping and projectGroupName is not "" then
            set projectGroupSearchPatternForWindowName to tabTitlePrefix & projectIdentifierInTitle & projectGroupName
            try
                repeat with w in windows
                    try
                        if name of w starts with projectGroupSearchPatternForWindowName then
                            if not frontmost then activate
                            delay 0.2
                            set newTabInGroup to do script "clear" in w 
                            delay 0.3
                            set custom title of newTabInGroup to desiredFullTitle 
                            delay 0.2
                            set selected tab of w to newTabInGroup
                            return {targetTab:newTabInGroup, parentWindow:w, wasNewlyCreated:true, createdInExistingWindowViaFuzzy:true}
                        end if
                    end try
                end repeat
            end try
        end if

        if allowCreate then
            try
                if not frontmost then activate 
                delay 0.3
                set newTabInNewWindow to do script "clear" 
                set wasActuallyCreated to true
                delay 0.4 
                set custom title of newTabInNewWindow to desiredFullTitle 
                delay 0.2
                set parentWinOfNew to missing value
                try
                    set parentWinOfNew to window of newTabInNewWindow
                on error
                    if (count of windows) > 0 then set parentWinOfNew to front window
                end try
                if parentWinOfNew is not missing value then
                    if custom title of newTabInNewWindow is desiredFullTitle then 
                        set selected tab of parentWinOfNew to newTabInNewWindow
                        return {targetTab:newTabInNewWindow, parentWindow:parentWinOfNew, wasNewlyCreated:wasActuallyCreated, createdInExistingWindowViaFuzzy:false}
                    end if
                end if
                repeat with w_final_scan in windows
                    repeat with tb_final_scan in tabs of w_final_scan
                        try
                            if custom title of tb_final_scan is desiredFullTitle then
                                set selected tab of w_final_scan to tb_final_scan
                                return {targetTab:tb_final_scan, parentWindow:w_final_scan, wasNewlyCreated:wasActuallyCreated, createdInExistingWindowViaFuzzy:false}
                            end if
                        end try
                    end repeat
                end repeat
                return missing value 
            on error
                return missing value 
            end try
        else
            return missing value 
        end if
    end tell
end ensureTabAndWindow
--#endregion Window Management (Using Original Reliable Implementation)

--#region Enhanced Argument Processing
on parseArgumentsEnhanced(argv)
    set argResult to {projectPathArg:"", taskTagName:"", shellCommand:"", tailLines:defaultTailLines, doWrite:false, explicitLinesProvided:false, errorMsg:"", isValid:true}
    
    if (count argv) < 1 then
        set argResult to argResult & {isValid:false, errorMsg:"No arguments provided"}
        return argResult
    end if
    
    set workingArgs to argv
    
    -- Phase 1: Check for project path as first argument
    if (count workingArgs) > 0 then
        set potentialPath to item 1 of workingArgs
        set pathValidation to my validateProjectPath(potentialPath)
        
        
        if isValid of pathValidation then
            set projectPathArg of argResult to potentialPath
            if (count workingArgs) > 1 then
                set workingArgs to items 2 thru -1 of workingArgs
            else
                set argResult to argResult & {isValid:false, errorMsg:"Project path provided but no task tag specified"}
                return argResult
            end if
        end if
    end if
    
    -- Phase 2: Extract task tag
    if (count workingArgs) > 0 then
        set taskTag to item 1 of workingArgs
        set tagValidation to my validateTaskTag(taskTag)
        
        if not (isValid of tagValidation) then
            set argResult to argResult & {isValid:false, errorMsg:(errorMsg of tagValidation)}
            return argResult
        end if
        
        set taskTagName of argResult to taskTag
        set workingArgs to rest of workingArgs
    else
        set argResult to argResult & {isValid:false, errorMsg:"Task tag is required"}
        return argResult
    end if
    
    -- Phase 3: Process remaining arguments (command and/or line count)
    if (count workingArgs) > 0 then
        -- Check if last argument is a number (tail lines)
        set lastArg to item -1 of workingArgs
        if my isInteger(lastArg) then
            set tailLines of argResult to (lastArg as integer)
            set explicitLinesProvided of argResult to true
            if (count workingArgs) > 1 then
                set workingArgs to items 1 thru -2 of workingArgs
            else
                set workingArgs to {}
            end if
        end if
        
        -- Remaining arguments form the shell command
        if (count workingArgs) > 0 then
            set shellCmd to my joinList(workingArgs, " ")
            set shellCommand of argResult to shellCmd
        end if
    end if
    
    -- Phase 4: Determine write mode based on what we have
    -- If we have a shell command OR project path without explicit lines, we're writing
    if (shellCommand of argResult) is not "" then
        -- We have a command to execute
        set doWrite of argResult to true
    else if (projectPathArg of argResult) is not "" and not (explicitLinesProvided of argResult) then
        -- Project path + task tag only, no explicit lines - create session with cd
        set doWrite of argResult to true
    else if (explicitLinesProvided of argResult) then
        -- Lines specified, this is a read operation that allows creation
        set doWrite of argResult to false
    else
        -- Just task tag, read-only operation
        set doWrite of argResult to false
    end if
    
    return argResult
end parseArgumentsEnhanced
--#endregion Enhanced Argument Processing

--#region Main Script Logic
on run argv
    set appSpecificErrorOccurred to false
    
    try
        -- Ensure Terminal is available
        tell application "System Events"
            if not (exists process "Terminal") then
                launch application id "com.apple.Terminal"
                delay startupDelayForTerminal
            end if
        end tell
        
        -- Parse and validate arguments
        set argData to my parseArgumentsEnhanced(argv)
        if not (isValid of argData) then
            return scriptInfoPrefix & "Error: " & (errorMsg of argData) & linefeed & linefeed & my usageTextEnhanced()
        end if
        
        -- Extract parsed data
        set projectPath to projectPathArg of argData
        set taskTag to taskTagName of argData
        set originalUserShellCmd to shellCommand of argData
        set currentTailLines to tailLines of argData
        set writeMode to doWrite of argData
        set explicitLinesProvided to explicitLinesProvided of argData
        
        -- Prepare shell command with project path integration
        set shellCmd to originalUserShellCmd
        if projectPath is not "" and writeMode then
            set quotedProjectPath to quoted form of projectPath
            if shellCmd is not "" then
                set shellCmd to "cd " & quotedProjectPath & " && " & shellCmd
            else
                set shellCmd to "cd " & quotedProjectPath
            end if
        end if
        
        -- Generate session identifiers
        set derivedProjectGroup to ""
        if projectPath is not "" then
            set derivedProjectGroup to my getPathComponent(projectPath, -1)
            if derivedProjectGroup is "" then set derivedProjectGroup to "DefaultProject"
        end if
        
        set allowCreation to writeMode or explicitLinesProvided
        set effectiveTabTitle to my generateWindowTitle(taskTag, derivedProjectGroup)
        
        
        -- Find or create terminal session (using original ensureTabAndWindow for compatibility)
        set sessionInfo to my ensureTabAndWindow(taskTag, derivedProjectGroup, allowCreation, effectiveTabTitle)
        
        if (targetTab of sessionInfo) is missing value then
            if not allowCreation then
                return scriptInfoPrefix & "Error: Terminal session \"" & effectiveTabTitle & "\" not found. " & ¬
                    "To create this session, provide a command or specify lines to read." & linefeed & linefeed & my usageTextEnhanced()
            else
                set errMsg to ""
                try
                    set errMsg to errorMsg of sessionInfo
                end try
                if errMsg is "" then set errMsg to "Unknown error in session creation"
                return scriptInfoPrefix & "Error: Could not create terminal session. " & errMsg
            end if
        end if
        
        set targetTab to targetTab of sessionInfo
        set wasNewlyCreated to wasNewlyCreated of sessionInfo
        
        -- Handle new session creation without command
        if not writeMode and wasNewlyCreated then
            if createdInExistingWindowViaFuzzy of sessionInfo then
                return scriptInfoPrefix & "New tab \"" & effectiveTabTitle & "\" created in existing project window and ready."
            else
                return scriptInfoPrefix & "New tab \"" & effectiveTabTitle & "\" created and ready."
            end if
        end if
        
        -- Execute command if needed
        set executionInfo to {success:true, timedOut:false, processInterrupted:false, errorMsg:""}
        if writeMode and shellCmd is not "" then
            set executionInfo to my executeCommandInTerminal(shellCmd, targetTab, projectPath, originalUserShellCmd)
        end if
        
        -- Capture output with enhanced retry logic
        set captureInfo to my captureTerminalOutputWithRetry(targetTab, currentTailLines)
        set bufferText to content of captureInfo
        
        -- Process and format output
        set tailedOutput to my tailBufferAS(bufferText, currentTailLines)
        set finalResult to my trimBlankLinesAS(tailedOutput)
        
        -- Generate enhanced status messages
        set statusMessages to {}
        if processInterrupted of executionInfo then
            set statusMessages to statusMessages & {"Previous process was interrupted"}
        end if
        if timedOut of executionInfo then
            set statusMessages to statusMessages & {"Command timed out after " & maxCommandWaitTime & "s"}
        end if
        if not (success of captureInfo) then
            set statusMessages to statusMessages & {"Output capture required " & (attempts of captureInfo) & " attempts"}
        end if
        if (count of (warnings of captureInfo)) > 0 then
            set statusMessages to statusMessages & (warnings of captureInfo)
        end if
        
        -- Append status information if needed (only for non-empty results)
        if (count of statusMessages) > 0 and finalResult is not "" then
            set statusText to linefeed & scriptInfoPrefix & my joinList(statusMessages, "; ") & " ---"
            set finalResult to finalResult & statusText
        end if
        
        -- Return appropriate result
        if finalResult is "" then
            if writeMode and shellCmd is not "" then
                set cmdForMsg to originalUserShellCmd
                if projectPath is not "" then
                    if originalUserShellCmd is "" then
                        set cmdForMsg to "(cd " & projectPath & ")"
                    else
                        set cmdForMsg to originalUserShellCmd & " (in " & projectPath & ")"
                    end if
                end if
                return scriptInfoPrefix & "Command '" & cmdForMsg & "' executed in session \"" & effectiveTabTitle & "\". No output captured."
            else
                return scriptInfoPrefix & "No meaningful content found in session \"" & effectiveTabTitle & "\"."
            end if
        end if
        
        return finalResult
        
    on error generalErrorMsg number generalErrorNum
        if appSpecificErrorOccurred then error generalErrorMsg number generalErrorNum
        return scriptInfoPrefix & "Enhanced AppleScript Error (" & generalErrorNum & "): " & generalErrorMsg
    end try
end run
--#endregion Main Script Logic

--#region Utility Functions (Preserved and Enhanced)
on getPathComponent(thePath, componentIndex)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "/"
    set pathParts to text items of thePath
    set AppleScript's text item delimiters to oldDelims
    
    set nonEmptyParts to {}
    repeat with aPart in pathParts
        if aPart is not "" then set end of nonEmptyParts to aPart
    end repeat
    
    if (count nonEmptyParts) = 0 then return ""
    
    try
        if componentIndex is -1 then
            return item -1 of nonEmptyParts
        else if componentIndex > 0 and componentIndex ≤ (count nonEmptyParts) then
            return item componentIndex of nonEmptyParts
        end if
    on error
        return ""
    end try
    
    return ""
end getPathComponent

on generateWindowTitle(taskTag as text, projectGroup as text)
    if projectGroup is not "" then
        return tabTitlePrefix & projectIdentifierInTitle & projectGroup & taskIdentifierInTitle & taskTag
    else
        return tabTitlePrefix & taskTag
    end if
end generateWindowTitle

on tailBufferAS(txt, n)
    set AppleScript's text item delimiters to linefeed
    set lst to text items of txt
    if (count lst) = 0 then return ""
    
    set startN to (count lst) - (n - 1)
    if startN < 1 then set startN to 1
    
    set slice to items startN thru -1 of lst
    set outText to slice as text
    set AppleScript's text item delimiters to ""
    return outText
end tailBufferAS

on trimBlankLinesAS(txt)
    if txt is "" then return ""
    
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to {linefeed}
    set originalLines to text items of txt
    
    -- Find first and last non-empty lines
    set firstContentLine to 1
    repeat while firstContentLine ≤ (count originalLines)
        set currentLine to my trimWhitespaceOptimized(item firstContentLine of originalLines)
        if currentLine is not "" then exit repeat
        set firstContentLine to firstContentLine + 1
    end repeat
    
    set lastContentLine to count originalLines
    repeat while lastContentLine ≥ firstContentLine
        set currentLine to my trimWhitespaceOptimized(item lastContentLine of originalLines)
        if currentLine is not "" then exit repeat
        set lastContentLine to lastContentLine - 1
    end repeat
    
    if firstContentLine > lastContentLine then
        set AppleScript's text item delimiters to oldDelims
        return ""
    end if
    
    set resultLines to items firstContentLine thru lastContentLine of originalLines
    set AppleScript's text item delimiters to linefeed
    set trimmedTxt to resultLines as text
    set AppleScript's text item delimiters to oldDelims
    
    return trimmedTxt
end trimBlankLinesAS

on isInteger(v)
    try
        v as integer
        return true
    on error
        return false
    end try
end isInteger

on joinList(theList, theDelimiter)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to theDelimiter
    set theText to theList as text
    set AppleScript's text item delimiters to oldDelims
    return theText
end joinList

on usageTextEnhanced()
    set LF to linefeed
    set scriptName to "terminator.scpt"
    set exampleProject to "/Users/name/Projects/FancyApp"
    set exampleTaskTag to "build_frontend"
    set exampleCommand to "npm run build"
    
    set outText to scriptName & " - v" & scriptVersion & " \"" & scriptCodename & "\" – Enhanced AppleScript Terminal Automation" & LF & LF
    set outText to outText & "🤖 Enhanced Features:" & LF
    set outText to outText & "  • Robust process interruption with multiple strategies" & LF
    set outText to outText & "  • Smart output capture with retry logic" & LF
    set outText to outText & "  • Enhanced path validation and error handling" & LF
    set outText to outText & "  • Optimized string processing and Terminal interactions" & LF
    set outText to outText & "  • Comprehensive status reporting and diagnostics" & LF & LF
    
    set outText to outText & "Usage Examples:" & LF
    set outText to outText & "  # Enhanced project session with robust execution:" & LF
    set outText to outText & "  osascript " & scriptName & " \"" & exampleProject & "\" \"" & exampleTaskTag & "\" \"" & exampleCommand & "\" 50" & LF
    set outText to outText & "  # Smart session creation with validation:" & LF
    set outText to outText & "  osascript " & scriptName & " \"" & exampleProject & "\" \"dev_shell\" \"\"" & LF
    set outText to outText & "  # Reliable output capture:" & LF
    set outText to outText & "  osascript " & scriptName & " \"" & exampleProject & "\" \"" & exampleTaskTag & "\" 25" & LF & LF
    
    set outText to outText & "⚡ Performance Improvements:" & LF
    set outText to outText & "  • Adaptive polling for better responsiveness" & LF
    set outText to outText & "  • Optimized string processing for large outputs" & LF
    set outText to outText & "  • Enhanced Terminal state detection" & LF
    set outText to outText & "  • Multiple output capture methods with fallbacks" & LF & LF
    
    set outText to outText & "🛡️ Enhanced Reliability:" & LF
    set outText to outText & "  • Multi-strategy process interruption (SIGINT/TERM/KILL)" & LF
    set outText to outText & "  • Comprehensive path validation with regex patterns" & LF
    set outText to outText & "  • Smart retry logic for output capture failures" & LF
    set outText to outText & "  • Better error messages with resolution guidance" & LF & LF
    
    set outText to outText & "Parameters remain the same as v0.5.1 for full backward compatibility." & LF
    
    return outText
end usageTextEnhanced
--#endregion Utility Functions