import Defaults
import Diagnostics

/// Legacy sound manager - replaced by SoundEngine for better performance and system integration
/// This provides a compatibility layer for existing code
@MainActor
public final class SoundManager {
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
            logger.debug("Empty sound name provided, falling back to user alert.")
            SoundEngine.playUserAlert()
            return
        }

        logger.debug("Playing system sound: \(soundName)")
        SoundEngine.playSystemSound(named: soundName)
    }

    // MARK: Private

    private let logger = Logger(category: .sound)
}
