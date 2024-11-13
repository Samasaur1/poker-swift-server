import Foundation
import Poker

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
        var it = output.fileHandleForReading.bytes.lines.makeAsyncIterator()
        return try await it.next()!
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
}

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
