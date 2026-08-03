@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Scan

extension WasmActor {

    func scan(
        imageData: Data,
        category: String,
        language: String
    ) async throws -> WasmClient.Vision.ScanResult {
        let instance = try await readyEngine()

        // Step 1: upload to blobstore
        let imageURL = try await uploadImage(imageData: imageData)
        logger("Scan: uploaded image → \(imageURL)")

        // Step 2: run scan action
        let scanAction = try await delegate.resolveAction(actionID: WasmClient.ActionID.scan.rawValue, logger: logger)
        let args = Self.scanArgs(fileURL: imageURL, category: category, language: language)
        let task = try await instance.create(action: scanAction, args: args)
        let visionResult = try Self.parseScanResult(task: task)
        var result = Self.mapScanResult(visionResult)
        // Attach the uploaded URL and provider for enrichment calls
        result.imageURL = imageURL
        result.provider = scanAction.provider
        return result
    }

    func describe(
        imageURL: String,
        category: String,
        language: String,
        provider: String
    ) async throws -> WasmClient.Vision.ScanResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.describe.rawValue,
            preferredProvider: provider.isEmpty ? nil : provider,
            logger: logger
        )
        let args = Self.scanArgs(fileURL: imageURL, category: category, language: language)
        let task = try await instance.create(action: action, args: args)
        let visionResult = try Self.parseScanResult(task: task)
        return Self.mapScanResult(visionResult)
    }

    /// Wire args shared by `scan` and `describe`. `category`/`language` are
    /// omitted at their engine-side defaults ("object"/"en") to keep the
    /// payload minimal.
    private static func scanArgs(
        fileURL: String,
        category: String,
        language: String
    ) -> [String: Google_Protobuf_Value] {
        var args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: fileURL)
        ]
        if category != "object" {
            args["category"] = Google_Protobuf_Value(stringValue: category)
        }
        if language != "en" {
            args["language"] = Google_Protobuf_Value(stringValue: language)
        }
        return args
    }

    func visualSearch(
        imageURL: String,
        provider: String
    ) async throws -> [WasmClient.Vision.ShoppingProduct] {
        _ = provider
        let instance = try await readyEngine()
        let args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: imageURL)
        ]
        logger("visualSearch: dispatch method=\(WasmClient.VisionMethod.visualSearch.rawValue) file=\(imageURL)")
        let result: VisionDiscoverResult = try await instance.run(
            method: WasmClient.VisionMethod.visualSearch.rawValue,
            args: args
        )
        logger("visualSearch: decoded \(result.products.count) product(s)")
        return result.products.map(Self.mapShoppingProduct)
    }

    func shopping(
        query: String,
        provider: String
    ) async throws -> [WasmClient.Vision.ShoppingProduct] {
        _ = provider
        let instance = try await readyEngine()
        let args: [String: Google_Protobuf_Value] = [
            "query": Google_Protobuf_Value(stringValue: query)
        ]
        logger("shopping: dispatch method=\(WasmClient.VisionMethod.shopping.rawValue) query=\(query)")
        let result: VisionShoppingResult = try await instance.run(
            method: WasmClient.VisionMethod.shopping.rawValue,
            args: args
        )
        logger("shopping: decoded \(result.products.count) product(s)")
        return result.products.map(Self.mapShoppingProduct)
    }
}

// MARK: - Parsing & Mapping

extension WasmActor {

    private static func parseScanResult(task: WaTTask) throws -> VisionScanResult {
        guard task.status == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        if let result = try? VisionScanResult(unpackingAny: task.value) {
            return result
        }
        // Fallback: legacy TypesBytes → JSON
        let bytes = try TypesBytes(unpackingAny: task.value)
        guard case .raw(let data) = bytes.data else {
            throw WasmClient.Error.unexpectedResponseFormat
        }
        var opts = JSONDecodingOptions()
        opts.ignoreUnknownFields = true
        return try VisionScanResult(jsonUTF8Data: data, options: opts)
    }

