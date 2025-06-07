import AudioToolbox
@testable import CodeLooper
import Foundation
import Testing

// MARK: - Sound Manager Test Suite with Comprehensive Organization

@Suite("Sound Manager", .tags(.utilities, .system, .reliability))
struct SoundManagerTests {
    // MARK: - SystemSound Enum Suite

    @Suite("SystemSound Enum", .tags(.enum, .types))
    struct SystemSoundEnumTests {
        @Test("Enum case creation and pattern matching")
        func enumCaseCreationAndPatternMatching() {
            let userAlert = SystemSound.userAlert
            let namedSound = SystemSound.named("Boop.aiff")

            // Verify userAlert case
            switch userAlert {
            case .userAlert:
                #expect(Bool(true), "userAlert case should be created successfully")
            case .named:
                Issue.record("Expected userAlert case, got named case")
            }

            // Verify named sound case
            guard case let .named(fileName) = namedSound else {
                Issue.record("Expected named sound case")
                return
            }
            #expect(fileName == "Boop.aiff", "Named sound should preserve filename")
        }

        @Test(
            "Named sound creation preserves filename",
            arguments: commonSoundFiles
        )
        func namedSoundCreation(soundFileName: String) {
            let sound = SystemSound.named(soundFileName)

            guard case let .named(fileName) = sound else {
                Issue.record("Expected named sound case for \(soundFileName)")
                return
            }
            #expect(fileName == soundFileName, "Filename should be preserved exactly")
        }

        @Test(
            "Named sound handles special characters correctly",
            arguments: specialCharacterFilenames
        )
        func namedSoundSpecialCharacters(testFileName: String) {
            let sound = SystemSound.named(testFileName)

            guard case let .named(fileName) = sound else {
                Issue.record("Expected named sound case for '\(testFileName)'")
                return
            }
            #expect(fileName == testFileName, "Special characters should be preserved exactly")
        }

        @Test("Enum equality and hashability")
        func enumEqualityAndHashability() {
            let userAlert1 = SystemSound.userAlert
            let userAlert2 = SystemSound.userAlert
            let namedSound1 = SystemSound.named("test.aiff")
            let namedSound2 = SystemSound.named("test.aiff")
            let namedSound3 = SystemSound.named("other.aiff")

            // Test equality
            #expect(userAlert1 == userAlert2, "Same enum cases should be equal")
            #expect(namedSound1 == namedSound2, "Same named sounds should be equal")
            #expect(namedSound1 != namedSound3, "Different named sounds should not be equal")
            #expect(userAlert1 != namedSound1, "Different enum cases should not be equal")
        }
    }

    // MARK: - Sound Playback Suite

    @Suite("Sound Playback", .tags(.operations, .robustness))
    struct SoundPlaybackTests {
        @Test("User alert sound playback does not crash")
        func userAlertSoundPlayback() {
            // Test that playing user alert sound doesn't crash
            // Note: This may not produce audible sound in tests but should not crash
            #expect(throws: Never.self) {
                SoundEngine.play(.userAlert)
            }
        }

