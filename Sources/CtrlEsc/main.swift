import AppKit
import SwiftUI

@main
struct CtrlEscApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = LauncherModel()
    private var menuController: MenuPanelController!
    private var settingsController: SettingsWindowController!
    private var hotKeyMonitor: GlobalHotKeyMonitor!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuController = MenuPanelController(model: model)
        settingsController = SettingsWindowController(model: model)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Ctrl-Esc")
        statusItem.button?.toolTip = "Ctrl-Esc"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleLauncher)

        hotKeyMonitor = GlobalHotKeyMonitor { [weak self] in
            Task { @MainActor in self?.menuController.toggle() }
        }
        hotKeyMonitor.register()
        model.onOpenSettings = { [weak self] in
            guard let self else { return }
            self.menuController.hide()
            self.settingsController.show()
        }
    }

    @objc private func toggleLauncher() {
        menuController.toggle()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyMonitor.unregister()
    }
}
