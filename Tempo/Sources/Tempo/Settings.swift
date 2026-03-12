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

    @Published var showBreakTimeInInsights: Bool {
        didSet { UserDefaults.standard.set(showBreakTimeInInsights, forKey: Keys.showBreakTimeInInsights) }
    }

    @Published var autoStopBreakEnabled: Bool {
        didSet { UserDefaults.standard.set(autoStopBreakEnabled, forKey: Keys.autoStopBreakEnabled) }
    }

    @Published var autoStopBreakMinutes: Int {
        didSet { UserDefaults.standard.set(autoStopBreakMinutes, forKey: Keys.autoStopBreakMinutes) }
    }

    init() {
        let br = UserDefaults.standard.integer(forKey: Keys.breakReminder)
        breakReminderMinutes = br > 0 ? br : 50

        let rr = UserDefaults.standard.integer(forKey: Keys.resumeReminder)
        resumeReminderMinutes = rr > 0 ? rr : 10

        showBreakTimeInInsights = UserDefaults.standard.object(forKey: Keys.showBreakTimeInInsights) != nil
            ? UserDefaults.standard.bool(forKey: Keys.showBreakTimeInInsights)
            : true

        autoStopBreakEnabled = UserDefaults.standard.bool(forKey: Keys.autoStopBreakEnabled)

        let autoStopMinutes = UserDefaults.standard.integer(forKey: Keys.autoStopBreakMinutes)
        autoStopBreakMinutes = autoStopMinutes > 0 ? autoStopMinutes : 15
    }

    private enum Keys {
        static let breakReminder           = "tempo.breakReminderMinutes"
        static let resumeReminder          = "tempo.resumeReminderMinutes"
        static let showBreakTimeInInsights = "tempo.showBreakTimeInInsights"
        static let autoStopBreakEnabled    = "tempo.autoStopBreakEnabled"
        static let autoStopBreakMinutes    = "tempo.autoStopBreakMinutes"
    }
}
