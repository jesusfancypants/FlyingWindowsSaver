import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "Flying Windows Preview"

guard let view = FlyingWindowsView(frame: window.contentView!.bounds, isPreview: false) else {
    fatalError("Failed to init FlyingWindowsView")
}
view.autoresizingMask = [.width, .height]
window.contentView = view
window.makeKeyAndOrderFront(nil)
view.startAnimation()

app.activate(ignoringOtherApps: true)
app.run()
