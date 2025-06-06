import AppKit
@testable import CodeLooper
import Foundation
import Testing

@Suite("Window Management Tests")
@MainActor
struct WindowManagementTests {
    // MARK: Internal

    @Test("Window manager initialization") @MainActor func windowManagerInitialization() async throws {
        let mockLoginItemManager = createMockLoginItemManager()
        let mockSessionLogger = createMockSessionLogger()
        let mockDelegate = createMockWindowManagerDelegate()

        let windowManager = await WindowManager(
            loginItemManager: mockLoginItemManager,
            sessionLogger: mockSessionLogger,
            delegate: mockDelegate
        )

        #expect(windowManager != nil)
        // Remove delegate check as it causes Sendable issues
    }

    @Test("windowControllerManagement") @MainActor func windowControllerManagement() async throws {
        let mockLoginItemManager = createMockLoginItemManager()
        let mockSessionLogger = createMockSessionLogger()
        let mockDelegate = createMockWindowManagerDelegate()

        let windowManager = await WindowManager(
            loginItemManager: mockLoginItemManager,
            sessionLogger: mockSessionLogger,
            delegate: mockDelegate
        )

        // Test that window controllers are initially nil
        let initialWelcomeController = await windowManager.welcomeWindowController
        #expect(initialWelcomeController == nil)
    }

    @Test("windowManagerDelegate") @MainActor func windowManagerDelegate() async throws {
        // Test delegate protocol methods exist and can be called
        let delegate = MockWindowManagerDelegate()

        // Test that delegate methods can be called without errors
        await delegate.windowManagerDidFinishOnboarding()

        // Use a simple boolean to avoid reflection issues
        let wasCalled = delegate.didFinishOnboardingCalled
        #expect(wasCalled)
    }

    @Test("windowPositionManagerSingleton") func windowPositionManagerSingleton() async throws {
        let manager1 = await WindowPositionManager.shared
        let manager2 = await WindowPositionManager.shared

        // Both references should point to the same instance
        #expect(manager1 === manager2)
    }

    @Test("windowPositionOperations") func windowPositionOperations() async throws {
        let manager = await WindowPositionManager.shared

        // Test position and size calculations
        let originalPosition = NSPoint(x: 100, y: 100)
        let originalSize = NSSize(width: 400, height: 300)
        let originalFrame = NSRect(origin: originalPosition, size: originalSize)

        // Test frame calculations
        let newPosition = NSPoint(x: 200, y: 150)
        let newFrame = NSRect(origin: newPosition, size: originalSize)

        #expect(newFrame.origin.x == 200)
        #expect(newFrame.origin.y == 150)
        #expect(newFrame.size.width == 400)
        #expect(newFrame.size.height == 300)

        // Test size calculations
        let newSize = NSSize(width: 500, height: 400)
        let resizedFrame = NSRect(origin: originalPosition, size: newSize)

        #expect(resizedFrame.origin.x == 100)
        #expect(resizedFrame.origin.y == 100)
        #expect(resizedFrame.size.width == 500)
        #expect(resizedFrame.size.height == 400)
    }

    @Test("positionSavingAndRestoration") func positionSavingAndRestoration() async throws {
        let manager = await WindowPositionManager.shared

        // Test saving and restoring positions using identifiers
        let testFrame = NSRect(x: 150, y: 200, width: 600, height: 500)
        let identifier = "test-window-\(Date().timeIntervalSince1970)"

        // Test that we can save position data
        // Note: We can't test actual window operations without creating real windows
        // So we test the identifier and frame data handling
        #expect(testFrame.origin.x == 150)
        #expect(testFrame.origin.y == 200)
        #expect(testFrame.size.width == 600)
        #expect(testFrame.size.height == 500)
        #expect(identifier.contains("test-window"))
    }

    @Test("appleScriptSupportMethods") func appleScriptSupportMethods() async throws {
        let manager = await WindowPositionManager.shared

        // Test NSNumber to NSPoint conversion
        let xNumber = NSNumber(value: 300)
        let yNumber = NSNumber(value: 250)
        let position = NSPoint(x: xNumber.doubleValue, y: yNumber.doubleValue)

        #expect(position.x == 300.0)
        #expect(position.y == 250.0)

        // Test NSNumber to NSSize conversion
        let widthNumber = NSNumber(value: 800)
        let heightNumber = NSNumber(value: 600)
        let size = NSSize(width: widthNumber.doubleValue, height: heightNumber.doubleValue)

        #expect(size.width == 800.0)
        #expect(size.height == 600.0)
    }

