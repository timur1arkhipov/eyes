import PhotosUI
import SwiftUI

struct EditorView: View {
    @StateObject private var viewModel: EditorViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showExport = false

    init(project: Project, store: ProjectStore) {
        _viewModel = StateObject(wrappedValue: EditorViewModel(project: project, store: store))
    }

    var body: some View {
        VStack(spacing: 12) {
            PlayerView(player: viewModel.player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .overlay {
                    if viewModel.project.clips.isEmpty {
                        ContentUnavailableView(
                            "Пустой проект",
                            systemImage: "film",
                            description: Text("Добавьте видео кнопкой + внизу")
                        )
                    }
                }
                .onTapGesture { viewModel.togglePlay() }

            playbackControls

            Group {
                if let clip = viewModel.selectedClip {
                    TrimRangeSlider(
                        totalMs: clip.sourceDurationMs,
                        thumbnails: viewModel.thumbnails,
                        startMs: trimStartBinding,
                        endMs: trimEndBinding,
                        onDrag: { viewModel.previewSourceFrame(atMs: $0) },
                        onCommit: { viewModel.commitTrim() }
                    )
                    clipActions
                } else {
                    Color.clear.frame(height: 56)
                }
            }
            .padding(.horizontal)

            ClipStrip(
                clips: viewModel.project.clips,
                selectedClipID: viewModel.selectedClipID,
                isImporting: viewModel.isImporting,
                pickerItem: $pickerItem,
                onSelect: { viewModel.selectClip($0) }
            )
            .padding(.bottom, 8)
        }
        .navigationTitle(viewModel.project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Экспорт") {
                    viewModel.pause()
                    showExport = true
                }
                .disabled(viewModel.project.clips.isEmpty)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            viewModel.importVideo(from: newItem)
            pickerItem = nil
        }
        .sheet(isPresented: $showExport) {
            ExportView(project: viewModel.project, media: viewModel.media)
        }
        .alert("Ошибка", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDisappear { viewModel.pause() }
    }

    private var playbackControls: some View {
        VStack(spacing: 4) {
            HStack {
                Text(TimeFormatting.short(viewModel.currentTimeMs))
                    .monospacedDigit()
                Spacer()
                Button {
                    viewModel.togglePlay()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .disabled(viewModel.project.clips.isEmpty)
                Spacer()
                Text(TimeFormatting.short(viewModel.project.durationMs))
                    .monospacedDigit()
            }
            .font(.footnote)
            .padding(.horizontal)

            Slider(
                value: Binding(
                    get: { Double(viewModel.currentTimeMs) },
                    set: { viewModel.seek(toMs: Int64($0)) }
                ),
                in: 0...Double(max(1, viewModel.project.durationMs))
            )
            .padding(.horizontal)
            .disabled(viewModel.project.clips.isEmpty)
        }
    }

    private var clipActions: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.moveSelectedClip(by: -1)
            } label: {
                Label("Левее", systemImage: "arrow.left")
            }
            .disabled(viewModel.selectedClipIndex == 0)

            Button {
                viewModel.moveSelectedClip(by: 1)
            } label: {
                Label("Правее", systemImage: "arrow.right")
            }
            .disabled(viewModel.selectedClipIndex == viewModel.project.clips.count - 1)

            Spacer()

            Button(role: .destructive) {
                viewModel.deleteSelectedClip()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .font(.footnote)
        .labelStyle(.titleAndIcon)
    }

    private var trimStartBinding: Binding<Int64> {
        Binding(
            get: { viewModel.selectedClip?.trimStartMs ?? 0 },
            set: { viewModel.updateTrim(startMs: $0, endMs: viewModel.selectedClip?.trimEndMs ?? 0) }
        )
    }

    private var trimEndBinding: Binding<Int64> {
        Binding(
            get: { viewModel.selectedClip?.trimEndMs ?? 0 },
            set: { viewModel.updateTrim(startMs: viewModel.selectedClip?.trimStartMs ?? 0, endMs: $0) }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
