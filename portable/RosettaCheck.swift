import AppKit
// Opening this small Intel-only app through Launch Services lets macOS offer
// its own Rosetta installation UI. It contains no Wine or Apple binaries.
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
DispatchQueue.main.async { app.terminate(nil) }
app.run()
