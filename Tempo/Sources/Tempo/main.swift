import AppKit

// Entry point - must not use @main with a manual AppDelegate in a Swift package target
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