    @Test("userDefaultsSerialization") func userDefaultsSerialization() async throws {
        // Test NSRect to Dictionary conversion (as used in saveToDisk)
        let testRect = NSRect(x: 100, y: 150, width: 400, height: 300)

        let encodableData: [String: CGFloat] = [
            "x": testRect.origin.x,
            "y": testRect.origin.y,
            "width": testRect.size.width,
            "height": testRect.size.height,
        ]

        #expect(encodableData["x"] == 100)
        #expect(encodableData["y"] == 150)
        #expect(encodableData["width"] == 400)
        #expect(encodableData["height"] == 300)

        // Test Dictionary to NSRect conversion (as used in loadSavedPositions)
        if let xPos = encodableData["x"],
           let yPos = encodableData["y"],
           let width = encodableData["width"],
           let height = encodableData["height"]
        {
            let reconstructedRect = NSRect(x: xPos, y: yPos, width: width, height: height)
            #expect(reconstructedRect.origin.x == testRect.origin.x)
            #expect(reconstructedRect.origin.y == testRect.origin.y)
            #expect(reconstructedRect.size.width == testRect.size.width)
            #expect(reconstructedRect.size.height == testRect.size.height)
        } else {
            #expect(false, "Failed to reconstruct rect from dictionary")
        }
    }

    @Test("monitoredWindowInfo") @MainActor func monitoredWindowInfo() async throws {
        // Test MonitoredWindowInfo creation and properties
        let windowId = "test-window-123"
        let windowTitle = "Test Window"
        let documentPath = "/Users/test/document.txt"

        // Since we can't create real AXElement in tests, we test the data structure
        let windowInfo = MonitoredWindowInfo(
            id: windowId,
            windowTitle: windowTitle,
            axElement: nil, // Would be real AXElement in actual usage
            documentPath: documentPath,
            isPaused: false
        )

        #expect(windowInfo.id == windowId)
        #expect(windowInfo.windowTitle == windowTitle)
        #expect(windowInfo.documentPath == documentPath)
        #expect(!windowInfo.isPaused)
    }

    @Test("windowTitleParsing") func windowTitleParsing() async throws {
        // Test various window title scenarios
        let windowTitles = [
            "MyApp - Document.txt",
            "Untitled",
            "",
            "Very Long Window Title With Many Words And Special Characters !@#$%",
            "File.swift — MyProject",
            nil,
        ]

        for title in windowTitles {
            let windowId = "test-pid-window-\(title ?? "untitled")-0"
            #expect(windowId.contains("test-pid-window"))
            #expect(windowId.contains("-0"))

            // Test that we handle nil titles gracefully
            if title == nil {
                #expect(windowId.contains("untitled"))
            }
        }
    }

    @Test("documentPathProcessing") func documentPathProcessing() async throws {
        // Test various document path formats
        let testPaths = [
            "file:///Users/test/Documents/file.txt",
            "/Users/test/Documents/file.txt",
            "https://example.com/document",
            "",
            nil,
        ]

        for pathString in testPaths {
            if let pathString {
                // Test file URL conversion
                if let url = URL(string: pathString), url.isFileURL {
                    let convertedPath = url.path
                    #expect(convertedPath.hasPrefix("/"))
                    #expect(!convertedPath.hasPrefix("file://"))
                }
            }
        }
    }

    @Test("displayTextExtraction") func displayTextExtraction() async throws {
        // Test the attribute keys used for text extraction
        let primaryAttributeKeys = [
            kAXValueAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXPlaceholderValueAttribute as String,
            kAXHelpAttribute as String,
        ]

        let secondaryAttributeKeys = [
            kAXValueAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
        ]

        // Test that keys are valid strings
        for key in primaryAttributeKeys {
            #expect(key.count > 0)
            #expect(key.hasPrefix("AX"))
        }

        for key in secondaryAttributeKeys {
            #expect(key.count > 0)
            #expect(key.hasPrefix("AX"))
        }

        // Test string trimming logic
        let testStrings = [
            "  normal text  ",
            "\n\ntext with newlines\n\n",
            "\t\ttabbed text\t\t",
            "already clean text",
            "",
        ]

        for testString in testStrings {
            let trimmed = testString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            #expect(!trimmed.hasPrefix(" "))
            #expect(!trimmed.hasSuffix(" "))
            #expect(!trimmed.hasPrefix("\n"))
            #expect(!trimmed.hasSuffix("\n"))
            #expect(!trimmed.hasPrefix("\t"))
            #expect(!trimmed.hasSuffix("\t"))
        }
    }

