import AppKit
import Foundation

struct LaunchableApp: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let category: String
    let bundleIdentifier: String?

    var icon: NSImage { NSWorkspace.shared.icon(forFile: path) }

    static func == (lhs: LaunchableApp, rhs: LaunchableApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct CLIApp: Identifiable, Codable, Hashable {
    let path: String

    var id: String { path }
    var name: String { URL(fileURLWithPath: path).lastPathComponent }
}

@MainActor
@Observable
final class LauncherModel {
    private(set) var apps: [LaunchableApp] = []
    private(set) var cliApps: [CLIApp] {
        didSet {
            guard let data = try? JSONEncoder().encode(cliApps) else { return }
            UserDefaults.standard.set(data, forKey: "cliApps")
        }
    }
    var query = ""
    var selectedCategory = "Pinned"
    var focusRequest = 0
    var pinnedIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(pinnedIDs), forKey: "pinnedAppIDs") }
    }
    var recentIDs: [String] {
        didSet { UserDefaults.standard.set(recentIDs, forKey: "recentAppIDs") }
    }
    private(set) var appAliases: [String: [String]] {
        didSet { UserDefaults.standard.set(appAliases, forKey: "appSearchAliases") }
    }
    private(set) var appCategoryOverrides: [String: String] {
        didSet { UserDefaults.standard.set(appCategoryOverrides, forKey: "appCategoryOverrides") }
    }
    var cliLaunchError: String?
    var onOpenSettings: (() -> Void)?

    let categories = ["Pinned", "Frequent", "All Applications", "CLI", "Accessories", "Development",
                      "Education", "Games", "Graphics", "Internet", "Office", "Other", "System"]
    var applicationGroupCategories: [String] {
        categories.filter { !["Pinned", "Frequent", "All Applications", "CLI"].contains($0) }
    }

    init() {
        pinnedIDs = Set(UserDefaults.standard.stringArray(forKey: "pinnedAppIDs") ?? [])
        recentIDs = UserDefaults.standard.stringArray(forKey: "recentAppIDs") ?? []
        appAliases = UserDefaults.standard.dictionary(forKey: "appSearchAliases") as? [String: [String]] ?? [:]
        appCategoryOverrides = UserDefaults.standard.dictionary(forKey: "appCategoryOverrides") as? [String: String] ?? [:]
        if let data = UserDefaults.standard.data(forKey: "cliApps"),
           let savedCLIApps = try? JSONDecoder().decode([CLIApp].self, from: data) {
            cliApps = savedCLIApps
        } else {
            cliApps = []
        }
        reloadApps()
    }

    var visibleApps: [LaunchableApp] {
        let base: [LaunchableApp]
        if !query.isEmpty {
            base = apps.filter { app in
                app.name.localizedCaseInsensitiveContains(query) ||
                    appAliases[app.id, default: []].contains { $0.localizedCaseInsensitiveContains(query) }
            }
        } else {
            switch selectedCategory {
            case "Pinned": base = apps.filter { pinnedIDs.contains($0.id) }
            case "Frequent": base = recentIDs.compactMap { id in apps.first { $0.id == id } }
            case "All Applications": base = apps
            case "CLI": base = []
            default: base = apps.filter { $0.category == selectedCategory }
            }
        }
        return base.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var pinnedApps: [LaunchableApp] {
        apps.filter { pinnedIDs.contains($0.id) }.sorted { $0.name < $1.name }
    }

    var firstVisibleApp: LaunchableApp? { visibleApps.first }

    var visibleCLIApps: [CLIApp] {
        if !query.isEmpty {
            return cliApps.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.path.localizedCaseInsensitiveContains(query)
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        return selectedCategory == "CLI" ? cliApps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } : []
    }

    var firstVisibleCLIApp: CLIApp? { visibleCLIApps.first }

    var showsCaptureAction: Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["capture", "screen capture", "capture screen", "screenshot", "screenshot to clipboard"]
            .contains(normalized)
    }

    func captureScreenToClipboard() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-c"]
        do {
            try process.run()
        } catch {
            NSLog("Ctrl-Esc could not start the macOS screen capture tool: %@", error.localizedDescription)
        }
    }

    func addCLIApp(path rawPath: String) -> String? {
        let cleanedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = (cleanedPath as NSString).expandingTildeInPath
        guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else {
            return "Enter the full path to an executable file."
        }
        guard !cliApps.contains(where: { $0.path == path }) else {
            return "This CLI app is already in the list."
        }
        cliApps.append(CLIApp(path: path))
        cliApps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return nil
    }

    func removeCLIApp(_ app: CLIApp) {
        cliApps.removeAll { $0.id == app.id }
    }

    func launchCLIApp(_ app: CLIApp) {
        cliLaunchError = nil
        guard FileManager.default.isExecutableFile(atPath: app.path) else {
            cliLaunchError = "The executable could not be found at \(app.path). Check its path in Settings."
            return
        }
        let shellQuotedPath = "'" + app.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let command = "exec \(shellQuotedPath)"
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application id "com.apple.Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """
        guard let script = NSAppleScript(source: source) else {
            cliLaunchError = "Could not prepare the Terminal command."
            return
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            NSLog("Ctrl-Esc could not open CLI app in Terminal: %@", error)
            cliLaunchError = error[NSAppleScript.errorMessage] as? String ?? error.description
        }
    }

    func reloadApps() {
        let roots = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]
        var found: [String: LaunchableApp] = [:]
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(atPath: root) else { continue }
            while let relative = enumerator.nextObject() as? String {
                guard relative.hasSuffix(".app") else { continue }
                let path = (root as NSString).appendingPathComponent(relative)
                let url = URL(fileURLWithPath: path)
                let bundle = Bundle(url: url)
                let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let identifier = bundle?.bundleIdentifier
                // Bundle identifiers are not guaranteed to be unique. For example,
                // ChatGPT.app and Codex.app can both register as com.openai.codex.
                // Use the installed bundle path as the catalog identity so neither
                // app overwrites the other during a scan.
                let appID = path
                let category = appCategoryOverrides[appID]
                    ?? identifier.flatMap { appCategoryOverrides[$0] }
                    ?? Self.category(for: bundle?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String)
                let app = LaunchableApp(id: appID, name: name, path: path,
                                        category: category, bundleIdentifier: identifier)
                found[app.id] = app
                enumerator.skipDescendants()
            }
        }
        apps = found.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        migrateLegacyBundleIdentifierSettings(for: apps)
        if pinnedIDs.isEmpty {
            pinnedIDs = Set(apps.prefix(8).map(\.id))
        }
    }

    private func migrateLegacyBundleIdentifierSettings(for apps: [LaunchableApp]) {
        var appsByBundleIdentifier: [String: [LaunchableApp]] = [:]
        for app in apps {
            guard let bundleIdentifier = app.bundleIdentifier else { continue }
            appsByBundleIdentifier[bundleIdentifier, default: []].append(app)
        }

        var migratedPinnedIDs = pinnedIDs
        var migratedRecentIDs = recentIDs
        var migratedAliases = appAliases
        var migratedCategoryOverrides = appCategoryOverrides

        for (bundleIdentifier, matchingApps) in appsByBundleIdentifier {
            // Settings written by earlier versions used the bundle identifier as
            // the app ID. Move those entries to each matching installed bundle.
            guard !matchingApps.contains(where: { $0.id == bundleIdentifier }) else { continue }
            let appIDs = matchingApps.map(\.id)

            if migratedPinnedIDs.remove(bundleIdentifier) != nil {
                migratedPinnedIDs.formUnion(appIDs)
            }
            if migratedRecentIDs.contains(bundleIdentifier) {
                migratedRecentIDs = migratedRecentIDs.flatMap { id in
                    id == bundleIdentifier ? appIDs : [id]
                }
            }
            if let aliases = migratedAliases.removeValue(forKey: bundleIdentifier) {
                for appID in appIDs where migratedAliases[appID] == nil {
                    migratedAliases[appID] = aliases
                }
            }
            if let category = migratedCategoryOverrides.removeValue(forKey: bundleIdentifier) {
                for appID in appIDs where migratedCategoryOverrides[appID] == nil {
                    migratedCategoryOverrides[appID] = category
                }
            }
        }

        pinnedIDs = migratedPinnedIDs
        recentIDs = Array(migratedRecentIDs.prefix(20))
        appAliases = migratedAliases
        appCategoryOverrides = migratedCategoryOverrides
    }

    func applyJevSort(apiKey: String, jevModel: String) async throws {
        let assignments = try await JevAPIClient().sort(
            apps: apps,
            categories: applicationGroupCategories,
            model: jevModel,
            apiKey: apiKey
        )
        appCategoryOverrides.merge(assignments) { _, new in new }
        apps = apps.map { app in
            LaunchableApp(
                id: app.id,
                name: app.name,
                path: app.path,
                category: assignments[app.id] ?? app.category,
                bundleIdentifier: app.bundleIdentifier
            )
        }
    }

    func launch(_ app: LaunchableApp) {
        let url = URL(fileURLWithPath: app.path)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        recentIDs.removeAll { $0 == app.id }
        recentIDs.insert(app.id, at: 0)
        recentIDs = Array(recentIDs.prefix(20))
    }

    func togglePinned(_ app: LaunchableApp) {
        if pinnedIDs.contains(app.id) { pinnedIDs.remove(app.id) }
        else { pinnedIDs.insert(app.id) }
    }

    func aliases(for app: LaunchableApp) -> [String] {
        appAliases[app.id, default: []]
    }

    func setAliases(_ aliases: [String], for app: LaunchableApp) {
        let cleaned = aliases.reduce(into: [String]()) { result, alias in
            let value = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty,
                  !result.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) else { return }
            result.append(value)
        }
        if cleaned.isEmpty { appAliases.removeValue(forKey: app.id) }
        else { appAliases[app.id] = cleaned }
    }

    private static func category(for identifier: String?) -> String {
        guard let identifier else { return "Other" }
        if identifier.contains("developer") || identifier.contains("development") { return "Development" }
        if identifier.contains("education") { return "Education" }
        if identifier.contains("game") { return "Games" }
        if identifier.contains("graphics") || identifier.contains("design") || identifier.contains("photo") { return "Graphics" }
        if identifier.contains("internet") || identifier.contains("network") || identifier.contains("browser") { return "Internet" }
        if identifier.contains("office") || identifier.contains("productivity") { return "Office" }
        if identifier.contains("accessories") || identifier.contains("utility") { return "Accessories" }
        if identifier.contains("system") { return "System" }
        return "Other"
    }
}
