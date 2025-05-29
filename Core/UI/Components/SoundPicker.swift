import AppKit
import Defaults
import DesignSystem
import SwiftUI

/// Simple model for macOS alert sounds
struct MacAlertSound: Identifiable, Hashable, Codable {
    let id = UUID()
    let name: String               // file name without extension
    var displayName: String { name }  // tweak if you want prettified titles
}

/// Curated "most-popular" list of macOS alert sounds
let popularSounds: [MacAlertSound] = [
    .init(name: "Boop"),
    .init(name: "Breeze"),
    .init(name: "Crystal"),
    .init(name: "Funky"),
    .init(name: "Heroine"),
    .init(name: "Jump"),
    .init(name: "Mezzo"),
    .init(name: "Pluck"),
    .init(name: "Pong"),
    .init(name: "Sonar"),
    .init(name: "Sonumi"),
    .init(name: "Submerge")
]

/// Sound picker for rule configuration
struct SoundPickerView: View {
    @Binding var selectedSound: String
    @State private var isShowingPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Alert Sound")
                .font(Typography.callout(.medium))
                .foregroundColor(ColorPalette.text)
            
            HStack {
                DSButton(style: .secondary) {
                    Text(selectedSound.isEmpty ? "Select Sound" : selectedSound)
                        .foregroundColor(ColorPalette.text)
                } action: {
                    isShowingPicker.toggle()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                DSButton(style: .secondary) {
                    Image(systemName: "play.fill")
                        .foregroundColor(ColorPalette.accent)
                } action: {
                    playSound(selectedSound)
                }
                .disabled(selectedSound.isEmpty)
            }
        }
        .popover(isPresented: $isShowingPicker, arrowEdge: .bottom) {
            SoundPickerPopover(selectedSound: $selectedSound, isPresented: $isShowingPicker)
        }
    }
    
    private func playSound(_ soundName: String) {
        guard !soundName.isEmpty else { return }
        SoundEngine.playSystemSound(named: soundName)
    }
}

/// Popover content for sound selection
private struct SoundPickerPopover: View {
    @Binding var selectedSound: String
    @Binding var isPresented: Bool
    @State private var tempSelection: String
    
    init(selectedSound: Binding<String>, isPresented: Binding<Bool>) {
        self._selectedSound = selectedSound
        self._isPresented = isPresented
        self._tempSelection = State(initialValue: selectedSound.wrappedValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Text("Select Alert Sound")
                    .font(Typography.headline(.semibold))
                    .foregroundColor(ColorPalette.text)
                
                Spacer()
                
                DSButton(style: .tertiary) {
                    Image(systemName: "xmark")
                        .foregroundColor(ColorPalette.textSecondary)
                } action: {
                    isPresented = false
                }
            }
            
            ScrollView {
                LazyVStack(spacing: Spacing.xxSmall) {
                    ForEach(popularSounds) { sound in
                        SoundRowView(
                            sound: sound,
                            isSelected: tempSelection == sound.name
                        )                            {
                                tempSelection = sound.name
                                playSound(sound.name)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            
            HStack {
                DSButton(style: .secondary) {
                    Text("Cancel")
                } action: {
                    isPresented = false
                }
                
                Spacer()
                
                DSButton(style: .primary) {
                    Text("Select")
                } action: {
                    selectedSound = tempSelection
                    isPresented = false
                }
                .disabled(tempSelection.isEmpty)
            }
        }
        .padding(Spacing.medium)
        .frame(width: 280)
    }
    
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
        DSButton(style: .tertiary) {
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
        } action: {
            onSelect()
        }
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
