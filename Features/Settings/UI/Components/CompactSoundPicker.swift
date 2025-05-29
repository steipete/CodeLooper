import Defaults
import DesignSystem
import SwiftUI

/// Compact sound picker for intervention rule notifications.
///
/// CompactSoundPicker provides:
/// - Quick selection of notification sounds
/// - Rule-specific sound configuration
/// - Sound preview functionality
/// - Integration with user defaults
struct CompactSoundPicker: View {
    // MARK: Internal

    let ruleName: String

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(ColorPalette.textSecondary)
                .font(.system(size: 12))

            Menu {
                ForEach(availableSounds, id: \.self) { sound in
                    Button(sound.displayName) {
                        setSound(sound, for: ruleName)
                    }
                }
            } label: {
                Text(getCurrentSound(for: ruleName).displayName)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.text)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ColorPalette.backgroundTertiary)
                    .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
        }
    }

    // MARK: Private

    private let availableSounds: [NotificationSound] = [
        .none,
        .default,
        .glass,
        .ping,
        .pop,
        .sosumi,
    ]

    // Default sound settings per rule
    @Default(.stopAfter25LoopsRuleSound) private var stopAfter25LoopsSound
    @Default(.plainStopRuleSound) private var plainStopSound
    @Default(.connectionIssuesRuleSound) private var connectionIssuesSound
    @Default(.editedInAnotherChatRuleSound) private var editedInAnotherChatSound

    private func getCurrentSound(for ruleName: String) -> NotificationSound {
        switch ruleName {
        case "Stop after 25 loops":
            NotificationSound(rawValue: stopAfter25LoopsSound) ?? .default
        case "Plain Stop":
            NotificationSound(rawValue: plainStopSound) ?? .default
        case "Connection Issues":
            NotificationSound(rawValue: connectionIssuesSound) ?? .default
        case "Edited in another chat":
            NotificationSound(rawValue: editedInAnotherChatSound) ?? .default
        default:
            .default
        }
    }

    private func setSound(_ sound: NotificationSound, for ruleName: String) {
        switch ruleName {
        case "Stop after 25 loops":
            Defaults[.stopAfter25LoopsRuleSound] = sound.rawValue
        case "Plain Stop":
            Defaults[.plainStopRuleSound] = sound.rawValue
        case "Connection Issues":
            Defaults[.connectionIssuesRuleSound] = sound.rawValue
        case "Edited in another chat":
            Defaults[.editedInAnotherChatRuleSound] = sound.rawValue
        default:
            break
        }
    }
}

// MARK: - Supporting Types

enum NotificationSound: String, CaseIterable {
    case none
    case `default`
    case glass = "Glass"
    case ping = "Ping"
    case pop = "Pop"
    case sosumi = "Sosumi"

    // MARK: Internal

    var displayName: String {
        switch self {
        case .none:
            "None"
        case .default:
            "Default"
        case .glass:
            "Glass"
        case .ping:
            "Ping"
        case .pop:
            "Pop"
        case .sosumi:
            "Sosumi"
        }
    }
}

#if DEBUG
    struct CompactSoundPicker_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: Spacing.medium) {
                CompactSoundPicker(ruleName: "Stop after 25 loops")
                CompactSoundPicker(ruleName: "Plain Stop")
                CompactSoundPicker(ruleName: "Connection Issues")
            }
            .padding()
            .withDesignSystem()
        }
    }
#endif
