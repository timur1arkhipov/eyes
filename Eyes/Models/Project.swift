import Foundation

/// Полное описание монтажа. Единственный источник правды для редактора,
/// превью и экспорта. Все времена - в миллисекундах.
struct Project: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var clips: [Clip]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        clips: [Clip] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.clips = clips
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Длительность всего таймлайна с учётом обрезки клипов.
    var durationMs: Int64 {
        clips.reduce(0) { $0 + $1.trimmedDurationMs }
    }

    /// Позиция начала клипа на таймлайне.
    func timelineStartMs(ofClipAt index: Int) -> Int64 {
        clips.prefix(index).reduce(0) { $0 + $1.trimmedDurationMs }
    }

    func index(ofClip id: UUID) -> Int? {
        clips.firstIndex { $0.id == id }
    }
}
