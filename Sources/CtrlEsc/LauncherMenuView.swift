import AppKit
import SwiftUI

struct LauncherMenuView: View {
    @Bindable var model: LauncherModel
    let onDismiss: () -> Void
    @FocusState private var searchFocused: Bool
    @State private var accountPhoto: NSImage?

    private let background = Color(nsColor: .windowBackgroundColor)

    var body: some View {
        HStack(spacing: 0) {
            appBrowser
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(.primary.opacity(0.09)).frame(width: 1)
            shortcutPanel
                .frame(width: 230)
        }
        .frame(width: 760, height: 540)
        .background(background.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.11), lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 26, y: 12)
        .onAppear {
            searchFocused = true
            accountPhoto = MacOSAccountPhoto.currentUserImage()
        }
        .onChange(of: model.focusRequest) { _, _ in searchFocused = true }
        .onExitCommand(perform: onDismiss)
        .alert("Couldn't Launch CLI App", isPresented: Binding(
            get: { model.cliLaunchError != nil },
            set: { if !$0 { model.cliLaunchError = nil } }
        )) {
            Button("OK", role: .cancel) { model.cliLaunchError = nil }
        } message: {
            Text(model.cliLaunchError ?? "")
        }
        .background {
            Button("") { onDismiss() }.keyboardShortcut(.escape, modifiers: [])
                .opacity(0).frame(width: 0, height: 0)
        }
    }

    private var appBrowser: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search apps…", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .font(.system(size: 14))
                    .onSubmit {
                        if model.showsCaptureAction {
                            startCapture()
                            return
                        }
                        if let app = model.firstVisibleApp {
                            model.launch(app)
                            onDismiss()
                        } else if let cliApp = model.firstVisibleCLIApp {
                            openCLIApp(cliApp)
                        }
                    }
                if !model.query.isEmpty {
                    Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).frame(height: 42)
            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
            .padding(16)

            HStack(alignment: .top, spacing: 0) {
                categoryList.frame(width: 150)
                Rectangle().fill(.primary.opacity(0.07)).frame(width: 1)
                appGrid
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var categoryList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(model.categories, id: \.self) { category in
                    Button {
                        model.selectedCategory = category
                        model.query = ""
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: icon(for: category)).frame(width: 17)
                            Text(category).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 12.5, weight: model.selectedCategory == category ? .semibold : .regular))
                        .foregroundStyle(model.selectedCategory == category ? .primary : .secondary)
                        .padding(.horizontal, 10).frame(height: 34)
                        .background(model.selectedCategory == category ? Color.primary.opacity(0.09) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
    }

    private var appGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 8)], spacing: 8) {
                if model.showsCaptureAction {
                    Button(action: startCapture) {
                        VStack(spacing: 8) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 34, weight: .regular))
                                .frame(width: 42, height: 42)
                            Text("Capture Area")
                                .font(.system(size: 11.5, weight: .medium))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(height: 28, alignment: .top)
                            Text("Copy to Clipboard")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).frame(height: 88)
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
                ForEach(model.visibleApps) { app in
                    Button { model.launch(app); onDismiss() } label: {
                        VStack(spacing: 8) {
                            Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: 42, height: 42)
                            Text(app.name).font(.system(size: 11.5)).lineLimit(2).multilineTextAlignment(.center)
                                .frame(height: 28, alignment: .top)
                        }
                        .frame(maxWidth: .infinity).frame(height: 88)
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(model.pinnedIDs.contains(app.id) ? "Unpin from Pinned" : "Pin to Pinned") {
                            model.togglePinned(app)
                        }
                        Button("Edit Search Aliases…") { editSearchAliases(for: app) }
                        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) }
                    }
                }
                ForEach(model.visibleCLIApps) { app in
                    Button { openCLIApp(app) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.system(size: 34, weight: .regular))
                                .frame(width: 42, height: 42)
                            Text(app.name).font(.system(size: 11.5)).lineLimit(2).multilineTextAlignment(.center)
                                .frame(height: 28, alignment: .top)
                        }
                        .frame(maxWidth: .infinity).frame(height: 88)
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .help(app.path)
                }
            }
            .padding(14)
            if model.visibleApps.isEmpty && model.visibleCLIApps.isEmpty && !model.showsCaptureAction {
                ContentUnavailableView("No Applications", systemImage: "app.dashed", description: Text("Try a different search or category."))
                    .padding(.top, 80)
            }
        }
    }

    private var shortcutPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if let accountPhoto {
                    Image(nsImage: accountPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSUserName()).font(.system(size: 14, weight: .semibold))
                    Text("Applications").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 5) {
                shortcut("Home", icon: "house", path: NSHomeDirectory())
                shortcut("Applications", icon: "square.grid.2x2", path: "/Applications")
                shortcut("Documents", icon: "doc.text", path: NSHomeDirectory() + "/Documents")
                shortcut("Downloads", icon: "arrow.down.circle", path: NSHomeDirectory() + "/Downloads")
                shortcut("Pictures", icon: "photo", path: NSHomeDirectory() + "/Pictures")
                shortcut("Music", icon: "music.note", path: NSHomeDirectory() + "/Music")
            }
            .padding(12)

            Divider().padding(.horizontal, 12)
            Text("PINNED").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(model.pinnedApps.prefix(6)) { app in
                        Button { model.launch(app); onDismiss() } label: {
                            HStack(spacing: 9) {
                                Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                                Text(app.name).lineLimit(1).font(.system(size: 12))
                                Spacer()
                            }
                            .padding(.horizontal, 8).frame(height: 30)
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 10)
            }
            Spacer(minLength: 8)
            Divider().padding(.horizontal, 12)
            HStack(spacing: 9) {
                Button { model.onOpenSettings?() } label: { Image(systemName: "gearshape") }
                    .help("Settings")
                Spacer()
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.help("Quit Ctrl-Esc")
            }
            .buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(.secondary)
            .padding(.horizontal, 18).frame(height: 48)
        }
        .background(.primary.opacity(0.025))
    }

    private func shortcut(_ title: String, icon: String, path: String) -> some View {
        Button { NSWorkspace.shared.open(URL(fileURLWithPath: path)) } label: {
            HStack(spacing: 9) {
                Image(systemName: icon).frame(width: 17)
                Text(title).lineLimit(1)
                Spacer()
            }
            .font(.system(size: 12.5)).foregroundStyle(.primary.opacity(0.84))
            .padding(.horizontal, 8).frame(height: 30)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func editSearchAliases(for app: LaunchableApp) {
        let alert = NSAlert()
        alert.messageText = "Search Aliases for \(app.name)"
        alert.informativeText = "Add alternate names to find this app in search. Separate aliases with commas or semicolons."
        alert.alertStyle = .informational

        let field = NSTextField(string: model.aliases(for: app).joined(separator: ", "))
        field.placeholderString = "e.g. browser, web"
        field.frame = NSRect(x: 0, y: 0, width: 360, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let separators = CharacterSet(charactersIn: ",;")
        let aliases = field.stringValue.components(separatedBy: separators)
        model.setAliases(aliases, for: app)
    }

    private func startCapture() {
        Task { @MainActor in
            onDismiss()
            try? await Task.sleep(for: .milliseconds(180))
            model.captureScreenToClipboard()
        }
    }

    private func openCLIApp(_ app: CLIApp) {
        model.launchCLIApp(app)
        if model.cliLaunchError == nil { onDismiss() }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Pinned": "pin.fill"
        case "Frequent": "clock"
        case "All Applications": "square.grid.2x2"
        case "CLI": "terminal"
        case "Accessories": "wrench.and.screwdriver"
        case "Development": "hammer"
        case "Education": "book"
        case "Games": "gamecontroller"
        case "Graphics": "paintpalette"
        case "Internet": "globe"
        case "Office": "doc.text"
        case "System": "gearshape.2"
        default: "folder"
        }
    }
}
