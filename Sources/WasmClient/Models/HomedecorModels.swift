import Foundation

// MARK: - Home Decor

extension WasmClient {
    /// Namespace for all home-decor types: process types, room styles, palettes,
    /// request, and result. Access via `WasmClient.HomeDecor.Result`, etc.
    public enum HomeDecor {
        /// Operation performed by a home-decor action. Each case maps 1:1 to a
        /// FlowKit `HomedecorProcessType` and resolves to a concrete `ActionID`.
        public enum ProcessType: Sendable, Equatable, Hashable, CaseIterable {
            case unspecified
            /// Full radical interior redesign (replace all furniture + decor).
            case interior
            /// Facade material swap only (keep building geometry).
            case exterior
            /// Landscape/vegetation redesign (keep hardscape).
            case garden
            /// Paint room walls/surfaces with color (needs mask + color).
            case paint
            /// Replace masked objects with prompt-described items (needs mask).
            case replace
            /// Floor material replacement only.
            case floor
            /// Redesign using a second reference image as style guide (needs ref_image).
            case reference
            /// Add furniture + decor to empty/sparse room (keep architecture).
            case staging
            /// Remove clutter, clean surfaces (fixed prompt, no style).
            case declutter
            /// Generate 2D floor plan from photo (fixed prompt, no style).
            case floorPlan
            /// Render floor plan as photorealistic interior in chosen style.
            case planToImage

            /// Wire-format string accepted by the action's `process_type` arg.
            public var wireName: String {
                switch self {
                case .unspecified: return ""
                case .interior: return "interior"
                case .exterior: return "exterior"
                case .garden: return "garden"
                case .paint: return "paint"
                case .replace: return "replace"
                case .floor: return "floor"
                case .reference: return "reference"
                case .staging: return "staging"
                case .declutter: return "declutter"
                case .floorPlan: return "floor_plan"
                case .planToImage: return "plan_to_image"
                }
            }

            /// The `ActionID` that handles this process type. `nil` for `.unspecified`.
            public var actionID: WasmClient.ActionID? {
                switch self {
                case .unspecified: return nil
                case .interior: return .interiorDesign
                case .exterior: return .exteriorDesign
                case .garden: return .gardenDesign
                case .paint: return .paintRoom
                case .replace: return .replaceObjects
                case .floor: return .floorRestyle
                case .reference: return .referenceStyle
                case .staging: return .roomStaging
                case .declutter: return .declutterRoom
                case .floorPlan: return .floorPlan
                case .planToImage: return .planToImage
                }
            }

            public init?(wireName: String) {
                guard let match = Self.allCases.first(where: { $0.wireName == wireName && !$0.wireName.isEmpty }) else {
                    return nil
                }
                self = match
            }
        }

        /// Whether to preserve room structure or allow renovation.
        public enum StyleSelection: Sendable, Equatable, Hashable, CaseIterable {
            case unspecified
            /// Keep room structure, change style only.
            case structuralPreservation
            /// Full renovation including structural changes.
            case renovationDesign

            public var wireName: String {
                switch self {
                case .unspecified: return ""
                case .structuralPreservation: return "structural_preservation"
                case .renovationDesign: return "renovation_design"
                }
            }

            public init?(wireName: String) {
                guard let match = Self.allCases.first(where: { $0.wireName == wireName && !$0.wireName.isEmpty }) else {
                    return nil
                }
                self = match
            }
        }

        /// Room or building category the design targets.
        public enum RoomType: Sendable, Equatable, Hashable, CaseIterable {
            case unspecified
            // Interior
            case livingRoom
            case bedroom
            case kitchen
            case diningRoom
            case bathroom
            case office
            case homeOffice
            case studyRoom
            case attic
            case coffeeShop
            case gamingRoom
            case restaurant
            case toilet
            case balcony
            case hall
            case gardenRoom
            case deck
            case entryway
            case laundryRoom
            // Exterior / building
            case apartment
            case residential
            case house
            case retail
            case villa
            case underStairSpace
            case officeBuilding
            case tower
            case ranch
            case swimmingPool
            case yard
            case otherRoom

