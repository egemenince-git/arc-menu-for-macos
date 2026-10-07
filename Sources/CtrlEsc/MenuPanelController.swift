import AppKit
import SwiftUI

@MainActor
final class MenuPanelController {
    private let model: LauncherModel
    private let panel: NSPanel
    private var keyMonitor: Any?

    init(model: LauncherModel) {
        self.model = model
        panel = LauncherPanel(contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: LauncherMenuView(model: model, onDismiss: { [weak self] in self?.hide() }))
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, self?.panel.isVisible == true else { return event }
            self?.hide()
            return nil
        }
    }

    func toggle() {
        if panel.isVisible { hide() }
        else { show() }
    }

    func show() {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let frame = panel.frame
        let x = screen.visibleFrame.minX + 24
        let y = screen.visibleFrame.maxY - frame.height - 12
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeKey()
        model.focusRequest += 1
        DispatchQueue.main.async { [weak self] in self?.panel.makeKey() }
    }

    func hide() {
        panel.orderOut(nil)
        model.query = ""
        model.selectedCategory = "Pinned"
    }
}

private final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
