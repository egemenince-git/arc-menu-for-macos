import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let model: LauncherModel
    private var window: NSWindow?

    init(model: LauncherModel) {
        self.model = model
    }

    func show() {
        if window == nil {
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 750),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Ctrl-Esc Settings"
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.contentView = NSHostingView(rootView: SettingsView(model: model))
            settingsWindow.center()
            window = settingsWindow
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