            public var wireName: String {
                switch self {
                case .unspecified: return ""
                case .livingRoom: return "living_room"
                case .bedroom: return "bedroom"
                case .kitchen: return "kitchen"
                case .diningRoom: return "dining_room"
                case .bathroom: return "bathroom"
                case .office: return "office"
                case .homeOffice: return "home_office"
                case .studyRoom: return "study_room"
                case .attic: return "attic"
                case .coffeeShop: return "coffee_shop"
                case .gamingRoom: return "gaming_room"
                case .restaurant: return "restaurant"
                case .toilet: return "toilet"
                case .balcony: return "balcony"
                case .hall: return "hall"
                case .gardenRoom: return "garden_room"
                case .deck: return "deck"
                case .entryway: return "entryway"
                case .laundryRoom: return "laundry_room"
                case .apartment: return "apartment"
                case .residential: return "residential"
                case .house: return "house"
                case .retail: return "retail"
                case .villa: return "villa"
                case .underStairSpace: return "under_stair_space"
                case .officeBuilding: return "office_building"
                case .tower: return "tower"
                case .ranch: return "ranch"
                case .swimmingPool: return "swimming_pool"
                case .yard: return "yard"
                case .otherRoom: return "other_room"
                }
            }

            public init?(wireName: String) {
                guard let match = Self.allCases.first(where: { $0.wireName == wireName && !$0.wireName.isEmpty }) else {
                    return nil
                }
                self = match
            }
        }

        /// Design aesthetic / room style.
        public enum RoomStyle: Sendable, Equatable, Hashable, CaseIterable {
            case unspecified
            case modern
            case tropical
            case minimalist
            case bohemian
            case rustic
            case vintage
            case baroque
            case mediterranean
            case cyberpunk
            case biophilic
            case ancientEgyptian
            case airbnb
            case discotheque
            case soho
            case rainbow
            case luxury
            case techno
            case gamer
            case cozy
            case coastal
            case japandi
            case cottagecore
            case skiChalet
            case gothic
            case creepy
            case medieval
            case eighties
            case cartoon
            case wood
            case chocolate
            case italianate
            case brutalist
            case artDeco
            case chinese
            case japanese
            case cottage
            case spanish
            case morocco
            case midcentury
            case middleEastern
            case farmhouse
            case french
            case christmas
            case industrial
            case scandinavian
            case noStyle
            case zen
            case halloween
            case concrete
            case retro
            case beachHouse
            case isle
            case stValentinesDay

            public var wireName: String {
                switch self {
                case .unspecified: return ""
                case .modern: return "modern"
                case .tropical: return "tropical"
                case .minimalist: return "minimalist"
                case .bohemian: return "bohemian"
                case .rustic: return "rustic"
                case .vintage: return "vintage"
                case .baroque: return "baroque"
                case .mediterranean: return "mediterranean"
                case .cyberpunk: return "cyberpunk"
                case .biophilic: return "biophilic"
                case .ancientEgyptian: return "ancient_egyptian"
                case .airbnb: return "airbnb"
                case .discotheque: return "discotheque"
                case .soho: return "soho"
                case .rainbow: return "rainbow"
                case .luxury: return "luxury"
                case .techno: return "techno"
                case .gamer: return "gamer"
                case .cozy: return "cozy"
                case .coastal: return "coastal"
                case .japandi: return "japandi"
                case .cottagecore: return "cottagecore"
                case .skiChalet: return "ski_chalet"
                case .gothic: return "gothic"
                case .creepy: return "creepy"
                case .medieval: return "medieval"
                case .eighties: return "eighties"
                case .cartoon: return "cartoon"
                case .wood: return "wood"
                case .chocolate: return "chocolate"
                case .italianate: return "italianate"
                case .brutalist: return "brutalist"
                case .artDeco: return "art_deco"
                case .chinese: return "chinese"
                case .japanese: return "japanese"
                case .cottage: return "cottage"
                case .spanish: return "spanish"
                case .morocco: return "morocco"
                case .midcentury: return "midcentury"
                case .middleEastern: return "middle_eastern"
                case .farmhouse: return "farmhouse"
                case .french: return "french"
                case .christmas: return "christmas"
                case .industrial: return "industrial"
                case .scandinavian: return "scandinavian"
                case .noStyle: return "no_style"
                case .zen: return "zen"
                case .halloween: return "halloween"
                case .concrete: return "concrete"
                case .retro: return "retro"
                case .beachHouse: return "beach_house"
                case .isle: return "isle"
                case .stValentinesDay: return "st_valentines_day"
                }
            }

