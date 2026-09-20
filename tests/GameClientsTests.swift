import Foundation

@main
struct GameClientsTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw SetupError(message: message) }
    }

    static func wait(_ predicate: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(8)
        while !predicate() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        try require(predicate(), "Timed out waiting for process completion")
    }

    static func sleeper() -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        return process
    }

    static func main() throws {
        let sessions = GameClients()
        var completed = [UUID]()
        var remainingCounts = [Int]()
        sessions.didExit = { client in
            precondition(Thread.isMainThread)
            completed.append(client.id)
            remainingCounts.append(sessions.count)
        }
        defer { for client in sessions.clients.values where client.process.isRunning { client.process.terminate() } }

        let first = try sessions.start(id: UUID(), process: sleeper())
        let second = try sessions.start(id: UUID(), process: sleeper())
        try require(sessions.count == 2, "A running game must not block a second launch")
        let args1 = PortableInstallation.gameArguments(clientID: first.id)
        let args2 = PortableInstallation.gameArguments(clientID: second.id)
        try require(args1[1] != args2[1], "Each client needs its own Wine desktop")
        try require(args1[0] == "explorer" && args1.last == "C:\\MapleRoyals\\MapleRoyals.exe", "Keep desktop-first game launch")

        first.process.terminate()
        try wait { completed.contains(first.id) }
        try require(sessions.count == 1 && second.process.isRunning, "Closing one client must leave the other running")
        try require(remainingCounts == [1], "Completion callback must see the surviving client")

        let missing = Process()
        missing.executableURL = URL(fileURLWithPath: "/nonexistent/mapleroyals-test-executable")
        var rejected = false
        do { try sessions.start(id: UUID(), process: missing) } catch { rejected = true }
        try require(rejected && sessions.count == 1 && second.process.isRunning, "Failed launch must preserve existing clients and count")

        for _ in 0..<14 { try sessions.start(id: UUID(), process: sleeper()) }
        try require(sessions.count == 15, "Do not impose a small fixed client cap")
        for client in Array(sessions.clients.values) { client.process.terminate() }
        try wait { sessions.count == 0 }
        try require(completed.count == 16 && Set(completed).count == 16, "Each successful launch must complete exactly once")
        try require(remainingCounts.filter { $0 == 0 }.count == 1, "Only the last completion may report no clients")

        let immediate = Process()
        immediate.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        let quick = try sessions.start(id: UUID(), process: immediate)
        try wait { completed.contains(quick.id) }
        try require(sessions.count == 0, "Fast exits must not leave a stale client")
        print("PASS: concurrent clients, independent exits, spawn failure, many clients, exact completion, and immediate exit")
    }
}
