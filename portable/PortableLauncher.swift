import AppKit
import UniformTypeIdentifiers

final class PortableLauncher: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let heading = NSTextField(labelWithString: "MapleRoyals")
    let message = NSTextField(wrappingLabelWithString: "Checking this Mac…")
    let selection = NSTextField(wrappingLabelWithString: "No installer selected")
    let primary = NSButton(title: "Install & Play", target: nil, action: nil)
    let choose = NSButton(title: "Choose game installer…", target: nil, action: nil)
    let download = NSButton(title: "Get the game installer", target: nil, action: nil)
    let progress = NSProgressIndicator()
    let worker = DispatchQueue(label: "local.mapleroyals.setup", qos: .userInitiated)
    var installation: PortableInstallation!
    var installer: URL?
    var busy = false
    var needsRosetta = false
    var fatalStartupError = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        createWindow()
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
            installation = PortableInstallation(root: support.appendingPathComponent("MapleRoyalsLauncher"),
                                                resources: Bundle.main.resourceURL!) { [weak self] text, fraction in
                DispatchQueue.main.async { self?.updateProgress(text, fraction) }
            }
            try installation.open()
            checkCompatibility(autoPlay: true)
        } catch {
            fatalStartupError = true
            showError(error)
        }
    }

    func createWindow() {
        let menu = NSMenu()
        let item = NSMenuItem(); menu.addItem(item)
        let submenu = NSMenu(); item.submenu = submenu
        submenu.addItem(withTitle: "Quit MapleRoyals", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "MapleRoyals"
        window.isReleasedWhenClosed = false
        heading.font = .systemFont(ofSize: 30, weight: .bold)
        message.font = .systemFont(ofSize: 14)
        selection.textColor = .secondaryLabelColor
        let subtitle = NSTextField(labelWithString: "Your game, ready to open on your Mac.")
        subtitle.textColor = .secondaryLabelColor
        let note = NSTextField(wrappingLabelWithString: "Experimental preview. Start with 800×600 for the smoother tested result. The game is downloaded separately.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        for button in [primary, choose, download] { button.target = self }
        primary.action = #selector(primaryAction)
        primary.keyEquivalent = "\r"
        choose.action = #selector(chooseInstaller)
        download.action = #selector(getInstaller)
        let logs = NSButton(title: "Show log", target: self, action: #selector(showLog))
        let files = NSButton(title: "Game files", target: self, action: #selector(showFiles))
        let buttons = NSStackView(views: [primary, choose])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        let utilities = NSStackView(views: [download, logs, files])
        utilities.orientation = .horizontal
        utilities.spacing = 12
        progress.style = .bar
        progress.minValue = 0; progress.maxValue = 1
        progress.isIndeterminate = true
        progress.isHidden = true
        let stack = NSStackView(views: [heading, subtitle, message, selection, progress, buttons, utilities, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 26),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor),
            selection.widthAnchor.constraint(equalTo: stack.widthAnchor),
            progress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        primary.isEnabled = false
        choose.isEnabled = false
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func intelExecutionWorks() -> Bool {
        let check = Process()
        check.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
        check.arguments = ["-x86_64", "/usr/bin/uname", "-m"]
        check.standardOutput = FileHandle.nullDevice
        check.standardError = FileHandle.nullDevice
        do { try check.run(); check.waitUntilExit(); return check.terminationStatus == 0 }
        catch { return false }
    }

    func checkCompatibility(autoPlay: Bool) {
        let os = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        guard os >= 14, os <= 27 else {
            fatalStartupError = true
            showError(SetupError(message: "This preview targets macOS 14–27 on Apple silicon. This Wine engine needs Rosetta, whose general availability changes in macOS 28."))
            return
        }
        busy = true
        worker.async {
            let works = Self.intelExecutionWorks()
            DispatchQueue.main.async {
                self.busy = false
                self.needsRosetta = !works
                self.refreshControls()
                if !works {
                    self.message.stringValue = "Apple's Rosetta is needed to run the game. Click Enable Rosetta and complete Apple's installation prompt, then click Check again."
                } else if self.installation.ready {
                    self.message.stringValue = "Ready to play."
                    if autoPlay { self.start(install: false) }
                } else {
                    self.message.stringValue = "Download the Windows WZ installer from MapleRoyals, then choose that file here. This app prepares everything else."
                }
            }
        }
    }

    func refreshControls() {
        primary.title = needsRosetta ? "Enable Rosetta" : (installation?.ready == true ? "Play" : "Install & Play")
        choose.title = needsRosetta ? "Check again" : "Choose game installer…"
        primary.isEnabled = !busy && !fatalStartupError && (needsRosetta || installation?.ready == true || installer != nil)
        choose.isEnabled = !busy && !fatalStartupError && (needsRosetta || installation?.ready != true)
        download.isEnabled = !busy
        selection.isHidden = needsRosetta || installation?.ready == true
    }

    @objc func primaryAction() {
        if needsRosetta {
            let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/Intel Compatibility.app")
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: helper, configuration: config) { _, error in
                DispatchQueue.main.async {
                    if let error = error { self.showError(error) }
                    else { self.checkCompatibility(autoPlay: false) }
                }
            }
            return
        }
        start(install: !installation.ready)
    }

    @objc func chooseInstaller() {
        if needsRosetta { checkCompatibility(autoPlay: false); return }
        let panel = NSOpenPanel()
        panel.title = "Choose the MapleRoyals Windows WZ installer"
        panel.message = "Select the .exe downloaded from the official MapleRoyals website."
        panel.allowedContentTypes = [UTType(filenameExtension: "exe") ?? .data]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                self.installer = url
                self.selection.stringValue = url.lastPathComponent
                self.refreshControls()
            }
        }
    }

    func start(install: Bool) {
        guard !busy, !needsRosetta, !fatalStartupError else { return }
        if install && installer == nil { chooseInstaller(); return }
        busy = true
        refreshControls()
        updateProgress(install ? "Preparing the installation…" : "Opening MapleRoyals…", nil)
        let selected = installer
        worker.async {
            do {
                if install { try self.installation.install(selected!) }
                try self.installation.play()
                DispatchQueue.main.async {
                    self.busy = false
                    self.progress.stopAnimation(nil); self.progress.isHidden = true
                    self.message.stringValue = "The game has closed. Click Play whenever you're ready."
                    self.refreshControls()
                }
            } catch {
                DispatchQueue.main.async {
                    self.busy = false
                    self.showError(error)
                    self.refreshControls()
                }
            }
        }
    }

    func updateProgress(_ text: String, _ fraction: Double?) {
        message.stringValue = text
        progress.isHidden = false
        if let fraction = fraction {
            progress.stopAnimation(nil)
            progress.isIndeterminate = false
            progress.doubleValue = fraction
        } else {
            progress.isIndeterminate = true
            progress.startAnimation(nil)
        }
    }

    func showError(_ error: Error) {
        message.stringValue = error.localizedDescription
        installation?.note("Error: \(error.localizedDescription)")
        progress.stopAnimation(nil); progress.isHidden = true
        refreshControls()
    }

    @objc func getInstaller() { NSWorkspace.shared.open(URL(string: "https://royals.ms/downloads")!) }
    @objc func showLog() {
        if let path = installation?.logURL { NSWorkspace.shared.activateFileViewerSelecting([path]) }
    }
    @objc func showFiles() {
        if let root = installation?.root { NSWorkspace.shared.open(root) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy {
            let alert = NSAlert()
            alert.messageText = "Finish setup or close the game first"
            alert.informativeText = "The launcher is still managing this session. Leave it open until the game or installer has closed."
            alert.addButton(withTitle: "Keep open")
            alert.runModal()
            window.makeKeyAndOrderFront(nil)
            return .terminateCancel
        }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct MapleRoyalsApp {
    static func main() {
        let app = NSApplication.shared
        let launcher = PortableLauncher()
        app.delegate = launcher
        app.setActivationPolicy(.regular)
        app.run()
    }
}
