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

    // MARK: - TCG Collections

    func tcgAccountInfo() async throws -> WasmClient.TCG.AccountInfo {
        let instance = try await readyEngine()
        let resp: TcgAccountInfoResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.accountInfo.rawValue,
            args: [:]
        )
        return Self.mapAccountInfo(resp)
    }

    func tcgListCollections() async throws -> [WasmClient.TCG.Collection] {
        let instance = try await readyEngine()
        let resp: TcgListCollectionsResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.listCollections.rawValue,
            args: [:]
        )
        return resp.collections.map(Self.mapCollection)
    }

    func tcgCreateCollection(
        name: String,
        isPublic: Bool
    ) async throws -> [WasmClient.TCG.Collection] {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !name.isEmpty { args["name"] = Google_Protobuf_Value(stringValue: name) }
        args["is_public"] = Google_Protobuf_Value(stringValue: isPublic ? "true" : "false")

        let resp: TcgListCollectionsResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.createCollection.rawValue,
            args: args
        )
        return resp.collections.map(Self.mapCollection)
    }

    func tcgUpdateCollection(
        collectionID: String,
        name: String?,
        isPublic: Bool?
    ) async throws -> [WasmClient.TCG.Collection] {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !collectionID.isEmpty { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }
        if let name { args["name"] = Google_Protobuf_Value(stringValue: name) }
        if let isPublic {
            args["is_public"] = Google_Protobuf_Value(stringValue: isPublic ? "true" : "false")
        }

        let resp: TcgListCollectionsResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.updateCollection.rawValue,
            args: args
        )
        return resp.collections.map(Self.mapCollection)
    }

    func tcgDeleteCollection(
        collectionID: String
    ) async throws -> [WasmClient.TCG.Collection] {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !collectionID.isEmpty { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }

        let resp: TcgListCollectionsResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.deleteCollection.rawValue,
            args: args
        )
        return resp.collections.map(Self.mapCollection)
    }

    func tcgCollectionSummary() async throws -> WasmClient.TCG.CollectionSummary {
        let instance = try await readyEngine()
        let resp: TcgCollectionSummaryResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.collectionSummary.rawValue,
            args: [:]
        )
        return Self.mapCollectionSummary(resp)
    }

    func tcgCollectionItems(
        collectionID: String,
        currency: String?,
        allCollections: Bool?
    ) async throws -> WasmClient.TCG.CollectionItems {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !collectionID.isEmpty { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }
        if let currency { args["currency"] = Google_Protobuf_Value(stringValue: currency) }
        if let allCollections {
            args["all_collections"] = Google_Protobuf_Value(stringValue: allCollections ? "true" : "false")
        }

        let resp: TcgCollectionItemsResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.collectionItems.rawValue,
            args: args
        )
        return WasmClient.TCG.CollectionItems(items: resp.items.map(Self.mapCollectionItem))
    }

    func tcgAddCards(
        collectionID: String,
        items: [WasmClient.TCG.AddCardItem]
    ) async throws -> WasmClient.TCG.AddCardsResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !collectionID.isEmpty { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }
        if !items.isEmpty {
            let encoded = items
                .compactMap { try? Self.mapAddCardItem($0).jsonUTF8Data() }
                .compactMap { String(data: $0, encoding: .utf8) }
            args["items"] = Google_Protobuf_Value(stringValue: "[" + encoded.joined(separator: ",") + "]")
        }

        let resp: TcgAddCardsResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.addCards.rawValue,
            args: args
        )
        return WasmClient.TCG.AddCardsResult(ok: resp.ok)
    }

    // MARK: - TCG Holdings

    func tcgHoldingDetail(
        holdingID: String
    ) async throws -> WasmClient.TCG.HoldingDetail {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !holdingID.isEmpty { args["holding_id"] = Google_Protobuf_Value(stringValue: holdingID) }

        let resp: TcgHoldingDetailResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.holdingDetail.rawValue,
            args: args
        )
        return Self.mapHoldingDetail(resp)
    }

    func tcgUpdateHolding(
        holdingID: String,
        paidPrice: String?,
        acquiredAt: String?,
        note: String?,
        quantity: Int?
    ) async throws -> WasmClient.TCG.UpdateHoldingResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !holdingID.isEmpty { args["holding_id"] = Google_Protobuf_Value(stringValue: holdingID) }
        if let paidPrice { args["paid_price"] = Google_Protobuf_Value(stringValue: paidPrice) }
        if let acquiredAt { args["acquired_at"] = Google_Protobuf_Value(stringValue: acquiredAt) }
        if let note { args["note"] = Google_Protobuf_Value(stringValue: note) }
        if let quantity { args["quantity"] = Google_Protobuf_Value(numberValue: Double(quantity)) }

        let resp: TcgUpdateHoldingResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.updateHolding.rawValue,
            args: args
        )
        return Self.mapUpdateHolding(resp)
    }

    func tcgRemoveHolding(
        holdingID: String,
        cardID: String,
        variant: WasmClient.TCG.Variant,
        quantity: Int
    ) async throws -> WasmClient.TCG.RemoveHoldingResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !holdingID.isEmpty { args["holding_id"] = Google_Protobuf_Value(stringValue: holdingID) }
        if !cardID.isEmpty { args["card_id"] = Google_Protobuf_Value(stringValue: cardID) }
        if let data = try? Self.variantProto(variant).jsonUTF8Data(),
           let json = String(data: data, encoding: .utf8) {
            args["variant"] = Google_Protobuf_Value(stringValue: json)
        }
        args["quantity"] = Google_Protobuf_Value(numberValue: Double(quantity))

        let resp: TcgRemoveHoldingResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.removeHolding.rawValue,
            args: args
        )
        return WasmClient.TCG.RemoveHoldingResult(ok: resp.ok)
    }

    // MARK: - TCG Analytics

    func tcgPortfolioPerformance(
        collectionID: String,
        currency: String?,
        allCollections: Bool?,
        window: WasmClient.TCG.AnalyticsWindow
    ) async throws -> WasmClient.TCG.PortfolioPerformance {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !collectionID.isEmpty { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }
        if let currency { args["currency"] = Google_Protobuf_Value(stringValue: currency) }
        if let allCollections {
            args["all_collections"] = Google_Protobuf_Value(stringValue: allCollections ? "true" : "false")
        }
        if !window.rawValue.isEmpty { args["window"] = Google_Protobuf_Value(stringValue: window.rawValue) }

        let resp: TcgPortfolioPerformanceResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.portfolioPerformance.rawValue,
            args: args
        )
        return Self.mapPortfolioPerformance(resp)
    }

    func tcgValueOverTime(
        collectionID: String,
        window: WasmClient.TCG.AnalyticsWindow,
        currency: String?,
        allCollections: Bool?
    ) async throws -> WasmClient.TCG.ValueOverTime {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !collectionID.isEmpty { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }
        if !window.rawValue.isEmpty { args["window"] = Google_Protobuf_Value(stringValue: window.rawValue) }
        if let currency { args["currency"] = Google_Protobuf_Value(stringValue: currency) }
        if let allCollections {
            args["all_collections"] = Google_Protobuf_Value(stringValue: allCollections ? "true" : "false")
        }

        let resp: TcgValueOverTimeResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.valueOverTime.rawValue,
            args: args
        )
        return Self.mapValueOverTime(resp)
    }

    func tcgTopMovers(
        collectionID: String,
        window: WasmClient.TCG.AnalyticsWindow,
        limit: Int?,
        currency: String?,
        allCollections: Bool?
    ) async throws -> WasmClient.TCG.TopMovers {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !collectionID.isEmpty { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }
        if !window.rawValue.isEmpty { args["window"] = Google_Protobuf_Value(stringValue: window.rawValue) }
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }
        if let currency { args["currency"] = Google_Protobuf_Value(stringValue: currency) }
        if let allCollections {
            args["all_collections"] = Google_Protobuf_Value(stringValue: allCollections ? "true" : "false")
        }

        let resp: TcgTopMoversResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.topMovers.rawValue,
            args: args
        )
        return Self.mapTopMovers(resp)
    }

    func tcgPerformanceBreakdown(
        collectionID: String,
        facet: WasmClient.TCG.BreakdownFacet,
        window: WasmClient.TCG.AnalyticsWindow,
        currency: String?,
        allCollections: Bool?
    ) async throws -> WasmClient.TCG.PerformanceBreakdown {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !collectionID.isEmpty { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }
        if !facet.rawValue.isEmpty { args["facet"] = Google_Protobuf_Value(stringValue: facet.rawValue) }
        if !window.rawValue.isEmpty { args["window"] = Google_Protobuf_Value(stringValue: window.rawValue) }
        if let currency { args["currency"] = Google_Protobuf_Value(stringValue: currency) }
        if let allCollections {
            args["all_collections"] = Google_Protobuf_Value(stringValue: allCollections ? "true" : "false")
        }

        let resp: TcgPerformanceBreakdownResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.performanceBreakdown.rawValue,
            args: args
        )
        return Self.mapPerformanceBreakdown(resp)
    }

    func tcgProfitLoss(
        collectionID: String,
        currency: String?
    ) async throws -> WasmClient.TCG.ProfitLoss {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !collectionID.isEmpty { args["collection_id"] = Google_Protobuf_Value(stringValue: collectionID) }
        if let currency { args["currency"] = Google_Protobuf_Value(stringValue: currency) }

        let resp: TcgProfitLossResponse = try await instance.run(
            method: WasmClient.TCG.ServiceMethod.profitLoss.rawValue,
            args: args
        )
        return Self.mapProfitLoss(resp)
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

    // MARK: - Collections mapping

    static func mapCondition(_ proto: TcgCondition) -> WasmClient.TCG.Condition {
        switch proto {
        case .nearMint: return .nearMint
        case .lightlyPlayed: return .lightlyPlayed
        case .moderatelyPlayed: return .moderatelyPlayed
        case .heavilyPlayed: return .heavilyPlayed
        case .damaged: return .damaged
        default: return WasmClient.TCG.Condition(rawValue: "")
        }
    }

    static func conditionProto(_ condition: WasmClient.TCG.Condition) -> TcgCondition {
        switch condition {
        case .nearMint: return .nearMint
        case .lightlyPlayed: return .lightlyPlayed
        case .moderatelyPlayed: return .moderatelyPlayed
        case .heavilyPlayed: return .heavilyPlayed
        case .damaged: return .damaged
        default: return .unspecified
        }
    }

    static func finishProto(_ finish: WasmClient.TCG.Finish) -> TcgFinish {
        switch finish {
        case .normal: return .normal
        case .foil: return .foil
        case .reverseHolo: return .reverseHolo
        case .holo: return .holo
        case .etched: return .etched
        case .parallel: return .parallel
        default: return .unspecified
        }
    }

    static func mapAccount(_ proto: TcgAccount) -> WasmClient.TCG.Account {
        WasmClient.TCG.Account(
            id: proto.id,
            handle: proto.handle,
            nickname: proto.nickname,
            email: proto.email,
            tier: proto.tier,
            defaultCurrency: proto.defaultCurrency,
            totalCards: proto.totalCards,
            totalFollowers: proto.totalFollowers,
            totalFollowing: proto.totalFollowing,
            metadata: mapStruct(proto.metadata)
        )
    }

    static func mapAccountInfo(_ proto: TcgAccountInfoResponse) -> WasmClient.TCG.AccountInfo {
        WasmClient.TCG.AccountInfo(account: mapAccount(proto.account))
    }

    static func mapCollection(_ proto: TcgCollection) -> WasmClient.TCG.Collection {
        WasmClient.TCG.Collection(
            id: proto.id,
            name: proto.name,
            isDefault: proto.isDefault,
            color: proto.color,
            isPublic: proto.isPublic,
            ordering: Int(proto.ordering)
        )
    }

    static func mapCollectionSummary(_ proto: TcgCollectionSummaryResponse) -> WasmClient.TCG.CollectionSummary {
        WasmClient.TCG.CollectionSummary(
            totalCards: proto.totalCards,
            totalSealed: proto.totalSealed,
            totalGraded: proto.totalGraded,
            totalValue: mapMoney(proto.totalValue)
        )
    }

    static func mapCollectionItem(_ proto: TcgCollectionItem) -> WasmClient.TCG.CollectionItem {
        WasmClient.TCG.CollectionItem(
            id: proto.id,
            card: mapCard(proto.card),
            variant: mapVariant(proto.variant),
            quantity: Int(proto.quantity),
            condition: mapCondition(proto.condition),
            paidPrice: mapMoney(proto.paidPrice),
            marketPrice: mapMoney(proto.marketPrice),
            acquiredAt: proto.acquiredAt,
            note: proto.note
        )
    }

    static func mapAddCardItem(_ item: WasmClient.TCG.AddCardItem) -> TcgAddCardItem {
        var proto = TcgAddCardItem()
        proto.cardID = item.cardID
        if !item.variantID.isEmpty { proto.variantID = item.variantID }
        proto.quantity = Int32(item.quantity)
        proto.condition = conditionProto(item.condition)
        proto.finish = finishProto(item.finish)
        if !item.paidPrice.isEmpty { proto.paidPrice = item.paidPrice }
        return proto
    }

    // MARK: - Holdings mapping

    static func variantProto(_ variant: WasmClient.TCG.Variant) -> TcgVariant {
        var proto = TcgVariant()
        proto.id = variant.id
        proto.finish = finishProto(variant.finish)
        proto.grade = variant.grade
        return proto
    }

    static func mapHoldingDetail(_ proto: TcgHoldingDetailResponse) -> WasmClient.TCG.HoldingDetail {
        WasmClient.TCG.HoldingDetail(item: mapCollectionItem(proto.item))
    }

    static func mapUpdateHolding(_ proto: TcgUpdateHoldingResponse) -> WasmClient.TCG.UpdateHoldingResult {
        WasmClient.TCG.UpdateHoldingResult(ok: proto.ok, item: mapCollectionItem(proto.item))
    }

    static func mapStruct(_ metadata: Google_Protobuf_Struct) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in metadata.fields {
            result[key] = value.stringValue
        }
        return result
    }

    // MARK: - Analytics mapping (wire argString; mirrors tcg.fk.pb.swift)

    static func mapWindow(_ proto: TcgAnalyticsWindow) -> WasmClient.TCG.AnalyticsWindow {
        switch proto {
        case .unspecified: return .allTime
        case .oneDay: return .oneDay
        case .oneWeek: return .oneWeek
        case .oneMonth: return .oneMonth
        case .threeMonths: return .threeMonths
        case .sixMonths: return .sixMonths
        case .oneYear: return .oneYear
        case .max: return .max
        default: return .threeMonths
        }
    }

    static func mapFacet(_ proto: TcgBreakdownFacet) -> WasmClient.TCG.BreakdownFacet {
        switch proto {
        case .unspecified: return .bySet
        case .bySet: return .bySet
        case .byRarity: return .byRarity
        case .byGame: return .byGame
        case .byFinish: return .byFinish
        default: return .bySet
        }
    }

    static func mapMoverDirection(_ proto: TcgMoverDirection) -> WasmClient.TCG.MoverDirection {
        switch proto {
        case .up: return .up
        case .down: return .down
        case .flat: return .flat
        default: return WasmClient.TCG.MoverDirection(rawValue: "")
        }
    }

    static func mapPortfolioPerformance(_ proto: TcgPortfolioPerformanceResponse) -> WasmClient.TCG.PortfolioPerformance {
        WasmClient.TCG.PortfolioPerformance(
            costBasis: mapMoney(proto.costBasis),
            marketValue: mapMoney(proto.marketValue),
            gain: mapMoney(proto.gain),
            roiPercentage: proto.roiPercentage,
            cardCount: Int(proto.cardCount),
            window: mapWindow(proto.window)
        )
    }

    static func mapValuePoint(_ proto: TcgValuePoint) -> WasmClient.TCG.ValuePoint {
        WasmClient.TCG.ValuePoint(at: proto.at, value: mapMoney(proto.value))
    }

    static func mapValueOverTime(_ proto: TcgValueOverTimeResponse) -> WasmClient.TCG.ValueOverTime {
        WasmClient.TCG.ValueOverTime(
            marketSeries: proto.marketSeries.map(mapValuePoint),
            costBasisSeries: proto.costBasisSeries.map(mapValuePoint),
            peakValue: mapMoney(proto.peakValue),
            peakAt: proto.peakAt,
            peakIsCurrent: proto.peakIsCurrent,
            window: mapWindow(proto.window),
            unrealizedPnlSeries: proto.unrealizedPnlSeries.map(mapValuePoint),
            pnlSeriesIsDerived: proto.pnlSeriesIsDerived,
            carousel: proto.carousel.map(mapCarouselSection)
        )
    }

    static func mapSortKind(_ proto: TcgSortKind) -> WasmClient.TCG.SortKind {
        switch proto {
        case .price: return .price
        case .name: return .name
        case .trending: return .trending
        case .dateAdded: return .dateAdded
        case .releaseDate: return .releaseDate
        case .quantity: return .quantity
        case .other: return .other
        default: return WasmClient.TCG.SortKind(rawValue: "")
        }
    }

    static func mapCarouselSection(_ proto: TcgCarouselSection) -> WasmClient.TCG.CarouselSection {
        WasmClient.TCG.CarouselSection(
            title: proto.title,
            sortID: proto.sortID,
            sortAscending: proto.sortAscending,
            cards: proto.cards.map(mapCard),
            kind: mapSortKind(proto.kind)
        )
    }

    static func mapMover(_ proto: TcgMover) -> WasmClient.TCG.Mover {
        WasmClient.TCG.Mover(
            card: mapCard(proto.card),
            variant: mapVariant(proto.variant),
            currentPrice: mapMoney(proto.currentPrice),
            windowOpenPrice: mapMoney(proto.windowOpenPrice),
            priceChange: mapMoney(proto.priceChange),
            changePercentage: proto.changePercentage
        )
    }

    static func mapTopMovers(_ proto: TcgTopMoversResponse) -> WasmClient.TCG.TopMovers {
        WasmClient.TCG.TopMovers(
            movers: proto.movers.map(mapMover),
            window: mapWindow(proto.window)
        )
    }

    static func mapBreakdownGroup(_ proto: TcgBreakdownGroup) -> WasmClient.TCG.BreakdownGroup {
        WasmClient.TCG.BreakdownGroup(
            label: proto.label,
            cardCount: Int(proto.cardCount),
            marketValue: mapMoney(proto.marketValue),
            changePercentage: proto.changePercentage,
            direction: mapMoverDirection(proto.direction),
            barFill: proto.barFill
        )
    }

    static func mapPerformanceBreakdown(_ proto: TcgPerformanceBreakdownResponse) -> WasmClient.TCG.PerformanceBreakdown {
        WasmClient.TCG.PerformanceBreakdown(
            groups: proto.groups.map(mapBreakdownGroup),
            facet: mapFacet(proto.facet),
            window: mapWindow(proto.window)
        )
    }

    static func mapProfitLossSummary(_ proto: TcgProfitLossSummary) -> WasmClient.TCG.ProfitLossSummary {
        WasmClient.TCG.ProfitLossSummary(
            costBasis: mapMoney(proto.costBasis),
            marketValue: mapMoney(proto.marketValue),
            gain: mapMoney(proto.gain),
            roiPercentage: proto.roiPercentage
        )
    }

    static func mapProfitLossRow(_ proto: TcgProfitLossRow) -> WasmClient.TCG.ProfitLossRow {
        WasmClient.TCG.ProfitLossRow(
            game: mapGame(proto.game),
            categoryID: proto.categoryID,
            categoryName: proto.categoryName,
            costBasis: mapMoney(proto.costBasis),
            marketValue: mapMoney(proto.marketValue),
            gain: mapMoney(proto.gain),
            roiPercentage: proto.roiPercentage
        )
    }

    static func mapProfitLoss(_ proto: TcgProfitLossResponse) -> WasmClient.TCG.ProfitLoss {
        WasmClient.TCG.ProfitLoss(
            currency: proto.currency,
            summary: mapProfitLossSummary(proto.summary),
            rows: proto.rows.map(mapProfitLossRow)
        )
    }
}
