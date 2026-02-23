import AppKit

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let store = TimeStore()
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure no Dock icon appears at runtime (belt-and-suspenders with Info.plist)
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController(store: store)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush any in-progress session to disk so no time is lost
        store.stop()
    }
}
