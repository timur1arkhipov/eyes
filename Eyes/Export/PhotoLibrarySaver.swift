import Photos

enum PhotoLibraryError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        "Нет доступа к Фото. Разрешите добавление в Настройках."
    }
}

enum PhotoLibrarySaver {
    static func save(videoAt url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.accessDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
