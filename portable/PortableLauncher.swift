import AppKit
import UniformTypeIdentifiers

final class PortableLauncher: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let heading = NSTextField(labelWithString: "MapleRoyals")
    let subtitle = NSTextField(labelWithString: "Your game, ready to open on your Mac.")
    let message = NSTextField(wrappingLabelWithString: "Checking this Mac…")
    let clientCount = NSTextField(labelWithString: "No game clients open")
    let selection = NSTextField(wrappingLabelWithString: "No installer selected")
    let primary = NSButton(title: "Play", target: nil, action: nil)
    let install = NSButton(title: "Install game", target: nil, action: nil)
    let back = NSButton(title: "Back to launcher", target: nil, action: nil)
    let choose = NSButton(title: "Choose game installer…", target: nil, action: nil)
    let update = NSButton(title: "Install downloaded update…", target: nil, action: nil)
    let download = NSButton(title: "Get the game installer", target: nil, action: nil)
    let logs = NSButton(title: "Show log", target: nil, action: nil)
    let files = NSButton(title: "Game files", target: nil, action: nil)
    let playPanel = NSStackView()
    let resolutionPanel = NSStackView()
    let settingsPanel = NSStackView()
    let installerPanel = NSStackView()
    let settingsActions = NSStackView()
    let settingsHeading = NSTextField(labelWithString: "Settings")
    let playDivider = NSBox()
    let resolutionDivider = NSBox()
    var showingError = false
    let progress = NSProgressIndicator()
    let displayChoice = NSPopUpButton(frame: .zero, pullsDown: false)
    let refreshChoice = NSPopUpButton(frame: .zero, pullsDown: false)
    let applyDisplay = NSButton(title: "Change screen resolution", target: nil, action: nil)
    var selectedDisplay = PlayDisplay.scaled800
    let restore = NSButton(title: "Restore normal display", target: nil, action: nil)
    let displayNote = NSTextField(wrappingLabelWithString: "Applies to the whole Mac screen. Your normal display returns after the last client closes. You can change resolution while playing.")
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
    var updatingGame = false
    // Worker activity is independent of temporary display changes.
    var busy = false
    let clients = GameClients()
    let clientCards = ClientCards(frame: .zero)
    var gameRunning: Bool { clients.count > 0 }
    var canChangeDisplay: Bool { !fatalStartupError && !preparingDisplay && !busy && !updatingGame }
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
            clients.didExit = { [weak self] client in self?.clientFinished(client) }
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
        let height = min(700, (NSScreen.main?.visibleFrame.height ?? 780) - 80)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: height),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.contentMinSize = NSSize(width: 560, height: 420)
        window.title = "MapleRoyals"
        window.isReleasedWhenClosed = false
        heading.font = .systemFont(ofSize: 30, weight: .bold)
        message.font = .systemFont(ofSize: 14)
        clientCount.textColor = .secondaryLabelColor
        selection.textColor = .secondaryLabelColor
        subtitle.textColor = .secondaryLabelColor
        let note = NSTextField(wrappingLabelWithString: "800×600 is recommended for smoother play. Fullscreen scaling does not fix 1024×768 graphics lag.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        for button in [primary, install, back, choose, download, update] { button.target = self }
        primary.action = #selector(primaryAction)
        primary.keyEquivalent = "\r"
        primary.controlSize = .large
        install.action = #selector(installAction)
        back.action = #selector(updateGameAction)
        choose.action = #selector(chooseInstaller)
        download.action = #selector(getInstaller)
        download.toolTip = "Opens the official website in your browser. Download the Windows WZ installer there."
        update.action = #selector(updateGameAction)
        logs.target = self; logs.action = #selector(showLog)
        files.target = self; files.action = #selector(showFiles)
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
        let buttons = NSStackView(views: [choose, install, back])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        settingsActions.orientation = .horizontal; settingsActions.spacing = 12
        for button in [update, logs, files] { settingsActions.addArrangedSubview(button) }
        progress.style = .bar
        progress.minValue = 0; progress.maxValue = 1
        progress.isIndeterminate = true
        progress.isHidden = true
        let playHeading = NSTextField(labelWithString: "Play")
        let resolutionHeading = NSTextField(labelWithString: "Resolution")
        for title in [playHeading, resolutionHeading, settingsHeading] {
            title.font = .systemFont(ofSize: 17, weight: .semibold)
        }
        for panel in [playPanel, resolutionPanel, settingsPanel, installerPanel] {
            panel.orientation = .vertical; panel.alignment = .leading; panel.spacing = 10
        }
        let playActions = NSStackView(views: [primary, clientCount])
        playActions.orientation = .horizontal; playActions.alignment = .centerY; playActions.spacing = 14
        for divider in [playDivider, resolutionDivider] { divider.boxType = .separator }
        for view in [playHeading, playActions, clientCards] as [NSView] { playPanel.addArrangedSubview(view) }
        for view in [resolutionHeading, displayOptions, displayButtons, displayNote, note] as [NSView] { resolutionPanel.addArrangedSubview(view) }
        for view in [download, selection, buttons] as [NSView] { installerPanel.addArrangedSubview(view) }
        for view in [settingsHeading, installerPanel, settingsActions] as [NSView] { settingsPanel.addArrangedSubview(view) }
        let stack = NSStackView(views: [heading, subtitle, message, progress, playPanel, playDivider, resolutionPanel, resolutionDivider, settingsPanel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedContentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.addSubview(stack)
        window.contentView!.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -26),
            playDivider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            resolutionDivider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            playPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            resolutionPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            settingsPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            installerPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor),
            selection.widthAnchor.constraint(equalTo: stack.widthAnchor),
            progress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor),
            displayNote.widthAnchor.constraint(equalTo: stack.widthAnchor),
            clientCards.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        primary.isEnabled = false
        install.isEnabled = false
        choose.isEnabled = false
        displayChoice.isEnabled = false; refreshChoice.isEnabled = false
        applyDisplay.isEnabled = false; restore.isHidden = true
        refreshLayout()
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
                    self.message.stringValue = "Ready. Apply a resolution below if wanted, then click Play."
                } else {
                    self.message.stringValue = "Download the Windows WZ installer from MapleRoyals, then choose that file here. This app prepares everything else."
                }
            }
        }
    }

    func refreshControls() {
        clientCards.setClients(Array(clients.clients.values))
        refreshLayout()
        let readyToPlay = installation?.ready == true && !needsRosetta
        primary.title = readyToPlay ? (gameRunning ? "Open another client" : "Play") : "Set up game…"
        clientCount.stringValue = clients.count == 0 ? "No game clients open" : "\(clients.count) game client\(clients.count == 1 ? "" : "s") open"
        primary.isEnabled = !busy && !preparingDisplay && !fatalStartupError && !updatingGame
        primary.keyEquivalent = readyToPlay && !updatingGame ? "\r" : ""
        install.title = needsRosetta ? "Enable Rosetta" : (updatingGame ? "Run selected installer" : "Install game")
        install.isEnabled = !busy && !preparingDisplay && !fatalStartupError && !gameRunning && (needsRosetta || installer != nil) && (needsRosetta || updatingGame || installation?.ready != true)
        install.keyEquivalent = updatingGame || !readyToPlay ? "\r" : ""
        choose.title = needsRosetta ? "Check again" : "Choose WZ installer…"
        choose.isEnabled = !busy && !preparingDisplay && !fatalStartupError && (needsRosetta || updatingGame || installation?.ready != true)
        choose.isHidden = !needsRosetta && !updatingGame && installation?.ready == true
        update.isHidden = updatingGame || needsRosetta || installation?.ready != true
        update.isEnabled = !busy && !preparingDisplay && !fatalStartupError && !gameRunning
        update.toolTip = gameRunning ? "Close all game clients before installing new game files." : "Install an official WZ .exe that you downloaded yourself."
        back.isHidden = !updatingGame
        back.isEnabled = update.isEnabled
        back.toolTip = "Return to the launcher without starting the installer."
        download.title = "Open download page"
        download.isHidden = needsRosetta
        download.isEnabled = !busy && !preparingDisplay
        displayChoice.isEnabled = canChangeDisplay
        refreshChoice.isEnabled = canChangeDisplay && selectedDisplay != .normal
        applyDisplay.title = awaitingDisplayConfirmation ? "Keep resolution" : "Change screen resolution"
        applyDisplay.isEnabled = awaitingDisplayConfirmation || (canChangeDisplay && gameDisplay != nil)
        restore.title = preparingDisplay ? "Cancel test" : "Restore normal display"
        restore.isHidden = gameDisplay?.active != true
        restore.isEnabled = gameDisplay?.active == true
        selection.isHidden = needsRosetta || (!updatingGame && installation?.ready == true)
    }

    func refreshLayout() {
        playPanel.isHidden = updatingGame
        resolutionPanel.isHidden = updatingGame
        playDivider.isHidden = updatingGame
        resolutionDivider.isHidden = updatingGame
        settingsHeading.isHidden = updatingGame
        clientCards.isHidden = !gameRunning
        let installing = updatingGame || needsRosetta || installation?.ready != true
        installerPanel.isHidden = !installing
        settingsActions.isHidden = updatingGame && !showingError
        files.isHidden = updatingGame
        subtitle.stringValue = updatingGame ? "Install downloaded game files" : "Your game, ready to open on your Mac."
    }

    func savePreferences() throws {
        try JSONEncoder().encode(preferences).write(to: preferencesURL, options: .atomic)
    }

    @objc func changePlayOptions() {
        guard canChangeDisplay else { return }
        selectedDisplay = PlayDisplay.allCases[displayChoice.indexOfSelectedItem]
        preferences.refreshRate = refreshChoice.indexOfSelectedItem == 1 ? 120 : 60
        do { try savePreferences(); refreshControls() }
        catch { showError(error) }
    }

    @objc func primaryAction() {
        guard !busy, !preparingDisplay, !fatalStartupError, !updatingGame else { return }
        guard installation?.ready == true, !needsRosetta else {
            settingsPanel.scrollToVisible(settingsPanel.bounds)
            return
        }
        start(install: false)
    }

    @objc func installAction() {
        guard !busy, !preparingDisplay, !fatalStartupError, !gameRunning else { return }
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
        guard updatingGame || !installation.ready else { return }
        start(install: true)
    }

    @objc func updateGameAction() {
        guard !busy, !preparingDisplay, !needsRosetta, !fatalStartupError, !gameRunning else { return }
        guard updatingGame || installation.ready else { return }
        updatingGame.toggle()
        showingError = false
        installer = nil
        selection.stringValue = "No installer selected"
        message.stringValue = updatingGame
            ? "Download the latest Windows WZ installer from the MapleRoyals website, then choose that .exe below and run it. Your current installation is kept if installation fails."
            : "Ready. Apply a resolution below if wanted, then click Play."
        refreshControls()
    }

    @objc func chooseInstaller() {
        if needsRosetta { checkCompatibility(); return }
        let panel = NSOpenPanel()
        panel.title = "Choose the MapleRoyals Windows WZ installer"
        panel.message = updatingGame ? "Select the latest Windows WZ .exe you downloaded from the MapleRoyals website." : "Select the .exe downloaded from the official MapleRoyals website."
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
        guard !busy, !preparingDisplay, !needsRosetta, !fatalStartupError else { return }
        if install && installer == nil { chooseInstaller(); return }
        if install {
            guard !gameRunning else { return }
            showingError = false
            busy = true
            refreshControls()
            updateProgress("Preparing the installation…", nil)
            let selected = installer!
            let isUpdate = updatingGame
            worker.async {
                do {
                    if isUpdate { try self.installation.updateGame(selected) }
                    else { try self.installation.install(selected) }
                    DispatchQueue.main.async {
                        self.busy = false
                        self.updatingGame = false
                        self.installer = nil
                        self.selection.stringValue = "No installer selected"
                        self.progress.stopAnimation(nil); self.progress.isHidden = true
                        self.message.stringValue = isUpdate ? "Game files installed. Click Play when you want to start the game. Your previous installation is saved in Settings → Game files → backups." : "Installation ready. Apply a resolution below if wanted, then click Play to start the game."
                        if self.installation.requiresUpdateRecovery {
                            self.fatalStartupError = true
                            self.message.stringValue = "The update needs recovery before playing. Quit and reopen the launcher. Your files are preserved."
                        }
                        self.refreshControls()
                    }
                } catch {
                    DispatchQueue.main.async {
                        if self.installation.requiresUpdateRecovery { self.fatalStartupError = true }
                        self.finishSession(error)
                    }
                }
            }
        } else { launchGame() }
    }

    @objc func applyDisplayAction() {
        if awaitingDisplayConfirmation {
            confirmationTimer?.invalidate(); confirmationTimer = nil
            if let key = pendingDisplayKey { preferences.confirmedDisplays.insert(key) }
            do { try savePreferences() }
            catch { finishDisplay(error); return }
            displayReady()
            return
        }
        guard canChangeDisplay else { return }
        if let failure = gameDisplay.restore() {
            showError(SetupError(message: failure))
            return
        }
        guard selectedDisplay != .normal else {
            message.stringValue = gameRunning ? "Normal display restored. The game session is still running." : "Normal display restored. Click Play to start the game."
            window.center(); refreshControls()
            return
        }
        updateProgress("Changing screen resolution…", nil)
        preparingDisplay = true
        gameDisplay.start(selectedDisplay, refreshRate: preferences.refreshRate) { result in
            switch result {
            case .failure(let error): self.finishDisplay(error)
            case .success(let key):
                self.fitWindowToScreen(); self.window.makeKeyAndOrderFront(nil)
                if self.preferences.confirmedDisplays.contains(key) {
                    self.displayReady()
                } else {
                    self.pendingDisplayKey = key
                    self.awaitingDisplayConfirmation = true
                    self.progress.stopAnimation(nil); self.progress.isHidden = true
                    self.message.stringValue = "Does the display look right? Choose Keep resolution within 20 seconds, or your normal display returns. This only changes the display."
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
        progress.stopAnimation(nil); progress.isHidden = true
        message.stringValue = gameRunning ? "Screen resolution applied. The game session is still running." : "Screen resolution applied. Click Play when you want to start the game."
        fitWindowToScreen()
        refreshControls()
    }

    func fitWindowToScreen() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        var frame = window.frame
        frame.size.width = min(frame.width, screen.visibleFrame.width)
        frame.size.height = min(frame.height, screen.visibleFrame.height)
        window.setFrame(frame, display: true)
        window.center()
    }

    func finishDisplay(_ error: Error? = nil) {
        confirmationTimer?.invalidate(); confirmationTimer = nil
        pendingDisplayKey = nil; preparingDisplay = false; awaitingDisplayConfirmation = false
        let failure = gameDisplay.restore()
        progress.stopAnimation(nil); progress.isHidden = true
        if let error = error { showError(error) }
        else {
            message.stringValue = gameRunning ? "Normal display restored. The game session is still running." : "Normal display restored. Click Change screen resolution to try again, or Play to use your current display."
        }
        if let failure = failure { message.stringValue += " " + failure }
        window.center(); refreshControls()
    }

    func cancelDisplayTest() { finishDisplay() }

    @objc func restoreDisplayNow() {
        if preparingDisplay { cancelDisplayTest(); return }
        let failure = gameDisplay.restore()
        message.stringValue = failure ?? (gameRunning ? "Normal display restored. The game session is still running." : "Normal display restored. Click Play to start the game.")
        window.center(); refreshControls()
    }

    func launchGame() {
        do {
            let id = UUID()
            let process = try installation.gameProcess(clientID: id, allowCompatibilityChanges: !gameRunning)
            let client = try clients.start(id: id, process: process)
            installation.note("Client \(client.number) started: \(id); PID \(process.processIdentifier); \(clients.count) clients open")
            message.stringValue = "Opening client \(client.number)… You can open another client from this launcher."
            progress.stopAnimation(nil); progress.isHidden = true
            refreshControls()
        } catch {
            if gameRunning { showError(error) }
            else { finishSession(error) }
        }
    }

    func clientFinished(_ client: GameClients.Client) {
        let status = client.process.terminationStatus
        installation.note("Client \(client.number) closed: \(client.id); PID \(client.process.processIdentifier); exit \(status); \(clients.count) clients remain")
        let error: Error? = status == 0 ? nil : SetupError(message: "Client \(client.number) closed with code \(status). Use Show log under Settings for details.")
        if gameRunning {
            // Keep active games and any in-progress display confirmation intact.
            if !preparingDisplay {
                message.stringValue = error?.localizedDescription ?? "Client \(client.number) closed. Your other game clients are still running."
            }
            refreshControls()
        } else { finishSession(error) }
    }

    func finishSession(_ error: Error?) {
        guard !gameRunning else { return }
        confirmationTimer?.invalidate(); confirmationTimer = nil
        preparingDisplay = false; awaitingDisplayConfirmation = false; pendingDisplayKey = nil
        let wasScaled = gameDisplay?.active == true
        let restoreFailure = gameDisplay?.restore()
        busy = false
        progress.stopAnimation(nil); progress.isHidden = true
        if let error = error { showError(error) }
        else { message.stringValue = wasScaled && restoreFailure == nil ? "All game clients have closed and your normal display is restored. Click Play to open a new client." : "All game clients have closed. Click Play to open a new client." }
        if let failure = restoreFailure { message.stringValue += " " + failure }
        window.center(); refreshControls()
    }

    func updateProgress(_ text: String, _ fraction: Double?) {
        // A late Wine progress callback must not obscure a live display confirmation.
        guard !gameRunning || !preparingDisplay else { return }
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
        showingError = true
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
        if preparingDisplay { cancelDisplayTest() }
        if busy || gameRunning {
            let alert = NSAlert()
            alert.messageText = "Finish setup or close all game clients first"
            alert.informativeText = "The launcher is still managing this session. Leave it open until every game client or the installer has closed."
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
