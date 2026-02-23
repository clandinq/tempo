import Foundation

// MARK: - ProjectColor

/// Fixed palette of named colors — stored as raw strings so JSON persists
/// across builds without depending on NSColor/SwiftUI.Color directly.
enum ProjectColor: String, CaseIterable, Codable {
    case blue   = "blue"
    case orange = "orange"
    case green  = "green"
    case pink   = "pink"
    case yellow = "yellow"
    case purple = "purple"
    case red    = "red"
    case teal   = "teal"

    var label: String { rawValue.capitalized }
}

// MARK: - Project

struct Project: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var color: ProjectColor
    var createdAt: Date

    init(id: UUID = UUID(), name: String, color: ProjectColor = .blue, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
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
