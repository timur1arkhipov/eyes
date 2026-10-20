import Foundation

/// Один фрагмент видео на основной дорожке.
struct Clip: Codable, Identifiable, Hashable {
    var id: UUID
    /// Имя файла в MediaLibrary (папка Documents/Media).
    var mediaFileName: String
    /// Полная длительность исходного файла.
    var sourceDurationMs: Int64
    /// Начало используемого участка в исходнике.
    var trimStartMs: Int64
    /// Конец используемого участка в исходнике.
    var trimEndMs: Int64

    /// Минимальная длина клипа после обрезки.
    static let minimumDurationMs: Int64 = 100

    var trimmedDurationMs: Int64 {
        max(0, trimEndMs - trimStartMs)
    }

    /// Возвращает копию с обрезкой, приведённой к допустимым границам.
    func clampedTrim(startMs: Int64, endMs: Int64) -> Clip {
        var copy = self
        let minLength = Clip.minimumDurationMs
        copy.trimStartMs = max(0, min(startMs, sourceDurationMs - minLength))
        copy.trimEndMs = min(sourceDurationMs, max(endMs, copy.trimStartMs + minLength))
        return copy
    }
}
