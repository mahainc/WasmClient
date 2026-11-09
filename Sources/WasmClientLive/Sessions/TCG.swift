@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - TCG Catalog / lookup

extension WasmActor {
    func tcgScan(
        imageBase64: String,
        game: WasmClient.TCG.Game
    ) async throws -> WasmClient.TCG.ScanResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !imageBase64.isEmpty { args["image_base64"] = Google_Protobuf_Value(stringValue: imageBase64) }
        if !game.rawValue.isEmpty { args["game"] = Google_Protobuf_Value(stringValue: game.rawValue) }

        let resp: TcgScanResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.scan.rawValue,
            args: args
        )
        return Self.mapScan(resp)
    }

    func tcgCatalogDetail(
        cardID: String,
        currency: String?
    ) async throws -> WasmClient.TCG.CatalogDetail {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !cardID.isEmpty { args["card_id"] = Google_Protobuf_Value(stringValue: cardID) }
        if let currency { args["currency"] = Google_Protobuf_Value(stringValue: currency) }

        let resp: TcgCatalogDetailResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.catalogDetail.rawValue,
            args: args
        )
        return Self.mapCatalogDetail(resp)
    }

    func tcgSoldListings(
        cardID: String,
        grade: String?,
        subType: String?,
        offset: Int?,
        limit: Int?
    ) async throws -> WasmClient.TCG.SoldListings {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !cardID.isEmpty { args["card_id"] = Google_Protobuf_Value(stringValue: cardID) }
        if let grade { args["grade"] = Google_Protobuf_Value(stringValue: grade) }
        if let subType { args["sub_type"] = Google_Protobuf_Value(stringValue: subType) }
        if let offset { args["offset"] = Google_Protobuf_Value(numberValue: Double(offset)) }
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }

        let resp: TcgSoldListingsResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.soldListings.rawValue,
            args: args
        )
        return Self.mapSoldListings(resp)
    }

    func tcgCatalogBrowse(
        page: Int?,
        limit: Int?,
        game: WasmClient.TCG.Game,
        query: String?,
        sortID: String?,
        sortAscending: Bool?,
        filterIds: [String],
        setID: String?
    ) async throws -> WasmClient.TCG.CatalogBrowse {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if let page { args["page"] = Google_Protobuf_Value(numberValue: Double(page)) }
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }
        if !game.rawValue.isEmpty { args["game"] = Google_Protobuf_Value(stringValue: game.rawValue) }
        if let query { args["query"] = Google_Protobuf_Value(stringValue: query) }
        if let sortID { args["sort_id"] = Google_Protobuf_Value(stringValue: sortID) }
        if let sortAscending {
            args["sort_ascending"] = Google_Protobuf_Value(stringValue: sortAscending ? "true" : "false")
        }
        if !filterIds.isEmpty {
            args["filter_ids"] = Google_Protobuf_Value(stringValue: filterIds.joined(separator: ","))
        }
        if let setID { args["set_id"] = Google_Protobuf_Value(stringValue: setID) }

        let resp: TcgCatalogBrowseResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.catalogBrowse.rawValue,
            args: args
        )
        return Self.mapCatalogBrowse(resp)
    }

    func tcgTrending(
        game: WasmClient.TCG.Game
    ) async throws -> WasmClient.TCG.Trending {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !game.rawValue.isEmpty { args["game"] = Google_Protobuf_Value(stringValue: game.rawValue) }

        let resp: TcgTrendingResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.trending.rawValue,
            args: args
        )
        return WasmClient.TCG.Trending(entries: resp.entries.map(Self.mapTrendingEntry))
    }

    func tcgSearchFilters() async throws -> WasmClient.TCG.SearchFilters {
        let instance = try await readyEngine()
        let resp: TcgSearchFiltersResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.searchFilters.rawValue,
            args: [:]
        )
        return Self.mapSearchFilters(resp)
    }

    func tcgListSets(
        collectionID: String?,
        game: WasmClient.TCG.Game,
        language: String?,
        currency: String?,
        allCollections: Bool?
    ) async throws -> WasmClient.TCG.ListSets {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if let collectionID { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }
        if !game.rawValue.isEmpty { args["game"] = Google_Protobuf_Value(stringValue: game.rawValue) }
        if let language { args["language"] = Google_Protobuf_Value(stringValue: language) }
        if let currency { args["currency"] = Google_Protobuf_Value(stringValue: currency) }
        if let allCollections {
            args["all_collections"] = Google_Protobuf_Value(stringValue: allCollections ? "true" : "false")
        }

        let resp: TcgListSetsResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.listSets.rawValue,
            args: args
        )
        return Self.mapListSets(resp)
    }

    // MARK: - Enum mapping (wire argString; empty = unspecified)

    static func mapGame(_ proto: TcgGame) -> WasmClient.TCG.Game {
        switch proto {
        case .pokemon: return .pokemon
        case .pokemonJp: return .pokemonJP
        case .magicTheGathering: return .magicTheGathering
        case .onePiece: return .onePiece
        case .lorcana: return .lorcana
        case .yugioh: return .yugioh
        case .generic: return .generic
        default: return WasmClient.TCG.Game(rawValue: "")
        }
    }

    static func mapFinish(_ proto: TcgFinish) -> WasmClient.TCG.Finish {
        switch proto {
        case .normal: return .normal
        case .foil: return .foil
        case .reverseHolo: return .reverseHolo
        case .holo: return .holo
        case .etched: return .etched
        case .parallel: return .parallel
        default: return WasmClient.TCG.Finish(rawValue: "")
        }
    }

    // MARK: - Value mapping

    static func mapMoney(_ proto: TcgMoney) -> WasmClient.TCG.Money {
        WasmClient.TCG.Money(amount: proto.amount, currency: proto.currency)
    }

    static func mapVariant(_ proto: TcgVariant) -> WasmClient.TCG.Variant {
        WasmClient.TCG.Variant(id: proto.id, finish: mapFinish(proto.finish), grade: proto.grade)
    }

    static func mapPricePoint(_ proto: TcgPricePoint) -> WasmClient.TCG.PricePoint {
        WasmClient.TCG.PricePoint(
            at: proto.at,
            price: mapMoney(proto.price),
            finish: mapFinish(proto.finish),
            grade: proto.grade
        )
    }

    static func mapBuyLink(_ proto: TcgBuyLink) -> WasmClient.TCG.BuyLink {
        WasmClient.TCG.BuyLink(url: proto.url, source: proto.source, price: mapMoney(proto.price))
    }

    static func mapGradePrice(_ proto: TcgGradePrice) -> WasmClient.TCG.GradePrice {
        WasmClient.TCG.GradePrice(
            variant: mapVariant(proto.variant),
            gradeLabel: proto.gradeLabel,
            marketPrice: mapMoney(proto.marketPrice),
            marketPriceDiff: mapMoney(proto.marketPriceDiff),
            marketPricePercentageDiff: proto.marketPricePercentageDiff,
            imageURL: proto.imageURL
        )
    }

    static func mapGradePopulation(_ proto: TcgGradePopulation) -> WasmClient.TCG.GradePopulation {
        WasmClient.TCG.GradePopulation(gradeLabel: proto.gradeLabel, count: Int(proto.count), at: proto.at)
    }

    static func mapCard(_ proto: TcgCard) -> WasmClient.TCG.Card {
        WasmClient.TCG.Card(
            id: proto.id,
            name: proto.name,
            game: mapGame(proto.game),
            setName: proto.setName,
            setID: proto.setID,
            number: proto.number,
            rarity: proto.rarity,
            imageURL: proto.imageURL,
            marketPrice: mapMoney(proto.marketPrice),
            marketPriceDiff: mapMoney(proto.marketPriceDiff),
            marketPricePercentageDiff: proto.marketPricePercentageDiff,
            isCard: proto.isCard,
            variants: proto.variants.map(mapVariant),
            metadata: mapStruct(proto.metadata)
        )
    }

    static func mapCardMatch(_ proto: TcgCardMatch) -> WasmClient.TCG.CardMatch {
        WasmClient.TCG.CardMatch(card: mapCard(proto.card), confidence: proto.confidence)
    }

    static func mapScan(_ proto: TcgScanResponse) -> WasmClient.TCG.ScanResult {
        WasmClient.TCG.ScanResult(
            scansRemaining: Int(proto.scansRemaining),
            matches: proto.matches.map(mapCardMatch)
        )
    }

    static func mapCatalogDetail(_ proto: TcgCatalogDetailResponse) -> WasmClient.TCG.CatalogDetail {
        WasmClient.TCG.CatalogDetail(
            card: mapCard(proto.card),
            priceHistory: proto.priceHistory.map(mapPricePoint),
            buyLinks: proto.buyLinks.map(mapBuyLink),
            related: proto.related.map(mapCard),
            rawPrices: proto.rawPrices.map(mapGradePrice),
            gradedPrices: proto.gradedPrices.map(mapGradePrice),
            population: proto.population.map(mapGradePopulation),
            ownedCount: Int(proto.ownedCount)
        )
    }

    static func mapSoldListing(_ proto: TcgSoldListing) -> WasmClient.TCG.SoldListing {
        WasmClient.TCG.SoldListing(
            id: proto.id,
            marketplace: proto.marketplace,
            title: proto.title,
            gradeLabel: proto.gradeLabel,
            grade: proto.grade,
            subType: proto.subType,
            soldDate: proto.soldDate,
            price: mapMoney(proto.price),
            originalPrice: mapMoney(proto.originalPrice),
            bidCount: Int(proto.bidCount),
            url: proto.url,
            imageURL: proto.imageURL
        )
    }

    static func mapSoldListings(_ proto: TcgSoldListingsResponse) -> WasmClient.TCG.SoldListings {
        WasmClient.TCG.SoldListings(
            searchURL: proto.searchURL,
            listings: proto.listings.map(mapSoldListing),
            hasMore: proto.hasMore_p
        )
    }

    static func mapCatalogBrowse(_ proto: TcgCatalogBrowseResponse) -> WasmClient.TCG.CatalogBrowse {
        WasmClient.TCG.CatalogBrowse(
            cards: proto.cards.map(mapCard),
            page: Int(proto.page),
            total: Int(proto.total)
        )
    }

    static func mapSearchFilter(_ proto: TcgSearchFilter) -> WasmClient.TCG.SearchFilter {
        WasmClient.TCG.SearchFilter(
            id: proto.id,
            name: proto.name,
            displayName: proto.displayName,
            imageURL: proto.imageURL,
            iconImageURL: proto.iconImageURL,
            quickFilter: proto.quickFilter,
            tier: proto.tier,
            game: mapGame(proto.game)
        )
    }

    static func mapSortOption(_ proto: TcgSortOption) -> WasmClient.TCG.SortOption {
        WasmClient.TCG.SortOption(
            id: proto.id,
            displayName: proto.displayName,
            ascLabel: proto.ascLabel,
            descLabel: proto.descLabel,
            ascIconURL: proto.ascIconURL,
            descIconURL: proto.descIconURL
        )
    }

    static func mapSearchFilterCategory(_ proto: TcgSearchFilterCategory) -> WasmClient.TCG.SearchFilterCategory {
        WasmClient.TCG.SearchFilterCategory(
            title: proto.title,
            subtitle: proto.subtitle,
            pro: proto.pro,
            catalogSearch: proto.catalogSearch,
            portfolioSearch: proto.portfolioSearch,
            showcaseSearch: proto.showcaseSearch,
            marketplaceSearch: proto.marketplaceSearch,
            filters: proto.filters.map(mapSearchFilter)
        )
    }

    static func mapSearchFilters(_ proto: TcgSearchFiltersResponse) -> WasmClient.TCG.SearchFilters {
        WasmClient.TCG.SearchFilters(
            filters: proto.filters.map(mapSearchFilter),
            sortOptions: proto.sortOptions.map(mapSortOption),
            categories: proto.categories.map(mapSearchFilterCategory),
            mutexGroups: proto.mutexGroups.map { WasmClient.TCG.FilterMutexGroup(filterIds: $0.filterIds) }
        )
    }

    static func mapTrendingEntry(_ proto: TcgTrendingEntry) -> WasmClient.TCG.TrendingEntry {
        WasmClient.TCG.TrendingEntry(cardID: proto.cardID, score: proto.score, rank: Int(proto.rank))
    }

    static func mapSetLanguage(_ proto: TcgSetLanguage) -> WasmClient.TCG.SetLanguage {
        WasmClient.TCG.SetLanguage(
            code: proto.code,
            description: proto.description_p,
            orderNumber: Int(proto.orderNumber)
        )
    }

    static func mapCardSet(_ proto: TcgCardSet) -> WasmClient.TCG.CardSet {
        WasmClient.TCG.CardSet(
            id: proto.id,
            name: proto.name,
            cardCount: Int(proto.cardCount),
            orderNumber: Int(proto.orderNumber),
            imageURL: proto.imageURL,
            releaseDate: proto.releaseDate,
            webSlug: proto.webSlug,
            ownedCount: Int(proto.ownedCount),
            totalValue: mapMoney(proto.totalValue)
        )
    }

    static func mapListSets(_ proto: TcgListSetsResponse) -> WasmClient.TCG.ListSets {
        WasmClient.TCG.ListSets(
            sets: proto.sets.map(mapCardSet),
            languages: proto.languages.map(mapSetLanguage),
            category: WasmClient.TCG.CategoryDetails(
                name: proto.category.name, imageURL: proto.category.imageURL
            ),
            currency: proto.currency
        )
    }

    static func mapStruct(_ metadata: Google_Protobuf_Struct) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in metadata.fields {
            result[key] = value.stringValue
        }
        return result
    }
}
