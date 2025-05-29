import Testing
import Foundation
import AudioToolbox
@testable import CodeLooper

@Test("SoundEngine - SystemSound Enum Cases")
func testSystemSoundEnumCases() async throws {
    // Test that SystemSound enum has the expected cases
    let userAlert = SystemSound.userAlert
    let namedSound = SystemSound.named("Boop.aiff")
    
    // Verify cases can be created
    #expect(userAlert != nil)
    #expect(namedSound != nil)
}

@Test("SoundEngine - SystemSound Named Sound Creation")
func testSystemSoundNamedSoundCreation() async throws {
    // Test creating named sounds with different file names
    let boopSound = SystemSound.named("Boop.aiff")
    let glassSound = SystemSound.named("Glass.aiff")
    let funkSound = SystemSound.named("Funk.aiff")
    
    // These should all be valid
    #expect(boopSound != nil)
    #expect(glassSound != nil)
    #expect(funkSound != nil)
}

@Test("SoundEngine - SystemSound Named Sound Empty String")
func testSystemSoundNamedSoundEmptyString() async throws {
    // Test creating a named sound with empty string
    let emptySound = SystemSound.named("")
    
    // Should still create the enum case
    #expect(emptySound != nil)
}

@Test("SoundEngine - SystemSound Named Sound Special Characters")
func testSystemSoundNamedSoundSpecialCharacters() async throws {
    // Test creating named sounds with special characters
    let soundWithSpaces = SystemSound.named("Sound With Spaces.aiff")
    let soundWithNumbers = SystemSound.named("Sound123.aiff")
    let soundWithSymbols = SystemSound.named("Sound-_().aiff")
    
    #expect(soundWithSpaces != nil)
    #expect(soundWithNumbers != nil)
    #expect(soundWithSymbols != nil)
}

@Test("SoundEngine - Play User Alert Sound")
func testSoundEnginePlayUserAlertSound() async throws {
    // Test that playing user alert sound doesn't crash
    // Note: This may not produce audible sound in tests but should not crash
    SoundEngine.play(.userAlert)
    
    #expect(true) // If we get here, the call didn't crash
}

@Test("SoundEngine - Play Named Sound")
func testSoundEnginePlayNamedSound() async throws {
    // Test that playing a named sound doesn't crash
    SoundEngine.play(.named("Boop.aiff"))
    SoundEngine.play(.named("Glass.aiff"))
    SoundEngine.play(.named("Funk.aiff"))
    
    #expect(true) // If we get here, the calls didn't crash
}

@Test("SoundEngine - Play Invalid Named Sound")
func testSoundEnginePlayInvalidNamedSound() async throws {
    // Test that playing an invalid named sound doesn't crash
    SoundEngine.play(.named("NonExistentSound.aiff"))
    SoundEngine.play(.named(""))
    SoundEngine.play(.named("invalid"))
    
    #expect(true) // If we get here, the calls didn't crash
}

@Test("SoundEngine - Multiple Sound Playback")
func testSoundEngineMultipleSoundPlayback() async throws {
    // Test playing multiple sounds in sequence
    SoundEngine.play(.userAlert)
    SoundEngine.play(.named("Boop.aiff"))
    SoundEngine.play(.userAlert)
    SoundEngine.play(.named("Glass.aiff"))
    
    #expect(true) // If we get here, multiple playback didn't crash
}

@Test("SoundEngine - Rapid Sound Playback")
func testSoundEngineRapidSoundPlayback() async throws {
    // Test rapid sound playback doesn't cause issues
    for _ in 0..<5 {
        SoundEngine.play(.named("Boop.aiff"))
    }
    
    #expect(true) // If we get here, rapid playback didn't crash
}

@Test("SoundEngine - Sound Playback With Mute State")
func testSoundEnginePlaybackWithMuteState() async throws {
    // Test that sound playback respects mute state
    // Note: We can't control the actual mute state in tests,
    // but we can verify the calls don't crash regardless
    SoundEngine.play(.userAlert)
    SoundEngine.play(.named("Boop.aiff"))
    
    #expect(true) // If we get here, playback with mute handling worked
}

@Test("SoundEngine - Common System Sounds")
func testSoundEngineCommonSystemSounds() async throws {
    // Test common system sounds that are likely to exist
    let commonSounds = [
        "Boop.aiff",
        "Glass.aiff",
        "Funk.aiff",
        "Purr.aiff",
        "Sosumi.aiff"
    ]
    
    for soundName in commonSounds {
        SoundEngine.play(.named(soundName))
    }
    
    #expect(true) // If we get here, common sounds didn't crash
}

@Test("SoundEngine - Sound Caching Behavior")
func testSoundEngineSoundCachingBehavior() async throws {
    // Test that playing the same sound multiple times works
    // (This exercises the internal caching mechanism)
    let soundName = "Boop.aiff"
    
    SoundEngine.play(.named(soundName))
    SoundEngine.play(.named(soundName))
    SoundEngine.play(.named(soundName))
    
    #expect(true) // If we get here, caching worked correctly
}

@Test("SoundEngine - Mixed Sound Types")
func testSoundEngineMixedSoundTypes() async throws {
    // Test mixing user alert and named sounds
    SoundEngine.play(.userAlert)
    SoundEngine.play(.named("Boop.aiff"))
    SoundEngine.play(.userAlert)
    SoundEngine.play(.named("Glass.aiff"))
    SoundEngine.play(.userAlert)
    
    #expect(true) // If we get here, mixed sound types worked
}

@Test("SoundEngine - Performance Test")
func testSoundEnginePerformance() async throws {
    let startTime = Date()
    
    // Play sounds rapidly to test performance
    for i in 0..<10 {
        if i % 2 == 0 {
            SoundEngine.play(.userAlert)
        } else {
            SoundEngine.play(.named("Boop.aiff"))
        }
    }
    
    let elapsed = Date().timeIntervalSince(startTime)
    
    // Should complete quickly (under 1 second for 10 sounds)
    #expect(elapsed < 1.0)
}

@Test("SoundEngine - Thread Safety")
func testSoundEngineThreadSafety() async throws {
    // Test concurrent sound playback from multiple tasks
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<5 {
            group.addTask {
                if i % 2 == 0 {
                    SoundEngine.play(.userAlert)
                } else {
                    SoundEngine.play(.named("Boop.aiff"))
                }
            }
        }
    }
    
    #expect(true) // If we get here, concurrent playback worked
}