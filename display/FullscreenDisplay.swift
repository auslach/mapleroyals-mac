import AppKit
import CoreGraphics

// CGVirtualDisplay declarations are reused from MIT-licensed DeskPad.
// This helper changes display presentation only; it does not modify Wine or the game.
final class DisplayController: NSObject, NSApplicationDelegate {
    static let refreshRate: Double = (Bundle.main.object(forInfoDictionaryKey: "MapleRoyalsRefreshRate") as? NSNumber)?.intValue == 120 ? 120 : 60
    let resolutions = [(width: 800, height: 600), (width: 1024, height: 768)]
    var window: NSWindow!
    let message = NSTextField(wrappingLabelWithString: "Close the game, then choose a resolution. This scales the whole Mac screen with side bars. The test restores automatically after 20 seconds.")
    let resolution = NSPopUpButton(frame: .zero, pullsDown: false)
    let enable = NSButton(title: "Test 1024×768 display", target: nil, action: nil)
    let keep = NSButton(title: "Keep this display", target: nil, action: nil)
    let restore = NSButton(title: "Restore normal display", target: nil, action: nil)
    var virtualDisplay: CGVirtualDisplay?
    var physicalID: CGDirectDisplayID = 0
    var previousMode: CGDisplayMode?
    var rollbackTimer: Timer?
    let logURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let logs = support.appendingPathComponent("MapleRoyalsLauncher/logs")
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent(DisplayController.refreshRate == 120 ? "fullscreen-display-120.log" : "fullscreen-display.log")
    }()

    var selectedSize: (width: Int, height: Int) { resolutions[resolution.indexOfSelectedItem] }
    var resolutionLabel: String { "\(selectedSize.width)×\(selectedSize.height)" }

    @objc func selectResolution() {
        enable.title = "Test \(resolutionLabel) display"
    }

    func log(_ text: String) {
        let data = Data("\(Date()): \(text)\n".utf8)
        if let file = try? FileHandle(forWritingTo: logURL) {
            _ = try? file.seekToEnd(); try? file.write(contentsOf: data); try? file.close()
        } else { try? data.write(to: logURL) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let item = NSMenuItem(); menu.addItem(item)
        let submenu = NSMenu(); item.submenu = submenu
        submenu.addItem(withTitle: "Restore and Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 310), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "MapleRoyals Display — \(Int(Self.refreshRate)) Hz"
        window.isReleasedWhenClosed = false
        let title = NSTextField(labelWithString: "4:3 fullscreen presentation")
        title.font = .boldSystemFont(ofSize: 19)
        resolution.addItems(withTitles: resolutions.map { "\($0.width)×\($0.height)" })
        resolution.selectItem(at: 1)
        resolution.target = self; resolution.action = #selector(selectResolution)
        resolution.setAccessibilityLabel("Resolution")
        let choices = NSStackView(views: [NSTextField(labelWithString: "Resolution:"), resolution])
        choices.orientation = .horizontal; choices.spacing = 8
        enable.target = self; enable.action = #selector(enableDisplay)
        keep.target = self; keep.action = #selector(keepDisplay); keep.isEnabled = false
        restore.target = self; restore.action = #selector(restoreDisplay); restore.isEnabled = false
        let stack = NSStackView(views: [title, message, choices, enable, keep, restore])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 22),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        log("Ready at \(Int(Self.refreshRate)) Hz; no display change made")
    }

    @objc func enableDisplay() {
        guard virtualDisplay == nil else { return }
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &displays, &count) == .success,
              let builtIn = displays.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }),
              CGDisplayMirrorsDisplay(builtIn) == kCGNullDirectDisplay,
              let original = CGDisplayCopyDisplayMode(builtIn) else {
            message.stringValue = "Could not find an unmirrored built-in display. Nothing was changed."
            return
        }
        physicalID = builtIn; previousMode = original
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(.main)
        let size = selectedSize
        descriptor.name = "MapleRoyals 4:3 \(Int(Self.refreshRate)) Hz"
        descriptor.maxPixelsWide = UInt32(size.width); descriptor.maxPixelsHigh = UInt32(size.height)
        descriptor.sizeInMillimeters = CGSize(width: 320, height: 240)
        descriptor.productID = 0x4D52; descriptor.vendorID = 0xF0F0
        // Give each size/rate a stable identity so cached display modes cannot mix.
        descriptor.serialNum = 0x4D523410 + UInt32(resolution.indexOfSelectedItem * 2) + (Self.refreshRate == 120 ? 1 : 0)
        let display = CGVirtualDisplay(descriptor: descriptor)
        let options = CGVirtualDisplaySettings()
        options.hiDPI = 0
        options.modes = [CGVirtualDisplayMode(width: UInt(size.width), height: UInt(size.height), refreshRate: Self.refreshRate)]
        guard display.apply(options) else {
            message.stringValue = "macOS could not create the requested display mode."
            log("applySettings failed"); return
        }
        virtualDisplay = display
        log("Created virtual display \(display.displayID): \(size.width)x\(size.height) @\(Self.refreshRate); original \(original.width)x\(original.height) @\(original.refreshRate)")
        enable.isEnabled = false
        resolution.isEnabled = false
        restore.isEnabled = true
        // Give macOS one notification cycle to register the new display.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.mirrorDisplay() }
    }

    func mirrorDisplay() {
        guard let display = virtualDisplay else { return }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config = config else { restoreDisplay(); return }
        let result = CGConfigureDisplayMirrorOfDisplay(config, physicalID, display.displayID)
        guard result == .success else {
            CGCancelDisplayConfiguration(config)
            log("Mirror request failed: \(result.rawValue)"); restoreDisplay(); return
        }
        let completed = CGCompleteDisplayConfiguration(config, .forSession)
        log("Mirror completed: \(completed.rawValue)")
        guard completed == .success else { restoreDisplay(); return }
        message.stringValue = "Testing \(resolutionLabel) at \(Int(Self.refreshRate)) Hz with side bars. It restores in 20 seconds unless you choose Keep."
        keep.isEnabled = true
        window.center(); window.makeKeyAndOrderFront(nil)
        rollbackTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in self?.restoreDisplay() }
    }

    @objc func keepDisplay() {
        rollbackTimer?.invalidate(); rollbackTimer = nil
        keep.isEnabled = false
        message.stringValue = "\(resolutionLabel) display active. Use Option+Return inside the game if needed. Close the game and restore here before choosing a different resolution. Quitting also restores the display."
        log("User kept display")
    }

    @objc func restoreDisplay() {
        rollbackTimer?.invalidate(); rollbackTimer = nil
        guard virtualDisplay != nil else { return }
        var config: CGDisplayConfigRef?
        if CGBeginDisplayConfiguration(&config) == .success, let config = config {
            _ = CGConfigureDisplayMirrorOfDisplay(config, physicalID, kCGNullDirectDisplay)
            if let mode = previousMode { _ = CGConfigureDisplayWithDisplayMode(config, physicalID, mode, nil) }
            log("Restore completed: \(CGCompleteDisplayConfiguration(config, .forSession).rawValue)")
        }
        virtualDisplay = nil
        previousMode = nil
        enable.isEnabled = true; keep.isEnabled = false; restore.isEnabled = false
        resolution.isEnabled = true
        message.stringValue = "Normal display restored."
        window.center()
    }

    func applicationWillTerminate(_ notification: Notification) { restoreDisplay() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let controller = DisplayController()
app.delegate = controller
app.setActivationPolicy(.regular)
app.run()
