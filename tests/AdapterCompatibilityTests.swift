import Foundation

@main struct AdapterCompatibilityTests {
    static let fm = FileManager.default
    static func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !value() { throw SetupError(message: message) }
    }
    static func rejects(_ action: () throws -> Void) throws {
        do { try action() } catch { return }
        throw SetupError(message: "Expected rejection")
    }
    static func write(_ data: Data, _ url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
    static func main() throws {
        let root = fm.temporaryDirectory.appendingPathComponent("mapleroyals-adapter-tests-" + UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let prefix = root.appendingPathComponent("Friend's Mac/prefix")
        let engine = root.appendingPathComponent("engine")
        let resources = root.appendingPathComponent("resources")
        let system = prefix.appendingPathComponent("drive_c/windows/syswow64")
        let target = system.appendingPathComponent("iphlpapi.dll")
        let alias = system.appendingPathComponent("royals_iphlpapi_wine.dll")
        let stockFile = engine.appendingPathComponent("lib/wine/i386-windows/iphlpapi.dll")
        let shimFile = resources.appendingPathComponent("adapter-compat/iphlpapi.dll")
        let manifestFile = resources.appendingPathComponent("adapter-compat/manifest.json")
        // Synthetic fixtures test provisioning without redistributing Wine.
        var stock = Data(repeating: 0x90, count: 256)
        stock.replaceSubrange(0..<2, with: Data("MZ".utf8))
        stock.replaceSubrange(64..<81, with: Data("Wine builtin DLL\0".utf8))
        let sourceHash = AdapterCompatibility.digest(stock)
        var shim = Data("MZproject-owned-test-shim".utf8)
        func resourcesForShim() throws {
            try write(shim, shimFile)
            let manifest = AdapterCompatibility.Manifest(schema: 1, sourceWineSHA256: sourceHash, shimSHA256: AdapterCompatibility.digest(shim))
            try write(JSONEncoder().encode(manifest), manifestFile)
        }
        @discardableResult func prepare(_ allow: Bool = true) throws -> Bool {
            try AdapterCompatibility.prepare(prefix: prefix, engine: engine, resources: resources,
                allowChanges: allow, expectedWineSHA256: sourceHash)
        }
        try write(stock, stockFile)
        try write(stock, target)
        try resourcesForShim()
        try rejects { try prepare(false) }
        try check(try Data(contentsOf: target) == stock, "Live-client guard must leave stock DLL untouched")
        try check(try prepare(), "First installation must provision the shim")
        var renamed = stock; renamed[64] = 0
        try check(try Data(contentsOf: alias) == renamed, "Change only the builtin marker in the renamed copy")
        try check(try Data(contentsOf: target) == shim, "Install shim in syswow64")
        try check(try Data(contentsOf: stockFile) == stock, "Shared runtime must be untouched")
        try check(!fm.fileExists(atPath: prefix.appendingPathComponent("drive_c/MapleRoyals").path), "Never add files to the game folder")
        let timestamp = try target.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        try check(try !prepare(false), "Second client must reuse already-installed files")
        try check(try target.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == timestamp, "Do not rewrite mapped libraries")
        let receipt = prefix.appendingPathComponent("mapleroyals-adapter-compat.json")
        try fm.removeItem(at: receipt)
        try check(try !prepare(false), "Live clients can keep using fully installed files without a receipt")
        try check(!fm.fileExists(atPath: receipt.path), "Do not repair metadata during gameplay")
        try check(try prepare(), "Recover an interrupted receipt write")
        try check(fm.fileExists(atPath: receipt.path), "Save recovered version receipt")
        shim.append(contentsOf: [1, 2, 3]); try resourcesForShim()
        try rejects { try prepare(false) }
        try check(try prepare(), "Recorded older shim may be upgraded once clients close")
        try write(Data("unknown library".utf8), target)
        try rejects { try prepare() }
        try check(try Data(contentsOf: target) == Data("unknown library".utf8), "Preserve unrelated DLLs")
        try write(stock, target) // Interrupted dependency-first installation.
        try check(try prepare(), "Retry after dependency-only installation")
        try write(Data("unknown dependency".utf8), alias)
        try rejects { try prepare() }
        try check(try Data(contentsOf: alias) == Data("unknown dependency".utf8), "Preserve unrelated dependency")
        try write(renamed, alias)
        try write(Data("MZtampered".utf8), shimFile)
        try rejects { try prepare() }
        try resourcesForShim()
        try write(Data("wrong Wine version".utf8), stockFile)
        try rejects { try prepare() }
        try check(AdapterCompatibility.overrides.contains("iphlpapi=n,b"), "64-bit services require builtin fallback")
        print("PASS: compatibility install/upgrade, exact Wine-copy change, live-client guard, retries, integrity checks, and preservation of game/runtime/unknown files")
    }
}
