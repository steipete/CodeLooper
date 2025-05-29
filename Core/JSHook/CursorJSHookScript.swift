import Diagnostics
import Foundation

/// Manages the JavaScript hook script resource
public enum CursorJSHookScript {
    // MARK: Public

    /// Current version of the JavaScript hook
    public static let version = "1.2.2"

    /// Load the JavaScript hook template from resources
    public static func loadTemplate() throws -> String {
        let logger = Logger(category: .jshook)
        
        // Try to load from bundle first
        if let bundlePath = Bundle.main.path(forResource: "cursor-hook", ofType: "js", inDirectory: "JavaScript"),
           let content = try? String(contentsOfFile: bundlePath)
        {
            logger.debug("📦 Loaded JS hook script from bundle: \(bundlePath)")
            return content
        }

        // Try development path
        let devPath = FileManager.default.currentDirectoryPath + "/Resources/JavaScript/cursor-hook.js"
        if let content = try? String(contentsOfFile: devPath) {
            logger.debug("🛠️ Loaded JS hook script from development path: \(devPath)")
            return content
        }

        // Fallback to inline script for development
        logger.info("📝 Using inline JS hook script (development fallback)")
        return inlineScript
    }

    /// Generate the JavaScript hook with the specified port
    /// - Parameter port: The WebSocket port to connect to
    /// - Returns: The complete JavaScript code ready for injection
    public static func generate(port: UInt16) throws -> String {
        let logger = Logger(category: .jshook)
        logger.debug("🔧 Generating JS hook script for port \(port)")
        
        // Get CodeLooper version from bundle
        let codeLooperVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        let template = try loadTemplate()
        let withPort = template.replacingOccurrences(of: "__CODELOOPER_PORT_PLACEHOLDER__", with: String(port))
        let generated = withPort.replacingOccurrences(of: "__CODELOOPER_VERSION_PLACEHOLDER__", with: codeLooperVersion)
        
        logger.info("✅ Generated JS hook script v\(version) for port \(port) (CodeLooper v\(codeLooperVersion))")
        logger.debug("📊 Script stats: \(generated.count) chars, \(generated.components(separatedBy: .newlines).count) lines")
        
        return generated
    }

    // MARK: Private

