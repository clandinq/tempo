# Tempo

A minimal macOS menu bar app for tracking time across projects.

## Features

- Lives in the menu bar — no Dock icon
- Click to see projects; click a project to start tracking it
- Active timer shows elapsed time in the menu bar
- Stop tracking without switching projects
- Today's time per project shown inline in the menu
- Add, rename, and delete projects freely
- Insights window: Today / This Week / This Month breakdown with bar chart
- All data stored locally in `~/Library/Application Support/Tempo/data.json`

## Building

### With the build script (no Xcode required)

```bash
./build.sh
open .build/Tempo.app
```

Requires: macOS Command Line Tools with Swift 5.8+ (`xcode-select --install`)

### In Xcode

Open `Tempo.xcodeproj` in Xcode 14+, then **Product > Run** (⌘R).

### With `swift build`

Only works when full Xcode (not just CLI Tools) is installed.

## File layout

```
Tempo/
  Sources/Tempo/
    Models.swift              – Project and TimeEntry data types
    Store.swift               – ObservableObject: timer logic, queries, persistence
    Formatters.swift          – Duration string helpers
    Settings.swift            – AppSettings (UserDefaults-backed)
    NotificationManager.swift – Break/resume reminders
    AppDelegate.swift         – NSApplicationDelegate entry point
    main.swift                – Manual NSApplicationMain entry
    MenuBarController.swift   – Status item, menu building, single tabbed window
    MainWindowView.swift      – AppTab enum, WindowState, tabbed container view
    HistoryView.swift         – History list with inline popover field editing
    InsightsView.swift        – Insights dashboard with Swift Charts
    ManageProjectsView.swift  – Project CRUD view
    SettingsView.swift        – Reminder settings view
  Resources/
    Info.plist                – LSUIElement=true (no Dock icon)
Tempo.xcodeproj/              – Xcode project for IDE use
Package.swift                 – SPM manifest (requires full Xcode)
build.sh                      – Direct swiftc build (CLI Tools compatible)
```
