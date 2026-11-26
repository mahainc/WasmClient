import Foundation

// MARK: - Home Decor

extension WasmClient {
    public enum HomeDecor {
        public struct ProcessType: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: String

            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(wireName: String) {
                self.init(rawValue: wireName)
            }

            public var wireName: String { rawValue }

            public static let unspecified = Self(rawValue: "")
            public static let interior = Self(rawValue: "interior")
            public static let exterior = Self(rawValue: "exterior")
            public static let garden = Self(rawValue: "garden")
            public static let paint = Self(rawValue: "paint")
            public static let replace = Self(rawValue: "replace")
            public static let floor = Self(rawValue: "floor")
            public static let reference = Self(rawValue: "reference")
            public static let staging = Self(rawValue: "staging")
            public static let declutter = Self(rawValue: "declutter")
            public static let floorPlan = Self(rawValue: "floor_plan")
            public static let planToImage = Self(rawValue: "plan_to_image")

            public var actionID: WasmClient.ActionID? {
                switch rawValue {
                    case Self.interior.rawValue: .interiorDesign
                    case Self.exterior.rawValue: .exteriorDesign
                    case Self.garden.rawValue: .gardenDesign
                    case Self.paint.rawValue: .paintRoom
                    case Self.replace.rawValue: .replaceObjects
                    case Self.floor.rawValue: .floorRestyle
                    case Self.reference.rawValue: .referenceStyle
                    case Self.staging.rawValue: .roomStaging
                    case Self.declutter.rawValue: .declutterRoom
                    case Self.floorPlan.rawValue: .floorPlan
                    case Self.planToImage.rawValue: .planToImage
                    default: nil
                }
            }
        }

        public struct StyleSelection: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: String

            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(wireName: String) {
                self.init(rawValue: wireName)
            }

            public var wireName: String { rawValue }

