import AppKit
import Defaults
import DesignSystem
import SwiftUI

/// Simple model for macOS alert sounds
struct MacAlertSound: Identifiable, Hashable {
    let id = UUID()
    let name: String // file name without extension

    var displayName: String { name } // tweak if you want prettified titles
}

/// Curated list of available macOS system alert sounds
let popularSounds: [MacAlertSound] = [
    .init(name: "Basso"),
    .init(name: "Blow"),
    .init(name: "Bottle"),
    .init(name: "Frog"),
    .init(name: "Funk"),
    .init(name: "Glass"),
    .init(name: "Hero"),
    .init(name: "Morse"),
    .init(name: "Ping"),
    .init(name: "Pop"),
    .init(name: "Purr"),
    .init(name: "Sosumi"),
    .init(name: "Submarine"),
    .init(name: "Tink"),
]

/// Sound picker for rule configuration
struct SoundPickerView: View {
    // MARK: Internal

    @Binding var selectedSound: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Alert Sound")
                .font(Typography.callout(.medium))
                .foregroundColor(ColorPalette.text)

            HStack {
                DSButton(
                    selectedSound.isEmpty ? "Select Sound" : selectedSound,
                    style: .secondary
                ) {
                    isShowingPicker.toggle()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                DSButton(
                    "",
                    icon: Image(systemName: "play.fill"),
                    style: .secondary
                ) {
                    playSound(selectedSound)
                }
                .disabled(selectedSound.isEmpty)
            }
        }
        .popover(isPresented: $isShowingPicker, arrowEdge: .bottom) {
            SoundPickerPopover(selectedSound: $selectedSound, isPresented: $isShowingPicker)
        }
    }

    // MARK: Private

    @State private var isShowingPicker = false

    private func playSound(_ soundName: String) {
        guard !soundName.isEmpty else { return }
        SoundEngine.playSystemSound(named: soundName)
    }
}

/// Popover content for sound selection
private struct SoundPickerPopover: View {
    // MARK: Lifecycle

    init(selectedSound: Binding<String>, isPresented: Binding<Bool>) {
        self._selectedSound = selectedSound
        self._isPresented = isPresented
        self._tempSelection = State(initialValue: selectedSound.wrappedValue)
    }

    // MARK: Internal

    @Binding var selectedSound: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Text("Select Alert Sound")
                    .font(Typography.headline(.semibold))
                    .foregroundColor(ColorPalette.text)

                Spacer()

                DSButton(
                    "",
                    icon: Image(systemName: "xmark"),
                    style: .tertiary
                ) {
                    isPresented = false
                }
            }

            ScrollView {
                LazyVStack(spacing: Spacing.xxSmall) {
                    ForEach(popularSounds) { sound in
                        SoundRowView(
                            sound: sound,
                            isSelected: tempSelection == sound.name
                        ) {
                            tempSelection = sound.name
                            playSound(sound.name)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)

            HStack {
                DSButton("Cancel", style: .secondary) {
                    isPresented = false
                }

                Spacer()

                DSButton("Select", style: .primary) {
                    selectedSound = tempSelection
                    isPresented = false
                }
                .disabled(tempSelection.isEmpty)
            }
        }
        .padding(Spacing.medium)
        .frame(width: 280)
    }

    // MARK: Private

    @State private var tempSelection: String

    private func playSound(_ soundName: String) {
        SoundEngine.playSystemSound(named: soundName)
    }
}

/// Individual sound row in the picker
private struct SoundRowView: View {
    let sound: MacAlertSound
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "speaker.wave.2")
                    .foregroundColor(ColorPalette.accent)
                    .font(.system(size: 14))

                Text(sound.displayName)
                    .font(Typography.body())
                    .foregroundColor(ColorPalette.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(ColorPalette.accent)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xxSmall)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? ColorPalette.accent.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Preview

#if DEBUG
    struct SoundPickerView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                SoundPickerView(selectedSound: .constant("Boop"))
                    .padding()
                    .background(ColorPalette.background)
                    .previewDisplayName("Sound Picker")

                SoundPickerPopover(
                    selectedSound: .constant("Boop"),
                    isPresented: .constant(true)
                )
                .background(ColorPalette.background)
                .previewDisplayName("Sound Picker Popover")
            }
            .withDesignSystem()
        }
    }
#endif
