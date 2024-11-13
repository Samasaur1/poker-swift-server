import Foundation
import Poker

var players: [Player] = []
for (id, arg) in CommandLine.arguments.dropFirst().enumerated() {
    print("Initializing player \(id) with executable path \(arg)")
    let player = Player(path: arg, id: id)
    players.append(player)
}

if players.count >= 23 {
    print("The maximum number of players with a 52-card deck is 23")
    exit(1)
}

for player in players {
    print("Starting player \(player.id)")
    await player.start()
}

var deck = Deck.standard52CardDeck()
deck.shuffle()

var pot = 0
print("Pot is at: \(pot)¢ ($\(Double(pot)/100))")

for player in players {
    guard let first = deck.deal(), let second = deck.deal() else {
        fatalError()
    }
    print("Player \(player.id) was dealt \(first), \(second)")
    let event = Event(type: .roundStart, roundStart: RoundStart(playerID: player.id, numberOfPlayers: players.count, ante: 25, cards: first, second))
    try await player.send(event: event)
    pot += 25
}
print("Pot is at: \(pot)¢ ($\(Double(pot)/100))")

var highestBet = 0
var playerBets: [Int] = .init(repeating: 0, count: players.count)

for player in players {
    let deficit = highestBet - playerBets[player.id]
    let action = try await player.doTurn(event: .init(deficit: deficit))
    // TODO: check that this is a legal move
    print("Player \(player.id): \(action)")
    switch action {
    case .checkOrCall:
        pot += deficit
        playerBets[player.id] = highestBet
    case .raise(by: let amountOver):
        pot += deficit + amountOver
        highestBet += amountOver
        playerBets[player.id] = highestBet
    case .fold:
        break
    }
    let event = Event(type: .turn, turn: Turn(playerID: player.id, move: action, potValue: pot))
    for other in players {
        if other.id == player.id { continue }
        try await other.send(event: event)
    }
    print("Pot is at: \(pot)¢ ($\(Double(pot)/100))")
}
