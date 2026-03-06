import SwiftUI

// MARK: - HistoryView

struct HistoryView: View {
    @EnvironmentObject var store: TimeStore

    @State private var editingEntry: TimeEntry? = nil
    @State private var confirmDeleteId: UUID? = nil

    // MARK: Derived data

    private var groupedEntries: [(label: String, total: TimeInterval, entries: [TimeEntry])] {
        let cal = Calendar.current
        let sorted = store.entries.sorted { $0.startDate > $1.startDate }
        let groups = Dictionary(grouping: sorted) { cal.startOfDay(for: $0.startDate) }
        return groups.keys.sorted(by: >).map { day in
            let dayEntries = groups[day]!.sorted { $0.startDate > $1.startDate }
            let total = dayEntries.reduce(0.0) { $0 + $1.duration }
            return (label: dayLabel(for: day), total: total, entries: dayEntries)
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.entries.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groupedEntries, id: \.label) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                entryRow(entry)
                                    .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                            }
                        } header: {
                            HStack {
                                Text(group.label)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .textCase(nil)
                                Spacer()
                                Text(Formatters.shortDuration(group.total))
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(entry: entry).environmentObject(store)
        }
        .alert("Delete Entry?", isPresented: Binding(
            get: { confirmDeleteId != nil },
            set: { if !$0 { confirmDeleteId = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let id = confirmDeleteId { store.deleteEntry(id: id) }
                confirmDeleteId = nil
            }
            Button("Cancel", role: .cancel) { confirmDeleteId = nil }
        } message: {
            Text("This tracked entry will be permanently removed.")
        }
    }

    // MARK: Sub-views

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("History")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("\(store.entries.count) entr\(store.entries.count == 1 ? "y" : "ies")")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No entries yet")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Start tracking a project from the menu bar.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func entryRow(_ entry: TimeEntry) -> some View {
        let project = store.projects.first(where: { $0.id == entry.projectId })

        HStack(spacing: 10) {
            // Project color + name
            Circle()
                .fill(project?.color.color ?? Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)

            Text(project?.name ?? "Deleted project")
                .font(.system(size: 13, design: .rounded))
                .lineLimit(1)
                .frame(minWidth: 100, maxWidth: 160, alignment: .leading)

            Spacer()

            // Start → End
            Text(entry.startDate, format: .dateTime.hour().minute())
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("→")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Text(entry.endDate, format: .dateTime.hour().minute())
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)

            // Duration
            Text(Formatters.shortDuration(entry.duration))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(width: 68, alignment: .trailing)

            // Action buttons
            HStack(spacing: 2) {
                Button {
                    editingEntry = entry
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help("Edit entry")

                Button {
                    confirmDeleteId = entry.id
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.65))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help("Delete entry")
            }
        }
        .padding(.vertical, 5)
    }

    // MARK: Helpers

    private func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }
}

// MARK: - EditEntrySheet

struct EditEntrySheet: View {
    @EnvironmentObject var store: TimeStore
    @Environment(\.dismiss) private var dismiss

    let entry: TimeEntry

    // End date is the primary editable state; duration is kept in sync.
    @State private var endDate: Date
    @State private var durationMinutes: Int
    // Separate text state so typing "120" doesn't flicker through intermediate values.
    @State private var durationText: String

    init(entry: TimeEntry) {
        self.entry = entry
        let mins = max(1, Int(entry.duration / 60))
        _endDate         = State(initialValue: entry.endDate)
        _durationMinutes = State(initialValue: mins)
        _durationText    = State(initialValue: "\(mins)")
    }

    // MARK: Linked bindings

    /// Changing the end date via DatePicker → recalculate and sync duration fields.
    private var endDateBinding: Binding<Date> {
        Binding(
            get: { endDate },
            set: { newDate in
                endDate = newDate
                let mins = max(1, Int(newDate.timeIntervalSince(entry.startDate) / 60))
                durationMinutes = mins
                durationText = "\(mins)"
            }
        )
    }

    /// Changing duration via Stepper → recalculate and sync end date.
    private var durationStepperBinding: Binding<Int> {
        Binding(
            get: { durationMinutes },
            set: { mins in
                let clamped = max(1, min(mins, 1440))
                durationMinutes = clamped
                durationText = "\(clamped)"
                endDate = entry.startDate.addingTimeInterval(TimeInterval(clamped * 60))
            }
        )
    }

    private var project: Project? {
        store.projects.first(where: { $0.id == entry.projectId })
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Entry")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            VStack(spacing: 0) {
                // Project (read-only)
                formRow("Project") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(project?.color.color ?? Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(project?.name ?? "Deleted project")
                            .font(.system(size: 13, design: .rounded))
                    }
                }

                Divider().padding(.leading, 116)

                // Start time (read-only)
                formRow("Start time") {
                    Text(entry.startDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Divider().padding(.leading, 116)

                // End time — editable via DatePicker
                formRow("End time") {
                    DatePicker("",
                               selection: endDateBinding,
                               in: entry.startDate...,
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                Divider().padding(.leading, 116)

                // Duration — editable via text field + stepper, synced with end time
                formRow("Duration") {
                    HStack(spacing: 6) {
                        TextField("", text: $durationText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                            .multilineTextAlignment(.trailing)
                            .onSubmit { commitDurationText() }
                        Stepper("", value: durationStepperBinding, in: 1...1440)
                            .labelsHidden()
                        Text("min")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Save") {
                    store.updateEntry(id: entry.id, endDate: endDate)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(endDate <= entry.startDate)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 420)
    }

    // MARK: Helpers

    @ViewBuilder
    private func formRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .trailing)
            content()
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    /// Called when the user presses Return in the duration text field.
    /// Parses the typed value and updates both endDate and the display.
    private func commitDurationText() {
        if let mins = Int(durationText), mins >= 1, mins <= 1440 {
            durationMinutes = mins
            endDate = entry.startDate.addingTimeInterval(TimeInterval(mins * 60))
        }
        // Always reset text to the current (possibly clamped) value
        durationText = "\(durationMinutes)"
    }
}
