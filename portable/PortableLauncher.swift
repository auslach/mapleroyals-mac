import AppKit
import UniformTypeIdentifiers

final class PortableLauncher: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let heading = NSTextField(labelWithString: "MapleRoyals")
    let message = NSTextField(wrappingLabelWithString: "Checking this Mac…")
    let selection = NSTextField(wrappingLabelWithString: "No installer selected")
    let primary = NSButton(title: "Install game", target: nil, action: nil)
    let choose = NSButton(title: "Choose game installer…", target: nil, action: nil)
    let download = NSButton(title: "Get the game installer", target: nil, action: nil)
    let progress = NSProgressIndicator()
    let displayChoice = NSPopUpButton(frame: .zero, pullsDown: false)
    let refreshChoice = NSPopUpButton(frame: .zero, pullsDown: false)
    let applyDisplay = NSButton(title: "Change screen resolution", target: nil, action: nil)
    var selectedDisplay = PlayDisplay.scaled800
    let restore = NSButton(title: "Restore normal display", target: nil, action: nil)
    let displayNote = NSTextField(wrappingLabelWithString: "Change screen resolution applies the selected size to the whole Mac screen. Play starts only the game. Your normal display returns when the game closes.")
    var preferences = PlayPreferences()
    var gameDisplay: GameDisplay!
    var preparingDisplay = false
    var awaitingDisplayConfirmation = false
    var confirmationTimer: Timer?
    var pendingDisplayKey: String?
    var preferencesURL: URL { installation.root.appendingPathComponent("play-preferences.json") }
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
            gameDisplay = GameDisplay { [weak self] text in self?.installation?.note(text) }
            if FileManager.default.fileExists(atPath: preferencesURL.path) {
                preferences = try JSONDecoder().decode(PlayPreferences.self, from: Data(contentsOf: preferencesURL))
                if ![60, 120].contains(preferences.refreshRate) { preferences.refreshRate = 60 }
            }
            displayChoice.selectItem(at: PlayDisplay.allCases.firstIndex(of: selectedDisplay) ?? 0)
            refreshChoice.selectItem(at: preferences.refreshRate == 120 ? 1 : 0)
            checkCompatibility()
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
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
        displayChoice.addItems(withTitles: PlayDisplay.allCases.map(\.title))
        displayChoice.setAccessibilityLabel("Display")
        refreshChoice.addItems(withTitles: ["60 Hz", "120 Hz"])
        refreshChoice.setAccessibilityLabel("Refresh rate")
        for control in [displayChoice, refreshChoice] {
            control.target = self; control.action = #selector(changePlayOptions)
        }
        applyDisplay.target = self; applyDisplay.action = #selector(applyDisplayAction)
        restore.target = self; restore.action = #selector(restoreDisplayNow)
        let displayOptions = NSStackView(views: [NSTextField(labelWithString: "Display:"), displayChoice, refreshChoice])
        displayOptions.orientation = .horizontal; displayOptions.spacing = 8
        displayNote.font = .systemFont(ofSize: 11)
        displayNote.textColor = .secondaryLabelColor
        let displayButtons = NSStackView(views: [applyDisplay, restore])
        displayButtons.orientation = .horizontal; displayButtons.spacing = 12
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
        let stack = NSStackView(views: [heading, subtitle, message, displayOptions, displayButtons, displayNote, selection, progress, buttons, utilities, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 26),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor),
            selection.widthAnchor.constraint(equalTo: stack.widthAnchor),
            progress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor),
            displayNote.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        primary.isEnabled = false
        choose.isEnabled = false
        displayChoice.isEnabled = false; refreshChoice.isEnabled = false
        applyDisplay.isEnabled = false; restore.isHidden = true
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

    func checkCompatibility() {
        let os = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        guard os >= 14, os <= 27 else {
            fatalStartupError = true
            showError(SetupError(message: "This preview targets macOS 14–27 on Apple silicon. This Wine engine needs Rosetta, whose general availability changes in macOS 28."))
            return
        }
        busy = true
        refreshControls()
        worker.async {
            let works = Self.intelExecutionWorks()
            DispatchQueue.main.async {
                self.busy = false
                self.needsRosetta = !works
                self.refreshControls()
                if !works {
                    self.message.stringValue = "Apple's Rosetta is needed to run the game. Click Enable Rosetta and complete Apple's installation prompt, then click Check again."
                } else if self.installation.ready {
                    self.message.stringValue = "Ready. Change screen resolution if wanted, then click Play. Opening the launcher does not change your display or start the game."
                } else {
                    self.message.stringValue = "Download the Windows WZ installer from MapleRoyals, then choose that file here. This app prepares everything else."
                }
            }
        }
    }

    func refreshControls() {
        primary.title = needsRosetta ? "Enable Rosetta" : (installation?.ready == true ? "Play" : "Install game")
        primary.isEnabled = !busy && !fatalStartupError && (needsRosetta || installation?.ready == true || installer != nil)
        choose.title = needsRosetta ? "Check again" : "Choose game installer…"
        choose.isEnabled = !busy && !fatalStartupError && (needsRosetta || installation?.ready != true)
        choose.isHidden = !needsRosetta && installation?.ready == true
        download.isEnabled = !busy
        displayChoice.isEnabled = !busy && !fatalStartupError
        refreshChoice.isEnabled = !busy && !fatalStartupError && selectedDisplay != .normal
        applyDisplay.title = awaitingDisplayConfirmation ? "Keep resolution" : "Change screen resolution"
        applyDisplay.isEnabled = awaitingDisplayConfirmation || (!busy && !fatalStartupError && gameDisplay != nil)
        restore.title = preparingDisplay ? "Cancel test" : "Restore normal display"
        restore.isHidden = gameDisplay?.active != true
        restore.isEnabled = gameDisplay?.active == true
        selection.isHidden = needsRosetta || installation?.ready == true
    }

    func savePreferences() throws {
        try JSONEncoder().encode(preferences).write(to: preferencesURL, options: .atomic)
    }

    @objc func changePlayOptions() {
        guard !busy, !fatalStartupError else { return }
        selectedDisplay = PlayDisplay.allCases[displayChoice.indexOfSelectedItem]
        preferences.refreshRate = refreshChoice.indexOfSelectedItem == 1 ? 120 : 60
        do { try savePreferences(); refreshControls() }
        catch { showError(error) }
    }

    @objc func primaryAction() {
        if needsRosetta {
            let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/Intel Compatibility.app")
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: helper, configuration: config) { _, error in
                DispatchQueue.main.async {
                    if let error = error { self.showError(error) }
                    else { self.checkCompatibility() }
                }
            }
            return
        }
        start(install: !installation.ready)
    }

    @objc func chooseInstaller() {
        if needsRosetta { checkCompatibility(); return }
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
        if install {
            updateProgress("Preparing the installation…", nil)
            let selected = installer!
            worker.async {
                do {
                    try self.installation.install(selected)
                    DispatchQueue.main.async {
                        self.busy = false
                        self.progress.stopAnimation(nil); self.progress.isHidden = true
                        self.message.stringValue = "Installation ready. Change screen resolution if wanted, then click Play to start the game."
                        self.refreshControls()
                    }
                } catch {
                    DispatchQueue.main.async { self.finishSession(error) }
                }
            }
        } else { launchGame() }
    }

    @objc func applyDisplayAction() {
        if awaitingDisplayConfirmation {
            confirmationTimer?.invalidate(); confirmationTimer = nil
            if let key = pendingDisplayKey { preferences.confirmedDisplays.insert(key) }
            do { try savePreferences() }
            catch { finishSession(error); return }
            displayReady()
            return
        }
        guard !busy, !fatalStartupError else { return }
        if let failure = gameDisplay.restore() {
            showError(SetupError(message: failure))
            return
        }
        guard selectedDisplay != .normal else {
            message.stringValue = "Normal display restored. Click Play to start the game."
            window.center(); refreshControls()
            return
        }
        busy = true; preparingDisplay = true
        updateProgress("Changing screen resolution…", nil)
        gameDisplay.start(selectedDisplay, refreshRate: preferences.refreshRate) { result in
            switch result {
            case .failure(let error): self.finishSession(error)
            case .success(let key):
                self.window.center(); self.window.makeKeyAndOrderFront(nil)
                if self.preferences.confirmedDisplays.contains(key) {
                    self.displayReady()
                } else {
                    self.pendingDisplayKey = key
                    self.awaitingDisplayConfirmation = true
                    self.progress.stopAnimation(nil); self.progress.isHidden = true
                    self.message.stringValue = "Does the display look right? Choose Keep resolution within 20 seconds, or your normal display returns. This does not start the game."
                    self.confirmationTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
                        self?.cancelDisplayTest()
                    }
                    self.refreshControls()
                }
            }
        }
        refreshControls()
    }

    func displayReady() {
        pendingDisplayKey = nil; preparingDisplay = false; awaitingDisplayConfirmation = false
        busy = false
        progress.stopAnimation(nil); progress.isHidden = true
        message.stringValue = "Screen resolution applied. Click Play when you want to start the game."
        refreshControls()
    }

    func cancelDisplayTest() {
        confirmationTimer?.invalidate(); confirmationTimer = nil
        pendingDisplayKey = nil; preparingDisplay = false; awaitingDisplayConfirmation = false
        let failure = gameDisplay.restore()
        busy = false
        progress.stopAnimation(nil); progress.isHidden = true
        message.stringValue = failure ?? "Normal display restored. The game was not started. Click Change screen resolution to try again, or Play to use your current display."
        window.center(); refreshControls()
    }

    @objc func restoreDisplayNow() {
        if preparingDisplay { cancelDisplayTest(); return }
        let failure = gameDisplay.restore()
        message.stringValue = failure ?? (busy ? "Normal display restored. Close the game before changing display options." : "Normal display restored. Click Play to start the game.")
        window.center(); refreshControls()
    }

    func launchGame() {
        preparingDisplay = false; awaitingDisplayConfirmation = false
        updateProgress("Opening MapleRoyals…", nil)
        refreshControls()
        worker.async {
            do {
                try self.installation.play()
                DispatchQueue.main.async { self.finishSession(nil) }
            } catch {
                DispatchQueue.main.async { self.finishSession(error) }
            }
        }
    }

    func finishSession(_ error: Error?) {
        confirmationTimer?.invalidate(); confirmationTimer = nil
        preparingDisplay = false; awaitingDisplayConfirmation = false; pendingDisplayKey = nil
        let wasScaled = gameDisplay?.active == true
        let restoreFailure = gameDisplay?.restore()
        busy = false
        progress.stopAnimation(nil); progress.isHidden = true
        if let error = error { showError(error) }
        else { message.stringValue = wasScaled && restoreFailure == nil ? "The game has closed and your normal display is restored. Apply a screen resolution if wanted, then click Play." : "The game has closed. Apply a screen resolution if wanted, then click Play." }
        if let failure = restoreFailure { message.stringValue += " " + failure }
        window.center(); refreshControls()
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
        if preparingDisplay { cancelDisplayTest(); return .terminateNow }
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
    func applicationWillTerminate(_ notification: Notification) {
        confirmationTimer?.invalidate()
        _ = gameDisplay?.restore()
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
