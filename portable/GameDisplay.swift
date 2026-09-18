import AppKit
import CoreGraphics

struct PlayPreferences: Codable {
    var refreshRate = 60
    var confirmedDisplays: Set<String> = []
}

enum PlayDisplay: String, Codable, CaseIterable {
    case normal, scaled800, scaled1024
    var title: String {
        switch self {
        case .normal: return "Normal Mac display"
        case .scaled800: return "Fullscreen scaling — 800×600"
        case .scaled1024: return "Fullscreen scaling — 1024×768"
        }
    }
    var size: (width: Int, height: Int)? {
        switch self {
        case .normal: return nil
        case .scaled800: return (800, 600)
        case .scaled1024: return (1024, 768)
        }
    }
}

// Uses the same DeskPad-derived CoreGraphics declarations as the standalone helper.
// All display work, including callbacks and cancellation, stays on the AppKit thread.
final class GameDisplay {
    private var display: CGVirtualDisplay?
    private var physicalID: CGDirectDisplayID = 0
    private var previousMode: CGDisplayMode?
    private var generation = 0
    let log: (String) -> Void
    var active: Bool { display != nil }

    init(log: @escaping (String) -> Void) { self.log = log }

    func start(_ choice: PlayDisplay, refreshRate: Int, completion: @escaping (Result<String, Error>) -> Void) {
        precondition(Thread.isMainThread)
        guard let size = choice.size, [60, 120].contains(refreshRate), !active else {
            completion(.failure(SetupError(message: "Restore the existing display before changing fullscreen settings.")))
            return
        }
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &displays, &count) == .success,
              let builtIn = displays.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }),
              CGDisplayMirrorsDisplay(builtIn) == kCGNullDirectDisplay,
              let original = CGDisplayCopyDisplayMode(builtIn) else {
            completion(.failure(SetupError(message: "Fullscreen needs an unmirrored built-in display. Restore and quit any separate display helper, or choose Normal Mac display.")))
            return
        }
        let uuid = CGDisplayCreateUUIDFromDisplayID(builtIn).takeRetainedValue()
        let identity = CFUUIDCreateString(nil, uuid) as String
        let key = "\(identity):macOS\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion):\(choice.rawValue):\(refreshRate)"
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(.main)
        descriptor.name = "MapleRoyals \(size.width)×\(size.height) \(refreshRate) Hz"
        descriptor.maxPixelsWide = UInt32(size.width); descriptor.maxPixelsHigh = UInt32(size.height)
        descriptor.sizeInMillimeters = CGSize(width: 320, height: 240)
        descriptor.productID = 0x4D52; descriptor.vendorID = 0xF0F0
        descriptor.serialNum = 0x4D523410 + (choice == .scaled1024 ? 2 : 0) + (refreshRate == 120 ? 1 : 0)
        let virtual = CGVirtualDisplay(descriptor: descriptor)
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 0
        settings.modes = [CGVirtualDisplayMode(width: UInt(size.width), height: UInt(size.height), refreshRate: Double(refreshRate))]
        guard virtual.apply(settings) else {
            completion(.failure(SetupError(message: "macOS could not create the selected fullscreen display. Try Normal Mac display.")))
            return
        }
        physicalID = builtIn; previousMode = original; display = virtual
        generation += 1
        let request = generation
        log("Display created: \(size.width)x\(size.height) @\(refreshRate); original \(original.width)x\(original.height) @\(original.refreshRate)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.generation == request, let virtual = self.display else { return }
            var config: CGDisplayConfigRef?
            guard CGBeginDisplayConfiguration(&config) == .success, let config = config else {
                _ = self.restore()
                completion(.failure(SetupError(message: "macOS could not begin fullscreen configuration.")))
                return
            }
            let mirror = CGConfigureDisplayMirrorOfDisplay(config, builtIn, virtual.displayID)
            guard mirror == .success else {
                CGCancelDisplayConfiguration(config)
                _ = self.restore()
                completion(.failure(SetupError(message: "macOS rejected fullscreen mirroring (\(mirror.rawValue)).")))
                return
            }
            let result = CGCompleteDisplayConfiguration(config, .forSession)
            self.log("Display mirror completed: \(result.rawValue)")
            guard result == .success else {
                _ = self.restore()
                completion(.failure(SetupError(message: "macOS could not finish fullscreen configuration (\(result.rawValue)).")))
                return
            }
            completion(.success(key))
        }
    }

    @discardableResult
    func restore() -> String? {
        precondition(Thread.isMainThread)
        generation += 1 // Cancel a pending mirror callback before it can change a later session.
        guard display != nil else { return nil }
        var config: CGDisplayConfigRef?
        var failure: String?
        if CGBeginDisplayConfiguration(&config) == .success, let config = config {
            let unmirror = CGConfigureDisplayMirrorOfDisplay(config, physicalID, kCGNullDirectDisplay)
            let mode = previousMode.map { CGConfigureDisplayWithDisplayMode(config, physicalID, $0, nil) } ?? .success
            let result = CGCompleteDisplayConfiguration(config, .forSession)
            log("Display restore: unmirror=\(unmirror.rawValue), mode=\(mode.rawValue), complete=\(result.rawValue)")
            if unmirror != .success || mode != .success || result != .success {
                failure = "The temporary display was removed, but macOS could not reapply every previous display setting. Check System Settings → Displays."
            }
        } else {
            failure = "The temporary display was removed. If your display still looks wrong, check System Settings → Displays."
            log("Display restore configuration could not begin")
        }
        // Releasing the virtual display also removes its mirror target on normal exit.
        display = nil; previousMode = nil; physicalID = 0
        return failure
    }
}
