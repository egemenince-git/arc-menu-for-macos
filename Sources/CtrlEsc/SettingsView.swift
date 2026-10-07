import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Bindable var model: LauncherModel
    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginNeedsApproval = false
    @State private var launchAtLoginError = ""
    @State private var cliPath = ""
    @State private var addError = ""
    @State private var jevAPIKey = ""
    @State private var jevModelName = ""
    @State private var jevKeyIsValid = false
    @State private var isCheckingJevKey = false
    @State private var isSortingAppsWithJev = false
    @State private var jevStatus = ""

    var body: some View {
        Form {
            Section("General") {
                LabeledContent("Global shortcut") {
                    Text("Control + Escape").foregroundStyle(.secondary)
                }
                Button("Rescan Applications") { model.reloadApps() }
            }
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: setLaunchAtLogin
                ))

                if launchAtLoginNeedsApproval {
                    Text("Allow Ctrl-Esc in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items Settings") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
            }
            Section("Pinned Applications") {
                Text("Right-click an app in the menu to pin or unpin it.")
                    .foregroundStyle(.secondary)
            }
            Section("USE AI") {
                SecureField("JEV API key", text: $jevAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isCheckingJevKey || isSortingAppsWithJev)
                    .onChange(of: jevAPIKey) { _, _ in
                        jevKeyIsValid = false
                        jevStatus = ""
                    }

                HStack {
                    Button("Verify API Key", action: verifyJevAPIKey)
                        .disabled(jevAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || isCheckingJevKey || isSortingAppsWithJev)
                    if isCheckingJevKey { ProgressView().controlSize(.small) }
                }

                Button("Sort Apps With JEV", action: sortAppsWithJEV)
                    .disabled(!jevKeyIsValid || isSortingAppsWithJev || isCheckingJevKey || model.apps.isEmpty)

                if isSortingAppsWithJev { ProgressView("Sending all apps and groups to JEV…") }
                if !jevStatus.isEmpty {
                    Text(jevStatus)
                        .font(.caption)
                        .foregroundStyle(jevKeyIsValid && !isSortingAppsWithJev ? Color.secondary : Color.red)
                        .textSelection(.enabled)
                }
                Text("The key stays in memory only. JEV receives all scanned apps and all application groups.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("CLI Applications") {
                HStack {
                    TextField("Full executable path", text: $cliPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Add CLI App") {
                        if let error = model.addCLIApp(path: cliPath) {
                            addError = error
                        } else {
                            cliPath = ""
                        }
                    }
                    .disabled(cliPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if model.cliApps.isEmpty {
                    Text("Added commands appear in the CLI section and open in Terminal when selected.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.cliApps) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                Text(app.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            Spacer()
                            Button(role: .destructive) { model.removeCLIApp(app) } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Remove \(app.name)")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 650)
        .padding(.top, 12)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("Developed by egemen@ince.name.tr")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .onAppear(perform: refreshLaunchAtLoginStatus)
        .alert("Couldn't Update Startup Setting", isPresented: Binding(
            get: { !launchAtLoginError.isEmpty },
            set: { if !$0 { launchAtLoginError = "" } }
        )) {
            Button("OK", role: .cancel) { launchAtLoginError = "" }
        } message: {
            Text(launchAtLoginError)
        }
        .alert("Cannot Add CLI App", isPresented: Binding(
            get: { !addError.isEmpty },
            set: { if !$0 { addError = "" } }
        )) {
            Button("OK", role: .cancel) { addError = "" }
        } message: {
            Text(addError)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
            launchAtLoginError = error.localizedDescription
        }
    }

    private func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled || status == .requiresApproval
        launchAtLoginNeedsApproval = status == .requiresApproval
    }

    private func verifyJevAPIKey() {
        let key = jevAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isCheckingJevKey = true
        jevKeyIsValid = false
        jevStatus = "Checking API key…"

        Task { @MainActor in
            defer { isCheckingJevKey = false }
            do {
                let models = try await JevAPIClient().validate(apiKey: key)
                guard jevAPIKey.trimmingCharacters(in: .whitespacesAndNewlines) == key else { return }
                jevModelName = models.first(where: { $0 == "jev-latest" }) ?? models[0]
                jevKeyIsValid = true
                jevStatus = "API key verified. Using \(jevModelName)."
            } catch {
                jevStatus = error.localizedDescription
            }
        }
    }

    private func sortAppsWithJEV() {
        guard jevKeyIsValid else { return }
        let key = jevAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isSortingAppsWithJev = true
        jevStatus = "Sending all apps and groups to JEV…"

        Task { @MainActor in
            defer { isSortingAppsWithJev = false }
            do {
                try await model.applyJevSort(apiKey: key, jevModel: jevModelName)
                jevStatus = "Sorted \(model.apps.count) apps into their application groups."
            } catch {
                jevStatus = error.localizedDescription
            }
        }
    }
}
