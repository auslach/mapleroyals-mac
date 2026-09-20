import Foundation
import CryptoKit
import Darwin

struct SetupError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct RuntimeAsset: Codable {
    let name: String
    let size: Int64
    let digest: String
    let browser_download_url: URL
}

struct InstallState: Codable {
    var schema = 1
    var runtime = "cx24-0.7_5-template-1.0.15"
    var installed = false
}

// All blocking work runs on the launcher's worker queue, never the AppKit thread.
final class PortableInstallation {
    static let runtimeID = "cx24-0.7_5-template-1.0.15"
    let root: URL
    let resources: URL
    let manager = FileManager.default
    let report: (String, Double?) -> Void
    var lockDescriptor: Int32 = -1
    var log: FileHandle?
    var state = InstallState()
    var diagnosingSetup = false
    var versionRoot: URL { root.appendingPathComponent("runtimes/" + Self.runtimeID) }
    var prefix: URL { root.appendingPathComponent("prefixes/" + Self.runtimeID) }
    var engine: URL { versionRoot.appendingPathComponent("engine/wswine.bundle") }
    var libraries: URL { versionRoot.appendingPathComponent("template/Template-1.0.15.app/Contents/Frameworks") }
    var game: URL { prefix.appendingPathComponent("drive_c/MapleRoyals/MapleRoyals.exe") }
    var stateFile: URL { root.appendingPathComponent("installation.json") }
    var logURL: URL { root.appendingPathComponent("logs/launcher.log") }

    init(root: URL, resources: URL, report: @escaping (String, Double?) -> Void) {
        self.root = root
        self.resources = resources
        self.report = report
    }

    deinit {
        try? log?.close()
        if lockDescriptor >= 0 { flock(lockDescriptor, LOCK_UN); close(lockDescriptor) }
    }

    func open() throws {
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        lockDescriptor = Darwin.open(root.appendingPathComponent("launcher.lock").path, O_CREAT | O_RDWR, 0o600)
        guard lockDescriptor >= 0, flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            throw SetupError(message: "Another copy of this launcher is already open. Close it, then reopen this app.")
        }
        try manager.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if manager.fileExists(atPath: logURL.path) {
            let previous = logURL.deletingLastPathComponent().appendingPathComponent("previous-launch.log")
            if manager.fileExists(atPath: previous.path) { try manager.removeItem(at: previous) }
            try manager.moveItem(at: logURL, to: previous)
        }
        manager.createFile(atPath: logURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        log = try FileHandle(forWritingTo: logURL)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        note("Launcher \(version) opened. Runtime: \(Self.runtimeID); macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        if manager.fileExists(atPath: stateFile.path) {
            state = try JSONDecoder().decode(InstallState.self, from: Data(contentsOf: stateFile))
            guard state.schema == 1, state.runtime == Self.runtimeID else {
                throw SetupError(message: "This app cannot open this installation version. Your files have been preserved.")
            }
        }
    }

    var ready: Bool {
        state.installed && manager.fileExists(atPath: game.path)
            && manager.isExecutableFile(atPath: engine.appendingPathComponent("bin/wine").path)
            && manager.fileExists(atPath: libraries.path)
    }

    func note(_ text: String) {
        try? log?.write(contentsOf: Data("\(Date()): \(text)\n".utf8))
    }

