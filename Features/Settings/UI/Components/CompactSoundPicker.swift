import DesignSystem
import SwiftUI

/// A compact sound picker component with popover for sound selection.
struct CompactSoundPicker: View {
    // MARK: - Properties
    
    @Binding var selectedSound: String
    let availableSounds: [SoundOption]
    let label: String
    
    @State private var showPopover = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(label)
                .font(Typography.caption1(.medium))
                .foregroundColor(ColorPalette.text)
            
            Button(action: {
                showPopover = true
            }) {
                HStack {
                    Text(selectedSoundName)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.text)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xxSmall)
                .background(ColorPalette.backgroundSecondary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .popover(isPresented: $showPopover) {
            CompactSoundPickerPopover(
                selectedSound: $selectedSound,
                availableSounds: availableSounds,
                onSoundSelected: {
                    showPopover = false
                }
            )
        }
    }
    
    // MARK: - Private
    
    private var selectedSoundName: String {
        availableSounds.first { $0.identifier == selectedSound }?.name ?? "Unknown"
    }
}

/// Popover content for sound selection
private struct CompactSoundPickerPopover: View {
    // MARK: - Properties
    
    @Binding var selectedSound: String
    let availableSounds: [SoundOption]
    let onSoundSelected: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Select Sound")
                    .font(Typography.subheadline(.medium))
                    .foregroundColor(ColorPalette.text)
                
                Spacer()
                
                Button("Done") {
                    onSoundSelected()
                }
                .font(Typography.caption1(.medium))
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            
            Divider()
            
            // Sound options
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(availableSounds, id: \.identifier) { sound in
                        SoundOptionRow(
                            sound: sound,
                            isSelected: selectedSound == sound.identifier,
                            onSelect: {
                                selectedSound = sound.identifier
                                onSoundSelected()
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 250)
    }
}

/// Individual sound option row
private struct SoundOptionRow: View {
    // MARK: - Properties
    
    let sound: SoundOption
    let isSelected: Bool
    let onSelect: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    Text(sound.name)
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.text)
                    
                    if let description = sound.description {
                        Text(description)
                            .font(Typography.caption2())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(ColorPalette.primary)
                }
                
                Button(action: {
                    SoundEngine.playSystemSound(named: sound.identifier)
                }) {
                    Image(systemName: "play.circle")
                        .font(.caption)
                        .foregroundColor(ColorPalette.primary)
                }
                .buttonStyle(.plain)
                .help("Preview sound")
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .background(isSelected ? ColorPalette.primary.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Types

struct SoundOption {
    let identifier: String
    let name: String
    let description: String?
    
    static let systemSounds: [SoundOption] = [
        SoundOption(identifier: "Basso", name: "Basso", description: "Deep, resonant tone"),
        SoundOption(identifier: "Blow", name: "Blow", description: "Soft wind sound"),
        SoundOption(identifier: "Bottle", name: "Bottle", description: "Pop sound"),
        SoundOption(identifier: "Frog", name: "Frog", description: "Ribbit sound"),
        SoundOption(identifier: "Funk", name: "Funk", description: "Musical tone"),
        SoundOption(identifier: "Glass", name: "Glass", description: "Chime sound"),
        SoundOption(identifier: "Hero", name: "Hero", description: "Triumphant fanfare"),
        SoundOption(identifier: "Morse", name: "Morse", description: "Telegraph beep"),
        SoundOption(identifier: "Ping", name: "Ping", description: "Network ping sound"),
        SoundOption(identifier: "Pop", name: "Pop", description: "Quick pop"),
        SoundOption(identifier: "Purr", name: "Purr", description: "Cat purring"),
        SoundOption(identifier: "Sosumi", name: "Sosumi", description: "Classic Mac sound"),
        SoundOption(identifier: "Submarine", name: "Submarine", description: "Sonar ping"),
        SoundOption(identifier: "Tink", name: "Tink", description: "Metallic clink")
    ]
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.large) {
        CompactSoundPicker(
            selectedSound: .constant("Basso"),
            availableSounds: SoundOption.systemSounds,
            label: "Notification Sound"
        )
        
        CompactSoundPicker(
            selectedSound: .constant("Hero"),
            availableSounds: SoundOption.systemSounds,
            label: "Success Sound"
        )
    }
    .padding()
}