            public init?(wireName: String) {
                guard let match = Self.allCases.first(where: { $0.wireName == wireName && !$0.wireName.isEmpty }) else {
                    return nil
                }
                self = match
            }
        }

        /// Color palette guide for paint actions.
        public enum ColorPalette: Sendable, Equatable, Hashable, CaseIterable {
            case unspecified
            case millennialGray
            case terracottaMirage
            case neonSunset
            case forestHues
            case peachOrchard
            case fuschiaBlossom
            case emeraldGem
            case pastelBreeze
            case azureMirage
            case twilightBlues
            case earthyHarmony
            case arcticLavender
            case antiqueSage
            case earthyHues
            case velvetDusk
            case oceanMist
            case amethystDream
            case sakuraBloom
            case lilacLove
            case whimsicalWish
            case turquoiseLagoon

            public var wireName: String {
                switch self {
                case .unspecified: return ""
                case .millennialGray: return "millennial_gray"
                case .terracottaMirage: return "terracotta_mirage"
                case .neonSunset: return "neon_sunset"
                case .forestHues: return "forest_hues"
                case .peachOrchard: return "peach_orchard"
                case .fuschiaBlossom: return "fuschia_blossom"
                case .emeraldGem: return "emerald_gem"
                case .pastelBreeze: return "pastel_breeze"
                case .azureMirage: return "azure_mirage"
                case .twilightBlues: return "twilight_blues"
                case .earthyHarmony: return "earthy_harmony"
                case .arcticLavender: return "arctic_lavender"
                case .antiqueSage: return "antique_sage"
                case .earthyHues: return "earthy_hues"
                case .velvetDusk: return "velvet_dusk"
                case .oceanMist: return "ocean_mist"
                case .amethystDream: return "amethyst_dream"
                case .sakuraBloom: return "sakura_bloom"
                case .lilacLove: return "lilac_love"
                case .whimsicalWish: return "whimsical_wish"
                case .turquoiseLagoon: return "turquoise_lagoon"
                }
            }

            public init?(wireName: String) {
                guard let match = Self.allCases.first(where: { $0.wireName == wireName && !$0.wireName.isEmpty }) else {
                    return nil
                }
                self = match
            }
        }

        /// Surface category for paint actions.
        public enum SurfaceType: Sendable, Equatable, Hashable, CaseIterable {
            case unspecified
            case wall
            case ceiling
            case floorSurface
            case door
            case cabinet

            public var wireName: String {
                switch self {
                case .unspecified: return ""
                case .wall: return "wall"
                case .ceiling: return "ceiling"
                case .floorSurface: return "floor_surface"
                case .door: return "door"
                case .cabinet: return "cabinet"
                }
            }

            public init?(wireName: String) {
                guard let match = Self.allCases.first(where: { $0.wireName == wireName && !$0.wireName.isEmpty }) else {
                    return nil
                }
                self = match
            }
        }