    static func sha256(_ file: URL) throws -> String {
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        var hash = SHA256()
        while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func assets() throws -> [RuntimeAsset] {
        let all = try JSONDecoder().decode([RuntimeAsset].self, from: Data(contentsOf: resources.appendingPathComponent("assets.json")))
        return try ["WS12WineCX24.0.7_5.tar.xz", "Template-1.0.15.tar.xz"].map { name in
            guard let asset = all.first(where: { $0.name == name }),
                  asset.browser_download_url.scheme == "https",
                  asset.browser_download_url.host == "github.com",
                  asset.digest.hasPrefix("sha256:"), asset.digest.count == 71 else {
                throw SetupError(message: "The app's download manifest is invalid. Get a fresh copy of the app.")
            }
            return asset
        }
    }

    static func check(_ file: URL, asset: RuntimeAsset) throws {
        let bytes = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber
        guard bytes?.int64Value == asset.size,
              try sha256(file) == String(asset.digest.dropFirst(7)) else {
            throw SetupError(message: "The download for \(asset.name) failed its integrity check. Nothing from that archive was installed. Try setup again.")
        }
    }

    func download(_ asset: RuntimeAsset) throws -> URL {
        let cache = root.appendingPathComponent("downloads")
        try manager.createDirectory(at: cache, withIntermediateDirectories: true)
        let target = cache.appendingPathComponent(asset.name)
        if manager.fileExists(atPath: target.path) {
            do { try Self.check(target, asset: asset); return target }
            catch {
                // Preserve corrupt data for inspection; never execute or extract it.
                try manager.moveItem(at: target, to: cache.appendingPathComponent(asset.name + ".rejected-" + UUID().uuidString))
            }
        }
        let partial = cache.appendingPathComponent(asset.name + ".partial")
        if manager.fileExists(atPath: partial.path) { try manager.removeItem(at: partial) }
        let task = AssetDownload(destination: partial) { fraction in
            self.report("Downloading game support files…", fraction)
        }
        try task.fetch(asset.browser_download_url)
        report("Checking the download…", nil)
        try Self.check(partial, asset: asset)
        try manager.moveItem(at: partial, to: target)
        return target
    }

    @discardableResult
    func process(_ executable: URL, _ arguments: [String], environment: [String: String]? = nil) throws -> Int32 {
        let child = Process()
        child.executableURL = executable
        child.arguments = arguments
        child.environment = environment
        child.currentDirectoryURL = manager.fileExists(atPath: game.path) ? game.deletingLastPathComponent() : root
        child.standardOutput = log
        child.standardError = log
        note("Run: \(executable.lastPathComponent) \(arguments)")
        let finished = DispatchSemaphore(value: 0)
        child.terminationHandler = { _ in finished.signal() }
        let started = ProcessInfo.processInfo.systemUptime
        try child.run()
        note("Started PID \(child.processIdentifier)")
        while finished.wait(timeout: .now() + 30) == .timedOut {
            if diagnosingSetup {
                note("Still waiting for \(executable.lastPathComponent), PID \(child.processIdentifier), \(Int(ProcessInfo.processInfo.systemUptime - started)) seconds elapsed")
            }
        }
        note("Exit: \(child.terminationStatus); PID \(child.processIdentifier); elapsed \(Int(ProcessInfo.processInfo.systemUptime - started)) seconds")
        guard child.terminationStatus == 0 else {
            throw SetupError(message: "\(executable.lastPathComponent) stopped with code \(child.terminationStatus). Open the log for details. Your installation files are preserved.")
        }
        return child.terminationStatus
    }

    func prepareRuntime() throws {
        let runtimeMarker = versionRoot.appendingPathComponent("verified-runtime.json")
        if manager.fileExists(atPath: runtimeMarker.path) {
            let recorded = try JSONDecoder().decode([RuntimeAsset].self, from: Data(contentsOf: runtimeMarker))
            let expected = try assets()
            guard recorded.map(\.digest) == expected.map(\.digest),
                  manager.isExecutableFile(atPath: engine.appendingPathComponent("bin/wine").path),
                  manager.isExecutableFile(atPath: engine.appendingPathComponent("bin/wineserver").path),
                  manager.fileExists(atPath: libraries.path) else {
                throw SetupError(message: "Some game support files are missing or changed. Open the installation folder and contact the maintainer; your game files are preserved.")
            }
            return
        }
        guard !manager.fileExists(atPath: versionRoot.path) else {
            throw SetupError(message: "An unrecognized runtime folder already exists. It has been preserved. Contact the maintainer before moving it.")
        }
        let selected = try assets()
        var downloaded: [URL] = []
        for asset in selected { downloaded.append(try download(asset)) }
        let staging = root.appendingPathComponent("staging-" + UUID().uuidString)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        report("Unpacking game support files…", nil)
        for (index, directory) in ["engine", "template"].enumerated() {
            let destination = staging.appendingPathComponent(directory)
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            try process(URL(fileURLWithPath: "/usr/bin/tar"), ["-xf", downloaded[index].path, "-C", destination.path])
        }
        guard manager.isExecutableFile(atPath: staging.appendingPathComponent("engine/wswine.bundle/bin/wine").path),
              manager.fileExists(atPath: staging.appendingPathComponent("template/Template-1.0.15.app/Contents/Frameworks").path) else {
            throw SetupError(message: "The runtime archive has an unexpected layout. No installation was activated.")
        }
        try JSONEncoder().encode(selected).write(to: staging.appendingPathComponent("verified-runtime.json"), options: .atomic)
        try manager.createDirectory(at: versionRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.moveItem(at: staging, to: versionRoot)
    }

    func environment() -> [String: String] {
        // Use a small explicit environment; do not inherit settings from another Wine installation.
        var values: [String: String] = [:]
        for key in ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_CTYPE", "DISPLAY"] {
            values[key] = ProcessInfo.processInfo.environment[key]
        }
        values["WINEPREFIX"] = prefix.path
        values["WINEARCH"] = "win64"
        values["WINESERVER"] = engine.appendingPathComponent("bin/wineserver").path
        values["DYLD_FALLBACK_LIBRARY_PATH"] = libraries.path + ":/usr/lib"
        values["WINEDLLOVERRIDES"] = "mscoree,mshtml="
        values["WINEDEBUG"] = diagnosingSetup
            ? "-all,err+all,+timestamp,+pid,+tid,trace+process,trace+loaddll,trace+macdrv"
            : "-all,err+all"
        values["WINEESYNC"] = "0"
        values["WINEMSYNC"] = "1"
        values["PATH"] = engine.appendingPathComponent("bin").path + ":/usr/bin:/bin:/usr/sbin:/sbin"
        return values
    }

    func wine(_ arguments: [String]) throws {
        try process(engine.appendingPathComponent("bin/wine"), arguments, environment: environment())
    }

    func waitForWine() throws {
        try process(engine.appendingPathComponent("bin/wineserver"), ["-w"], environment: environment())
    }

    func runInstaller(_ installer: URL) throws {
        // A fixed Wine path keeps the user's filename out of the batch command.
        // The link also avoids copying a multi-gigabyte installer into the prefix.
        let name = "mapleroyals-setup-" + UUID().uuidString
        let staging = prefix.appendingPathComponent("drive_c/" + name)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        try manager.createSymbolicLink(at: staging.appendingPathComponent("installer.exe"), withDestinationURL: installer)
        let windowsDirectory = "C:\\" + name
        let script = """
        @echo off
        "\(windowsDirectory)\\installer.exe" /DIR=C:\\MapleRoyals /NOICONS
        >"\(windowsDirectory)\\exit-code.txt" echo %errorlevel%
        exit
        """
        try Data((script.replacingOccurrences(of: "\n", with: "\r\n") + "\r\n").utf8)
            .write(to: staging.appendingPathComponent("launch.cmd"))
        // Explorer creates the desktop first. It does not forward the child's exit
        // code, so the batch records it before we decide setup succeeded.
        try wine(["explorer", "/desktop=MapleRoyalsSetup,1024x768", "C:\\windows\\system32\\cmd.exe",
                  "/d", "/c", windowsDirectory + "\\launch.cmd"])
        try waitForWine()
        let statusFile = staging.appendingPathComponent("exit-code.txt")
        let text = try? String(contentsOf: statusFile, encoding: .utf8)
        guard let text = text, let status = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SetupError(message: "The Windows installer did not report a result. Click Show log and send the log to the maintainer. Your game files are preserved.")
        }
        note("Windows installer exit code: \(status)")
        guard status == 0 else {
            throw SetupError(message: "The Windows installer was cancelled or failed (code \(status)). Click Show log for details. Your game files are preserved.")
        }
    }

