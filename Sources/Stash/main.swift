import AppKit

// `swift run Stash --test` runs the in-process smoke tests instead of
// starting the GUI. See SelfTests.swift.
if CommandLine.arguments.contains("--test") {
    SelfTests.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
