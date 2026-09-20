import Foundation

// Accessed on the main thread. Each entry owns one distinct Wine desktop process,
// so one client's completion never waits for (or terminates) the other clients.
final class GameClients {
    struct Client {
        let id: UUID
        let number: Int
        let process: Process
    }

    private(set) var clients: [UUID: Client] = [:]
    private var nextNumber = 1
    var didExit: ((Client) -> Void)?
    var count: Int { clients.count }

    @discardableResult
    func start(id: UUID, process: Process) throws -> Client {
        precondition(Thread.isMainThread)
        guard clients[id] == nil else { throw SetupError(message: "This game client is already being tracked.") }
        let client = Client(id: id, number: nextNumber, process: process)
        nextNumber += 1
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let finished = self.clients.removeValue(forKey: id) else { return }
                self.didExit?(finished)
            }
        }
        clients[id] = client
        do { try process.run() }
        catch {
            clients.removeValue(forKey: id)
            process.terminationHandler = nil
            throw error
        }
        return client
    }
}