    func install(_ installer: URL) throws {
        report("Checking the game installer…", nil)
        note("Selected installer: \(installer.lastPathComponent)")
        guard installer.pathExtension.lowercased() == "exe", manager.isReadableFile(atPath: installer.path) else {
            throw SetupError(message: "Choose the Windows WZ installer downloaded from the official MapleRoyals website.")
        }
        // A basic executable header check catches a mistaken HTML/download-error file.
        let input = try FileHandle(forReadingFrom: installer)
        let header = try input.read(upToCount: 2)
        try input.close()
        guard header == Data([0x4d, 0x5a]) else { throw SetupError(message: "That file is not a Windows installer. Download the Windows WZ installer again.") }
        diagnosingSetup = true
        defer { diagnosingSetup = false }
        report("Checking game support files…", nil)
        note("Checking Wine runtime files")
        try prepareRuntime()
        try manager.createDirectory(at: prefix, withIntermediateDirectories: true)
        note("Setup environment: \(environment())")
        report("Preparing your game folder…", nil)
        try wine(["wineboot", "-u"])
        report("Waiting for Windows setup to finish preparing… This can take several minutes.", nil)
        try waitForWine()
        report("Finish the MapleRoyals installer. Keep C:\\MapleRoyals and turn off ‘Launch MapleRoyals’ before Finish.", nil)
        note("User-selected installer SHA-256: \(try Self.sha256(installer))")
        try runInstaller(installer)
        guard manager.fileExists(atPath: game.path) else {
            throw SetupError(message: "The game was not installed at C:\\MapleRoyals. Choose the installer again to retry, keeping that destination.")
        }
        report("Applying the game settings…", nil)
        try wine(["reg", "import", resources.appendingPathComponent("settings.reg").path])
        try wine(["reg", "add", "HKCU\\Software\\Wine\\Direct3D", "/v", "csmt", "/t", "REG_DWORD", "/d", "0", "/f"])
        try waitForWine()
        state.installed = true
        try JSONEncoder().encode(state).write(to: stateFile, options: .atomic)
        note("Installation complete")
    }