    private static func mapScanResult(_ v: VisionScanResult) -> WasmClient.Vision.ScanResult {
        WasmClient.Vision.ScanResult(
            title: v.hasTitle ? v.title : "",
            description: v.description_p,
            categoryType: v.hasCategoryType ? v.categoryType : "",
            imageURL: v.hasImageURL ? v.imageURL : "",
            characteristics: v.hasCharacteristics ? v.characteristics.fields : [:],
            suggestedQuestions: v.suggestedQuestions,
            nutrition: v.hasNutrition ? mapNutrition(v.nutrition) : nil,
            physical: v.hasPhysical ? mapPhysical(v.physical) : nil,
            price: v.hasPrice ? mapPrice(v.price) : nil,
            aiCommentary: v.hasAiCommentary ? mapAICommentary(v.aiCommentary) : nil,
            discoverMore: v.discoverMore.map(mapShoppingProduct),
            buyNow: v.buyNow.map(mapLink),
            sources: v.sources.map(mapLink),
            raw: v.hasRaw ? v.raw : nil
        )
    }

    private static func mapNutrition(_ n: VisionNutritionInfo) -> WasmClient.Vision.NutritionInfo {
        WasmClient.Vision.NutritionInfo(
            kcal: n.hasKcal ? n.kcal : nil,
            calories: n.hasCalories ? n.calories : nil,
            protein: n.hasProtein ? n.protein : nil,
            carbs: n.hasCarbs ? n.carbs : nil,
            fat: n.hasFat ? n.fat : nil,
            shelfLife: n.hasShelfLife ? n.shelfLife : nil,
            freshness: n.hasFreshness ? n.freshness : nil
        )
    }

    private static func mapPhysical(_ p: VisionPhysicalFeatures) -> WasmClient.Vision.PhysicalFeatures {
        var fields: [String: String] = [:]
        if p.hasWeight { fields["weight"] = p.weight }
        if p.hasDiameter { fields["diameter"] = p.diameter }
        if p.hasThickness { fields["thickness"] = p.thickness }
        if p.hasComposition { fields["composition"] = p.composition }
        if p.hasGrade { fields["grade"] = p.grade }
        if p.hasRarity { fields["rarity"] = p.rarity }
        if p.hasHardnessScale { fields["hardnessScale"] = p.hardnessScale }
        if p.hasDensity { fields["density"] = p.density }
        if p.hasColor { fields["color"] = p.color }
        if p.hasFormula { fields["formula"] = p.formula }
        if p.hasLuster { fields["luster"] = p.luster }
        return WasmClient.Vision.PhysicalFeatures(fields: fields)
    }

    private static func mapPrice(_ p: VisionPriceInfo) -> WasmClient.Vision.PriceInfo {
        WasmClient.Vision.PriceInfo(
            averageFairMarketPrice: p.hasAverageFairMarketPrice ? p.averageFairMarketPrice : nil,
            webPurchaseURL: p.hasWebPurchaseURL ? p.webPurchaseURL : nil
        )
    }

    private static func mapAICommentary(_ a: VisionAICommentary) -> WasmClient.Vision.AICommentary {
        WasmClient.Vision.AICommentary(
            aiAssistantSays: a.hasAiAssistantSays ? a.aiAssistantSays : nil,
            aiSuggests: a.hasAiSuggests ? a.aiSuggests : nil,
            expertInsights: a.hasExpertInsights ? a.expertInsights : nil,
            recommendation: a.hasRecommendation ? a.recommendation : nil,
            interestingFacts: a.hasInterestingFacts ? a.interestingFacts : nil,
            realOrFake: a.hasRealOrFake ? a.realOrFake : nil,
            marketDemand: a.hasMarketDemand ? a.marketDemand : nil
        )
    }

    private static func mapShoppingProduct(_ p: VisionShoppingProduct) -> WasmClient.Vision.ShoppingProduct {
        WasmClient.Vision.ShoppingProduct(
            title: p.hasTitle ? p.title : "",
            price: p.hasPrice ? p.price : nil,
            currency: p.hasCurrency ? p.currency : nil,
            url: p.hasURL ? p.url : "",
            image: p.hasImage ? p.image : nil,
            source: p.hasSource ? p.source : nil,
            rating: p.hasRating ? p.rating : nil,
            reviewsCount: p.hasReviewsCount ? Int(p.reviewsCount) : nil
        )
    }

    private static func mapLink(_ l: VisionLink) -> WasmClient.Vision.Link {
        WasmClient.Vision.Link(
            title: l.hasTitle ? l.title : "",
            url: l.hasURL ? l.url : "",
            description: l.hasDescription_p ? l.description_p : nil,
            image: l.hasImage ? l.image : nil
        )
    }
}
