import Foundation
import Combine

// MARK: - TimeStore

/// Single source of truth for all app state. Handles persistence and timer ticks.
final class TimeStore: ObservableObject {

    // MARK: Published state

    @Published private(set) var projects: [Project] = []
    @Published private(set) var activeProjectId: UUID? = nil
    @Published private(set) var sessionStart: Date? = nil     // when the current run started
    @Published private(set) var entries: [TimeEntry] = []

    // Fires every second so the menu bar elapsed label stays fresh
    private var tickTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Persistence

    private let dataURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Tempo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    // MARK: Init

    init() {
        load()
        startTickTimer()
    }

    // MARK: Timer management

    private func startTickTimer() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            // Publish a change so observers re-read currentElapsed
            self?.objectWillChange.send()
        }
    }

    /// Elapsed seconds for the currently running session (0 if stopped).
    var currentSessionElapsed: TimeInterval {
        guard let start = sessionStart else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: Project CRUD

    func addProject(name: String) {
        let project = Project(name: name)
        projects.append(project)
        save()
    }

    func renameProject(id: UUID, to name: String) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].name = name
        save()
    }

    func deleteProject(id: UUID) {
        // Stop tracking if this project is active
        if activeProjectId == id { stop() }
        projects.removeAll { $0.id == id }
        entries.removeAll { $0.projectId == id }
        save()
    }

    // MARK: Timer control

    /// Start (or switch to) tracking a project.
    func startTracking(projectId: UUID) {
        guard projects.contains(where: { $0.id == projectId }) else { return }

        // Flush any in-flight session for the previous project
        flushCurrentSession()

        activeProjectId = projectId
        sessionStart = Date()
        save()
    }

    /// Pause tracking without clearing the active project.
    func stop() {
        flushCurrentSession()
        sessionStart = nil
        save()
    }

    /// True when the timer is actively counting.
    var isRunning: Bool { sessionStart != nil }

    // MARK: Queries

    /// Total tracked seconds for a project within a date range (including live session).
    func totalTime(for projectId: UUID, in range: DateInterval) -> TimeInterval {
        let stored = entries
            .filter { $0.projectId == projectId }
            .filter { range.contains($0.startDate) || range.contains($0.endDate) }
            .reduce(0) { $0 + clamp($1, to: range) }

        // Add live session if this project is currently running
        let live: TimeInterval
        if activeProjectId == projectId, let start = sessionStart {
            let sessionInterval = DateInterval(start: start, end: Date())
            // Intersect session with requested range
            if let overlap = range.intersection(with: sessionInterval) {
                live = overlap.duration
            } else {
                live = 0
            }
        } else {
            live = 0
        }
        return stored + live
    }

    /// Clamp an entry's duration to a given DateInterval (for period-aware queries).
    private func clamp(_ entry: TimeEntry, to range: DateInterval) -> TimeInterval {
        let start = max(entry.startDate, range.start)
        let end   = min(entry.endDate, range.end)
        return max(0, end.timeIntervalSince(start))
    }

    // MARK: Today summary (used by menu)

    func todayRange() -> DateInterval {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    func weekRange() -> DateInterval {
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
        return DateInterval(start: weekStart, end: weekEnd)
    }

    func monthRange() -> DateInterval {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let monthStart = cal.date(from: comps)!
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!
        return DateInterval(start: monthStart, end: monthEnd)
    }

    // MARK: Private helpers

    /// Commits the current session as a TimeEntry and resets sessionStart.
    private func flushCurrentSession() {
        guard let projectId = activeProjectId, let start = sessionStart else { return }
        let end = Date()
        guard end.timeIntervalSince(start) > 0 else { return }
        let entry = TimeEntry(id: UUID(), projectId: projectId, startDate: start, endDate: end)
        entries.append(entry)
        activeProjectId = nil
        sessionStart = nil
    }

    // MARK: Persistence

    private func save() {
        let data = AppData(projects: projects, entries: entries)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: dataURL, options: .atomic)
        } catch {
            print("Tempo: save failed: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            seedDefaultProject()
            return
        }
        do {
            let raw = try Data(contentsOf: dataURL)
            let data = try JSONDecoder().decode(AppData.self, from: raw)
            self.projects = data.projects
            self.entries = data.entries
        } catch {
            print("Tempo: load failed: \(error)")
            seedDefaultProject()
        }
    }

    private func seedDefaultProject() {
        let demo = Project(name: "My First Project")
        projects = [demo]
        entries = []
        save()
    }
}
