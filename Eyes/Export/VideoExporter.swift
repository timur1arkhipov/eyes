import AVFoundation
import Foundation

enum ExportError: LocalizedError {
    case cannotCreateSession
    case cancelled
    case emptyProject

    var errorDescription: String? {
        switch self {
        case .cannotCreateSession: return "Не удалось запустить экспорт."
        case .cancelled: return "Экспорт отменён."
        case .emptyProject: return "В проекте нет клипов."
        }
    }
}

/// Экспорт проекта через AVAssetExportSession и сохранение в Фото.
@MainActor
final class VideoExporter: ObservableObject {
    enum State {
        case idle
        case exporting(progress: Double)
        case saving
        case done
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private var session: AVAssetExportSession?

    func export(project: Project, media: MediaLibrary) async {
        guard !project.clips.isEmpty else {
            state = .failed(ExportError.emptyProject.localizedDescription)
            return
        }
        state = .exporting(progress: 0)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        do {
            let composition = try await CompositionBuilder(media: media).makeComposition(for: project)

            guard let session = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw ExportError.cannotCreateSession
            }
            session.outputURL = outputURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true
            self.session = session

            let progressTask = Task { [weak self] in
                while !Task.isCancelled {
                    self?.state = .exporting(progress: Double(session.progress))
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }

            await session.export()
            progressTask.cancel()

            if let error = session.error { throw error }
            guard session.status == .completed else { throw ExportError.cancelled }

            state = .saving
            try await PhotoLibrarySaver.save(videoAt: outputURL)
            state = .done
        } catch {
            state = .failed(error.localizedDescription)
        }

        try? FileManager.default.removeItem(at: outputURL)
        session = nil
    }

    func cancel() {
        session?.cancelExport()
    }
}
