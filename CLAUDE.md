# Tempo — Claude Code Instructions

## Build and relaunch after every change

After any Swift source file modification, always run:

```bash
./build.sh --install
```

This compiles all sources with `swiftc` (no Xcode required) and installs to `/Applications/Tempo.app`. The build will surface any Swift compile errors immediately.

After a successful install, relaunch the app so changes take effect:

```bash
pkill -x Tempo; sleep 0.5; open /Applications/Tempo.app
```

## Project type: Development

## File layout

```
Tempo/Sources/Tempo/
  Models.swift              – Project (isBreak, breakProjectID), TimeEntry, AppData (w/ session fields)
  Store.swift               – TimeStore: timer logic, queries, JSON persistence
  Formatters.swift          – Duration string helpers (shortDuration, elapsedClock)
  Settings.swift            – AppSettings (UserDefaults-backed)
  NotificationManager.swift – Break/resume UNUserNotificationCenter reminders
  AppDelegate.swift         – NSApplicationDelegate entry point
  main.swift                – Manual NSApplicationMain entry
  MenuBarController.swift   – NSStatusItem, menu building, single tabbed window
  MainWindowView.swift      – AppTab enum, WindowState, tabbed container view
  HistoryView.swift         – History list with inline popover field editing
  InsightsView.swift        – Insights dashboard (Charts framework)
  ManageProjectsView.swift  – Project CRUD view
  SettingsView.swift        – Reminder settings view
Tempo/Resources/
  Info.plist                – LSUIElement=true (no Dock icon)
  tempo_logo.png            – Menu bar icon (18×18, opaque)
  AppIcon.icns              – App icon
build.sh                    – Direct swiftc build script; adds new .swift files here
```

## Architecture

- **SwiftUI + AppKit hybrid**: Views are SwiftUI, embedded in AppKit `NSWindow` via `NSHostingView`
- **Single source of truth**: `TimeStore` (ObservableObject) holds all state; views use `@EnvironmentObject`
- **Single window**: `MenuBarController` opens one "Tempo" window (`openMainWindow(tab:)`). All four menu items (Manage Projects, Insights, History, Settings) open the same window to the appropriate tab.
- **WindowState**: `ObservableObject` owned by `MenuBarController`; holds `selectedTab: AppTab`. Setting it before calling `openOrFocusWindow` switches tabs even when the window is already open.
- **Data persistence**: JSON to `~/Library/Application Support/Tempo/data.json`; `AppData` also persists `activeProjectId` and `sessionStart` for crash recovery
- **Break project**: a built-in protected `Project` with `id = 00000000-0000-0000-0000-000000000001` and `isBreak = true`; seeded by `ensureBreakProject()` on every load. Guards in `deleteProject`, `renameProject`, `recolorProject` prevent mutation.
- **Notification actions**: break reminders carry "Start Break" (`.foreground`) and "Dismiss" action buttons. Tapping "Start Break" calls `store.startBreak()`; tapping "Dismiss" calls `store.rescheduleBreakIfRunning()` via callbacks on `NotificationManager.shared`.

## Adding a new Swift source file

1. Create the file in `Tempo/Sources/Tempo/`
2. Add it to `build.sh`'s `swiftc` source list (order matters — dependencies before dependents)