    static func gameArguments(clientID: UUID) -> [String] {
        // Reusing a desktop can hand off to an existing Explorer and return early.
        // A distinct desktop preserves startup ordering and each client's lifetime.
        ["explorer", "/desktop=MapleRoyals-\(clientID.uuidString),1024x768", "C:\\MapleRoyals\\MapleRoyals.exe"]
    }

    func gameProcess(clientID: UUID) throws -> Process {
        guard ready else { throw SetupError(message: "Complete the game installation first.") }
        let child = Process()
        child.executableURL = engine.appendingPathComponent("bin/wine")
        child.arguments = Self.gameArguments(clientID: clientID)
        child.environment = environment()
        child.currentDirectoryURL = game.deletingLastPathComponent()
        child.standardOutput = log
        child.standardError = log
        note("Client \(clientID): wine \(child.arguments!)")
        note("Launch environment: \(child.environment!)")
        return child
    }
}

final class AssetDownload: NSObject, URLSessionDownloadDelegate {
    let destination: URL
    let progress: (Double) -> Void
    let finished = DispatchSemaphore(value: 0)
    var failure: Error?
    init(destination: URL, progress: @escaping (Double) -> Void) {
        self.destination = destination
        self.progress = progress
    }
    func fetch(_ url: URL) throws {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 1800
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        task.resume()
        finished.wait()
        session.finishTasksAndInvalidate()
        if let error = failure { throw error }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 { progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else {
                throw SetupError(message: "The runtime download server returned an error. Check your connection and try again.")
            }
            try FileManager.default.moveItem(at: location, to: destination)
        } catch { failure = error }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error { failure = error }
        finished.signal()
    }
}
