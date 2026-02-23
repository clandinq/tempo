import Foundation
import SwiftUI
import AppKit

// MARK: - Duration formatting helpers

enum Formatters {

    /// "2h 34m" or "34m" — no seconds shown.
    static func shortDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60

        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        } else {
            return String(format: "%dm", m)
        }
    }

    /// "H:MM" for the active timer in the menu bar — no seconds.
    static func elapsedClock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return String(format: "%d:%02d", h, m)
        } else {
            return String(format: "%dm", m)
        }
    }
}

// MARK: - ProjectColor → SwiftUI.Color / NSColor

extension ProjectColor {
    var color: Color {
        switch self {
        case .blue:   return Color(red: 0.35, green: 0.60, blue: 0.95)
        case .orange: return Color(red: 0.95, green: 0.55, blue: 0.30)
        case .green:  return Color(red: 0.35, green: 0.75, blue: 0.50)
        case .pink:   return Color(red: 0.90, green: 0.40, blue: 0.70)
        case .yellow: return Color(red: 0.90, green: 0.78, blue: 0.20)
        case .purple: return Color(red: 0.65, green: 0.40, blue: 0.90)
        case .red:    return Color(red: 0.92, green: 0.30, blue: 0.30)
        case .teal:   return Color(red: 0.25, green: 0.75, blue: 0.80)
        }
    }

    /// NSColor wrapper for use in AppKit menu items.
    var nsColor: NSColor { NSColor(color) }
}
