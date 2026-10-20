import SwiftUI

struct ExportView: View {
    let project: Project
    let media: MediaLibrary

    @StateObject private var exporter = VideoExporter()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch exporter.state {
                case .idle:
                    ProgressView()

                case .exporting(let progress):
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("\(Int(progress * 100))%")
                        .font(.title2)
                        .monospacedDigit()
                    Text("Экспорт видео")
                        .foregroundStyle(.secondary)
                    Button("Отмена", role: .cancel) {
                        exporter.cancel()
                    }

                case .saving:
                    ProgressView()
                    Text("Сохранение в Фото")
                        .foregroundStyle(.secondary)

                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Видео сохранено в Фото")
                    Button("Готово") { dismiss() }
                        .buttonStyle(.borderedProminent)

                case .failed(let message):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.orange)
                    Text(message)
                        .multilineTextAlignment(.center)
                    Button("Повторить") {
                        Task { await exporter.export(project: project, media: media) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Экспорт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        exporter.cancel()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .task {
            await exporter.export(project: project, media: media)
        }
    }
}
