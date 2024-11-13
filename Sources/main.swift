import Foundation
import Poker

private actor aQ<Element> {
    private var arr: [Element] = []

    func enqueue(_ e: Element) {
        arr.append(e)
    }

    func dequeue() -> Element? {
        if arr.isEmpty { return nil }
        return arr.removeLast()
    }
}

private class CCW<S,F: Error>: @unchecked Sendable {
    var continuation: CheckedContinuation<S,F>? = nil

    func set(_ new: CheckedContinuation<S,F>?) {
        self.continuation = new
    }
    func get() -> CheckedContinuation<S,F>? {
        return continuation
    }
}

private actor aQW<Element: Sendable> {
    private let q: aQ<Element>
    // private var continuation: CheckedContinuation<Element, Never>? = nil
    nonisolated private let continuation = CCW<Element, Never>()

    init(_ q: aQ<Element>) { self.q = q }

    func enqueue(_ e: Element) async {
        if let c = continuation.get() {
            c.resume(returning: e)
            continuation.set(nil)
        } else {
            await q.enqueue(e)
        }
    }

    nonisolated func dequeue() async -> Element {
        if let e = await q.dequeue() {
            return e
        }
        return await withCheckedContinuation { continuation in
            self.continuation.set(continuation)
        }
    }
}

actor Subprocess {
    static let DEBUG = false

    init(path: String) {
        if Self.DEBUG {
            print("Subprocess: initializing with path: \(path)")
        }
        let u = URL(fileURLWithPath: path)

        process = Process()
        process.executableURL = u

        input = Pipe()
        output = Pipe()
        error = Pipe()

        // let tmp = Pipe()
        //
        // let p2 = Process()
        // p2.executableURL = URL(fileURLWithPath: "/usr/bin/tee")
        // p2.standardOutput = output
        // p2.standardInput = tmp
        // p2.arguments = ["-a", "/tmp/\(UInt8.random(in: 0...250))"]
        // p2.launch()
        // print("\(path) -> \(p2.arguments![1])")

        process.standardInput = input
        process.standardOutput = output
        // process.standardOutput = tmp
        // process.standardError = FileHandle.standardError
        process.standardError = error
    }

    func start() {
        if Self.DEBUG {
            print("Subprocess: will launch")
        }
        process.launch()
        if Self.DEBUG {
            print("Subprocess: did launch")
        }

        readingTask = Task {
            for try await line in output.fileHandleForReading.bytes.lines {
                if Self.DEBUG {
                    print("Subprocess: got line in stdout task")
                }
                await self.outputQueue.enqueue(line)
            }
        }

        // Task {
        //     for try await line in error.fileHandleForReading.bytes.lines {
        //     }
        // }
    }

    func stop() {
        if Self.DEBUG {
            print("Subprocess: will interrupt")
        }
        process.interrupt()
        if Self.DEBUG {
            print("Subprocess: did interrupt")
        }
    }

    func readNextLine() async throws -> String {
        if Self.DEBUG {
            print("Subprocess: will read line")
        }
        return await outputQueue.dequeue()
        // var it = output.fileHandleForReading.bytes.lines.makeAsyncIterator()
        // return try await it.next()!
    }

    func write(_ data: Data, addNewline: Bool = true) {
        if Self.DEBUG {
            print("Subprocess: will write")
        }
        var data = data
        if addNewline {
            data.append(10)
        }
        input.fileHandleForWriting.write(data)
        if Self.DEBUG {
            print("Subprocess: did write")
        }
    }

    private let process: Process
    private let input: Pipe
    private let output: Pipe
    private let error: Pipe
    private var readingTask: Task<(), any Error>? = nil
    private var outputQueue = aQW<String>(aQ())
}

// let a = Subprocess(path: "/bin/cat")
//
// await a.start()
// await a.write("Hello".data(using: .utf8)!)
// let res = try await a.readNextLine()
// print("got from cat: \(res)")
//
// await a.write("line 2".data(using: .utf8)!)
// let res2 = try await a.readNextLine()
// print("got from cat: \(res2)")
//
// Task {
//     try await Task.sleep(nanoseconds: 3_000_000_000)
//     await a.write("line 3".data(using: .utf8)!)
// }
// let res3 = try await a.readNextLine()
// print("got from cat: \(res3)")

actor Player {
    private static let DEBUG = false

    private let proc: Subprocess
    let id: Int

    init(path: String, id: Int) {
        if Self.DEBUG {
            print("Player: initializing with path: \(path) and id: \(id)")
        }
        self.proc = Subprocess(path: path)
        self.id = id
    }

    func start() async {
        await proc.start()
    }

    func doTurn(event: TurnRequest) async throws -> Action {
        if Self.DEBUG {
            print("Player \(id): will do turn")
        }
        let wrappedEvent = Event(type: .requestForTurn, turnRequest: event)
        let eventData = try JSONEncoder().encode(wrappedEvent)
        if Self.DEBUG {
            let s = String(bytes: eventData, encoding: .utf8)!
            print("sending: \(s)")
        }
        await proc.write(eventData)
        let s = try await proc.readNextLine()
        if Self.DEBUG {
            print("got: \(s)")
        }
        let actionData = s.data(using: .utf8)!
        let action = try JSONDecoder().decode(Action.self, from: actionData)
        return action
    }
}

var players: [Player] = []
for (id, arg) in CommandLine.arguments.enumerated().dropFirst() {
    print("Initializing player \(id) with executable path \(arg)")
    let player = Player(path: arg, id: id)
    players.append(player)
}

for player in players {
    print("Starting player \(player.id)")
    await player.start()
}

for player in players {
    let action = try await player.doTurn(event: .init())
    print("Player \(player.id): \(action)")
}

// // MARK: set up CPUs
//
// var cpus: [(Process, Pipe, Pipe)] = []
// for arg in CommandLine.arguments.dropFirst() {
//     let url = URL(fileURLWithPath: arg)
//
//     let process = Process()
//
//     let inputPipe = Pipe()
//     let outputPipe = Pipe()
//
//     process.executableURL = url
//     process.standardInput = inputPipe
//     process.standardOutput = outputPipe
//
//     cpus.append((process, inputPipe, outputPipe))
// }
//
// print("Have \(cpus.count) CPU(s)")
// cpus.forEach { $0.0.launch() }
//
//
// // MARK: begin game
//
// for (proc, input, output) in cpus {
//     let roundStart = RoundStart(playerID: 0, cards: [])
//     let startEvent = Event(type: .roundStart, roundStart: roundStart)
//
//     let data = try JSONEncoder().encode(startEvent)
//
//     input.fileHandleForWriting.write(data)
// }
