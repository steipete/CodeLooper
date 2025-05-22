import AVFoundation
import Defaults
import OSLog

public actor SoundManager {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper", 
        category: "SoundManager"
    )
    public static let shared = SoundManager()

    private var audioPlayer: AVAudioPlayer?

    private init() {}

    public func playInterventionSound() async {
        guard Defaults[.playSoundOnIntervention] else {
            // Self.logger.debug("Play sound on intervention is disabled in settings.")
            return
        }

        // Assuming the sound file is in the app bundle
        guard let soundURL = Bundle.main.url(
            forResource: "intervention_sound", 
            withExtension: "aiff", 
            subdirectory: "Sounds"
        ) else {
            Self.logger.error("Intervention sound file (intervention_sound.aiff in Sounds/) not found in bundle.")
            return
        }

        do {
            // Initialize the player each time to ensure it plays from the beginning
            // and respects potential changes in system audio output.
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            Self.logger.debug("Playing intervention sound.")
        } catch {
            Self.logger.error("Could not play intervention sound: \\(error.localizedDescription)")
        }
    }
    
    // Example of how to play other sounds if needed in the future
    // public func playSound(named soundName: String, withExtension ext: String) { ... }
}
