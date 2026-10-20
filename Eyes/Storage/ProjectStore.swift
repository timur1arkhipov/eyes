import Foundation

/// Список проектов и их сохранение в JSON: Documents/Projects/<id>.json.
@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [Project] = []

    let media = MediaLibrary()

    private let directory: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("Projects", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    func project(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    func create(name: String) -> Project {
        let project = Project(name: name)
        save(project)
        return project
    }

    func save(_ project: Project) {
        var updated = project
        updated.updatedAt = .now
        do {
            let data = try encoder.encode(updated)
            try data.write(to: fileURL(for: updated.id), options: .atomic)
        } catch {
            print("ProjectStore: не удалось сохранить проект \(updated.id): \(error)")
        }
        if let index = projects.firstIndex(where: { $0.id == updated.id }) {
            projects[index] = updated
        } else {
            projects.append(updated)
        }
        sortProjects()
    }

    func delete(_ project: Project) {
        try? FileManager.default.removeItem(at: fileURL(for: project.id))
        projects.removeAll { $0.id == project.id }

        // Удаляем медиафайлы, которые больше никем не используются.
        let stillUsed = Set(projects.flatMap { $0.clips.map(\.mediaFileName) })
        for clip in project.clips where !stillUsed.contains(clip.mediaFileName) {
            media.remove(fileName: clip.mediaFileName)
        }
    }

    /// Имя для нового проекта: "Проект 3".
    func nextProjectName() -> String {
        "Проект \(projects.count + 1)"
    }

    private func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        projects = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Project.self, from: data)
            }
        sortProjects()
    }

    private func sortProjects() {
        projects.sort { $0.updatedAt > $1.updatedAt }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString + ".json")
    }
}
