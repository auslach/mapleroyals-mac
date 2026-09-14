import AppKit
import CryptoKit

struct LaunchConfiguration: Decodable {
    let root: String
    let engine: String
    let prefix: String
    let libraries: String
    let log: String
    let debug: String
    let overrides: String
    let msync: Bool?
    let runtimeProbe: Bool?
    let rendererEnvironment: [String: String]?
    let setup: [[String]]
    let arguments: [String]
}

final class MapleLauncher: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let status = NSTextField(wrappingLabelWithString: "Preparing MapleRoyals…")
    let playButton = NSButton(title: "Launch another client", target: nil, action: nil)
    var configuration: LaunchConfiguration!
    var root: URL!
    var log: FileHandle!
    var logURL: URL!
    var children: [Process] = []
    var runningGames = 0
    var setupMarker: URL!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit MapleRoyals Launcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 170), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "MapleRoyals Launcher"
        window.isReleasedWhenClosed = false
        let title = NSTextField(labelWithString: "MapleRoyals")
        title.font = .boldSystemFont(ofSize: 22)
        playButton.target = self
        playButton.action = #selector(launchGame)
        playButton.isEnabled = false
        let logsButton = NSButton(title: "Show log", target: self, action: #selector(showLog))
        let buttons = NSStackView(views: [playButton, logsButton])
        buttons.orientation = .horizontal
        let stack = NSStackView(views: [title, status, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 22)
        ])
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        do {
            let url = Bundle.main.resourceURL!.appendingPathComponent("configuration.json")
            let configData = try Data(contentsOf: url)
            configuration = try JSONDecoder().decode(LaunchConfiguration.self, from: configData)
            root = URL(fileURLWithPath: configuration.root)
            let fingerprint = SHA256.hash(data: configData).map { String(format: "%02x", $0) }.joined()
            setupMarker = root.appendingPathComponent(configuration.prefix + "/.launcher-setup-" + fingerprint)
            logURL = root.appendingPathComponent("logs/" + configuration.log)
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: logURL.path) {
                let old = logURL.deletingPathExtension().appendingPathExtension("\(Int(Date().timeIntervalSince1970)).log")
                try FileManager.default.moveItem(at: logURL, to: old)
            }
            FileManager.default.createFile(atPath: logURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
            log = try FileHandle(forWritingTo: logURL)
            writeLog("Launch: \(Date())\nEngine: \(configuration.engine)\nPrefix: \(configuration.prefix)\nEnvironment: \(environment().filter { ["WINEPREFIX", "WINEARCH", "WINESERVER", "DYLD_FALLBACK_LIBRARY_PATH", "WINEDLLOVERRIDES", "WINEDEBUG", "WINEESYNC", "WINEMSYNC", "PATH", "DXVK_HUD", "DXVK_LOG_PATH", "MVK_CONFIG_LOG_LEVEL", "VK_DRIVER_FILES", "VK_LOADER_DEBUG", "ROSETTA_ADVERTISE_AVX"].contains($0.key) })\n")
            if FileManager.default.fileExists(atPath: setupMarker.path) { launchGame() }
            else { runSetup(0) }
        } catch { failed(error.localizedDescription) }
    }

    func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        // Explicitly avoid inheriting renderer/synchronization options from another wrapper.
        for key in ["ROSETTA_X87_PATH", "WINELOADER", "WINESERVER", "WINE_D3D_CONFIG", "DXVK_CONFIG_FILE", "DXVK_ASYNC", "DXVK_HUD", "DXVK_LOG_PATH", "MVK_CONFIG_LOG_LEVEL", "VK_DRIVER_FILES", "VK_LOADER_DEBUG", "ROSETTA_ADVERTISE_AVX", "WINEDLLPATH", "DYLD_LIBRARY_PATH"] { env.removeValue(forKey: key) }
        let engine = root.appendingPathComponent(configuration.engine)
        env["WINEPREFIX"] = root.appendingPathComponent(configuration.prefix).path
        env["WINEARCH"] = "win64"
        env["WINESERVER"] = engine.appendingPathComponent("bin/wineserver").path
        env["DYLD_FALLBACK_LIBRARY_PATH"] = root.appendingPathComponent(configuration.libraries).path + ":/usr/lib"
        env["WINEDLLOVERRIDES"] = configuration.overrides
        env["WINEDEBUG"] = configuration.debug
        env["WINEESYNC"] = "0"
        env["WINEMSYNC"] = configuration.msync == true ? "1" : "0"
        env["PATH"] = engine.appendingPathComponent("bin").path + ":/usr/bin:/bin:/usr/sbin:/sbin"
        for (key, value) in configuration.rendererEnvironment ?? [:] {
            guard ["DXVK_HUD", "DXVK_LOG_PATH", "MVK_CONFIG_LOG_LEVEL", "VK_DRIVER_FILES", "VK_LOADER_DEBUG", "ROSETTA_ADVERTISE_AVX"].contains(key) else { continue }
            env[key] = value.replacingOccurrences(of: "${ROOT}", with: root.path)
        }
        return env
    }

    func writeLog(_ text: String) { try? log?.write(contentsOf: Data(text.utf8)) }

    func run(_ arguments: [String], started: (() -> Void)? = nil, completion: @escaping (Int32) -> Void) {
        let p = Process()
        p.executableURL = root.appendingPathComponent(configuration.engine + "/bin/wine")
        p.arguments = arguments.map { $0.replacingOccurrences(of: "${ROOT}", with: root.path) }
        p.environment = environment()
        let gameDir = root.appendingPathComponent(configuration.prefix + "/drive_c/MapleRoyals")
        p.currentDirectoryURL = FileManager.default.fileExists(atPath: gameDir.path) ? gameDir : root
        p.standardOutput = log
        p.standardError = log
        writeLog("Command: \(p.executableURL!.path) \(p.arguments!)\n")
        p.terminationHandler = { [weak self] child in
            DispatchQueue.main.async {
                self?.children.removeAll { $0 === child }
                self?.writeLog("Process ended: \(child.terminationStatus) at \(Date())\n")
                completion(child.terminationStatus)
            }
        }
        children.append(p)
        // Process spawning can wait in the macOS loader. Keep the native UI responsive.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try p.run()
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.writeLog("Process spawned: \(p.processIdentifier) at \(Date())\n")
                    if self.children.contains(where: { $0 === p }) { started?() }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.children.removeAll { $0 === p }
                    completion(-1)
                    self?.failed(error.localizedDescription)
                }
            }
        }
    }

    func runSetup(_ index: Int) {
        guard index < configuration.setup.count else {
            if configuration.runtimeProbe == true {
                status.stringValue = "Runtime initialization completed."
                return
            }
            let game = root.appendingPathComponent(configuration.prefix + "/drive_c/MapleRoyals/MapleRoyals.exe")
            guard FileManager.default.fileExists(atPath: game.path) else { failed("The game installation did not finish. Close and reopen the launcher to retry."); return }
            try? Data().write(to: setupMarker)
            launchGame()
            return
        }
        status.stringValue = "Preparing the game environment (\(index + 1)/\(configuration.setup.count))…"
        run(configuration.setup[index]) { [weak self] code in
            guard let self = self else { return }
            if code == 0 { self.runSetup(index + 1) }
            else { self.failed("Environment setup stopped with exit status \(code). See the log.") }
        }
    }

    @objc func launchGame() {
        runningGames += 1
        status.stringValue = "Starting the game. The first launch may take several minutes."
        playButton.isEnabled = false
        run(configuration.arguments, started: { [weak self] in
            self?.playButton.isEnabled = true
        }) { [weak self] code in
            guard let self = self else { return }
            self.runningGames = max(0, self.runningGames - 1)
            self.playButton.isEnabled = true
            self.status.stringValue = self.runningGames > 0 ? "\(self.runningGames) client process(es) running." : "The game closed (exit status \(code))."
        }
    }

    @objc func showLog() { if let url = logURL { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
    func failed(_ message: String) { status.stringValue = message; writeLog("Launcher error: \(message)\n") }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let launcher = MapleLauncher()
app.delegate = launcher
app.setActivationPolicy(.regular)
app.run()
