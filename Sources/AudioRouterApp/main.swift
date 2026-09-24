import AppKit

// Temporary test UI: a plain NSMenu. The dynamic-island panel replaces it in Phase 4.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
