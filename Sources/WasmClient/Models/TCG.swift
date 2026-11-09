import Foundation

// MARK: - TCG Namespace

extension WasmClient {
    public enum TCG {}
}

// MARK: - ServiceMethod

extension WasmClient.TCG {
    // FlowKit service RPC method name (mirrors tcg.fk.pb.swift).
    public struct ServiceMethod: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let scan = ServiceMethod(rawValue: "asyncify.tcg.TcgService/Scan")
        public static let catalogDetail = ServiceMethod(rawValue: "asyncify.tcg.TcgService/CatalogDetail")
        public static let soldListings = ServiceMethod(rawValue: "asyncify.tcg.TcgService/SoldListings")
        public static let catalogBrowse = ServiceMethod(rawValue: "asyncify.tcg.TcgService/CatalogBrowse")
        public static let trending = ServiceMethod(rawValue: "asyncify.tcg.TcgService/Trending")
        public static let searchFilters = ServiceMethod(rawValue: "asyncify.tcg.TcgService/SearchFilters")
        public static let listSets = ServiceMethod(rawValue: "asyncify.tcg.TcgService/ListSets")
    }
}

// MARK: - Game / Finish (wire = argString; empty = unspecified)

extension WasmClient.TCG {
    public struct Game: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let pokemon = Game(rawValue: "POKEMON")
        public static let pokemonJP = Game(rawValue: "POKEMON_JP")
        public static let magicTheGathering = Game(rawValue: "MTG")
        public static let onePiece = Game(rawValue: "ONE_PIECE")
        public static let lorcana = Game(rawValue: "LORCANA")
        public static let yugioh = Game(rawValue: "YUGIOH")
        public static let generic = Game(rawValue: "GENERIC")
    }

    public struct Finish: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let normal = Finish(rawValue: "NORMAL")
        public static let foil = Finish(rawValue: "FOIL")
        public static let reverseHolo = Finish(rawValue: "REVERSE_HOLO")
        public static let holo = Finish(rawValue: "HOLO")
        public static let etched = Finish(rawValue: "ETCHED")
        public static let parallel = Finish(rawValue: "PARALLEL")
    }
}

// MARK: - Money / Variant

extension WasmClient.TCG {
    public struct Money: Sendable, Equatable {
        public let amount: String
        public let currency: String

        public init(amount: String = "", currency: String = "") {
            self.amount = amount
            self.currency = currency
        }
    }

    public struct Variant: Sendable, Equatable, Identifiable {
        public let id: String
        public let finish: Finish
        public let grade: String

        public init(id: String = "", finish: Finish = Finish(rawValue: ""), grade: String = "") {
            self.id = id
            self.finish = finish
            self.grade = grade
        }
    }
}

// MARK: - PricePoint / BuyLink

extension WasmClient.TCG {
    public struct PricePoint: Sendable, Equatable {
        public let at: String
        public let price: Money
        public let finish: Finish
        public let grade: String

        public init(at: String = "", price: Money = Money(), finish: Finish = Finish(rawValue: ""), grade: String = "") {
            self.at = at
            self.price = price
            self.finish = finish
            self.grade = grade
        }
    }

    public struct BuyLink: Sendable, Equatable, Identifiable {
        public let id: String
        public let url: String
        public let source: String
        public let price: Money

        public init(url: String = "", source: String = "", price: Money = Money()) {
            self.id = url
            self.url = url
            self.source = source
            self.price = price
        }
    }
}

// MARK: - GradePrice / GradePopulation

extension WasmClient.TCG {
    public struct GradePrice: Sendable, Equatable {
        public let variant: Variant
        public let gradeLabel: String
        public let marketPrice: Money
        public let marketPriceDiff: Money
        public let marketPricePercentageDiff: String
        public let imageURL: String

        public init(
            variant: Variant = Variant(),
            gradeLabel: String = "",
            marketPrice: Money = Money(),
            marketPriceDiff: Money = Money(),
            marketPricePercentageDiff: String = "",
            imageURL: String = ""
        ) {
            self.variant = variant
            self.gradeLabel = gradeLabel
            self.marketPrice = marketPrice
            self.marketPriceDiff = marketPriceDiff
            self.marketPricePercentageDiff = marketPricePercentageDiff
            self.imageURL = imageURL
        }
    }

    public struct GradePopulation: Sendable, Equatable {
        public let gradeLabel: String
        public let count: Int
        public let at: String

        public init(gradeLabel: String = "", count: Int = 0, at: String = "") {
            self.gradeLabel = gradeLabel
            self.count = count
            self.at = at
        }
    }
}

// MARK: - Card / CardMatch

extension WasmClient.TCG {
    public struct Card: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let game: Game
        public let setName: String
        public let setID: String
        public let number: String
        public let rarity: String
        public let imageURL: String
        public let marketPrice: Money
        public let marketPriceDiff: Money
        public let marketPricePercentageDiff: String
        public let isCard: Bool
        public let variants: [Variant]
        public let metadata: [String: String]

