import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarController

/// Owns the NSStatusItem and rebuilds the menu whenever store publishes changes.
final class MenuBarController {

    private let store: TimeStore
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()

    // Keep a reference so the window is not deallocated
    private var insightsWindowController: NSWindowController?

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
        button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Tempo")
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

        // Project list
        if store.projects.isEmpty {
            let empty = NSMenuItem(title: "No projects yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for project in store.projects {
                let todaySeconds = store.totalTime(for: project.id, in: today)
                let label: String
                if store.activeProjectId == project.id, store.isRunning {
                    let live = Formatters.elapsedClock(store.currentSessionElapsed)
                    let todayStr = Formatters.shortDuration(todaySeconds)
                    label = "\(project.name)  \(live)  (today: \(todayStr))"
                } else {
                    let todayStr = Formatters.shortDuration(todaySeconds)
                    label = "\(project.name)  (today: \(todayStr))"
                }

                let item = NSMenuItem(title: label, action: #selector(projectTapped(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = project.id
                // Checkmark for active project
                item.state = (store.activeProjectId == project.id) ? .on : .off
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // Stop
        let stopItem = NSMenuItem(title: "Stop", action: #selector(stopTapped), keyEquivalent: "")
        stopItem.target = self
        stopItem.isEnabled = store.isRunning
        menu.addItem(stopItem)

        menu.addItem(.separator())

        // Manage projects
        let manageItem = NSMenuItem(title: "Manage Projects...", action: #selector(openManage), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)

        // Insights
        let insightsItem = NSMenuItem(title: "Open Insights", action: #selector(openInsights), keyEquivalent: "i")
        insightsItem.target = self
        menu.addItem(insightsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Tempo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
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

    @objc private func openInsights() {
        openOrFocusWindow(id: "insights") {
            let content = InsightsView().environmentObject(self.store)
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Tempo Insights"
            win.center()
            win.contentView = NSHostingView(rootView: content)
            win.setFrameAutosaveName("InsightsWindow")
            return win
        }
    }

    @objc private func openManage() {
        openOrFocusWindow(id: "manage") {
            let content = ManageProjectsView().environmentObject(self.store)
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 460),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Projects"
            win.center()
            win.contentView = NSHostingView(rootView: content)
            win.setFrameAutosaveName("ManageWindow")
            return win
        }
    }

    // MARK: Window helpers

    /// Opens a window by logical id, or focuses it if already open.
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

        // Clean up reference when window closes
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
