import Foundation

// MARK: - Project

struct Project: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

// MARK: - TimeEntry

/// A completed interval of work on a project.
struct TimeEntry: Identifiable, Codable {
    var id: UUID
    var projectId: UUID
    var startDate: Date
    var endDate: Date

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}

// MARK: - AppData (top-level persistence envelope)

struct AppData: Codable {
    var projects: [Project]
    var entries: [TimeEntry]

    init(projects: [Project] = [], entries: [TimeEntry] = []) {
        self.projects = projects
        self.entries = entries
    }
}
