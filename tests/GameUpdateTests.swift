import Foundation

@main struct GameUpdateTests {
    static let fm = FileManager.default
    static func require(_ condition: @autoclosure () throws -> Bool, _ text: String) throws {
        if try !condition() { throw SetupError(message: text) }
    }
    static func rejects(_ action: () throws -> Void) throws {
        do { try action() } catch { return }
        throw SetupError(message: "Expected rejection")
    }
    static func write(_ text: String, _ path: URL) throws {
        try fm.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: path)
    }
    static func contents(_ path: URL) throws -> String { try String(contentsOf: path, encoding: .utf8) }
    static func fixture(_ root: URL) throws -> URL {
        let active = root.appendingPathComponent("prefixes/active")
        try write("MZold", active.appendingPathComponent("drive_c/MapleRoyals/MapleRoyals.exe"))
        try write("old assets", active.appendingPathComponent("drive_c/MapleRoyals/Old.wz"))
        try write("saved settings", active.appendingPathComponent("user.reg"))
        try write("adapter shim", active.appendingPathComponent("drive_c/windows/syswow64/iphlpapi.dll"))
        try fm.createSymbolicLink(at: active.appendingPathComponent("home-link"), withDestinationURL: root)
        return active
    }
    static func newGame(_ prefix: URL) throws {
        try write("MZnew", prefix.appendingPathComponent("drive_c/MapleRoyals/MapleRoyals.exe"))
        try write("new assets", prefix.appendingPathComponent("drive_c/MapleRoyals/New.wz"))
    }

    static func main() throws {
        let root = fm.temporaryDirectory.appendingPathComponent("mapleroyals-update-tests-" + UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let normalRoot = root.appendingPathComponent("normal")
        let active = try fixture(normalRoot)
        let update = GameUpdate(root: normalRoot, active: active)
        try update.prepare()
        try require(fm.fileExists(atPath: active.appendingPathComponent("drive_c/MapleRoyals/Old.wz").path), "Preparing must retain active files")
        try require(!fm.fileExists(atPath: update.staged.appendingPathComponent("drive_c/MapleRoyals").path), "Staging must exclude all old game assets")
        try require(try contents(update.staged.appendingPathComponent("user.reg")) == "saved settings", "Staging must preserve registry settings")
        try require(try fm.destinationOfSymbolicLink(atPath: update.staged.appendingPathComponent("home-link").path) == normalRoot.path, "Copy links without traversing them")
        try rejects { try update.activate() }
        try newGame(update.staged)
        try update.activate()
        try require(try contents(active.appendingPathComponent("drive_c/MapleRoyals/MapleRoyals.exe")) == "MZnew", "Success must activate new files")
        try require(try contents(update.backup.appendingPathComponent("drive_c/MapleRoyals/MapleRoyals.exe")) == "MZold", "Success must retain original backup")
        try require(!fm.fileExists(atPath: active.appendingPathComponent("drive_c/MapleRoyals/Old.wz").path), "Do not mix outdated assets with new assets")
        try require(try contents(active.appendingPathComponent("drive_c/windows/syswow64/iphlpapi.dll")) == "adapter shim", "Game updates must preserve Wine system compatibility files")
        try require(!fm.fileExists(atPath: update.journalURL.path), "Completed updates must clear the journal")

        // Simulate interruption at every boundary of the directory swap.
        for boundary in 0...3 {
            let recoveryRoot = root.appendingPathComponent("interrupted-\(boundary)")
            let original = try fixture(recoveryRoot)
            let operation = GameUpdate(root: recoveryRoot, active: original)
            try operation.prepare()
            try newGame(operation.staged)
            try fm.createDirectory(at: operation.backup.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(GameUpdate.Journal(id: operation.id, committed: boundary == 3)).write(to: operation.journalURL)
            if boundary >= 1 { try fm.moveItem(at: original, to: operation.backup) }
            if boundary >= 2 { try fm.moveItem(at: operation.staged, to: original) }
            try require(try GameUpdate.recover(root: recoveryRoot, active: original), "Interrupted swap must be recovered")
            let exe = try contents(original.appendingPathComponent("drive_c/MapleRoyals/MapleRoyals.exe"))
            try require(exe == (boundary == 3 ? "MZnew" : "MZold"), "Recover committed update or roll back uncommitted update")
            try require(try !GameUpdate.recover(root: recoveryRoot, active: original), "Recovery must be idempotent")
        }

        // Exercise the production updater with a tiny stand-in installer, including
        // its exit-code file, Wine wait, duplicated log handle and runtime reuse.
        let coreRoot = root.appendingPathComponent("core")
        let resources = URL(fileURLWithPath: CommandLine.arguments[1])
        let core = PortableInstallation(root: coreRoot, resources: resources) { _, _ in }
        try core.open()
        try write("MZold", core.game)
        try write("old assets", core.game.deletingLastPathComponent().appendingPathComponent("Old.wz"))
        try write("keep me", core.prefix.appendingPathComponent("user.reg"))
        try write("display preferences", coreRoot.appendingPathComponent("play-preferences.json"))
        core.state.installed = true
        try JSONEncoder().encode(core.state).write(to: core.stateFile)
        let marker = try JSONEncoder().encode(core.assets())
        try fm.createDirectory(at: core.libraries, withIntermediateDirectories: true)
        try marker.write(to: core.versionRoot.appendingPathComponent("verified-runtime.json"))
        let wine = core.engine.appendingPathComponent("bin/wine")
        let server = core.engine.appendingPathComponent("bin/wineserver")
        try write("#!/bin/sh\nexit 0\n", server)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
        let installer = root.appendingPathComponent("MapleRoyalsSetupWz-test.exe")
        try write("MZtest", installer)
        for exitCode in [1, 0] {
            try write("""
            #!/bin/sh
            mkdir -p "$WINEPREFIX/drive_c/MapleRoyals"
            printf MZnew > "$WINEPREFIX/drive_c/MapleRoyals/MapleRoyals.exe"
            printf assets > "$WINEPREFIX/drive_c/MapleRoyals/New.wz"
            for folder in "$WINEPREFIX"/drive_c/mapleroyals-setup-*; do
              printf '\(exitCode)\\n' > "$folder/exit-code.txt"
            done
            exit 0
            """, wine)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
            if exitCode != 0 {
                try rejects { try core.updateGame(installer) }
                try require(try contents(core.game) == "MZold", "Cancelled installer must keep original active")
            } else {
                try core.updateGame(installer)
                try require(try contents(core.game) == "MZnew", "Successful installer must activate replacement")
            }
            try require(core.ready, "Original or successfully updated installation must remain playable")
            try require(try contents(core.prefix.appendingPathComponent("user.reg")) == "keep me", "Update must not reset saved registry")
            try require(try contents(coreRoot.appendingPathComponent("play-preferences.json")) == "display preferences", "Update must preserve display choices")
        }
        core.note("Log still usable after update")
        try require(try contents(core.logURL).contains("Log still usable after update"), "Staged logger must not close the launcher's file handle")
        try require(!fm.fileExists(atPath: coreRoot.appendingPathComponent("downloads").path), "Update must reuse installed runtime")
        print("PASS: clean staged install, backup, cancellation, update activation, settings preservation, runtime reuse, log ownership and interrupted-swap recovery")
    }
}
