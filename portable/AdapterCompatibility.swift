import Foundation
import CryptoKit

// The game ignores GetAdaptersInfo's insufficient-buffer error on Macs with
// many interfaces. Install our IPv4-only adapter query in Wine's system folder;
// the game's own folder rejects proxy DLLs. Never modify the shared engine.
enum AdapterCompatibility {
    struct Manifest: Codable, Equatable {
        let schema: Int
        let sourceWineSHA256: String
        let shimSHA256: String
    }
    static let sourceWineSHA256 = "cd5803a41bf6546e9685f2706b1fc8b960fc5cd9a1656037069bc299001cf8b6"
    static let overrides = "mscoree,mshtml=;iphlpapi=n,b;royals_iphlpapi_wine=n"

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    static func prepare(prefix: URL, engine: URL, resources: URL, allowChanges: Bool,
                        expectedWineSHA256: String = sourceWineSHA256) throws -> Bool {
        let manager = FileManager.default
        let folder = resources.appendingPathComponent("adapter-compat")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: folder.appendingPathComponent("manifest.json")))
        let shim = try Data(contentsOf: folder.appendingPathComponent("iphlpapi.dll"))
        var original = try Data(contentsOf: engine.appendingPathComponent("lib/wine/i386-windows/iphlpapi.dll"))
        guard manifest.schema == 1, manifest.sourceWineSHA256 == expectedWineSHA256,
              digest(original) == expectedWineSHA256, digest(shim) == manifest.shimSHA256,
              shim.starts(with: [0x4d, 0x5a]) else {
            throw SetupError(message: "The adapter compatibility files do not match this Wine version. Get a fresh app copy; your game files are preserved.")
        }
        // Wine's DOS-stub marker makes it treat a renamed copy as a builtin.
        // Clear only that marker's first byte; executable code stays unchanged.
        let marker = Data("Wine builtin DLL\0".utf8)
        guard original.count >= 64 + marker.count, original[64..<(64 + marker.count)] == marker else {
            throw SetupError(message: "The Wine adapter library has an unexpected format. No files were changed.")
        }
        original[64] = 0
        let system = prefix.appendingPathComponent("drive_c/windows/syswow64")
        let target = system.appendingPathComponent("iphlpapi.dll")
        let dependency = system.appendingPathComponent("royals_iphlpapi_wine.dll")
        let receipt = prefix.appendingPathComponent("mapleroyals-adapter-compat.json")
        let previous = (try? Data(contentsOf: receipt)).flatMap { try? JSONDecoder().decode(Manifest.self, from: $0) }
        let currentShim = try manager.fileExists(atPath: target.path) ? Data(contentsOf: target) : nil
        let currentDependency = try manager.fileExists(atPath: dependency.path) ? Data(contentsOf: dependency) : nil
        if currentShim == shim && currentDependency == original {
            // Recover an interruption after both libraries were written but
            // before the version receipt. Never write while clients are live.
            if allowChanges && previous != manifest {
                try JSONEncoder().encode(manifest).write(to: receipt, options: .atomic)
                return true
            }
            return false
        }
        guard allowChanges else {
            throw SetupError(message: "Close all game clients before updating the compatibility files, then press Play again.")
        }
        // Accept the stock DLL, our current DLL or an earlier recorded version.
        // Do not silently replace a library supplied by the user.
        if let current = currentShim {
            let hash = digest(current)
            let recorded = previous?.schema == 1 && previous?.sourceWineSHA256 == expectedWineSHA256 && previous?.shimSHA256 == hash
            guard hash == expectedWineSHA256 || current == shim || recorded else {
                throw SetupError(message: "An unrecognized adapter library is installed in Wine. It has been preserved. Use Show log for help.")
            }
        }
        guard currentDependency == nil || currentDependency == original else {
            throw SetupError(message: "An unrecognized adapter dependency is installed in Wine. It has been preserved. Use Show log for help.")
        }
        try manager.createDirectory(at: system, withIntermediateDirectories: true)
        // Dependency first: an interruption leaves the stock DLL usable, or a
        // fully provisioned shim. Retrying completes the receipt safely.
        if currentDependency != original { try original.write(to: dependency, options: .atomic) }
        if currentShim != shim { try shim.write(to: target, options: .atomic) }
        try JSONEncoder().encode(manifest).write(to: receipt, options: .atomic)
        return true
    }
}
