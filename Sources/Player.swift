import Poker
import Foundation

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

    func send(event: Event) async throws {
        if Self.DEBUG {
            print("Player \(id): will send event \(event)")
        }
        let eventData = try JSONEncoder().encode(event)
        if Self.DEBUG {
            let s = String(bytes: eventData, encoding: .utf8)!
            print("Player \(id): will send \(s)")
        }
        await proc.write(eventData)
    }

    func doTurn(event: TurnRequest) async throws -> Action {
        if Self.DEBUG {
            print("Player \(id): will do turn")
        }
        let wrappedEvent = Event(type: .requestForTurn, turnRequest: event)
        try await self.send(event: wrappedEvent)

        let s = try await proc.readNextLine()
        if Self.DEBUG {
            print("Player \(id): received \(s)")
        }
        let actionData = s.data(using: .utf8)!
        let action = try JSONDecoder().decode(Action.self, from: actionData)
        return action
    }
}
