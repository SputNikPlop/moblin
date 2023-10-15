import SwiftUI

struct BitratePresetsSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Form {
            List {
                ForEach(model.database.bitratePresets!) { preset in
                    NavigationLink(destination: BitratePresetsPresetSettingsView(
                        model: model,
                        preset: preset
                    )) {
                        HStack {
                            DraggableItemPrefixView()
                            TextItemView(
                                name: formatBytesPerSecond(speed: Int64(preset.bitrate)),
                                value: String(bitrateToMbps(bitrate: preset.bitrate))
                            )
                        }
                    }
                    .deleteDisabled(model.database.bitratePresets!.count == 1)
                }
                .onMove(perform: { froms, to in
                    model.database.bitratePresets!.move(fromOffsets: froms, toOffset: to)
                })
                .onDelete(perform: { offsets in
                    model.database.bitratePresets!.remove(atOffsets: offsets)
                })
            }
            CreateButtonView(action: {
                model.database.bitratePresets!.append(SettingsBitratePreset(
                    id: UUID(),
                    bitrate: 1_000_000
                ))
            })
        }
        .navigationTitle("Bitrate presets")
    }
}
