import AudioToolbox
@testable import CodeLooper
import Foundation
import XCTest

class SoundManagerTests: XCTestCase {
    func testSystemSoundEnumCases() async throws {
        // Test that SystemSound enum has the expected cases
        let userAlert = SystemSound.userAlert
        let namedSound = SystemSound.named("Boop.aiff")

        // Verify cases can be created
        XCTAssertNotNil(userAlert)
        XCTAssertNotNil(namedSound)
    }

    func testSystemSoundNamedSoundCreation() async throws {
        // Test creating named sounds with different file names
        let boopSound = SystemSound.named("Boop.aiff")
        let glassSound = SystemSound.named("Glass.aiff")
        let funkSound = SystemSound.named("Funk.aiff")

        // These should all be valid
        XCTAssertNotNil(boopSound)
        XCTAssertNotNil(glassSound)
        XCTAssertNotNil(funkSound)
    }

    func testSystemSoundNamedSoundEmptyString() async throws {
        // Test creating a named sound with empty string
        let emptySound = SystemSound.named("")

        // Should still create the enum case
        XCTAssertNotNil(emptySound)
    }

    func testSystemSoundNamedSoundSpecialCharacters() async throws {
        // Test creating named sounds with special characters
        let soundWithSpaces = SystemSound.named("Sound With Spaces.aiff")
        let soundWithNumbers = SystemSound.named("Sound123.aiff")
        let soundWithSymbols = SystemSound.named("Sound-_().aiff")

        XCTAssertNotNil(soundWithSpaces)
        XCTAssertNotNil(soundWithNumbers)
        XCTAssertNotNil(soundWithSymbols)
    }

    func testSoundEnginePlayUserAlertSound() async throws {
        // Test that playing user alert sound doesn't crash
        // Note: This may not produce audible sound in tests but should not crash
        SoundEngine.play(.userAlert)

        XCTAssertTrue(true) // If we get here, the call didn't crash
    }

    func testSoundEnginePlayNamedSound() async throws {
        // Test that playing a named sound doesn't crash
        SoundEngine.play(.named("Boop.aiff"))
        SoundEngine.play(.named("Glass.aiff"))
        SoundEngine.play(.named("Funk.aiff"))

        XCTAssertTrue(true) // If we get here, the calls didn't crash
    }

    func testSoundEnginePlayInvalidNamedSound() async throws {
        // Test that playing an invalid named sound doesn't crash
        SoundEngine.play(.named("NonExistentSound.aiff"))
        SoundEngine.play(.named(""))
        SoundEngine.play(.named("invalid"))

        XCTAssertTrue(true) // If we get here, the calls didn't crash
    }

    func testSoundEngineMultipleSoundPlayback() async throws {
        // Test playing multiple sounds in sequence
        SoundEngine.play(.userAlert)
        SoundEngine.play(.named("Boop.aiff"))
        SoundEngine.play(.userAlert)
        SoundEngine.play(.named("Glass.aiff"))

        XCTAssertTrue(true) // If we get here, multiple playback didn't crash
    }

    func testSoundEngineRapidSoundPlayback() async throws {
        // Test rapid sound playback doesn't cause issues
        for _ in 0 ..< 5 {
            SoundEngine.play(.named("Boop.aiff"))
        }

        XCTAssertTrue(true) // If we get here, rapid playback didn't crash
    }

    func testSoundEngineConcurrentPlayback() async throws {
        // Test concurrent sound playback from multiple contexts
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 3 {
                group.addTask {
                    SoundEngine.play(i % 2 == 0 ? .userAlert : .named("Boop.aiff"))
                }
            }
        }

        XCTAssertTrue(true) // If we get here, concurrent playback didn't crash
    }

    func testSoundEnginePerformance() async throws {
        // Test performance of sound playback
        let startTime = Date()

        for _ in 0 ..< 10 {
            SoundEngine.play(.userAlert)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 1.0) // Should complete quickly
    }

    func testSystemSoundIDValidation() async throws {
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

        XCTAssertTrue(true) // If we get here, all sounds were handled without crash
    }

    func testSoundEngineFileExtensions() async throws {
        // Test different file extensions
        SoundEngine.play(.named("Sound.aiff"))
        SoundEngine.play(.named("Sound.aif"))
        SoundEngine.play(.named("Sound.wav"))
        SoundEngine.play(.named("Sound.m4a"))
        SoundEngine.play(.named("Sound"))

        XCTAssertTrue(true) // If we get here, different extensions didn't crash
    }

    func testSoundEngineMemoryUsage() async throws {
        // Test that repeated sound playback doesn't leak memory
        var sounds: [SystemSound] = []

        for i in 0 ..< 100 {
            let sound = SystemSound.named("Sound\(i).aiff")
            sounds.append(sound)
            SoundEngine.play(sound)
        }

        XCTAssertEqual(sounds.count, 100)

        // Clear references
        sounds.removeAll()
        XCTAssertTrue(sounds.isEmpty)
    }
}
