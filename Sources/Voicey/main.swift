import AppKit

let app = NSApplication.shared
Prefs.register()
AppPolicy.update(windowOpen: false)         // a Dock icon unless "Show in Dock" is off
let delegate = AppDelegate()
app.delegate = delegate
app.run()
