import AppKit
import AVFoundation
import Defaults
import Diagnostics
import OSLog

public actor SoundManager {
    // MARK: Lifecycle

    private init() {}

    // MARK: Public

    public static let shared = SoundManager()

    public func playSound(soundName: String) async {
        guard Defaults[.playSoundOnIntervention] else {
            return
        }

        // Handle empty sound name
        if soundName.isEmpty {
            Self.logger.debug("Empty sound name provided, falling back to default system sound.")
            await playDefaultSystemSound()
            return
        }

        // Check if soundName contains an extension
        let hasExtension = soundName.contains(".")

        // First attempt: Try to play system sound if no extension
        if !hasExtension {
            Self.logger.debug("Attempting to play system sound: \(soundName)")
            if let systemSound = NSSound(named: NSSound.Name(soundName)) {
                systemSound.play()
                Self.logger.debug("Successfully played system sound: \(soundName)")
                return
            } else {
                Self.logger.debug("System sound \(soundName) not found, attempting to play bundled sound.")
            }
        }

        // Second attempt: Try to play from Resources/Sounds/ directory
        let components = soundName.split(separator: ".", maxSplits: 1)
        let fileName: String
        let fileExtension: String

        if components.count == 2 {
            fileName = String(components[0])
            fileExtension = String(components[1])
        } else {
            // Default to .aiff if no extension provided
            fileName = soundName
            fileExtension = "aiff"
        }

        Self.logger.debug("Attempting to play bundled sound: \(fileName).\(fileExtension)")

        if let soundURL = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExtension,
            subdirectory: "Sounds"
        ) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                Self.logger.debug("Playing bundled sound: \(fileName).\(fileExtension)")
                return
            } catch {
                Self.logger
                    .error("Could not play bundled sound \(fileName).\(fileExtension): \(error.localizedDescription)")
            }
        } else {
            Self.logger.error("Bundled sound file (\(fileName).\(fileExtension) in Sounds/) not found.")
        }

        // Fallback: Play default system sound
        Self.logger.debug("Fallback: Playing default system sound.")
        await playDefaultSystemSound()
    }

    // MARK: Private

    private static let logger = Logger(category: .sound)

    private var audioPlayer: AVAudioPlayer?

    private func playDefaultSystemSound() async {
        // Use the system "Glass" sound as a default notification sound
        if let systemSound = NSSound(named: NSSound.Name("Glass")) {
            systemSound.play()
            Self.logger.debug("Playing default system sound (Glass).")
        } else {
            Self.logger.error("Could not play default system sound.")
        }
    }
}
