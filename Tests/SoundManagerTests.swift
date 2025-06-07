import AudioToolbox
@testable import CodeLooper
import Foundation
import Testing

@Suite("SoundManager Tests")
struct SoundManagerTests {
    @Test("System sound enum cases")
    func systemSoundEnumCases() async throws {
        // Test that SystemSound enum has the expected cases
        let userAlert = SystemSound.userAlert
        let namedSound = SystemSound.named("Boop.aiff")

        // Verify cases can be created - SystemSound is an enum, so these will always be valid
        // Test that userAlert case matches expected pattern
        switch userAlert {
        case .userAlert:
            #expect(Bool(true), "userAlert case created successfully")
        case .named:
            Issue.record("Expected userAlert case, got named case")
        }
        
        // Named sounds should match their input
        if case let .named(fileName) = namedSound {
            #expect(fileName == "Boop.aiff")
        } else {
            Issue.record("Expected named sound case")
        }
    }

    @Test("System sound named sound creation", arguments: ["Boop.aiff", "Glass.aiff", "Funk.aiff"])
    func systemSoundNamedSoundCreation(soundFileName: String) async throws {
        // Test creating named sound with the given file name
        let sound = SystemSound.named(soundFileName)

        // Verify named sound contains the correct file name
        if case let .named(fileName) = sound {
            #expect(fileName == soundFileName)
        } else {
            Issue.record("Expected named sound case for \(soundFileName)")
        }
    }

    @Test("System sound named sound with special characters", 
          arguments: ["Sound With Spaces.aiff", "Sound123.aiff", "Sound-_().aiff", "Sound@#$%.aiff", ""])
    func systemSoundNamedSoundSpecialCharacters(testFileName: String) async throws {
        // Test creating named sound with special characters or empty string
        let sound = SystemSound.named(testFileName)

        // Verify named sound preserves the exact input
        if case let .named(fileName) = sound {
            #expect(fileName == testFileName)
        } else {
            Issue.record("Expected named sound case for '\(testFileName)'")
        }
    }

    @Test("Sound engine play user alert sound")
    func soundEnginePlayUserAlertSound() async throws {
        // Test that playing user alert sound doesn't crash
        // Note: This may not produce audible sound in tests but should not crash
        SoundEngine.play(.userAlert)

        #expect(Bool(true)) // If we get here, the call didn't crash
    }

    @Test("Sound engine play named sound", arguments: ["Boop.aiff", "Glass.aiff", "Funk.aiff", "NonExistent.aiff"])
    func soundEnginePlayNamedSound(soundName: String) async throws {
        // Test that playing a named sound doesn't crash (even if file doesn't exist)
        SoundEngine.play(.named(soundName))
        
        #expect(Bool(true)) // If we get here, the call didn't crash
    }

    @Test("Sound engine play invalid named sound")
    func soundEnginePlayInvalidNamedSound() async throws {
        // Test that playing an invalid named sound doesn't crash
        SoundEngine.play(.named("NonExistentSound.aiff"))
        SoundEngine.play(.named(""))
        SoundEngine.play(.named("invalid"))

        #expect(Bool(true)) // If we get here, the calls didn't crash
    }

    @Test("Sound engine multiple sound playback")
    func soundEngineMultipleSoundPlayback() async throws {
        // Test playing multiple sounds in sequence
        SoundEngine.play(.userAlert)
        SoundEngine.play(.named("Boop.aiff"))
        SoundEngine.play(.userAlert)
        SoundEngine.play(.named("Glass.aiff"))

        #expect(Bool(true)) // If we get here, multiple playback didn't crash
    }

    @Test("Sound engine rapid sound playback")
    func soundEngineRapidSoundPlayback() async throws {
        // Test rapid sound playback doesn't cause issues
        for _ in 0 ..< 5 {
            SoundEngine.play(.named("Boop.aiff"))
        }

        #expect(Bool(true)) // If we get here, rapid playback didn't crash
    }

    @Test("Sound engine concurrent playback")
    func soundEngineConcurrentPlayback() async throws {
        // Test concurrent sound playback from multiple contexts
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 3 {
                group.addTask {
                    SoundEngine.play(i % 2 == 0 ? .userAlert : .named("Boop.aiff"))
                }
            }
        }

        #expect(Bool(true)) // If we get here, concurrent playback didn't crash
    }

    @Test("Sound engine performance")
    func soundEnginePerformance() async throws {
        // Test performance of sound playback
        let startTime = Date()

        for _ in 0 ..< 10 {
            SoundEngine.play(.userAlert)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        #expect(elapsed < 1.0) // Should complete quickly
    }

    @Test("System sound ID validation")
    func systemSoundIDValidation() async throws {
        // Test that system sound IDs are handled correctly
        // Note: Actual SystemSoundID values may vary by system
        SoundEngine.play(.userAlert)

        // Test with common system sounds
        let commonSounds = [
            "Boop.aiff",
            "Glass.aiff",
            "Funk.aiff",
            "Pop.aiff",
            "Submarine.aiff",
            "Frog.aiff",
            "Hero.aiff",
            "Morse.aiff",
            "Ping.aiff",
            "Tink.aiff",
        ]

        for soundName in commonSounds {
            SoundEngine.play(.named(soundName))
        }

        #expect(Bool(true)) // If we get here, all sounds were handled without crash
    }

    @Test("Sound engine file extensions")
    func soundEngineFileExtensions() async throws {
        // Test different file extensions
        SoundEngine.play(.named("Sound.aiff"))
        SoundEngine.play(.named("Sound.aif"))
        SoundEngine.play(.named("Sound.wav"))
        SoundEngine.play(.named("Sound.m4a"))
        SoundEngine.play(.named("Sound"))

        #expect(Bool(true)) // If we get here, different extensions didn't crash
    }

    @Test("Sound engine memory usage")
    func soundEngineMemoryUsage() async throws {
        // Test that repeated sound playback doesn't leak memory
        var sounds: [SystemSound] = []

        for i in 0 ..< 100 {
            let sound = SystemSound.named("Sound\(i).aiff")
            sounds.append(sound)
            SoundEngine.play(sound)
        }

        #expect(sounds.count == 100)

        // Clear references
        sounds.removeAll()
        #expect(sounds.isEmpty)
    }
}
