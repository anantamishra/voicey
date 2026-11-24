import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)          // a menu-bar app: no Dock icon until a window is open
let delegate = AppDelegate()
app.delegate = delegate
app.run()