            public static let unspecified = Self(rawValue: "")
            public static let structuralPreservation = Self(rawValue: "structural_preservation")
            public static let renovationDesign = Self(rawValue: "renovation_design")
        }

        public struct RoomType: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: String

            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(wireName: String) {
                self.init(rawValue: wireName)
            }

            public var wireName: String { rawValue }

            public static let unspecified = Self(rawValue: "")
            public static let livingRoom = Self(rawValue: "living_room")
            public static let bedroom = Self(rawValue: "bedroom")
            public static let kitchen = Self(rawValue: "kitchen")
            public static let diningRoom = Self(rawValue: "dining_room")
            public static let bathroom = Self(rawValue: "bathroom")
            public static let office = Self(rawValue: "office")
            public static let homeOffice = Self(rawValue: "home_office")
            public static let studyRoom = Self(rawValue: "study_room")
            public static let attic = Self(rawValue: "attic")
            public static let coffeeShop = Self(rawValue: "coffee_shop")
            public static let gamingRoom = Self(rawValue: "gaming_room")
            public static let restaurant = Self(rawValue: "restaurant")
            public static let toilet = Self(rawValue: "toilet")
            public static let balcony = Self(rawValue: "balcony")
            public static let hall = Self(rawValue: "hall")
            public static let gardenRoom = Self(rawValue: "garden_room")
            public static let deck = Self(rawValue: "deck")
            public static let entryway = Self(rawValue: "entryway")
            public static let laundryRoom = Self(rawValue: "laundry_room")
            public static let apartment = Self(rawValue: "apartment")
            public static let residential = Self(rawValue: "residential")
            public static let house = Self(rawValue: "house")
            public static let retail = Self(rawValue: "retail")
            public static let villa = Self(rawValue: "villa")
            public static let underStairSpace = Self(rawValue: "under_stair_space")
            public static let officeBuilding = Self(rawValue: "office_building")
            public static let tower = Self(rawValue: "tower")
            public static let ranch = Self(rawValue: "ranch")
            public static let swimmingPool = Self(rawValue: "swimming_pool")
            public static let yard = Self(rawValue: "yard")
            public static let otherRoom = Self(rawValue: "other_room")
        }

        public struct RoomStyle: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: String

            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(wireName: String) {
                self.init(rawValue: wireName)
            }

            public var wireName: String { rawValue }

            public static let unspecified = Self(rawValue: "")
            public static let modern = Self(rawValue: "modern")
            public static let tropical = Self(rawValue: "tropical")
            public static let minimalist = Self(rawValue: "minimalist")
            public static let bohemian = Self(rawValue: "bohemian")
            public static let rustic = Self(rawValue: "rustic")
            public static let vintage = Self(rawValue: "vintage")
            public static let baroque = Self(rawValue: "baroque")
            public static let mediterranean = Self(rawValue: "mediterranean")
            public static let cyberpunk = Self(rawValue: "cyberpunk")
            public static let biophilic = Self(rawValue: "biophilic")
            public static let ancientEgyptian = Self(rawValue: "ancient_egyptian")
            public static let airbnb = Self(rawValue: "airbnb")
            public static let discotheque = Self(rawValue: "discotheque")
            public static let soho = Self(rawValue: "soho")
            public static let rainbow = Self(rawValue: "rainbow")
            public static let luxury = Self(rawValue: "luxury")
            public static let techno = Self(rawValue: "techno")
            public static let gamer = Self(rawValue: "gamer")
            public static let cozy = Self(rawValue: "cozy")
            public static let coastal = Self(rawValue: "coastal")
            public static let japandi = Self(rawValue: "japandi")
            public static let cottagecore = Self(rawValue: "cottagecore")
            public static let skiChalet = Self(rawValue: "ski_chalet")
            public static let gothic = Self(rawValue: "gothic")
            public static let creepy = Self(rawValue: "creepy")
            public static let medieval = Self(rawValue: "medieval")
            public static let eighties = Self(rawValue: "eighties")
            public static let cartoon = Self(rawValue: "cartoon")
            public static let wood = Self(rawValue: "wood")
            public static let chocolate = Self(rawValue: "chocolate")
            public static let italianate = Self(rawValue: "italianate")
            public static let brutalist = Self(rawValue: "brutalist")
            public static let artDeco = Self(rawValue: "art_deco")
            public static let chinese = Self(rawValue: "chinese")
            public static let japanese = Self(rawValue: "japanese")
            public static let cottage = Self(rawValue: "cottage")
            public static let spanish = Self(rawValue: "spanish")
            public static let morocco = Self(rawValue: "morocco")
            public static let midcentury = Self(rawValue: "midcentury")
            public static let middleEastern = Self(rawValue: "middle_eastern")
            public static let farmhouse = Self(rawValue: "farmhouse")
            public static let french = Self(rawValue: "french")
            public static let christmas = Self(rawValue: "christmas")
            public static let industrial = Self(rawValue: "industrial")
            public static let scandinavian = Self(rawValue: "scandinavian")
            public static let noStyle = Self(rawValue: "no_style")
            public static let zen = Self(rawValue: "zen")
            public static let halloween = Self(rawValue: "halloween")
            public static let concrete = Self(rawValue: "concrete")
            public static let retro = Self(rawValue: "retro")
            public static let beachHouse = Self(rawValue: "beach_house")
            public static let isle = Self(rawValue: "isle")
            public static let stValentinesDay = Self(rawValue: "st_valentines_day")
        }

        public struct ColorPalette: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: String

            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(wireName: String) {
                self.init(rawValue: wireName)
            }

            public var wireName: String { rawValue }

            public static let unspecified = Self(rawValue: "")
            public static let millennialGray = Self(rawValue: "millennial_gray")
            public static let terracottaMirage = Self(rawValue: "terracotta_mirage")
            public static let neonSunset = Self(rawValue: "neon_sunset")
            public static let forestHues = Self(rawValue: "forest_hues")
            public static let peachOrchard = Self(rawValue: "peach_orchard")
            public static let fuschiaBlossom = Self(rawValue: "fuschia_blossom")
            public static let emeraldGem = Self(rawValue: "emerald_gem")
            public static let pastelBreeze = Self(rawValue: "pastel_breeze")
            public static let azureMirage = Self(rawValue: "azure_mirage")
            public static let twilightBlues = Self(rawValue: "twilight_blues")
            public static let earthyHarmony = Self(rawValue: "earthy_harmony")
            public static let arcticLavender = Self(rawValue: "arctic_lavender")
            public static let antiqueSage = Self(rawValue: "antique_sage")
            public static let earthyHues = Self(rawValue: "earthy_hues")
            public static let velvetDusk = Self(rawValue: "velvet_dusk")
            public static let oceanMist = Self(rawValue: "ocean_mist")
            public static let amethystDream = Self(rawValue: "amethyst_dream")
            public static let sakuraBloom = Self(rawValue: "sakura_bloom")
            public static let lilacLove = Self(rawValue: "lilac_love")
            public static let whimsicalWish = Self(rawValue: "whimsical_wish")
            public static let turquoiseLagoon = Self(rawValue: "turquoise_lagoon")
        }

        public struct SurfaceType: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: String

            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(wireName: String) {
                self.init(rawValue: wireName)
            }

            public var wireName: String { rawValue }

            public static let unspecified = Self(rawValue: "")
            public static let wall = Self(rawValue: "wall")
            public static let ceiling = Self(rawValue: "ceiling")
            public static let floorSurface = Self(rawValue: "floor_surface")
            public static let door = Self(rawValue: "door")
            public static let cabinet = Self(rawValue: "cabinet")
        }

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

            public func toWireArgs() -> [String: String] {
                var args: [String: String] = [:]
                if !file.isEmpty { args["file"] = file }
                if !processType.wireName.isEmpty { args["process_type"] = processType.wireName }
                if let value = roomStyle?.wireName, !value.isEmpty { args["room_style"] = value }
                if let value = roomType?.wireName, !value.isEmpty { args["room_type"] = value }
                if let value = styleSelection?.wireName, !value.isEmpty { args["style_selection"] = value }
                if let value = colorPalette?.wireName, !value.isEmpty { args["color"] = value }
                if let value = surfaceType?.wireName, !value.isEmpty { args["surface_type"] = value }
                if let value = mask, !value.isEmpty { args["mask"] = value }
                if let value = refImage, !value.isEmpty { args["ref_image"] = value }
                if let value = prompt, !value.isEmpty { args["prompt"] = value }
                for (key, value) in extraArgs where !value.isEmpty { args[key] = value }
                return args
            }
        }

        public struct Result: Sendable, Equatable {
            public let status: TaskStatus
            public let imageURL: String
            public let inputImageURL: String
            public let taskID: String
            public let metadata: [String: String]
            public let processType: ProcessType?
            public let roomStyle: RoomStyle?
            public let roomType: RoomType?
            public let progress: Double
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
