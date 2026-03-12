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
    var isBreak: Bool

    static let breakProjectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init(id: UUID = UUID(), name: String, color: ProjectColor = .blue,
         createdAt: Date = Date(), isBreak: Bool = false) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.isBreak = isBreak
    }

    // Custom decoder for backwards-compat — isBreak falls back to false when absent from stored JSON
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self, forKey: .id)
        name      = try c.decode(String.self, forKey: .name)
        color     = try c.decode(ProjectColor.self, forKey: .color)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isBreak   = (try? c.decode(Bool.self, forKey: .isBreak)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, color, createdAt, isBreak
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
    var activeProjectId: UUID?
    var sessionStart: Date?

    init(projects: [Project] = [], entries: [TimeEntry] = [],
         activeProjectId: UUID? = nil, sessionStart: Date? = nil) {
        self.projects = projects
        self.entries = entries
        self.activeProjectId = activeProjectId
        self.sessionStart = sessionStart
    }

    // Custom decoder so old JSON without activeProjectId/sessionStart decodes as nil
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projects        = try c.decode([Project].self, forKey: .projects)
        entries         = try c.decode([TimeEntry].self, forKey: .entries)
        activeProjectId = try? c.decode(UUID.self, forKey: .activeProjectId)
        sessionStart    = try? c.decode(Date.self, forKey: .sessionStart)
    }

    private enum CodingKeys: String, CodingKey {
        case projects, entries, activeProjectId, sessionStart
    }
}
