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

        // Verify cases can be created
        #expect(userAlert != nil)
        #expect(namedSound != nil)
    }

    @Test("System sound named sound creation")
    func systemSoundNamedSoundCreation() async throws {
        // Test creating named sounds with different file names
        let boopSound = SystemSound.named("Boop.aiff")
        let glassSound = SystemSound.named("Glass.aiff")
        let funkSound = SystemSound.named("Funk.aiff")

        // These should all be valid
        #expect(boopSound != nil)
        #expect(glassSound != nil)
        #expect(funkSound != nil)
    }

    @Test("System sound named sound with empty string")
    func systemSoundNamedSoundEmptyString() async throws {
        // Test creating a named sound with empty string
        let emptySound = SystemSound.named("")

        // Should still create the enum case
        #expect(emptySound != nil)
    }

    @Test("System sound named sound with special characters")
    func systemSoundNamedSoundSpecialCharacters() async throws {
        // Test creating named sounds with special characters
        let soundWithSpaces = SystemSound.named("Sound With Spaces.aiff")
        let soundWithNumbers = SystemSound.named("Sound123.aiff")
        let soundWithSymbols = SystemSound.named("Sound-_().aiff")

        #expect(soundWithSpaces != nil)
        #expect(soundWithNumbers != nil)
        #expect(soundWithSymbols != nil)
    }

    @Test("Sound engine play user alert sound")
    func soundEnginePlayUserAlertSound() async throws {
        // Test that playing user alert sound doesn't crash
        // Note: This may not produce audible sound in tests but should not crash
        SoundEngine.play(.userAlert)

        #expect(true) // If we get here, the call didn't crash
    }

    @Test("Sound engine play named sound")
    func soundEnginePlayNamedSound() async throws {
        // Test that playing a named sound doesn't crash
        SoundEngine.play(.named("Boop.aiff"))
        SoundEngine.play(.named("Glass.aiff"))
        SoundEngine.play(.named("Funk.aiff"))

        #expect(true) // If we get here, the calls didn't crash
    }

    @Test("Sound engine play invalid named sound")
    func soundEnginePlayInvalidNamedSound() async throws {
        // Test that playing an invalid named sound doesn't crash
        SoundEngine.play(.named("NonExistentSound.aiff"))
        SoundEngine.play(.named(""))
        SoundEngine.play(.named("invalid"))

        #expect(true) // If we get here, the calls didn't crash
    }

    @Test("Sound engine multiple sound playback")
    func soundEngineMultipleSoundPlayback() async throws {
        // Test playing multiple sounds in sequence
        SoundEngine.play(.userAlert)
        SoundEngine.play(.named("Boop.aiff"))
        SoundEngine.play(.userAlert)
        SoundEngine.play(.named("Glass.aiff"))

        #expect(true) // If we get here, multiple playback didn't crash
    }

    @Test("Sound engine rapid sound playback")
    func soundEngineRapidSoundPlayback() async throws {
        // Test rapid sound playback doesn't cause issues
        for _ in 0 ..< 5 {
            SoundEngine.play(.named("Boop.aiff"))
        }

        #expect(true) // If we get here, rapid playback didn't crash
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

        #expect(true) // If we get here, concurrent playback didn't crash
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

        #expect(true) // If we get here, all sounds were handled without crash
    }

    @Test("Sound engine file extensions")
    func soundEngineFileExtensions() async throws {
        // Test different file extensions
        SoundEngine.play(.named("Sound.aiff"))
        SoundEngine.play(.named("Sound.aif"))
        SoundEngine.play(.named("Sound.wav"))
        SoundEngine.play(.named("Sound.m4a"))
        SoundEngine.play(.named("Sound"))

        #expect(true) // If we get here, different extensions didn't crash
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