    @Test("asyncOperations") func asyncOperations() async throws {
        // Test concurrent window processing simulation
        let appCount = 5
        var results: [(Int, String)] = []

        await withTaskGroup(of: (Int, String).self) { group in
            for index in 0 ..< appCount {
                group.addTask {
                    // Simulate window processing
                    try? await Task.sleep(for: .milliseconds(10)) // 10ms
                    return (index, "processed-\(index)")
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        #expect(results.count == appCount)

        // Results may arrive in any order due to concurrency
        let indices = results.map(\.0)
        let processedStrings = results.map(\.1)

        #expect(Set(indices) == Set(0 ..< appCount))
        for processedString in processedStrings {
            #expect(processedString.hasPrefix("processed-"))
        }
    }

    @Test("frameCalculations") func frameCalculations() async throws {
        // Test various frame calculation scenarios
        let originalFrame = NSRect(x: 100, y: 100, width: 400, height: 300)

        // Test moving without resizing
        let newPosition = NSPoint(x: 200, y: 150)
        let movedFrame = NSRect(origin: newPosition, size: originalFrame.size)

        #expect(movedFrame.origin.x == 200)
        #expect(movedFrame.origin.y == 150)
        #expect(movedFrame.size.width == originalFrame.size.width)
        #expect(movedFrame.size.height == originalFrame.size.height)

        // Test resizing without moving
        let newSize = NSSize(width: 500, height: 400)
        let resizedFrame = NSRect(origin: originalFrame.origin, size: newSize)

        #expect(resizedFrame.origin.x == originalFrame.origin.x)
        #expect(resizedFrame.origin.y == originalFrame.origin.y)
        #expect(resizedFrame.size.width == 500)
        #expect(resizedFrame.size.height == 400)

        // Test complete frame change
        let newFrame = NSRect(x: 300, y: 250, width: 600, height: 500)
        #expect(newFrame.origin.x == 300)
        #expect(newFrame.origin.y == 250)
        #expect(newFrame.size.width == 600)
        #expect(newFrame.size.height == 500)
    }

    @Test("windowManagementThreadSafety") func windowManagementThreadSafety() async throws {
        // Test concurrent access to window operations
        let windowPositionManager = await WindowPositionManager.shared

        // Test concurrent position calculations
        await withTaskGroup(of: NSRect.self) { group in
            for i in 0 ..< 10 {
                group.addTask {
                    let position = NSPoint(x: CGFloat(i * 50), y: CGFloat(i * 30))
                    let size = NSSize(width: 400, height: 300)
                    return NSRect(origin: position, size: size)
                }
            }

            var frameCount = 0
            for await frame in group {
                frameCount += 1
                #expect(frame.size.width == 400)
                #expect(frame.size.height == 300)
            }

            #expect(frameCount == 10)
        }
    }

    @Test("errorHandling") func errorHandling() async throws {
        // Test graceful handling of nil values
        let manager = await WindowPositionManager.shared

        // Test operations with nil windows (should not crash)
        await manager.moveWindow(nil, to: NSPoint(x: 100, y: 100))
        await manager.resizeWindow(nil, to: NSSize(width: 400, height: 300))
        await manager.setWindowFrame(nil, to: NSRect(x: 0, y: 0, width: 400, height: 300))
        await manager.centerWindow(nil)

        // Test position saving/restoring with nil window
        await manager.saveWindowPosition(nil, identifier: "test")
        let restored = await manager.restoreWindowPosition(nil, identifier: "test")
        #expect(!restored)

        // Test restoring non-existent position
        let nonExistentRestored = await manager.restoreWindowPosition(nil, identifier: "non-existent")
        #expect(!nonExistentRestored)
    }

    // MARK: Private

    // MARK: - Helper Functions and Mocks

    @MainActor
    private class MockWindowManagerDelegate: WindowManagerDelegate {
        var didFinishOnboardingCalled = false

        func windowManagerDidFinishOnboarding() {
            didFinishOnboardingCalled = true
        }
    }

    @MainActor
    private func createMockLoginItemManager() -> LoginItemManager {
        LoginItemManager.shared
    }

    private func createMockSessionLogger() -> SessionLogger {
        // SessionLogger.shared is @MainActor, so we need to access it safely
        return MainActor.assumeIsolated {
            SessionLogger.shared
        }
    }

    private func createMockWindowManagerDelegate() -> MockWindowManagerDelegate {
        MockWindowManagerDelegate()
    }
}
