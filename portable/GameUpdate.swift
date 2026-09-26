import Foundation

// Install into a separate prefix. Only the final directory swap touches the
// active installation; its journal makes an interrupted swap recoverable.
final class GameUpdate {
    struct Journal: Codable {
        let id: UUID
        var committed: Bool
    }

    let root: URL
    let active: URL
    let id: UUID
    let manager = FileManager.default
    var directory: URL { root.appendingPathComponent("updates/" + id.uuidString) }
    var staged: URL { directory.appendingPathComponent("prefix") }
    var backup: URL { root.appendingPathComponent("backups/" + id.uuidString + "/prefix") }
    var journalURL: URL { root.appendingPathComponent("game-update.json") }

    init(root: URL, active: URL, id: UUID = UUID()) {
        self.root = root
        self.active = active
        self.id = id
    }

    func prepare() throws {
        guard !manager.fileExists(atPath: journalURL.path) else {
            throw SetupError(message: "An interrupted update needs recovery. Quit and reopen the launcher first.")
        }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        try manager.copyItem(at: active, to: staged)
        // Never mix old game assets into a new full installation. The active
        // prefix still owns all original files, including user-added files.
        let copiedGame = staged.appendingPathComponent("drive_c/MapleRoyals")
        try manager.removeItem(at: copiedGame)
    }

    static func validateGame(in prefix: URL) throws {
        let folder = prefix.appendingPathComponent("drive_c/MapleRoyals")
        let executable = folder.appendingPathComponent("MapleRoyals.exe")
        let input = try FileHandle(forReadingFrom: executable)
        defer { try? input.close() }
        let header = try input.read(upToCount: 2)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        guard header == Data([0x4d, 0x5a]), files.contains(where: { $0.pathExtension.lowercased() == "wz" }) else {
            throw SetupError(message: "The new game files were not found at C:\\MapleRoyals. Your previous installation is still in place. Retry with the official Windows WZ installer and keep that destination.")
        }
    }

    func activate() throws {
        try Self.validateGame(in: staged)
        guard !manager.fileExists(atPath: journalURL.path), !manager.fileExists(atPath: backup.path) else {
            throw SetupError(message: "An update backup already exists. Your files are preserved; reopen the launcher before retrying.")
        }
        try manager.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
        var journal = Journal(id: id, committed: false)
        try JSONEncoder().encode(journal).write(to: journalURL, options: .atomic)
        do {
            try manager.moveItem(at: active, to: backup)
            try manager.moveItem(at: staged, to: active)
            journal.committed = true
            try JSONEncoder().encode(journal).write(to: journalURL, options: .atomic)
        } catch {
            do { try Self.recover(root: root, active: active) }
            catch {
                throw SetupError(message: "The update could not finish switching installations. Your files are preserved. Quit and reopen the launcher to recover, or use Show log for help.")
            }
            throw error
        }
        // A leftover committed journal is safe to clear on the next opening.
        try? manager.removeItem(at: journalURL)
    }

    @discardableResult
    static func recover(root: URL, active: URL) throws -> Bool {
        let manager = FileManager.default
        let marker = root.appendingPathComponent("game-update.json")
        guard manager.fileExists(atPath: marker.path) else { return false }
        let journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: marker))
        let update = GameUpdate(root: root, active: active, id: journal.id)
        if journal.committed {
            try validateGame(in: active)
        } else if manager.fileExists(atPath: update.backup.path) {
            if manager.fileExists(atPath: active.path) {
                let failed = update.directory.appendingPathComponent("uncommitted-prefix")
                try manager.moveItem(at: active, to: failed)
            }
            try manager.moveItem(at: update.backup, to: active)
        } else if !manager.fileExists(atPath: active.path) {
            throw SetupError(message: "An interrupted update could not find the previous installation. The backup folders have been preserved. Use Show log and contact the maintainer.")
        }
        try manager.removeItem(at: marker)
        return true
    }
}
