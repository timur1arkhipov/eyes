import SwiftUI

/// Полоса миниатюр с двумя ручками для выбора участка клипа.
struct TrimRangeSlider: View {
    let totalMs: Int64
    let thumbnails: [UIImage]
    @Binding var startMs: Int64
    @Binding var endMs: Int64
    /// Время исходника под пальцем во время перетаскивания.
    var onDrag: (Int64) -> Void
    var onCommit: () -> Void

    private let handleWidth: CGFloat = 18
    private let height: CGFloat = 56
    private let minGapMs: Int64 = Clip.minimumDurationMs

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(1, geometry.size.width - handleWidth * 2)
            let startX = position(for: startMs, trackWidth: trackWidth)
            let endX = position(for: endMs, trackWidth: trackWidth)

            ZStack(alignment: .leading) {
                thumbnailStrip(trackWidth: trackWidth)
                    .offset(x: handleWidth)

                // Затемнение отрезанных частей.
                Rectangle()
                    .fill(.black.opacity(0.6))
                    .frame(width: startX, height: height)
                    .offset(x: handleWidth)
                Rectangle()
                    .fill(.black.opacity(0.6))
                    .frame(width: max(0, trackWidth - endX), height: height)
                    .offset(x: handleWidth + endX)

                // Рамка выбранного участка.
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.yellow, lineWidth: 3)
                    .frame(width: endX - startX + handleWidth * 2, height: height)
                    .offset(x: startX)

                handle
                    .offset(x: startX)
                    .gesture(startGesture(trackWidth: trackWidth))

                handle
                    .offset(x: handleWidth + endX)
                    .gesture(endGesture(trackWidth: trackWidth))
            }
            .coordinateSpace(name: "trim")
        }
        .frame(height: height)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.yellow)
            .frame(width: handleWidth, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.black.opacity(0.6))
                    .frame(width: 3, height: 20)
            }
    }

    private func thumbnailStrip(trackWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            if thumbnails.isEmpty {
                Rectangle().fill(Color(.systemGray5))
            } else {
                ForEach(thumbnails.indices, id: \.self) { index in
                    Image(uiImage: thumbnails[index])
                        .resizable()
                        .scaledToFill()
                        .frame(width: trackWidth / CGFloat(thumbnails.count), height: height)
                        .clipped()
                }
            }
        }
        .frame(width: trackWidth, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func startGesture(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("trim"))
            .onChanged { value in
                // Центр ручки начала - на половину ширины ручки левее позиции на треке.
                let ms = milliseconds(forPosition: value.location.x - handleWidth / 2, trackWidth: trackWidth)
                startMs = min(max(0, ms), endMs - minGapMs)
                onDrag(startMs)
            }
            .onEnded { _ in onCommit() }
    }

    private func endGesture(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("trim"))
            .onChanged { value in
                let ms = milliseconds(forPosition: value.location.x - handleWidth * 1.5, trackWidth: trackWidth)
                endMs = max(min(totalMs, ms), startMs + minGapMs)
                onDrag(endMs)
            }
            .onEnded { _ in onCommit() }
    }

    private func position(for ms: Int64, trackWidth: CGFloat) -> CGFloat {
        guard totalMs > 0 else { return 0 }
        return trackWidth * CGFloat(ms) / CGFloat(totalMs)
    }

    private func milliseconds(forPosition x: CGFloat, trackWidth: CGFloat) -> Int64 {
        let fraction = min(max(x / trackWidth, 0), 1)
        return Int64((Double(fraction) * Double(totalMs)).rounded())
    }
}
