import Poker

struct Deck {
    private var cards: [Card]

    public static func standard52CardDeck() -> Deck {
        var cards = [Card]()
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(suit: suit, rank: rank))
            }
        }
        return Deck(cards: cards)
    }

    public mutating func shuffle() {
        cards.shuffle()
    }

    public mutating func deal() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeLast()
    }

    public var isEmpty: Bool {
        return cards.isEmpty
    }

    public var count: Int {
        cards.count
    }
}

extension Deck: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Card...) {
        self.init(cards: elements)
    }
}
