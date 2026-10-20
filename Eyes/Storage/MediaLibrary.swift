import AVFoundation
import Foundation

/// Хранилище импортированных видеофайлов: Documents/Media.
/// Файлы копируются внутрь приложения, чтобы проект не зависел от галереи.
final class MediaLibrary: Sendable {
    let directory: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// Переносит файл в библиотеку и возвращает его новое имя.
    func store(fileAt source: URL) throws -> String {
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let name = UUID().uuidString + "." + ext
        try FileManager.default.moveItem(at: source, to: url(for: name))
        return name
    }

    func remove(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    func durationMs(of fileName: String) async throws -> Int64 {
        let asset = AVURLAsset(url: url(for: fileName))
        return try await asset.load(.duration).ms
    }
}
