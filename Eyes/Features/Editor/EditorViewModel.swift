import AVFoundation
import Combine
import PhotosUI
import SwiftUI

enum EditorError: LocalizedError {
    case importFailed

    var errorDescription: String? {
        "Не удалось импортировать видео."
    }
}

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var project: Project
    @Published private(set) var selectedClipID: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTimeMs: Int64 = 0
    @Published private(set) var thumbnails: [UIImage] = []
    @Published private(set) var isImporting = false
    @Published var errorMessage: String?

    let player = AVPlayer()

    var media: MediaLibrary { store.media }

    private let store: ProjectStore
    /// Снимок проекта, из которого собран текущий player item.
    /// Нужен, чтобы при перетаскивании ручек обрезки правильно искать кадр.
    private var renderedProject: Project
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var rebuildTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?

    init(project: Project, store: ProjectStore) {
        self.project = project
        self.store = store
        self.renderedProject = project
        self.selectedClipID = project.clips.first?.id

        player.actionAtItemEnd = .pause
        observePlayer()
        rebuildPlayer()
        loadThumbnails()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    // MARK: - Клипы

    var selectedClip: Clip? {
        guard let selectedClipID else { return nil }
        return project.clips.first { $0.id == selectedClipID }
    }

    var selectedClipIndex: Int? {
        guard let selectedClipID else { return nil }
        return project.index(ofClip: selectedClipID)
    }

    func selectClip(_ id: UUID) {
        guard selectedClipID != id else { return }
        selectedClipID = id
        loadThumbnails()
        if let index = project.index(ofClip: id) {
            seek(toMs: project.timelineStartMs(ofClipAt: index))
        }
    }

    func importVideo(from item: PhotosPickerItem) {
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                guard let file = try await item.loadTransferable(type: VideoTransferable.self) else {
                    throw EditorError.importFailed
                }
                let fileName = try media.store(fileAt: file.url)
                let duration = try await media.durationMs(of: fileName)
                let clip = Clip(
                    id: UUID(),
                    mediaFileName: fileName,
                    sourceDurationMs: duration,
                    trimStartMs: 0,
                    trimEndMs: duration
                )
                project.clips.append(clip)
                selectedClipID = clip.id
                save()
                rebuildPlayer(seekToMs: project.timelineStartMs(ofClipAt: project.clips.count - 1))
                loadThumbnails()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteSelectedClip() {
        guard let index = selectedClipIndex else { return }
        let removed = project.clips.remove(at: index)
        if !project.clips.contains(where: { $0.mediaFileName == removed.mediaFileName }) {
            media.remove(fileName: removed.mediaFileName)
        }
        selectedClipID = project.clips.indices.contains(index)
            ? project.clips[index].id
            : project.clips.last?.id
        save()
        rebuildPlayer(seekToMs: 0)
        loadThumbnails()
    }

    func moveSelectedClip(by offset: Int) {
        guard let index = selectedClipIndex else { return }
        let target = index + offset
        guard project.clips.indices.contains(target) else { return }
        project.clips.swapAt(index, target)
        save()
        rebuildPlayer(seekToMs: project.timelineStartMs(ofClipAt: target))
    }

    // MARK: - Обрезка

    /// Вызывается во время перетаскивания ручки. Меняет модель, но не пересобирает плеер.
    func updateTrim(startMs: Int64, endMs: Int64) {
        guard let index = selectedClipIndex else { return }
        project.clips[index] = project.clips[index].clampedTrim(startMs: startMs, endMs: endMs)
    }

    /// Показать в плеере кадр исходника под пальцем.
    /// Плеер играет старую композицию, поэтому пересчитываем время относительно неё.
    func previewSourceFrame(atMs sourceMs: Int64) {
        guard
            let id = selectedClipID,
            let renderedIndex = renderedProject.index(ofClip: id)
        else { return }
        let rendered = renderedProject.clips[renderedIndex]
        let clampedSource = min(max(sourceMs, rendered.trimStartMs), rendered.trimEndMs - 1)
        let timelineMs = renderedProject.timelineStartMs(ofClipAt: renderedIndex) + (clampedSource - rendered.trimStartMs)
        pause()
        player.seek(to: CMTime(ms: timelineMs), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Вызывается, когда ручку отпустили.
    func commitTrim() {
        save()
        let start = selectedClipIndex.map { project.timelineStartMs(ofClipAt: $0) }
        rebuildPlayer(seekToMs: start)
    }

    // MARK: - Воспроизведение

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            if currentTimeMs >= project.durationMs - 50 {
                seek(toMs: 0)
            }
            player.play()
        }
    }

    func pause() {
        player.pause()
    }

    func seek(toMs ms: Int64) {
        currentTimeMs = ms
        player.seek(to: CMTime(ms: ms), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Внутреннее

    private func save() {
        store.save(project)
    }

    private func observePlayer() {
        player.publisher(for: \.timeControlStatus)
            .map { $0 == .playing }
            .receive(on: RunLoop.main)
            .assign(to: &$isPlaying)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(ms: 33),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTimeMs = time.ms
            }
        }
    }

    private func rebuildPlayer(seekToMs: Int64? = nil) {
        rebuildTask?.cancel()
        let snapshot = project

        guard !snapshot.clips.isEmpty else {
            player.replaceCurrentItem(with: nil)
            renderedProject = snapshot
            currentTimeMs = 0
            return
        }

        rebuildTask = Task {
            do {
                let composition = try await CompositionBuilder(media: media).makeComposition(for: snapshot)
                guard !Task.isCancelled else { return }
                player.replaceCurrentItem(with: AVPlayerItem(asset: composition))
                renderedProject = snapshot
                if let seekToMs {
                    seek(toMs: seekToMs)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadThumbnails() {
        thumbnailTask?.cancel()
        thumbnails = []
        guard let clip = selectedClip else { return }

        let url = media.url(for: clip.mediaFileName)
        let durationMs = clip.sourceDurationMs
        let count = 10

        thumbnailTask = Task {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 160, height: 160)
            generator.requestedTimeToleranceBefore = CMTime(ms: 300)
            generator.requestedTimeToleranceAfter = CMTime(ms: 300)

            var images: [UIImage] = []
            for i in 0..<count {
                if Task.isCancelled { return }
                let ms = durationMs * Int64(i) / Int64(count) + durationMs / Int64(count * 2)
                if let result = try? await generator.image(at: CMTime(ms: ms)) {
                    images.append(UIImage(cgImage: result.image))
                }
            }
            if !Task.isCancelled {
                thumbnails = images
            }
        }
    }
}
