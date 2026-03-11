import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: TimeStore
    @State private var confirmDeleteId: UUID? = nil

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
                                InlineEditableEntryRow(entry: entry) {
                                    confirmDeleteId = entry.id
                                }
                                .environmentObject(store)
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

    private func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }
}

struct InlineEditableEntryRow: View {
    @EnvironmentObject var store: TimeStore
    let entry: TimeEntry
    let onDelete: () -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var durationMinutes: Int
    @State private var durationText: String
    @State private var showStart = false
    @State private var showEnd   = false
    @State private var showDur   = false
    @State private var hoverStart = false
    @State private var hoverEnd   = false
    @State private var hoverDur   = false

    init(entry: TimeEntry, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onDelete = onDelete
        let mins = max(1, Int(entry.duration / 60))
        _startDate       = State(initialValue: entry.startDate)
        _endDate         = State(initialValue: entry.endDate)
        _durationMinutes = State(initialValue: mins)
        _durationText    = State(initialValue: "\(mins)")
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { startDate },
            set: { newStart in
                startDate = newStart
                let mins = max(1, Int(endDate.timeIntervalSince(newStart) / 60))
                durationMinutes = mins
                durationText = "\(mins)"
            }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { endDate },
            set: { newDate in
                endDate = newDate
                let mins = max(1, Int(newDate.timeIntervalSince(startDate) / 60))
                durationMinutes = mins
                durationText = "\(mins)"
            }
        )
    }

    private var durationStepperBinding: Binding<Int> {
        Binding(
            get: { durationMinutes },
            set: { mins in
                let clamped = max(1, min(mins, 1440))
                durationMinutes = clamped
                durationText = "\(clamped)"
                endDate = startDate.addingTimeInterval(TimeInterval(clamped * 60))
            }
        )
    }

    private var project: Project? {
        store.projects.first(where: { $0.id == entry.projectId })
    }

    private func save() {
        guard endDate > startDate else { return }
        store.updateEntry(id: entry.id, startDate: startDate, endDate: endDate)
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(project?.color.color ?? Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)

            Text(project?.name ?? "Deleted project")
                .font(.system(size: 13, design: .rounded))
                .lineLimit(1)
                .frame(minWidth: 100, maxWidth: 160, alignment: .leading)

            Spacer()

            Button { showStart.toggle() } label: {
                Text(startDate, format: .dateTime.hour().minute())
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(hoverStart ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(hoverStart ? Color.accentColor.opacity(0.08) : Color.clear))
            }
            .buttonStyle(.plain)
            .onHover { hoverStart = $0 }
            .popover(isPresented: $showStart) {
                VStack(spacing: 12) {
                    DatePicker("", selection: startDateBinding, in: ...endDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Button("Done") { showStart = false }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(16)
                .onDisappear { save() }
            }

            Text("->")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Button { showEnd.toggle() } label: {
                Text(endDate, format: .dateTime.hour().minute())
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(hoverEnd ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(hoverEnd ? Color.accentColor.opacity(0.08) : Color.clear))
            }
            .buttonStyle(.plain)
            .onHover { hoverEnd = $0 }
            .popover(isPresented: $showEnd) {
                VStack(spacing: 12) {
                    DatePicker("", selection: endDateBinding, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Button("Done") { showEnd = false }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(16)
                .onDisappear { save() }
            }

            Button { showDur.toggle() } label: {
                Text(Formatters.shortDuration(entry.duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(hoverDur ? Color.accentColor : Color.primary)
                    .frame(width: 60, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(hoverDur ? Color.accentColor.opacity(0.08) : Color.clear))
            }
            .buttonStyle(.plain)
            .onHover { hoverDur = $0 }
            .popover(isPresented: $showDur) {
                VStack(spacing: 12) {
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
                    Button("Done") { showDur = false }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(16)
                .onDisappear { save() }
            }

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.65))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("Delete entry")
        }
        .padding(.vertical, 5)
        .onChange(of: entry.startDate) { newDate in
            startDate = newDate
            let mins = max(1, Int(endDate.timeIntervalSince(newDate) / 60))
            durationMinutes = mins; durationText = "\(mins)"
        }
        .onChange(of: entry.endDate) { newDate in
            endDate = newDate
            let mins = max(1, Int(newDate.timeIntervalSince(startDate) / 60))
            durationMinutes = mins; durationText = "\(mins)"
        }
    }

    private func commitDurationText() {
        if let mins = Int(durationText), mins >= 1, mins <= 1440 {
            durationMinutes = mins
            endDate = startDate.addingTimeInterval(TimeInterval(mins * 60))
        }
        durationText = "\(durationMinutes)"
    }
}
