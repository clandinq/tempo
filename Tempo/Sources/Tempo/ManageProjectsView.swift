import SwiftUI

// MARK: - ManageProjectsView

struct ManageProjectsView: View {
    @EnvironmentObject var store: TimeStore

    @State private var newName: String = ""
    @State private var editingId: UUID? = nil
    @State private var editingName: String = ""
    @State private var confirmDeleteId: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Projects")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Text("\(store.projects.count) project\(store.projects.count == 1 ? "" : "s")")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Project list
            List {
                ForEach(store.projects) { project in
                    projectRow(project)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
            }
            .listStyle(.inset)

            Divider()

            // Add project row
            HStack(spacing: 8) {
                TextField("New project name...", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addProject() }

                Button("Add") { addProject() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 360, minHeight: 380)
        // Confirmation alert for delete
        .alert("Delete Project?", isPresented: Binding(
            get: { confirmDeleteId != nil },
            set: { if !$0 { confirmDeleteId = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let id = confirmDeleteId {
                    store.deleteProject(id: id)
                }
                confirmDeleteId = nil
            }
            Button("Cancel", role: .cancel) { confirmDeleteId = nil }
        } message: {
            if let id = confirmDeleteId,
               let project = store.projects.first(where: { $0.id == id }) {
                Text("Delete \"\(project.name)\"? All tracked time for this project will be permanently removed.")
            }
        }
    }

    // MARK: Row

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 10) {
            // Active indicator
            Circle()
                .fill(store.activeProjectId == project.id && store.isRunning
                      ? Color.green : Color.clear)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))

            if editingId == project.id {
                // Inline rename field
                TextField("Project name", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitRename(project.id) }
                Button("Save") { commitRename(project.id) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Cancel") {
                    editingId = nil
                    editingName = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text(project.name)
                    .font(.system(size: 14, design: .rounded))
                Spacer()

                // Today time badge
                let today = store.totalTime(for: project.id, in: store.todayRange())
                if today > 0 {
                    Text(Formatters.shortDuration(today))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
                }

                // Rename button
                Button {
                    editingId = project.id
                    editingName = project.name
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Rename project")

                // Delete button
                Button {
                    confirmDeleteId = project.id
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.borderless)
                .help("Delete project")
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: Actions

    private func addProject() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addProject(name: trimmed)
        newName = ""
    }

    private func commitRename(_ id: UUID) {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.renameProject(id: id, to: trimmed)
        }
        editingId = nil
        editingName = ""
    }
}
