import Foundation

@main
struct PortableCoreTests {
    static func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw SetupError(message: message) }
    }
    static func rejects(_ action: () throws -> Void, _ message: String) throws {
        do { try action() } catch { return }
        throw SetupError(message: message)
    }
    static func main() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory.appendingPathComponent("mapleroyals-core-tests-" + UUID().uuidString)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        let resource = URL(fileURLWithPath: CommandLine.arguments[1])
        let root = temporary.appendingPathComponent("Friend's Mac/support")
        let core = PortableInstallation(root: root, resources: resource) { _, _ in }
        try core.open()
        try require(!core.ready, "An empty installation must not be marked ready")
        let other = PortableInstallation(root: root, resources: resource) { _, _ in }
        try rejects({ try other.open() }, "Two launchers must not own one installation")
        try require(core.environment()["WINEPREFIX"]?.hasPrefix(root.path) == true, "Prefix must use this user's data folder")
        try require(core.environment()["WINEMSYNC"] == "1", "MSync setting missing")
        try require(core.environment()["WINEESYNC"] == "0", "ESync must be disabled")
        try require(core.environment()["WINEARCH"] == "win64", "WoW64 prefix must be win64")
        try require(core.environment()["DXVK_HUD"] == nil, "Do not inherit renderer overrides")
        try require(core.environment()["DYLD_LIBRARY_PATH"] == nil, "Do not inherit another runtime's libraries")
        let payload = temporary.appendingPathComponent("payload")
        try Data("abc".utf8).write(to: payload)
        let checksum = try PortableInstallation.sha256(payload)
        try require(checksum == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA256 failed")
        let asset = RuntimeAsset(name: "test", size: 3, digest: "sha256:" + checksum,
                                 browser_download_url: URL(string: "https://github.com/example/example")!)
        try PortableInstallation.check(payload, asset: asset)
        try Data("abd".utf8).write(to: payload)
        try rejects({ try PortableInstallation.check(payload, asset: asset) }, "Tampered archives must be rejected")
        let fake = temporary.appendingPathComponent("not an installer.exe")
        try Data("<html>download failed</html>".utf8).write(to: fake)
        try rejects({ try core.install(fake) }, "HTML files must not be launched as installers")
        try require(!manager.fileExists(atPath: root.appendingPathComponent("downloads").path), "Reject wrong installer before downloading")
        let selected = try core.assets()
        try require(selected.count == 2, "Use only the pinned CX24 engine and template")
        try manager.createDirectory(at: core.versionRoot, withIntermediateDirectories: true)
        let sentinel = core.versionRoot.appendingPathComponent("do-not-delete.txt")
        try Data("preserve".utf8).write(to: sentinel)
        try rejects({ try core.prepareRuntime() }, "Do not overwrite unrecognized runtime")
        try require(manager.fileExists(atPath: sentinel.path), "Existing runtime data was removed")
        core.state.installed = true
        try require(!core.ready, "A marker alone must not mean the game exists")
        print("PASS: integrity checks, installer rejection, exclusive ownership, portable paths, environment, and existing-data preservation")
    }
}
