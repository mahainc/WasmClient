@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Scan

extension WasmActor {

    /// Upload image data, then scan it via the vision engine.
    /// Returns a mapped ScanResult with all fields including the imageURL and provider used.
    func scan(
        imageData: Data,
        category: String,
        language: String
    ) async throws -> WasmClient.ScanResult {
        let instance = try await readyEngine()

        // Step 1: upload to blobstore
        let imageURL = try await uploadImage(imageData: imageData)
        logger("Scan: uploaded image → \(imageURL)")

        // Step 2: run scan action
        let scanAction = try await delegate.resolveAction(actionID: WasmClient.ActionID.scan.rawValue, logger: logger)
        var args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: imageURL)
        ]
        if category != "object" {
            args["category"] = Google_Protobuf_Value(stringValue: category)
        }
        if language != "en" {
            args["language"] = Google_Protobuf_Value(stringValue: language)
        }
        let task = try await instance.create(action: scanAction, args: args)
        let visionResult = try Self.parseScanResult(task: task)
        var result = Self.mapScanResult(visionResult)
        // Attach the uploaded URL and provider for enrichment calls
        result.imageURL = imageURL
        result.provider = scanAction.provider
        return result
    }

    /// Describe/enrich an image with full details using the describe action.
    /// Uses the same provider as the initial scan when possible.
    func describe(
        imageURL: String,
        category: String,
        language: String,
        provider: String
    ) async throws -> WasmClient.ScanResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.describe.rawValue,
            preferredProvider: provider.isEmpty ? nil : provider,
            logger: logger
        )
        var args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: imageURL)
        ]
        if category != "object" {
            args["category"] = Google_Protobuf_Value(stringValue: category)
        }
        if language != "en" {
            args["language"] = Google_Protobuf_Value(stringValue: language)
        }
        let task = try await instance.create(action: action, args: args)
        let visionResult = try Self.parseScanResult(task: task)
        return Self.mapScanResult(visionResult)
    }

    /// Run visual search on an already-uploaded image URL.
    ///
    /// Dispatches via the method-name route (`asyncify.vision.VisionService/VisualSearch`)
    /// rather than legacy UUID discovery — the dispatcher routes by method name and picks
    /// the provider via the persisted `provider_strategy`.
    ///
    /// `provider` is intentionally NOT forwarded as the providerId: VisualSearch is served
    /// by different providers than Scan, so pinning the caller's scan provider here makes the
    /// engine answer 502 "unsupported". Mirrors flow-kit-example, which always lets the
    /// strategy choose for this RPC (`vision.visualSearch(file:)`). The parameter is kept for
    /// source compatibility.
    func visualSearch(
        imageURL: String,
        provider: String
    ) async throws -> [WasmClient.ShoppingProduct] {
        _ = provider
        let instance = try await readyEngine()
        let args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: imageURL)
        ]
        logger("visualSearch: dispatch method=\(WasmClient.VisionMethod.visualSearch.rawValue) file=\(imageURL)")
        let task = try await instance.create(
            providerId: "",
            actionId: WasmClient.VisionMethod.visualSearch.rawValue,
            args: args
        )
        logger("visualSearch: task status=\(task.status) hasValue=\(task.hasValue)")
        guard task.status == .completed, task.hasValue else {
            let err = task.metadata.fields["error"]?.stringValue ?? "—"
            logger("visualSearch: FAILED status=\(task.status) error=\(err) — throwing taskFailed")
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let result = try VisionDiscoverResult(unpackingAny: task.value)
        logger("visualSearch: decoded \(result.products.count) product(s)")
        return result.products.map(Self.mapShoppingProduct)
    }

    /// Search for shopping products by text query.
    ///
    /// Dispatches via the method-name route (`asyncify.vision.VisionService/Shopping`)
    /// rather than legacy UUID discovery — the dispatcher picks the provider via the
    /// persisted `provider_strategy`.
    ///
    /// `provider` is intentionally NOT forwarded as the providerId (see `visualSearch` —
    /// Shopping is served by different providers than Scan; pinning the scan provider yields
    /// a 502). Mirrors flow-kit-example's `vision.shopping(query:)`. Kept for source compat.
    func shopping(
        query: String,
        provider: String
    ) async throws -> [WasmClient.ShoppingProduct] {
        _ = provider
        let instance = try await readyEngine()
        let args: [String: Google_Protobuf_Value] = [
            "query": Google_Protobuf_Value(stringValue: query)
        ]
        logger("shopping: dispatch method=\(WasmClient.VisionMethod.shopping.rawValue) query=\(query)")
        let task = try await instance.create(
            providerId: "",
            actionId: WasmClient.VisionMethod.shopping.rawValue,
            args: args
        )
        logger("shopping: task status=\(task.status) hasValue=\(task.hasValue)")
        guard task.status == .completed, task.hasValue else {
            let err = task.metadata.fields["error"]?.stringValue ?? "—"
            logger("shopping: FAILED status=\(task.status) error=\(err) — throwing taskFailed")
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let result = try VisionShoppingResult(unpackingAny: task.value)
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

    private static func mapScanResult(_ v: VisionScanResult) -> WasmClient.ScanResult {
        WasmClient.ScanResult(
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

    private static func mapNutrition(_ n: VisionNutritionInfo) -> WasmClient.NutritionInfo {
        WasmClient.NutritionInfo(
            kcal: n.hasKcal ? n.kcal : nil,
            calories: n.hasCalories ? n.calories : nil,
            protein: n.hasProtein ? n.protein : nil,
            carbs: n.hasCarbs ? n.carbs : nil,
            fat: n.hasFat ? n.fat : nil,
            shelfLife: n.hasShelfLife ? n.shelfLife : nil,
            freshness: n.hasFreshness ? n.freshness : nil
        )
    }

    private static func mapPhysical(_ p: VisionPhysicalFeatures) -> WasmClient.PhysicalFeatures {
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
        return WasmClient.PhysicalFeatures(fields: fields)
    }

    private static func mapPrice(_ p: VisionPriceInfo) -> WasmClient.PriceInfo {
        WasmClient.PriceInfo(
            averageFairMarketPrice: p.hasAverageFairMarketPrice ? p.averageFairMarketPrice : nil,
            webPurchaseURL: p.hasWebPurchaseURL ? p.webPurchaseURL : nil
        )
    }

    private static func mapAICommentary(_ a: VisionAICommentary) -> WasmClient.AICommentary {
        WasmClient.AICommentary(
            aiAssistantSays: a.hasAiAssistantSays ? a.aiAssistantSays : nil,
            aiSuggests: a.hasAiSuggests ? a.aiSuggests : nil,
            expertInsights: a.hasExpertInsights ? a.expertInsights : nil,
            recommendation: a.hasRecommendation ? a.recommendation : nil,
            interestingFacts: a.hasInterestingFacts ? a.interestingFacts : nil,
            realOrFake: a.hasRealOrFake ? a.realOrFake : nil,
            marketDemand: a.hasMarketDemand ? a.marketDemand : nil
        )
    }

    private static func mapShoppingProduct(_ p: VisionShoppingProduct) -> WasmClient.ShoppingProduct {
        WasmClient.ShoppingProduct(
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

    private static func mapLink(_ l: VisionLink) -> WasmClient.Link {
        WasmClient.Link(
            title: l.hasTitle ? l.title : "",
            url: l.hasURL ? l.url : "",
            description: l.hasDescription_p ? l.description_p : nil,
            image: l.hasImage ? l.image : nil
        )
    }
}
