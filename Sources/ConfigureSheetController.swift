import AppKit

/// Owns the configure-sheet NSWindow so FlyingWindowsView can hold a single
/// strong reference across repeated `configureSheet` property accesses.
final class ConfigureSheetController: NSObject {
    let window: NSWindow

    init(defaults: Defaults, onDone: @escaping (NSWindow) -> Void) {
        let panel = SettingsPanelView(defaults: defaults)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: panel.frame.size),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = panel
        window.setContentSize(panel.frame.size)
        window.contentMinSize = panel.frame.size
        window.contentMaxSize = panel.frame.size
        self.window = window
        super.init()
        panel.onDone = { onDone(window) }
        // The panel's own size can change after the sheet is already open
        // (e.g. switching to the Emoji icon mode reveals a text field) —
        // resize the window to match instead of clipping the new content.
        panel.onLayoutChange = { [weak window] in
            guard let window else { return }
            let size = panel.frame.size
            window.setContentSize(size)
            window.contentMinSize = size
            window.contentMaxSize = size
        }
    }
}
