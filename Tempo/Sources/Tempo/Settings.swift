import Foundation
import Combine

// MARK: - AppSettings

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {

    // Minutes of continuous tracking before a break reminder fires (default 50).
    @Published var breakReminderMinutes: Int {
        didSet { UserDefaults.standard.set(breakReminderMinutes, forKey: Keys.breakReminder) }
    }

    // Minutes of being stopped before a "get back to work" reminder fires (default 10).
    @Published var resumeReminderMinutes: Int {
        didSet { UserDefaults.standard.set(resumeReminderMinutes, forKey: Keys.resumeReminder) }
    }

    init() {
        let br = UserDefaults.standard.integer(forKey: Keys.breakReminder)
        breakReminderMinutes = br > 0 ? br : 50

        let rr = UserDefaults.standard.integer(forKey: Keys.resumeReminder)
        resumeReminderMinutes = rr > 0 ? rr : 10
    }

    private enum Keys {
        static let breakReminder  = "tempo.breakReminderMinutes"
        static let resumeReminder = "tempo.resumeReminderMinutes"
    }
}
