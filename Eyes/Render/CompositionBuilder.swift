import AVFoundation

enum CompositionError: LocalizedError {
    case cannotCreateTrack
    case missingVideoTrack(String)

    var errorDescription: String? {
        switch self {
        case .cannotCreateTrack:
            return "Не удалось создать дорожку композиции."
        case .missingVideoTrack(let name):
            return "В файле \(name) нет видеодорожки."
        }
    }
}

/// Собирает AVMutableComposition из Project.
/// Одна и та же функция используется для превью и для экспорта,
/// поэтому результат экспорта совпадает с тем, что видно в редакторе.
struct CompositionBuilder {
    let media: MediaLibrary

    func makeComposition(for project: Project) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw CompositionError.cannotCreateTrack
        }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero

        for clip in project.clips {
            let asset = AVURLAsset(url: media.url(for: clip.mediaFileName))
            guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else {
                throw CompositionError.missingVideoTrack(clip.mediaFileName)
            }

            let sourceDuration = try await asset.load(.duration)
            let start = min(CMTime(ms: clip.trimStartMs), sourceDuration)
            let end = min(CMTime(ms: clip.trimEndMs), sourceDuration)
            let range = CMTimeRange(start: start, end: end)
            guard range.duration > .zero else { continue }

            try videoTrack.insertTimeRange(range, of: sourceVideo, at: cursor)

            if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack?.insertTimeRange(range, of: sourceAudio, at: cursor)
            }

            // Ориентация берётся из первого клипа. Разные ориентации у разных
            // клипов - задача этапа 2 (понадобится AVVideoComposition).
            if cursor == .zero {
                videoTrack.preferredTransform = try await sourceVideo.load(.preferredTransform)
            }

            cursor = cursor + range.duration
        }

        return composition
    }
}
