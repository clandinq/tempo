import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarController

/// Owns the NSStatusItem and rebuilds the menu whenever store publishes changes.
final class MenuBarController {

    private let store: TimeStore
    private let windowState = WindowState()
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()

    init(store: TimeStore) {
        self.store = store
        setupStatusItem()
        subscribeToStore()
    }

    // MARK: Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusButton()
        // Build initial menu immediately so the button is clickable on launch
        let m = NSMenu()
        statusItem.menu = m
        populateMenu(m)
    }

    private func subscribeToStore() {
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusButton()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    // MARK: Status button label

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }

        if store.isRunning {
            let elapsed = Formatters.elapsedClock(store.currentSessionElapsed)
            if let id = store.activeProjectId,
               let project = store.projects.first(where: { $0.id == id }) {
                button.title = "\(project.name) \(elapsed)"
            } else {
                button.title = elapsed
            }
        } else {
            button.title = "Tempo"
        }

        // Use the custom logo; isTemplate=false preserves the original colors
        if let url = Bundle.main.url(forResource: "tempo_logo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = false
            img.size = NSSize(width: 18, height: 18)
            button.image = img
        } else {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Tempo")
        }
        button.imagePosition = .imageLeading
    }

    // MARK: Menu building

    private func rebuildMenu() {
        if let menu = statusItem.menu {
            populateMenu(menu)
        }
    }

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let today = store.todayRange()

        if store.projects.isEmpty {
            let empty = NSMenuItem(title: "No projects yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for project in store.projects {
                let todaySeconds = store.totalTime(for: project.id, in: today)
                let suffix: String
                if store.activeProjectId == project.id, store.isRunning {
                    let live = Formatters.elapsedClock(store.currentSessionElapsed)
                    let todayStr = Formatters.shortDuration(todaySeconds)
                    suffix = "  \(live)  (today: \(todayStr))"
                } else {
                    let todayStr = Formatters.shortDuration(todaySeconds)
                    suffix = "  (today: \(todayStr))"
                }

                let item = NSMenuItem(title: "", action: #selector(projectTapped(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = project.id
                item.state = (store.activeProjectId == project.id) ? .on : .off
                item.attributedTitle = coloredMenuTitle(project: project, suffix: suffix)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let stopItem = NSMenuItem(title: "Stop", action: #selector(stopTapped), keyEquivalent: "")
        stopItem.target = self
        stopItem.isEnabled = store.isRunning
        menu.addItem(stopItem)

        menu.addItem(.separator())

        let manageItem = NSMenuItem(title: "Manage Projects...", action: #selector(openProjects), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)

        let insightsItem = NSMenuItem(title: "Open Insights", action: #selector(openInsights), keyEquivalent: "i")
        insightsItem.target = self
        menu.addItem(insightsItem)

        let historyItem = NSMenuItem(title: "View History", action: #selector(openHistory), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Tempo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    /// Builds an attributed string: colored bullet + project name + gray suffix.
    private func coloredMenuTitle(project: Project, suffix: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Colored dot using the project's color
        let dot = NSAttributedString(string: "● ", attributes: [
            .foregroundColor: project.color.nsColor,
            .font: NSFont.menuFont(ofSize: 0)
        ])
        result.append(dot)

        // Project name in normal menu color
        let nameAttr = NSAttributedString(string: project.name, attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.menuFont(ofSize: 0)
        ])
        result.append(nameAttr)

        // Suffix in secondary color
        let suffixAttr = NSAttributedString(string: suffix, attributes: [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.menuFont(ofSize: 0)
        ])
        result.append(suffixAttr)

        return result
    }

    // MARK: Actions

    @objc private func projectTapped(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        if store.activeProjectId == id && store.isRunning {
            store.stop()
        } else {
            store.startTracking(projectId: id)
        }
    }

    @objc private func stopTapped() {
        store.stop()
    }

    @objc private func openHistory() { openMainWindow(tab: .history) }
    @objc private func openInsights() { openMainWindow(tab: .insights) }
    @objc private func openSettings() { openMainWindow(tab: .settings) }
    @objc private func openProjects() { openMainWindow(tab: .projects) }

    private func openMainWindow(tab: AppTab) {
        windowState.selectedTab = tab
        openOrFocusWindow(id: "main") {
            let content = MainWindowView()
                .environmentObject(self.store)
                .environmentObject(self.windowState)
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Tempo"
            win.center()
            win.contentView = NSHostingView(rootView: content)
            win.setFrameAutosaveName("MainWindow")
            return win
        }
    }

    // MARK: Window helpers

    private var openWindows: [String: NSWindowController] = [:]

    private func openOrFocusWindow(id: String, makeWindow: () -> NSWindow) {
        if let existing = openWindows[id] {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = makeWindow()
        let wc = NSWindowController(window: win)
        openWindows[id] = wc

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { [weak self] _ in
            self?.openWindows.removeValue(forKey: id)
        }

        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
