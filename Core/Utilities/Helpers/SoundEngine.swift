import AppKit
import AudioToolbox
import CoreAudio
import Foundation

/// Built-in tones or the user's preferred alert
enum SystemSound {
    case userAlert // kSystemSoundID_UserPreferredAlert
    case named(String) // e.g. "Boop.aiff"
}

/// One tiny helper that does everything
enum SoundEngine {
    // MARK: Internal

    /// Play a tone that obeys the user's sound settings
    static func play(_ sound: SystemSound) {
        // Skip the call entirely when the user has muted the Mac
        guard !isOutputMuted else { return }

        switch sound {
        case .userAlert:
            AudioServicesPlayAlertSoundWithCompletion(
                kSystemSoundID_UserPreferredAlert, nil
            )

        case let .named(filename):
            guard let id = id(for: filename) else { return }
            AudioServicesPlaySystemSoundWithCompletion(id, nil)
        }
    }

    // MARK: Private

    private nonisolated(unsafe) static var cache: [String: SystemSoundID] = [:]

    /// Quick test for master-output mute (works on Apple Silicon & Intel)
    private static var isOutputMuted: Bool {
        var defaultDeviceID = AudioObjectID(bitPattern: kAudioObjectSystemObject)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(defaultDeviceID,
                                         &address, 0, nil,
                                         &size, &defaultDeviceID) == noErr
        else {
            return false
        }

        var mute: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyMute
        address.mScope = kAudioObjectPropertyScopeOutput

        let hasMute = AudioObjectHasProperty(defaultDeviceID, &address) &&
            AudioObjectGetPropertyData(defaultDeviceID,
                                       &address, 0, nil,
                                       &size, &mute) == noErr
        if hasMute { return mute != 0 }

        // Device offers no mute flag → treat vol == 0 as "muted"
        var vol: Float32 = 1
        size = UInt32(MemoryLayout<Float32>.size)
        address.mSelector = kAudioDevicePropertyVolumeScalar
        if AudioObjectGetPropertyData(defaultDeviceID,
                                      &address, 0, nil,
                                      &size, &vol) == noErr
        {
            return vol == 0
        }
        return false
    }

    /// Build or reuse a SystemSoundID for a system .aiff/.caf
    private static func id(for filename: String) -> SystemSoundID? {
        if let existing = cache[filename] { return existing }

        // 1. Try the classic /System/Library/Sounds location
        let sysURL = URL(fileURLWithPath:
            "/System/Library/Sounds/\(filename)")

        // 2. Fall back to an app-bundled resource if present
        let url = FileManager.default.fileExists(atPath: sysURL.path)
            ? sysURL : Bundle.main.url(forResource: filename,
                                       withExtension: nil)

        guard let finalURL = url else { return nil }

        var id: SystemSoundID = 0
        if AudioServicesCreateSystemSoundID(finalURL as CFURL, &id)
            == kAudioServicesNoError
        {
            // Tag it as a UI sound → respects "Play user interface sounds"
            var flag: UInt32 = 1
            AudioServicesSetProperty(kAudioServicesPropertyIsUISound,
                                     UInt32(MemoryLayout.size(ofValue: id)),
                                     &id,
                                     UInt32(MemoryLayout.size(ofValue: flag)),
                                     &flag)
            cache[filename] = id
            return id
        }

        // Fallback: old-school NSSound (uses main volume, no UI-sound rules)
        NSSound(named: .init(filename.dropLast(5)))?.play()
        return nil
    }
}

// MARK: - Convenience Extensions

extension SoundEngine {
    /// Play a system sound by name (adds .aiff extension if needed)
    static func playSystemSound(named name: String) {
        let filename = name.hasSuffix(".aiff") ? name : "\(name).aiff"
        play(.named(filename))
    }

    /// Play the user's preferred alert sound
    static func playUserAlert() {
        play(.userAlert)
    }
}