    /// The inline script (used as fallback during development)
    private static let inlineScript = """
    // CodeLooper Cursor Hook
    // Version: 1.2.2
    // This script is injected into Cursor to enable communication with CodeLooper

    (function() {
        'use strict';

        const HOOK_VERSION = '1.2.2';
        const HEARTBEAT_INTERVAL = 1000; // 1 second
        
        // One-liner to disable hook: window.__codeLooperDisable && window.__codeLooperDisable()
        window.__codeLooperDisable = function() {
            console.log('🛑 CodeLooper: Disabling hook...');
            if (window.__codeLooperHook) {
                window.__codeLooperHook.close();
            }
            if (window.__codeLooperHeartbeat) {
                clearInterval(window.__codeLooperHeartbeat);
            }
            if (window.__codeLooperWaitingLog) {
                clearInterval(window.__codeLooperWaitingLog);
            }
            window.__codeLooperHook = null;
            window.__codeLooperPort = null;
            window.__codeLooperVersion = null;
            window.__codeLooperHeartbeat = null;
            window.__codeLooperWaitingLog = null;
            console.log('✅ CodeLooper: Hook disabled');
        };

        // Helper function for logging that works in both Node.js and browser environments
        function hookLog(msg) {
            // 1. Send it over stdout so "outputCapture": "std" can pick it up
            if (typeof process !== 'undefined' &&
                process.stdout && process.stdout.write) {
                process.stdout.write(msg + '\\n');
            }

            // 2. Still call console.log for when you run the same snippet in a real browser
            console.log(msg);

            // 3. Return the string so the debug-REPL echoes it even if logs get swallowed
            return msg;
        }

        // Check if hook already exists and clean it up
        if (window.__codeLooperHook) {
            hookLog('🔄 CodeLooper: Cleaning up existing hook on port ' + window.__codeLooperPort);
            try {
                if (window.__codeLooperHook.readyState === WebSocket.OPEN || 
                    window.__codeLooperHook.readyState === WebSocket.CONNECTING) {
                    window.__codeLooperHook.close();
                }
                if (window.__codeLooperHeartbeat) {
                    clearInterval(window.__codeLooperHeartbeat);
                    window.__codeLooperHeartbeat = null;
                }
                if (window.__codeLooperWaitingLog) {
                    clearInterval(window.__codeLooperWaitingLog);
                    window.__codeLooperWaitingLog = null;
                }
            } catch (e) {
                hookLog('🔄 CodeLooper: Error closing existing connection: ' + e);
            }
            window.__codeLooperHook = null;
            window.__codeLooperPort = null;
            window.__codeLooperVersion = null;
            window.__codeLooperWaitingLog = null;
        }

        const port = __CODELOOPER_PORT_PLACEHOLDER__; // Will be replaced by Swift
        const url = 'ws://127.0.0.1:' + port;
        let reconnectAttempts = 0;
        const maxReconnectAttempts = 5;
        const reconnectDelay = 3000; // 3 seconds
        let composerObserver = null; // MutationObserver for composer bar

        function showSuccessNotification() {
            try {
                // Create a toast notification in Cursor's UI
                const notification = document.createElement('div');
                notification.textContent = '✅ CodeLooper v__CODELOOPER_VERSION_PLACEHOLDER__ connected successfully!';
                notification.style.cssText = 'position: fixed; top: 20px; right: 20px; background: #10b981; color: white; padding: 12px 24px; border-radius: 8px; font-weight: 500; z-index: 999999; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); animation: slideIn 0.3s ease-out; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 14px;';

                // Add animation
                const style = document.createElement('style');
                style.textContent = '@keyframes slideIn { from { transform: translateX(100%); opacity: 0; } to { transform: translateX(0); opacity: 1; } }';
                document.head.appendChild(style);

                document.body.appendChild(notification);

                // Remove notification after 5 seconds
                setTimeout(() => {
                    notification.style.opacity = '0';
                    notification.style.transform = 'translateX(100%)';
                    notification.style.transition = 'all 0.3s ease-out';
                    setTimeout(() => {
                        notification.remove();
                        style.remove();
                    }, 300);
                }, 5000);

                // Also show in console
                hookLog('✅ CodeLooper Hook Active! Port: ' + port + ', Version: ' + HOOK_VERSION + ', Ready to receive commands');

            } catch (e) {
                console.error('Failed to show notification:', e);
            }
        }

        function detectResumeNeeded() {
            // Check if resume is needed by looking for rate limit text
            const elements = document.querySelectorAll('body *');
            for (const el of elements) {
                if (!el || !el.textContent) continue;
                
                // Check if element contains rate limit text
                if (el.textContent.includes('stop the agent after 25 tool calls') || 
                    el.textContent.includes('Note: we default stop')) {
                    
                    // Find the resume link inside this element
                    const links = el.querySelectorAll('a, span.markdown-link, [role="link"], [data-link]');
                    for (const link of links) {
                        if (link.textContent.trim() === 'resume the conversation') {
                            return true; // Resume is needed
                        }
                    }
                }
            }
            return false;
        }

        function startComposerObserver(ws) {
            // Stop any existing observer
            stopComposerObserver();
            
            // Find the composer bar
            const composerBar = document.querySelector('.composer-bar');
            if (!composerBar) {
                hookLog('🔍 CodeLooper: Composer bar not found, will retry...');
                // Retry after a delay if not found
                setTimeout(() => {
                    if (ws.readyState === WebSocket.OPEN) {
                        startComposerObserver(ws);
                    }
                }, 2000);
                return false;
            }
            
            hookLog('👁️ CodeLooper: Starting composer bar observation');
            
            // Send initial state
            ws.send(JSON.stringify({
                type: 'composerUpdate',
                content: composerBar.innerHTML,
                timestamp: new Date().toISOString(),
                initial: true
            }));
            
            // Create mutation observer
            composerObserver = new MutationObserver((mutations) => {
                // Debounce updates to avoid flooding
                if (composerObserver.timeout) {
                    clearTimeout(composerObserver.timeout);
                }
                
                composerObserver.timeout = setTimeout(() => {
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.send(JSON.stringify({
                            type: 'composerUpdate',
                            content: composerBar.innerHTML,
                            timestamp: new Date().toISOString(),
                            mutations: mutations.length
                        }));
                    }
                }, 100); // 100ms debounce
            });
            
            // Start observing
            composerObserver.observe(composerBar, {
                childList: true,
                subtree: true,
                attributes: true,
                characterData: true,
                attributeOldValue: true,
                characterDataOldValue: true
            });
            
            return true;
        }
        
        function stopComposerObserver() {
            if (composerObserver) {
                composerObserver.disconnect();
                if (composerObserver.timeout) {
                    clearTimeout(composerObserver.timeout);
                }
                composerObserver = null;
                hookLog('🛑 CodeLooper: Stopped composer bar observation');
            }
        }
        
        function getComposerContent() {
            const composerBar = document.querySelector('.composer-bar');
            return composerBar ? composerBar.innerHTML : null;
        }

        function startHeartbeat(ws) {
            // Clear any existing heartbeat
            if (window.__codeLooperHeartbeat) {
                clearInterval(window.__codeLooperHeartbeat);
            }

            // Start heartbeat
            window.__codeLooperHeartbeat = setInterval(() => {
                if (ws.readyState === WebSocket.OPEN) {
                    const resumeNeeded = detectResumeNeeded();
                    ws.send(JSON.stringify({
                        type: 'heartbeat',
                        version: HOOK_VERSION,
                        timestamp: new Date().toISOString(),
                        location: window.location.href,
                        readyState: ws.readyState,
                        resumeNeeded: resumeNeeded
                    }));
                }
            }, HEARTBEAT_INTERVAL);
        }

        function handleCommand(command) {
            let result;

            switch(command.type) {
                case 'getSystemInfo':
                    result = {
                        userAgent: navigator.userAgent,
                        platform: navigator.platform,
                        language: navigator.language,
                        onLine: navigator.onLine,
                        cookieEnabled: navigator.cookieEnabled,
                        windowLocation: window.location.href,
                        timestamp: new Date().toISOString(),
                        hookVersion: HOOK_VERSION
                    };
                    break;

                case 'querySelector':
                    const element = document.querySelector(command.selector);
                    result = element ? {
                        found: true,
                        tagName: element.tagName,
                        id: element.id,
                        className: element.className,
                        text: element.textContent?.substring(0, 100)
                    } : { found: false };
                    break;

                case 'getElementInfo':
                    const el = document.querySelector(command.selector);
                    if (el) {
                        const rect = el.getBoundingClientRect();
                        result = {
                            found: true,
                            position: { x: rect.x, y: rect.y },
                            size: { width: rect.width, height: rect.height },
                            visible: rect.width > 0 && rect.height > 0,
                            text: el.textContent?.substring(0, 200)
                        };
                    } else {
                        result = { found: false };
                    }
                    break;

                case 'clickElement':
                    const target = document.querySelector(command.selector);
                    if (target && target instanceof HTMLElement) {
                        target.click();
                        result = { success: true, clicked: command.selector };
                    } else {
                        result = { success: false, error: 'Element not found or not clickable' };
                    }
                    break;

                case 'getActiveElement':
                    const active = document.activeElement;
                    result = {
                        tagName: active?.tagName,
                        id: active?.id,
                        className: active?.className,
                        value: active?.value || active?.textContent
                    };
                    break;

                case 'showNotification':
                    // Display a notification in the console with custom styling
                    const message = command.message || 'Hello from CodeLooper!';
                    const style = command.style || 'background: linear-gradient(45deg, #667eea 0%, #764ba2 100%); color: white; font-size: 14px; padding: 20px; border-radius: 8px; font-weight: bold;';
                    console.log('%c' + message, style);

                    // Try to show a browser notification if permissions allow
                    if (command.browserNotification && typeof Notification !== 'undefined' && Notification.permission === 'granted') {
                        new Notification(command.title || 'CodeLooper', {
                            body: message,
                            icon: command.icon || 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="%23667eea" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M8 12a4 4 0 0 0 8 0"/></svg>'
                        });
                    }

                    // Create a temporary DOM element for visual feedback
                    if (command.showToast) {
                        const toast = document.createElement('div');
                        toast.textContent = message;
                        toast.style.cssText = 'position: fixed; top: 20px; right: 20px; background: linear-gradient(45deg, #667eea 0%, #764ba2 100%); color: white; padding: 16px 24px; border-radius: 8px; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 14px; font-weight: 500; box-shadow: 0 4px 12px rgba(0,0,0,0.15); z-index: 999999; animation: slideIn 0.3s ease-out;';

                        // Add animation
                        const styleEl = document.createElement('style');
                        styleEl.textContent = '@keyframes slideIn { from { transform: translateX(100%); opacity: 0; } to { transform: translateX(0); opacity: 1; } }';
                        document.head.appendChild(styleEl);

                        document.body.appendChild(toast);

                        // Remove after delay
                        setTimeout(() => {
                            toast.style.animation = 'slideOut 0.3s ease-in forwards';
                            toast.style.animationName = 'slideOut';
                            setTimeout(() => {
                                toast.remove();
                                styleEl.remove();
                            }, 300);
                        }, command.duration || 3000);

                        // Add slide out animation
                        styleEl.textContent += ' @keyframes slideOut { from { transform: translateX(0); opacity: 1; } to { transform: translateX(100%); opacity: 0; } }';
                    }

                    result = { success: true, message: 'Notification shown' };
                    break;

                case 'getVersion':
                    result = { version: HOOK_VERSION };
                    break;

                case 'ping':
                    result = { pong: true, timestamp: new Date().toISOString() };
                    break;
                    
                case 'checkResumeNeeded':
                    result = { 
                        resumeNeeded: detectResumeNeeded(),
                        timestamp: new Date().toISOString()
                    };
                    break;
                    
                case 'clickResume':
                    // Find and click the resume link
                    let clicked = false;
                    const elements = document.querySelectorAll('body *');
                    for (const el of elements) {
                        if (!el || !el.textContent) continue;
                        
                        // Check if element contains rate limit text
                        if (el.textContent.includes('stop the agent after 25 tool calls') || 
                            el.textContent.includes('Note: we default stop')) {
                            
                            // Find the resume link inside this element
                            const links = el.querySelectorAll('a, span.markdown-link, [role="link"], [data-link]');
                            for (const link of links) {
                                if (link.textContent.trim() === 'resume the conversation') {
                                    hookLog('🔄 CodeLooper: Clicking "resume the conversation" link');
                                    link.click();
                                    clicked = true;
                                    break;
                                }
                            }
                            if (clicked) break;
                        }
                    }
                    result = { 
                        success: clicked,
                        message: clicked ? 'Resume link clicked' : 'Resume link not found',
                        timestamp: new Date().toISOString()
                    };
                    break;
                    
                case 'startComposerObserver':
                    // Pass the WebSocket from the global reference
                    if (window.__codeLooperHook) {
                        const started = startComposerObserver(window.__codeLooperHook);
                        result = {
                            success: started,
                            message: started ? 'Composer observer started' : 'Composer bar not found yet, will retry',
                            timestamp: new Date().toISOString()
                        };
                    } else {
                        result = {
                            success: false,
                            error: 'WebSocket not available',
                            timestamp: new Date().toISOString()
                        };
                    }
                    break;
                    
                case 'stopComposerObserver':
                    stopComposerObserver();
                    result = {
                        success: true,
                        message: 'Composer observer stopped',
                        timestamp: new Date().toISOString()
                    };
                    break;
                    
                case 'getComposerContent':
                    const content = getComposerContent();
                    result = {
                        found: content !== null,
                        content: content,
                        timestamp: new Date().toISOString()
                    };
                    break;

                case 'rawCode':
                    // Fallback for backward compatibility - will fail with Trusted Types
                    result = {
                        error: 'Trusted Types policy prevents eval. Use predefined commands instead.',
                        suggestion: 'Available commands: getSystemInfo, querySelector, getElementInfo, clickElement, getActiveElement, showNotification, getVersion, ping, checkResumeNeeded, clickResume, startComposerObserver, stopComposerObserver, getComposerContent'
                    };
                    break;

                default:
                    result = {
                        error: 'Unknown command type',
                        type: command.type,
                        availableCommands: ['getSystemInfo', 'querySelector', 'getElementInfo', 'clickElement', 'getActiveElement', 'showNotification', 'getVersion', 'ping', 'checkResumeNeeded', 'clickResume', 'startComposerObserver', 'stopComposerObserver', 'getComposerContent']
                    };
            }

            return result;
        }

        function connect() {
            hookLog('🔄 CodeLooper: Attempting to connect to ' + url);

            try {
                const ws = new WebSocket(url);

                ws.onopen = () => {
                    hookLog('🔄 CodeLooper: Connected to ' + url);
                    
                    // Stop waiting log
                    if (window.__codeLooperWaitingLog) {
                        clearInterval(window.__codeLooperWaitingLog);
                        window.__codeLooperWaitingLog = null;
                    }
                    
                    ws.send('ready');
                    reconnectAttempts = 0; // Reset on successful connection

                    // Show success notification
                    showSuccessNotification();

                    // Start heartbeat
                    startHeartbeat(ws);
                    
                    // Auto-start composer observer after a short delay to ensure DOM is ready
                    setTimeout(() => {
                        hookLog('🚀 CodeLooper: Auto-starting composer observer...');
                        startComposerObserver(ws);
                    }, 1000); // 1 second delay to let the page settle
                };

                ws.onerror = (e) => {
                    hookLog('🔄 CodeLooper: WebSocket error: ' + e);
                };

                ws.onclose = (e) => {
                    hookLog('🔄 CodeLooper: WebSocket closed: ' + e);
                    window.__codeLooperHook = null;
                    window.__codeLooperPort = null;
                    window.__codeLooperVersion = null;

                    // Stop heartbeat
                    if (window.__codeLooperHeartbeat) {
                        clearInterval(window.__codeLooperHeartbeat);
                        window.__codeLooperHeartbeat = null;
                    }
                    
                    // Stop waiting log
                    if (window.__codeLooperWaitingLog) {
                        clearInterval(window.__codeLooperWaitingLog);
                        window.__codeLooperWaitingLog = null;
                    }
                    
                    // Stop composer observer
                    stopComposerObserver();

                    // Auto-reconnect logic
                    if (reconnectAttempts < maxReconnectAttempts) {
                        reconnectAttempts++;
                        hookLog('🔄 CodeLooper: Reconnecting in ' + (reconnectDelay/1000) + 's... ' +
                            '(attempt ' + reconnectAttempts + '/' + maxReconnectAttempts + ')');
                        setTimeout(connect, reconnectDelay);
                    } else {
                        hookLog('🔄 CodeLooper: Max reconnection attempts reached. Hook disabled.');
                    }
                };

                ws.onmessage = async (e) => {
                    let result;
                    try {
                        // Parse message as a command
                        const command = JSON.parse(e.data);

                        // Don't respond to our own heartbeats
                        if (command.type === 'heartbeat') {
                            return;
                        }

                        result = handleCommand(command);
                    } catch (e) {
                        // Fallback for non-JSON messages (backward compatibility)
                        result = {
                            error: 'Invalid command format. Expected JSON with type field.',
                            received: e.data,
                            actualError: e.message,
                            suggestion: 'Send commands as JSON: {"type": "getSystemInfo"}'
                        };
                    }
                    ws.send(JSON.stringify(result));
                };

                // Store reference globally
                window.__codeLooperHook = ws;
                window.__codeLooperPort = port;
                window.__codeLooperVersion = HOOK_VERSION;

            } catch(err) {
                hookLog('🔄 CodeLooper: Failed to create WebSocket: ' + err);
                return 'CodeLooper hook failed: ' + err.message;
            }
        }

        // Start periodic waiting log (logs every 5 seconds while waiting for connection)
        // To disable: clearInterval(window.__codeLooperWaitingLog)
        window.__codeLooperWaitingLog = setInterval(() => {
            if (!window.__codeLooperHook || window.__codeLooperHook.readyState !== WebSocket.OPEN) {
                hookLog('⏳ CodeLooper: Waiting for connection on port ' + port + '... (disable with: clearInterval(window.__codeLooperWaitingLog))');
            }
        }, 5000);
        
        // Start connection
        connect();

        return hookLog('!!! CODE LOOPER HOOK SCRIPT STARTED !!! v' + HOOK_VERSION + ' on port ' + port);
    })();
    """
}