        public init(
            id: String = "",
            name: String = "",
            game: Game = Game(rawValue: ""),
            setName: String = "",
            setID: String = "",
            number: String = "",
            rarity: String = "",
            imageURL: String = "",
            marketPrice: Money = Money(),
            marketPriceDiff: Money = Money(),
            marketPricePercentageDiff: String = "",
            isCard: Bool = false,
            variants: [Variant] = [],
            metadata: [String: String] = [:]
        ) {
            self.id = id
            self.name = name
            self.game = game
            self.setName = setName
            self.setID = setID
            self.number = number
            self.rarity = rarity
            self.imageURL = imageURL
            self.marketPrice = marketPrice
            self.marketPriceDiff = marketPriceDiff
            self.marketPricePercentageDiff = marketPricePercentageDiff
            self.isCard = isCard
            self.variants = variants
            self.metadata = metadata
        }
    }

    public struct CardMatch: Sendable, Equatable {
        public let card: Card
        public let confidence: Double

        public init(card: Card = Card(), confidence: Double = 0) {
            self.card = card
            self.confidence = confidence
        }
    }
}

// MARK: - Scan

extension WasmClient.TCG {
    public struct ScanResult: Sendable, Equatable {
        public let scansRemaining: Int
        public let matches: [CardMatch]

        public init(scansRemaining: Int = 0, matches: [CardMatch] = []) {
            self.scansRemaining = scansRemaining
            self.matches = matches
        }
    }
}

// MARK: - CatalogDetail

extension WasmClient.TCG {
    public struct CatalogDetail: Sendable, Equatable {
        public let card: Card
        public let priceHistory: [PricePoint]
        public let buyLinks: [BuyLink]
        public let related: [Card]
        public let rawPrices: [GradePrice]
        public let gradedPrices: [GradePrice]
        public let population: [GradePopulation]
        public let ownedCount: Int

        public init(
            card: Card = Card(),
            priceHistory: [PricePoint] = [],
            buyLinks: [BuyLink] = [],
            related: [Card] = [],
            rawPrices: [GradePrice] = [],
            gradedPrices: [GradePrice] = [],
            population: [GradePopulation] = [],
            ownedCount: Int = 0
        ) {
            self.card = card
            self.priceHistory = priceHistory
            self.buyLinks = buyLinks
            self.related = related
            self.rawPrices = rawPrices
            self.gradedPrices = gradedPrices
            self.population = population
            self.ownedCount = ownedCount
        }
    }
}

// MARK: - SoldListings

extension WasmClient.TCG {
    public struct SoldListing: Sendable, Equatable, Identifiable {
        public let id: String
        public let marketplace: String
        public let title: String
        public let gradeLabel: String
        public let grade: String
        public let subType: String
        public let soldDate: String
        public let price: Money
        public let originalPrice: Money
        public let bidCount: Int
        public let url: String
        public let imageURL: String

        public init(
            id: String = "",
            marketplace: String = "",
            title: String = "",
            gradeLabel: String = "",
            grade: String = "",
            subType: String = "",
            soldDate: String = "",
            price: Money = Money(),
            originalPrice: Money = Money(),
            bidCount: Int = 0,
            url: String = "",
            imageURL: String = ""
        ) {
            self.id = id
            self.marketplace = marketplace
            self.title = title
            self.gradeLabel = gradeLabel
            self.grade = grade
            self.subType = subType
            self.soldDate = soldDate
            self.price = price
            self.originalPrice = originalPrice
            self.bidCount = bidCount
            self.url = url
            self.imageURL = imageURL
        }
    }

    public struct SoldListings: Sendable, Equatable {
        public let searchURL: String
        public let listings: [SoldListing]
        public let hasMore: Bool

        public init(searchURL: String = "", listings: [SoldListing] = [], hasMore: Bool = false) {
            self.searchURL = searchURL
            self.listings = listings
            self.hasMore = hasMore
        }
    }
}

// MARK: - CatalogBrowse

extension WasmClient.TCG {
    public struct CatalogBrowse: Sendable, Equatable {
        public let cards: [Card]
        public let page: Int
        public let total: Int

        public init(cards: [Card] = [], page: Int = 0, total: Int = 0) {
            self.cards = cards
            self.page = page
            self.total = total
        }
    }
}

// MARK: - SearchFilters

extension WasmClient.TCG {
    public struct SearchFilter: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let displayName: String
        public let imageURL: String
        public let iconImageURL: String
        public let quickFilter: Bool
        public let tier: String
        public let game: Game

