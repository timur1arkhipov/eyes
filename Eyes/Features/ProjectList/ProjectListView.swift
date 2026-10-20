import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.projects.isEmpty {
                    ContentUnavailableView(
                        "Нет проектов",
                        systemImage: "film",
                        description: Text("Нажмите + чтобы создать первый проект")
                    )
                } else {
                    List {
                        ForEach(store.projects) { project in
                            NavigationLink(value: project.id) {
                                ProjectRow(project: project)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { store.projects[$0] }.forEach(store.delete)
                        }
                    }
                }
            }
            .navigationTitle("Проекты")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let project = store.create(name: store.nextProjectName())
                        path.append(project.id)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let project = store.project(id: id) {
                    EditorView(project: project, store: store)
                } else {
                    Text("Проект не найден")
                }
            }
        }
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.headline)
            HStack(spacing: 12) {
                Label(TimeFormatting.compact(project.durationMs), systemImage: "clock")
                Label("\(project.clips.count)", systemImage: "film.stack")
                Text(project.updatedAt, style: .date)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
