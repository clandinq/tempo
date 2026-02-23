import SwiftUI

// MARK: - ManageProjectsView

struct ManageProjectsView: View {
    @EnvironmentObject var store: TimeStore

    @State private var newName: String = ""
    @State private var newColor: ProjectColor = .blue
    @State private var editingId: UUID? = nil
    @State private var editingName: String = ""
    @State private var editingColor: ProjectColor = .blue
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
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("New project name...", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addProject() }

                    Button("Add") { addProject() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                colorPicker(selected: $newColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 380, minHeight: 420)
        .alert("Delete Project?", isPresented: Binding(
            get: { confirmDeleteId != nil },
            set: { if !$0 { confirmDeleteId = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let id = confirmDeleteId { store.deleteProject(id: id) }
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

    // MARK: Color picker (reused for both add and edit)

    @ViewBuilder
    private func colorPicker(selected: Binding<ProjectColor>) -> some View {
        HStack(spacing: 6) {
            ForEach(ProjectColor.allCases, id: \.self) { pc in
                Button {
                    selected.wrappedValue = pc
                } label: {
                    Circle()
                        .fill(pc.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(selected.wrappedValue == pc ? 0.8 : 0), lineWidth: 2)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
                .help(pc.label)
            }
            Spacer()
        }
    }

    // MARK: Row

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Active indicator uses project color
                Circle()
                    .fill(store.activeProjectId == project.id && store.isRunning
                          ? project.color.color : project.color.color.opacity(0.3))
                    .frame(width: 10, height: 10)

                if editingId == project.id {
                    TextField("Project name", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitEdit(project.id) }
                    Button("Save") { commitEdit(project.id) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Cancel") {
                        editingId = nil
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

                    Button {
                        editingId = project.id
                        editingName = project.name
                        editingColor = project.color
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Rename / recolor project")

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

            // Inline color picker shown only while editing this row
            if editingId == project.id {
                colorPicker(selected: $editingColor)
                    .padding(.bottom, 6)
            }
        }
    }

    // MARK: Actions

    private func addProject() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addProject(name: trimmed, color: newColor)
        newName = ""
        newColor = .blue
    }

    private func commitEdit(_ id: UUID) {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.renameProject(id: id, to: trimmed)
        }
        store.recolorProject(id: id, color: editingColor)
        editingId = nil
    }
}