        /// Typed request payload for a home-decor generation. Use this with
        /// `homeDesignRequest` for compile-time-checked inputs; the legacy
        /// `homeDesign(actionID:args:)` closure remains for free-form callers.
        public struct Request: Sendable, Equatable {
            public var file: String
            public var processType: ProcessType
            public var roomStyle: RoomStyle?
            public var roomType: RoomType?
            public var styleSelection: StyleSelection?
            public var colorPalette: ColorPalette?
            public var surfaceType: SurfaceType?
            public var mask: String?
            public var refImage: String?
            public var prompt: String?
            public var extraArgs: [String: String]

            public init(
                file: String,
                processType: ProcessType,
                roomStyle: RoomStyle? = nil,
                roomType: RoomType? = nil,
                styleSelection: StyleSelection? = nil,
                colorPalette: ColorPalette? = nil,
                surfaceType: SurfaceType? = nil,
                mask: String? = nil,
                refImage: String? = nil,
                prompt: String? = nil,
                extraArgs: [String: String] = [:]
            ) {
                self.file = file
                self.processType = processType
                self.roomStyle = roomStyle
                self.roomType = roomType
                self.styleSelection = styleSelection
                self.colorPalette = colorPalette
                self.surfaceType = surfaceType
                self.mask = mask
                self.refImage = refImage
                self.prompt = prompt
                self.extraArgs = extraArgs
            }

            /// Wire-format args dict for the engine. Drops nil / empty /
            /// `.unspecified` entries. `extraArgs` is merged last and wins on
            /// key collision so callers can override or forward unknown fields.
            public func toWireArgs() -> [String: String] {
                var args: [String: String] = [:]
                if !file.isEmpty { args["file"] = file }
                if !processType.wireName.isEmpty { args["process_type"] = processType.wireName }
                if let v = roomStyle?.wireName, !v.isEmpty { args["room_style"] = v }
                if let v = roomType?.wireName, !v.isEmpty { args["room_type"] = v }
                if let v = styleSelection?.wireName, !v.isEmpty { args["style_selection"] = v }
                if let v = colorPalette?.wireName, !v.isEmpty { args["color"] = v }
                if let v = surfaceType?.wireName, !v.isEmpty { args["surface_type"] = v }
                if let v = mask, !v.isEmpty { args["mask"] = v }
                if let v = refImage, !v.isEmpty { args["ref_image"] = v }
                if let v = prompt, !v.isEmpty { args["prompt"] = v }
                for (k, v) in extraArgs where !v.isEmpty { args[k] = v }
                return args
            }
        }

        /// Result of a home decor design generation.
        public struct Result: Sendable, Equatable {
            public let status: TaskStatus
            public let imageURL: String
            public let inputImageURL: String
            public let taskID: String
            public let metadata: [String: String]
            /// Process type echoed back by the engine on success.
            public let processType: ProcessType?
            /// Applied room style echoed back by the engine on success.
            public let roomStyle: RoomStyle?
            /// Detected or applied room type echoed back by the engine on success.
            public let roomType: RoomType?
            /// 0.0–1.0 progress, parsed from `metadata["progress"]` when present.
            public let progress: Double
            /// Provider id that ran the task (e.g. `"reroom"`, `"homeai"`, `"decai"`).
            public let provider: String

            public init(
                status: TaskStatus = .completed,
                imageURL: String = "",
                inputImageURL: String = "",
                taskID: String = "",
                metadata: [String: String] = [:],
                processType: ProcessType? = nil,
                roomStyle: RoomStyle? = nil,
                roomType: RoomType? = nil,
                progress: Double = 0,
                provider: String = ""
            ) {
                self.status = status
                self.imageURL = imageURL
                self.inputImageURL = inputImageURL
                self.taskID = taskID
                self.metadata = metadata
                self.processType = processType
                self.roomStyle = roomStyle
                self.roomType = roomType
                self.progress = progress
                self.provider = provider
            }
        }
    }
}