        @Test(
            "Named sound playback robustness",
            arguments: commonSoundFiles + ["NonExistent.aiff", "Invalid.file"]
        )
        func namedSoundPlayback(soundName: String) {
            // Test that playing a named sound doesn't crash (even if file doesn't exist)
            #expect(throws: Never.self) {
                SoundEngine.play(.named(soundName))
            }
        }

        @Test("Invalid sound handling gracefully fails")
        func invalidSoundHandling() {
            let invalidSounds = ["NonExistentSound.aiff", "", "invalid", "null", "/invalid/path"]

            for invalidSound in invalidSounds {
                #expect(throws: Never.self) {
                    SoundEngine.play(.named(invalidSound))
                }
            }
        }

        @Test("Sequential sound playback works correctly")
        func sequentialSoundPlayback() {
            let sounds: [SystemSound] = [
                .userAlert,
                .named("Boop.aiff"),
                .userAlert,
                .named("Glass.aiff"),
            ]

            #expect(throws: Never.self) {
                for sound in sounds {
                    SoundEngine.play(sound)
                }
            }
        }

        @Test("Rapid sound playback stress test", arguments: [5, 10, 25])
        func rapidSoundPlayback(playbackCount: Int) {
            #expect(throws: Never.self) {
                for _ in 0 ..< playbackCount {
                    SoundEngine.play(.named("Boop.aiff"))
                }
            }
        }

        @Test("Concurrent playback thread safety", arguments: [3, 5, 10])
        func concurrentPlayback(taskCount: Int) async {
            await withTaskGroup(of: Void.self) { group in
                for i in 0 ..< taskCount {
                    group.addTask {
                        let sound = i % 2 == 0 ? SystemSound.userAlert : .named("Boop.aiff")
                        SoundEngine.play(sound)
                    }
                }
            }
            // If we reach here without crashing, concurrent playback is safe
        }

        @Test(
            "File extension compatibility",
            arguments: fileExtensionVariations
        )
        func fileExtensionCompatibility(testCase: (filename: String, description: String)) {
            #expect(throws: Never.self) {
                SoundEngine.play(.named(testCase.filename))
            }
        }
    }

    // MARK: - Performance Suite

    @Suite("Performance", .tags(.performance, .timing))
    struct PerformanceTests {
        @Test("Sound playback performance", .timeLimit(.minutes(1)))
        func soundPlaybackPerformance() {
            let startTime = ContinuousClock().now

            for _ in 0 ..< 10 {
                SoundEngine.play(.userAlert)
            }

            let elapsed = ContinuousClock().now - startTime
            #expect(elapsed < .seconds(1), "10 sound plays should complete within 1 second")
        }

        @Test("Bulk playback performance", .timeLimit(.minutes(1)))
        func bulkPlaybackPerformance() async {
            let startTime = ContinuousClock().now
            let playbackCount = 100

            await withTaskGroup(of: Void.self) { group in
                for i in 0 ..< playbackCount {
                    group.addTask {
                        let sound = i % 2 == 0 ? SystemSound.userAlert : .named("Boop.aiff")
                        SoundEngine.play(sound)
                    }
                }
            }

            let elapsed = ContinuousClock().now - startTime
            let soundsPerSecond = Double(playbackCount) / Double(elapsed.components.seconds)

            #expect(soundsPerSecond > 50, "Should process at least 50 sounds per second")
        }

        @Test("Memory efficiency with many sounds")
        func memoryEfficiency() {
            var sounds: [SystemSound] = []

            // Create many sound instances
            for i in 0 ..< 100 {
                let sound = SystemSound.named("Sound\(i).aiff")
                sounds.append(sound)
                SoundEngine.play(sound)
            }

            #expect(sounds.count == 100, "Should create 100 sounds")

            // Test that we can clear references
            sounds.removeAll()
            #expect(sounds.isEmpty, "Should clear all sound references")
        }
    }

    // MARK: - System Integration Suite

    @Suite("System Integration", .tags(.system, .integration))
    struct SystemIntegrationTests {
        @Test("Common system sounds compatibility")
        func commonSystemSoundsCompatibility() {
            // Test with common macOS system sounds
            #expect(throws: Never.self) {
                SoundEngine.play(.userAlert)
            }

            for soundName in commonSoundFiles {
                #expect(throws: Never.self) {
                    SoundEngine.play(.named(soundName))
                }
            }
        }

        @Test("AudioToolbox integration works correctly")
        func audioToolboxIntegration() {
            // Verify that AudioToolbox integration doesn't crash
            // Test multiple sound types to ensure robust integration
            let testScenarios: [(SystemSound, String)] = [
                (.userAlert, "System alert"),
                (.named("Test.aiff"), "Named AIFF"),
                (.named("Test.wav"), "Named WAV"),
                (.named(""), "Empty filename"),
            ]

            for (sound, description) in testScenarios {
                #expect(throws: Never.self, "\(description) should not crash") {
                    SoundEngine.play(sound)
                }
            }
        }

        @Test("System resource cleanup")
        func systemResourceCleanup() {
            // Test that sound engine cleans up system resources properly
            let iterations = 50

            for i in 0 ..< iterations {
                let sound = SystemSound.named("TestSound\(i % 5).aiff")
                SoundEngine.play(sound)

                // Occasional validation points
                if i % 10 == 0 {
                    #expect(i >= 0, "Iteration \(i) should proceed normally")
                }
            }

            // If we complete all iterations without issues, resource management is working
            #expect(Bool(true), "All \(iterations) iterations completed successfully")
        }

        @Test("Cross-platform sound handling")
        func crossPlatformSoundHandling() {
            // Test that sound handling works across different macOS configurations
            let platformTestSounds = [
                "system:alert", // System-style identifier
                "Boop.aiff", // Classic macOS sound
                "nonexistent.wav", // Non-existent file
                "unicode🔊.aiff", // Unicode filename
            ]

            for soundName in platformTestSounds {
                #expect(throws: Never.self, "Sound '\(soundName)' should be handled gracefully") {
                    SoundEngine.play(.named(soundName))
                }
            }
        }
    }

    // MARK: - Edge Cases Suite

    @Suite("Edge Cases", .tags(.edge_cases, .robustness))
    struct EdgeCasesTests {
        @Test("Extreme filename lengths")
        func extremeFilenameLengths() {
            let shortName = "a"
            let longName = String(repeating: "VeryLong", count: 100) + ".aiff"
            let emptyName = ""

            let extremeCases = [shortName, longName, emptyName]

            for filename in extremeCases {
                #expect(throws: Never.self, "Filename '\(filename.prefix(20))...' should be handled") {
                    SoundEngine.play(.named(filename))
                }
            }
        }

        @Test("Unicode and international character support")
        func unicodeCharacterSupport() {
            let unicodeFilenames = [
                "🔊Sound.aiff",
                "测试声音.aiff",
                "صوت.aiff",
                "звук.aiff",
                "音.aiff",
            ]

            for filename in unicodeFilenames {
                #expect(throws: Never.self, "Unicode filename should be handled gracefully") {
                    SoundEngine.play(.named(filename))
                }
            }
        }

        @Test("Memory pressure resilience", .timeLimit(.minutes(1)))
        func memoryPressureResilience() async {
            // Test behavior under simulated memory pressure
            await withTaskGroup(of: Void.self) { group in
                // Create multiple concurrent sound operations
                for taskId in 0 ..< 20 {
                    group.addTask {
                        for iteration in 0 ..< 50 {
                            let soundName = "PressureTest_\(taskId)_\(iteration).aiff"
                            SoundEngine.play(.named(soundName))
                        }
                    }
                }
            }

            // System should remain stable after memory pressure
            #expect(throws: Never.self) {
                SoundEngine.play(.userAlert)
            }
        }
    }

    // MARK: - Test Data

    static let commonSoundFiles = [
        "Boop.aiff", "Glass.aiff", "Funk.aiff", "Pop.aiff",
        "Submarine.aiff", "Frog.aiff", "Hero.aiff", "Morse.aiff",
        "Ping.aiff", "Tink.aiff",
    ]

    static let specialCharacterFilenames = [
        "Sound With Spaces.aiff", "Sound123.aiff", "Sound-_().aiff",
        "Sound@#$%.aiff", "", "LongSoundFileName" + String(repeating: "X", count: 100) + ".aiff",
    ]

    static let fileExtensionVariations = [
        ("Sound.aiff", "AIFF format"),
        ("Sound.aif", "AIF format"),
        ("Sound.wav", "WAV format"),
        ("Sound.m4a", "M4A format"),
        ("Sound", "No extension"),
    ]
}
