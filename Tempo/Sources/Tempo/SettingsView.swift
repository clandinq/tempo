import SwiftUI
import UserNotifications
import AppKit

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @EnvironmentObject var store: TimeStore

    @State private var showAddForm: Bool = false
    @State private var newName: String = ""
    @State private var newColor: ProjectColor = .blue
    @State private var editingId: UUID? = nil
    @State private var editingName: String = ""
    @State private var editingColor: ProjectColor = .blue
    @State private var confirmDeleteId: UUID? = nil
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var testSent = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()
            remindersSection
            Divider()
            notificationsSection
            Divider()
            projectsSection
            Divider()

            // Footer
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Changes take effect on the next tracking session.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 380, maxWidth: .infinity)
        .task { checkStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkStatus()
        }
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

    // MARK: - Sections

    private var remindersSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reminders")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            reminderRow(
                icon: "cup.and.saucer",
                title: "Break reminder",
                detail: "Notify after this many minutes of continuous tracking",
                value: $settings.breakReminderMinutes,
                range: 1...240
            )

            Divider().padding(.leading, 56)

            reminderRow(
                icon: "arrow.clockwise",
                title: "Resume reminder",
                detail: "Notify after this many minutes of being stopped",
                value: $settings.resumeReminderMinutes,
                range: 1...120
            )

            Divider().padding(.leading, 56)

            Toggle(isOn: $settings.showBreakTimeInInsights) {
                Label("Show break time in Insights", systemImage: "cup.and.saucer.fill")
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            Divider().padding(.leading, 56)

            Toggle(isOn: $settings.autoStopBreakEnabled) {
                Label("Auto-stop breaks", systemImage: "timer")
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            if settings.autoStopBreakEnabled {
                Divider().padding(.leading, 56)

                reminderRow(
                    icon: "timer",
                    title: "Auto-stop after",
                    detail: "Automatically stop break tracking after this many minutes",
                    value: $settings.autoStopBreakMinutes,
                    range: 1...120
                )
            }
        }
    }

    private var notificationsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notifications")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            HStack(spacing: 16) {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                    notifStatusLabel
                }

                Spacer()
                notifActionButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }

    private var projectsSection: some View {
        let visibleProjects = store.projects.filter { !$0.isBreak }

        return VStack(spacing: 0) {
            // Section header with [+] button
            HStack {
                Text("Projects")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showAddForm.toggle()
                        if !showAddForm { newName = ""; newColor = .blue }
                    }
                } label: {
                    Image(systemName: showAddForm ? "minus" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help(showAddForm ? "Cancel" : "Add project")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            // Project list
            if !visibleProjects.isEmpty {
                List {
                    ForEach(visibleProjects) { project in
                        projectRow(project)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 44, maxHeight: min(CGFloat(visibleProjects.count) * 52 + 16, 260))
            }

            // Inline add form (shown when [+] is tapped)
            if showAddForm {
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Notification status helpers

    @ViewBuilder
    private var notifStatusLabel: some View {
        switch notifStatus {
        case .authorized:
            Text("Enabled")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.green)
        case .denied:
            Text("Denied")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.red)
        default:
            Text("Not set up")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var notifActionButton: some View {
        switch notifStatus {
        case .authorized:
            if testSent {
                Text("Sent ✓")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.green)
            } else {
                Button("Test") { sendTest() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        case .denied:
            Button("Open Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        default:
            Button("Open Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Color picker

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

    // MARK: - Project row

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(project.color.color)
                    .frame(width: 10, height: 10)

                if editingId == project.id {
                    TextField("Project name", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitEdit(project.id) }
                    Button("Save") { commitEdit(project.id) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Cancel") { editingId = nil }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    Text(project.name)
                        .font(.system(size: 14, design: .rounded))
                    Spacer()
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

            if editingId == project.id {
                colorPicker(selected: $editingColor)
                    .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Actions

    private func addProject() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addProject(name: trimmed, color: newColor)
        newName = ""
        newColor = .blue
        withAnimation(.easeInOut(duration: 0.15)) { showAddForm = false }
    }

    private func commitEdit(_ id: UUID) {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { store.renameProject(id: id, to: trimmed) }
        store.recolorProject(id: id, color: editingColor)
        editingId = nil
    }

    // MARK: - Reminder row

    @ViewBuilder
    private func reminderRow(
        icon: String,
        title: String,
        detail: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                Text(detail)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("", value: value, formatter: minuteFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 52)
                    .multilineTextAlignment(.trailing)
                Stepper("", value: value, in: range)
                    .labelsHidden()
                Text("min")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var minuteFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.minimum = 1
        f.maximum = 240
        return f
    }

    // MARK: - Notification helpers

    private func checkStatus() {
        NotificationManager.shared.checkAuthorizationStatus { status in
            self.notifStatus = status
        }
    }

    private func sendTest() {
        NotificationManager.shared.scheduleTest()
        testSent = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            self.testSent = false
        }
    }
}
