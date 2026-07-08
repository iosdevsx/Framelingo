import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    var onOpenProject: (Project) -> Void = { _ in }
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                dropZone

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }

                recentProjects
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(32)
        }
        .navigationTitle("Home")
        .task {
            await viewModel.loadRecentProjects()
        }
    }

    private var dropZone: some View {
        VStack(spacing: 18) {
            Image(systemName: "film.stack")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            Text("Drop video here or choose a file")
                .font(.title2)
                .fontWeight(.medium)

            Text("Supported formats: MP4, MOV, M4V, WEBM, MKV")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                chooseVideo()
            } label: {
                Label("Choose Video", systemImage: "folder")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSavingProject)

            Button {
                chooseProjectFile()
            } label: {
                Label("Open Project File", systemImage: "doc")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isSavingProject)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(28)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        }
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: $isDropTargeted,
            perform: handleDrop(providers:)
        )
    }

    private var recentProjects: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Projects")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.recentProjects.isEmpty {
                Text("No recent projects yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(viewModel.recentProjects) { project in
                    recentProjectRow(project)
                }
            }
        }
    }

    private func recentProjectRow(_ project: Project) -> some View {
        Button {
            Task {
                await viewModel.selectProject(project)
                if let selectedProject = viewModel.selectedProject {
                    onOpenProject(selectedProject)
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "video")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.displayName)
                        .font(.headline)
                    Text("\(project.mediaFile.fileName) • \(project.mediaFile.readableSize)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(project.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func chooseVideo() {
        let panel = NSOpenPanel()
        panel.title = "Choose Video"
        panel.prompt = "Choose Video"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = supportedContentTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        openVideo(url)
    }

    private func chooseProjectFile() {
        let panel = NSOpenPanel()
        panel.title = "Open Project File"
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = projectContentTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            if let project = await viewModel.openProjectFile(url) {
                onOpenProject(project)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let url = fileURL(from: item) else {
                return
            }

            Task { @MainActor in
                openVideo(url)
            }
        }

        return true
    }

    private func openVideo(_ url: URL) {
        Task {
            if let project = await viewModel.createProject(from: url) {
                onOpenProject(project)
            }
        }
    }

    private var supportedContentTypes: [UTType] {
        ["mp4", "mov", "m4v", "webm", "mkv"].compactMap { UTType(filenameExtension: $0) }
    }

    private var projectContentTypes: [UTType] {
        [UTType(filenameExtension: "subtitleedit") ?? .json, .json]
    }

    private func fileURL(from item: Any?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data,
           let urlString = String(data: data, encoding: .utf8) {
            return URL(string: urlString)
        }

        if let string = item as? String {
            return URL(string: string)
        }

        return nil
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(viewModel: HomeViewModel(appState: AppState()))
    }
}
