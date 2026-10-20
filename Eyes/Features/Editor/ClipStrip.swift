import PhotosUI
import SwiftUI

/// Горизонтальный список клипов с кнопкой добавления.
struct ClipStrip: View {
    let clips: [Clip]
    let selectedClipID: UUID?
    let isImporting: Bool
    @Binding var pickerItem: PhotosPickerItem?
    var onSelect: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    Button {
                        onSelect(clip.id)
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.headline)
                            Text(TimeFormatting.short(clip.trimmedDurationMs))
                                .font(.caption2)
                                .monospacedDigit()
                        }
                        .frame(width: 64, height: 56)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(clip.id == selectedClipID ? Color.yellow : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }

                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    Group {
                        if isImporting {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                                .font(.title2)
                        }
                    }
                    .frame(width: 64, height: 56)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isImporting)
            }
            .padding(.horizontal)
        }
    }
}
