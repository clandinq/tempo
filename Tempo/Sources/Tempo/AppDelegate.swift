import AppKit

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let store = TimeStore()
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure no Dock icon appears at runtime (belt-and-suspenders with Info.plist)
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController(store: store)
        // Request notification permission after app is fully initialized so
        // the permission dialog can be shown to the user.
        NotificationManager.shared.requestPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush any in-progress session to disk so no time is lost
        store.stop()
        // Clear pending reminders so they don't fire after quit
        NotificationManager.shared.cancelBreak()
        NotificationManager.shared.cancelResume()
    }
}