        public init(
            id: String = "",
            name: String = "",
            displayName: String = "",
            imageURL: String = "",
            iconImageURL: String = "",
            quickFilter: Bool = false,
            tier: String = "",
            game: Game = Game(rawValue: "")
        ) {
            self.id = id
            self.name = name
            self.displayName = displayName
            self.imageURL = imageURL
            self.iconImageURL = iconImageURL
            self.quickFilter = quickFilter
            self.tier = tier
            self.game = game
        }
    }

    public struct SortOption: Sendable, Equatable, Identifiable {
        public let id: String
        public let displayName: String
        public let ascLabel: String
        public let descLabel: String
        public let ascIconURL: String
        public let descIconURL: String

        public init(
            id: String = "",
            displayName: String = "",
            ascLabel: String = "",
            descLabel: String = "",
            ascIconURL: String = "",
            descIconURL: String = ""
        ) {
            self.id = id
            self.displayName = displayName
            self.ascLabel = ascLabel
            self.descLabel = descLabel
            self.ascIconURL = ascIconURL
            self.descIconURL = descIconURL
        }
    }

    public struct SearchFilterCategory: Sendable, Equatable {
        public let title: String
        public let subtitle: String
        public let pro: Bool
        public let catalogSearch: Bool
        public let portfolioSearch: Bool
        public let showcaseSearch: Bool
        public let marketplaceSearch: Bool
        public let filters: [SearchFilter]

        public init(
            title: String = "",
            subtitle: String = "",
            pro: Bool = false,
            catalogSearch: Bool = false,
            portfolioSearch: Bool = false,
            showcaseSearch: Bool = false,
            marketplaceSearch: Bool = false,
            filters: [SearchFilter] = []
        ) {
            self.title = title
            self.subtitle = subtitle
            self.pro = pro
            self.catalogSearch = catalogSearch
            self.portfolioSearch = portfolioSearch
            self.showcaseSearch = showcaseSearch
            self.marketplaceSearch = marketplaceSearch
            self.filters = filters
        }
    }

    public struct FilterMutexGroup: Sendable, Equatable {
        public let filterIds: [String]

        public init(filterIds: [String] = []) {
            self.filterIds = filterIds
        }
    }

    public struct SearchFilters: Sendable, Equatable {
        public let filters: [SearchFilter]
        public let sortOptions: [SortOption]
        public let categories: [SearchFilterCategory]
        public let mutexGroups: [FilterMutexGroup]

        public init(
            filters: [SearchFilter] = [],
            sortOptions: [SortOption] = [],
            categories: [SearchFilterCategory] = [],
            mutexGroups: [FilterMutexGroup] = []
        ) {
            self.filters = filters
            self.sortOptions = sortOptions
            self.categories = categories
            self.mutexGroups = mutexGroups
        }
    }
}

// MARK: - Trending

extension WasmClient.TCG {
    public struct TrendingEntry: Sendable, Equatable, Identifiable {
        public let id: String
        public let cardID: String
        public let score: String
        public let rank: Int

        public init(cardID: String = "", score: String = "", rank: Int = 0) {
            self.id = cardID
            self.cardID = cardID
            self.score = score
            self.rank = rank
        }
    }

    public struct Trending: Sendable, Equatable {
        public let entries: [TrendingEntry]

        public init(entries: [TrendingEntry] = []) {
            self.entries = entries
        }
    }
}

// MARK: - ListSets

extension WasmClient.TCG {
    public struct SetLanguage: Sendable, Equatable, Identifiable {
        public let id: String
        public let code: String
        public let description: String
        public let orderNumber: Int

        public init(code: String = "", description: String = "", orderNumber: Int = 0) {
            self.id = code
            self.code = code
            self.description = description
            self.orderNumber = orderNumber
        }
    }

    public struct CardSet: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let cardCount: Int
        public let orderNumber: Int
        public let imageURL: String
        public let releaseDate: String
        public let webSlug: String
        public let ownedCount: Int
        public let totalValue: Money

        public init(
            id: String = "",
            name: String = "",
            cardCount: Int = 0,
            orderNumber: Int = 0,
            imageURL: String = "",
            releaseDate: String = "",
            webSlug: String = "",
            ownedCount: Int = 0,
            totalValue: Money = Money()
        ) {
            self.id = id
            self.name = name
            self.cardCount = cardCount
            self.orderNumber = orderNumber
            self.imageURL = imageURL
            self.releaseDate = releaseDate
            self.webSlug = webSlug
            self.ownedCount = ownedCount
            self.totalValue = totalValue
        }
    }

    public struct CategoryDetails: Sendable, Equatable {
        public let name: String
        public let imageURL: String

        public init(name: String = "", imageURL: String = "") {
            self.name = name
            self.imageURL = imageURL
        }
    }

    public struct ListSets: Sendable, Equatable {
        public let sets: [CardSet]
        public let languages: [SetLanguage]
        public let category: CategoryDetails
        public let currency: String

        public init(
            sets: [CardSet] = [],
            languages: [SetLanguage] = [],
            category: CategoryDetails = CategoryDetails(),
            currency: String = ""
        ) {
            self.sets = sets
            self.languages = languages
            self.category = category
            self.currency = currency
        }
    }
}
