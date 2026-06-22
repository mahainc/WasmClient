import Foundation

// MARK: - LiveScore Namespace

extension WasmClient {
    /// Namespace for Livescore-domain types (lsWebpage / lsUpcoming / lsScores).
    public enum LiveScore {}
}

// MARK: - Match Status

extension WasmClient.LiveScore {
    /// Typed match state mirroring FlowKit's `LivescoreMatchStatus` proto.
    /// Raw values match the proto numbers so unknown values from a newer
    /// backend fall back to `.unspecified` via `init(rawValue:)`.
    public enum MatchStatus: Int, Sendable, Equatable {
        case unspecified = 0
        case notStarted = 1
        case tbd = 2
        case firstHalf = 10
        case halftime = 11
        case secondHalf = 12
        case extraTime = 13
        case extraTimeBreak = 14
        case penalties = 15
        case fullTime = 20
        case afterExtraTime = 21
        case afterPenalties = 22
        case suspended = 30
        case interrupted = 31
        case postponed = 32
        case cancelled = 33
        case abandoned = 34
        case walkover = 35
        case awarded = 36
        case delayed = 37
    }
}

// MARK: - Livescore Entity

extension WasmClient.LiveScore {
    /// Typed entity namespace for the livescore favourite/subscribe flow.
    /// The raw value is what ships on the wire as the OTel event's
    /// `entity` field — it must stay stable across releases since stored
    /// favourites and backend records key off it.
    ///
    /// Leagues and Competitions share Scorebat's `competition/` id space
    /// (the Leagues tab is just a curated subset), so both surface as
    /// `.competition` here. Adding more entities (e.g. `player`, `coach`)
    /// is additive — never rename or remove an existing case.
    ///
    /// `.match` is the per-fixture "Follow match" entity. Unlike
    /// `.team`/`.competition` (persistent personalization → home feed +
    /// goal-push topics), a `.match` subscription is the explicit opt-in
    /// that drives the iOS Live Activity: the backend's scorebat-worker
    /// fans Live Activity APNs pushes *strictly* to devices that sent
    /// `entity="match", id=<match_id>`. Backend soft-deletes the row at
    /// full time, so the client never has to unfollow on match end.
    public enum Entity: String, CaseIterable, Sendable {
        case team
        case competition
        case match
    }
}

// MARK: - Livescore MatchSummary

extension WasmClient.LiveScore {
    /// A single upcoming match returned by `lsUpcoming` / `lsScores`. Mirrors
    /// the `LivescoreMatchSummary` proto, with the UNIX `datetime` field
    /// decoded to a `Date` so consumers don't deal with the raw integer.
    public struct MatchSummary: Sendable, Equatable, Identifiable {
        /// String form of the Scorebat match id, suitable for `Identifiable`.
        public let id: String
        public let homeTeam: String
        public let awayTeam: String
        public let homeLogoURL: String
        public let awayLogoURL: String
        /// Decoded from the proto's `datetime` (UNIX seconds).
        public let kickoff: Date
        /// String form of the Scorebat competition id.
        public let competitionID: String
        /// 0 before kickoff; only meaningful when `status` is post-kickoff.
        public let homeScore: Int
        public let awayScore: Int
        /// Typed match state. `.notStarted` until kickoff.
        public let status: MatchStatus
        /// Scorebat embed URL: `scorebat.com/embed/matchview/{id}`.
        public let embedURL: String
        /// Competition flag URL (CloudFront flag). Empty for raw Scorebat
        /// upcoming feed; populated by `/serverless/mobile/scores`.
        public let competitionImage: String
        /// Full competition name (e.g. "RUSSIA: Premier League"). Empty for
        /// raw Scorebat upcoming feed.
        public let competitionName: String
        /// Competition region (e.g. "Russia"). Empty for raw Scorebat
        /// upcoming feed.
        public let competitionRegion: String

        public init(
            id: String, homeTeam: String, awayTeam: String,
            homeLogoURL: String, awayLogoURL: String,
            kickoff: Date, competitionID: String,
            homeScore: Int, awayScore: Int,
            status: MatchStatus = .unspecified, embedURL: String,
            competitionImage: String = "",
            competitionName: String = "",
            competitionRegion: String = ""
        ) {
            self.id = id
            self.homeTeam = homeTeam
            self.awayTeam = awayTeam
            self.homeLogoURL = homeLogoURL
            self.awayLogoURL = awayLogoURL
            self.kickoff = kickoff
            self.competitionID = competitionID
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.status = status
            self.embedURL = embedURL
            self.competitionImage = competitionImage
            self.competitionName = competitionName
            self.competitionRegion = competitionRegion
        }
    }
}

// MARK: - Livescore Entry

extension WasmClient.LiveScore {
    /// A content entry returned by `lsWebpage`. Mirrors the `LivescoreWebPage`
    /// proto from FlowKit. The same type backs every `WebPageType` variant
    /// (leagues, competitions, teams, page, discovers, videos, news).
    public struct Entry: Sendable, Equatable, Identifiable {
        /// Slug identifier (e.g. "team/real-madrid", "competition/england-premier-league").
        public let id: String
        /// Thumbnail / logo URL for list display.
        public let image: String
        /// Primary label (league name, team name, match title, news headline).
        public let title: String
        /// Secondary label (country, date, competition, source·author).
        public let subtitle: String
        /// Embed URL loaded directly in WKWebView (no-proxy).
        public let url: String
        /// UNIX seconds; populated for Highlights/news items, 0 otherwise.
        public let datetime: Int64
        /// Highlight clips for this entry. Populated only for `webpageVideos`
        /// (Highlights) rows; empty for all other WebPage variants.
        public let videos: [Video]

        public init(
            id: String = "", image: String = "", title: String = "",
            subtitle: String = "", url: String = "", datetime: Int64 = 0,
            videos: [Video] = []
        ) {
            self.id = id; self.image = image; self.title = title
            self.subtitle = subtitle; self.url = url; self.datetime = datetime
            self.videos = videos
        }
    }
}

// MARK: - Match Detail Event Types

extension WasmClient.LiveScore {
    /// In-match incident kind. Raw values mirror the `LivescoreEventType`
    /// proto so unknown values from a newer backend decay to `.unspecified`.
    public enum EventType: Int, Sendable, Equatable {
        case unspecified = 0
        case goal = 1
        case ownGoal = 2
        case penaltyGoal = 3
        case missedPenalty = 4
        case yellowCard = 5
        case redCard = 6
        case secondYellow = 7
        case substitution = 8
        /// Backticked because `var` is a Swift keyword. Mirrors proto field name.
        case `var` = 9
    }

    /// Player role used in lineups.
    public enum PlayerPosition: Int, Sendable, Equatable {
        case unspecified = 0
        case goalkeeper = 1
        case defender = 2
        case midfielder = 3
        case forward = 4
    }

    /// Typed match statistic (`xg`, `possession`, `shot`, …). The `typeName`
    /// on the parent `FixtureStatistic` carries the backend's raw label for
    /// stats not yet mapped to a case here.
    public enum StatType: Int, Sendable, Equatable {
        case unspecified = 0
        case xg = 1
        case possession = 2
        case bigChance = 3
        case shot = 4
        case shotOnGoal = 5
        case blockedShot = 6
        case shotInsideBox = 7
        case shotOutsideBox = 8
        case woodwork = 9
        case foul = 10
        case corner = 11
        case throwIn = 12
        case save = 13
        case freeKick = 14
        case offside = 15
        case passesFinalThird = 16
        case passesFinalThirdCompleted = 17
        case touchesInOppositionBox = 18
        case tackle = 19
        case tackleCompleted = 20
        case cross = 21
        case crossCompleted = 22
        case interception = 23
        case clearance = 24
    }
}

// MARK: - Match Detail

extension WasmClient.LiveScore {
    /// Enriched match payload returned by `lsMatchDetail`. The `summary`
    /// mirrors `lsUpcoming` / `lsScores` rows; the rest is fixture-specific.
    /// Most nested fields can be empty when the backend has nothing — the
    /// View must tolerate empty arrays / empty strings.
    public struct Match: Sendable, Equatable, Identifiable {
        public let summary: MatchSummary
        public let events: [MatchEvent]
        public let lineups: Lineups
        public let statistics: [FixtureStatistic]
        public let refereeName: String
        public let venue: Venue
        public let predictions: [Prediction]
        public let h2h: H2H
        public let videos: [Video]

        public var id: String { summary.id }

        public init(
            summary: MatchSummary,
            events: [MatchEvent] = [],
            lineups: Lineups = Lineups(),
            statistics: [FixtureStatistic] = [],
            refereeName: String = "",
            venue: Venue = Venue(),
            predictions: [Prediction] = [],
            h2h: H2H = H2H(),
            videos: [Video] = []
        ) {
            self.summary = summary
            self.events = events
            self.lineups = lineups
            self.statistics = statistics
            self.refereeName = refereeName
            self.venue = venue
            self.predictions = predictions
            self.h2h = h2h
            self.videos = videos
        }
    }

    public struct MatchEvent: Sendable, Equatable, Identifiable {
        public let playerID: String
        public let playerName: String
        /// "home" / "away" as the backend conventionally reports it.
        public let participantID: String
        public let minute: Int
        public let eventType: EventType
        /// Raw backend label for events not represented in `EventType` yet.
        public let typeRaw: String
        /// Sub-in target (for substitutions) or assist (for goals). Empty otherwise.
        public let relatedPlayerID: String
        public let relatedPlayerName: String

        public var id: String { "\(participantID)-\(minute)-\(playerID)-\(eventType.rawValue)" }

        public init(
            playerID: String = "", playerName: String = "",
            participantID: String = "", minute: Int = 0,
            eventType: EventType = .unspecified, typeRaw: String = "",
            relatedPlayerID: String = "", relatedPlayerName: String = ""
        ) {
            self.playerID = playerID; self.playerName = playerName
            self.participantID = participantID; self.minute = minute
            self.eventType = eventType; self.typeRaw = typeRaw
            self.relatedPlayerID = relatedPlayerID
            self.relatedPlayerName = relatedPlayerName
        }
    }

    public struct Lineups: Sendable, Equatable {
        public let home: TeamLineup
        public let away: TeamLineup

        public var isEmpty: Bool {
            home.startXi.isEmpty && away.startXi.isEmpty
        }

        public init(home: TeamLineup = TeamLineup(), away: TeamLineup = TeamLineup()) {
            self.home = home; self.away = away
        }
    }

    public struct TeamLineup: Sendable, Equatable, Identifiable {
        public let teamID: String
        public let teamName: String
        public let teamLogoURL: String
        public let formation: String
        public let startXi: [Lineup]
        public let substitutes: [Lineup]
        public let coachName: String

        public var id: String { teamID }

        public init(
            teamID: String = "", teamName: String = "", teamLogoURL: String = "",
            formation: String = "", startXi: [Lineup] = [], substitutes: [Lineup] = [],
            coachName: String = ""
        ) {
            self.teamID = teamID; self.teamName = teamName
            self.teamLogoURL = teamLogoURL; self.formation = formation
            self.startXi = startXi; self.substitutes = substitutes
            self.coachName = coachName
        }
    }

    public struct Lineup: Sendable, Equatable, Identifiable {
        public let playerID: String
        public let playerName: String
        public let jerseyNumber: Int
        public let position: PlayerPosition
        public let isSubstitute: Bool

        public var id: String { playerID.isEmpty ? "\(playerName)-\(jerseyNumber)" : playerID }

        public init(
            playerID: String = "", playerName: String = "",
            jerseyNumber: Int = 0, position: PlayerPosition = .unspecified,
            isSubstitute: Bool = false
        ) {
            self.playerID = playerID; self.playerName = playerName
            self.jerseyNumber = jerseyNumber; self.position = position
            self.isSubstitute = isSubstitute
        }
    }

    /// Typed match statistic. Exactly one of `valueInt` / `valueString`
    /// is populated for any given backend row; the view chooses which to
    /// render based on which is non-nil.
    public struct FixtureStatistic: Sendable, Equatable, Identifiable {
        /// Raw backend label (e.g. "Expected Goals", "Possession %").
        public let typeName: String
        /// "home" or "away" — the side this row represents.
        public let location: String
        public let statType: StatType
        public let valueInt: Int?
        public let valueString: String?

        public var id: String { "\(statType.rawValue)-\(location)-\(typeName)" }

        public init(
            typeName: String = "", location: String = "",
            statType: StatType = .unspecified,
            valueInt: Int? = nil, valueString: String? = nil
        ) {
            self.typeName = typeName; self.location = location
            self.statType = statType
            self.valueInt = valueInt; self.valueString = valueString
        }
    }

    public struct Venue: Sendable, Equatable {
        public let id: String
        public let name: String
        /// City the venue is located in. Empty when the backend has no mapping.
        public let city: String
        /// Country metadata for the venue. Empty `Country()` when unavailable.
        public let country: Country
        /// Stadium capacity. 0 when the backend hasn't populated it.
        public let capacity: Int
        /// Stadium photo URL. Empty when unavailable.
        public let imageURL: String
        /// Playing surface (e.g. "grass", "artificial"). Empty when unknown.
        public let surface: String
        public let latitude: Double
        public let longitude: Double
        public let address: String

        public var isEmpty: Bool { id.isEmpty && name.isEmpty }

        public init(
            id: String = "", name: String = "",
            city: String = "", country: Country = Country(),
            capacity: Int = 0, imageURL: String = "",
            surface: String = "",
            latitude: Double = 0, longitude: Double = 0,
            address: String = ""
        ) {
            self.id = id; self.name = name
            self.city = city; self.country = country
            self.capacity = capacity; self.imageURL = imageURL
            self.surface = surface
            self.latitude = latitude; self.longitude = longitude
            self.address = address
        }
    }

    /// Per-market prediction (e.g. "1X2", "Both Teams To Score"). Percent
    /// values arrive as strings to preserve backend formatting ("52", "48.5%").
    public struct Prediction: Sendable, Equatable, Identifiable {
        public let typeID: String
        public let typeName: String
        public let homePercent: String
        public let drawPercent: String
        public let awayPercent: String

        public var id: String { typeID }

        public init(
            typeID: String = "", typeName: String = "",
            homePercent: String = "", drawPercent: String = "", awayPercent: String = ""
        ) {
            self.typeID = typeID; self.typeName = typeName
            self.homePercent = homePercent
            self.drawPercent = drawPercent
            self.awayPercent = awayPercent
        }
    }

    public struct H2H: Sendable, Equatable {
        public let home: TeamH2H
        public let away: TeamH2H
        public let between: [MatchSummary]

        public var isEmpty: Bool {
            home.form.isEmpty && away.form.isEmpty && between.isEmpty
        }

        public init(
            home: TeamH2H = TeamH2H(), away: TeamH2H = TeamH2H(),
            between: [MatchSummary] = []
        ) {
            self.home = home; self.away = away; self.between = between
        }
    }

    public struct TeamH2H: Sendable, Equatable, Identifiable {
        public let teamID: String
        public let teamName: String
        public let teamLogoURL: String
        public let form: [MatchSummary]
        public let recentCoach: String

        public var id: String { teamID }

        public init(
            teamID: String = "", teamName: String = "", teamLogoURL: String = "",
            form: [MatchSummary] = [], recentCoach: String = ""
        ) {
            self.teamID = teamID; self.teamName = teamName
            self.teamLogoURL = teamLogoURL; self.form = form
            self.recentCoach = recentCoach
        }
    }

    /// Highlight clip attached to a match. `embed` is an iframe-ready URL;
    /// `sourceURL` (when present) is the direct media URL preferred for
    /// in-app players.
    public struct Video: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let embed: String
        public let sourceID: String
        public let source: String
        public let sourceURL: String
        public let image: String

        public init(
            id: String = "", title: String = "", embed: String = "",
            sourceID: String = "", source: String = "",
            sourceURL: String = "", image: String = ""
        ) {
            self.id = id; self.title = title; self.embed = embed
            self.sourceID = sourceID; self.source = source
            self.sourceURL = sourceURL; self.image = image
        }
    }
}

// MARK: - Competition Detail

extension WasmClient.LiveScore {
    /// Country metadata attached to a `Competition`.
    public struct Country: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        /// ISO 3166-1 alpha-2 (e.g. "GB"). Empty when the backend has no mapping.
        public let iso2: String
        /// ISO 3166-1 alpha-3 (e.g. "GBR"). Empty when unavailable.
        public let iso3: String
        /// FIFA country identifier (e.g. "ENG"). Empty when unavailable.
        public let fifaName: String
        /// Continent label (e.g. "Europe"). Empty when unavailable.
        public let continentName: String
        /// Continent code (e.g. "EU"). Empty when unavailable.
        public let continentCode: String
        public let imagePath: String

        public init(
            id: String = "", name: String = "",
            iso2: String = "", iso3: String = "",
            fifaName: String = "",
            continentName: String = "", continentCode: String = "",
            imagePath: String = ""
        ) {
            self.id = id; self.name = name
            self.iso2 = iso2; self.iso3 = iso3
            self.fifaName = fifaName
            self.continentName = continentName
            self.continentCode = continentCode
            self.imagePath = imagePath
        }
    }

    /// Minimal player reference (id + display name). Used inside `Topscorer`.
    public struct Player: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String

        public init(id: String = "", name: String = "") {
            self.id = id; self.name = name
        }
    }

    /// Per-player row in a competition's top-scorers / top-assists list.
    public struct Topscorer: Sendable, Equatable, Identifiable {
        public let position: Int
        public let total: Int
        public let player: Player
        public let teamID: String
        public let teamName: String
        public let teamLogoURL: String

        public var id: String { "\(position)-\(player.id)" }

        public init(
            position: Int = 0, total: Int = 0,
            player: Player = Player(),
            teamID: String = "", teamName: String = "", teamLogoURL: String = ""
        ) {
            self.position = position; self.total = total
            self.player = player
            self.teamID = teamID; self.teamName = teamName
            self.teamLogoURL = teamLogoURL
        }
    }

    /// Aggregate W/D/L record for a single team in a standings row.
    public struct StandingRecord: Sendable, Equatable {
        public let played: Int
        public let win: Int
        public let draw: Int
        public let loss: Int
        public let goalsFor: Int
        public let goalsAgainst: Int

        public init(
            played: Int = 0, win: Int = 0, draw: Int = 0, loss: Int = 0,
            goalsFor: Int = 0, goalsAgainst: Int = 0
        ) {
            self.played = played; self.win = win; self.draw = draw; self.loss = loss
            self.goalsFor = goalsFor; self.goalsAgainst = goalsAgainst
        }
    }

    /// One row of a competition standings table.
    public struct Standing: Sendable, Equatable, Identifiable {
        public let position: Int
        public let points: Int
        public let goalsDiff: Int
        /// Group label (e.g. "Group A"). Empty for league-table competitions.
        public let groupName: String
        /// Recent-form streak as a five-character string (e.g. "WWDLW").
        public let form: String
        public let teamID: String
        public let teamName: String
        public let teamLogoURL: String
        public let all: StandingRecord

        public var id: String { "\(groupName)-\(position)-\(teamID)" }

        public init(
            position: Int = 0, points: Int = 0, goalsDiff: Int = 0,
            groupName: String = "", form: String = "",
            teamID: String = "", teamName: String = "", teamLogoURL: String = "",
            all: StandingRecord = StandingRecord()
        ) {
            self.position = position; self.points = points
            self.goalsDiff = goalsDiff; self.groupName = groupName
            self.form = form
            self.teamID = teamID; self.teamName = teamName
            self.teamLogoURL = teamLogoURL
            self.all = all
        }
    }

    /// Repeated `{count, score1, score2}` row in `CompetitionStats.commonScorelines`.
    public struct CompetitionScoreline: Sendable, Equatable, Identifiable {
        public let count: Int
        public let score1: Int
        public let score2: Int

        public var id: String { "\(score1)-\(score2)" }

        public init(count: Int = 0, score1: Int = 0, score2: Int = 0) {
            self.count = count; self.score1 = score1; self.score2 = score2
        }
    }

    /// Aggregate stats and ranked-player lists for a `Competition`.
    /// `topScorers` / `topAssists` may be empty when the backend hasn't
    /// populated them — render gracefully.
    public struct CompetitionStats: Sendable, Equatable {
        public let matches: Int
        public let goals: Int
        public let homeWins: Int
        public let awayWins: Int
        public let draws: Int
        public let cleanSheets: Int
        public let biggestWins: [MatchSummary]
        public let commonScorelines: [CompetitionScoreline]
        public let topScorers: [Topscorer]
        public let topAssists: [Topscorer]

        public var isEmpty: Bool {
            matches == 0 && goals == 0
                && biggestWins.isEmpty && commonScorelines.isEmpty
                && topScorers.isEmpty && topAssists.isEmpty
        }

        public init(
            matches: Int = 0, goals: Int = 0,
            homeWins: Int = 0, awayWins: Int = 0, draws: Int = 0,
            cleanSheets: Int = 0,
            biggestWins: [MatchSummary] = [],
            commonScorelines: [CompetitionScoreline] = [],
            topScorers: [Topscorer] = [],
            topAssists: [Topscorer] = []
        ) {
            self.matches = matches; self.goals = goals
            self.homeWins = homeWins; self.awayWins = awayWins
            self.draws = draws; self.cleanSheets = cleanSheets
            self.biggestWins = biggestWins
            self.commonScorelines = commonScorelines
            self.topScorers = topScorers; self.topAssists = topAssists
        }
    }

    /// Enriched competition payload returned by `lsCompetitionDetail`.
    /// `id` is the stringified Scorebat numeric id; `slug` is the
    /// `competition/...` form used by webpage / favourite flows.
    public struct Competition: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let image: String
        public let region: String
        public let slug: String
        public let seasonID: Int
        public let country: Country
        public let url: String
        public let fixtures: [MatchSummary]
        public let standings: [Standing]
        public let stats: CompetitionStats
        public let fetchedAt: String

        public init(
            id: String = "", name: String = "",
            image: String = "", region: String = "",
            slug: String = "", seasonID: Int = 0,
            country: Country = Country(),
            url: String = "",
            fixtures: [MatchSummary] = [],
            standings: [Standing] = [],
            stats: CompetitionStats = CompetitionStats(),
            fetchedAt: String = ""
        ) {
            self.id = id; self.name = name
            self.image = image; self.region = region
            self.slug = slug; self.seasonID = seasonID
            self.country = country; self.url = url
            self.fixtures = fixtures
            self.standings = standings
            self.stats = stats
            self.fetchedAt = fetchedAt
        }
    }
}

// MARK: - Team Detail

extension WasmClient.LiveScore {
    /// Slim league reference attached to `Team.tables`. Mirrors
    /// `LivescoreLeague` proto (id, name, countryID).
    public struct League: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let countryID: String

        public init(id: String = "", name: String = "", countryID: String = "") {
            self.id = id; self.name = name; self.countryID = countryID
        }
    }

    /// Enriched team payload returned by `lsTeamDetail`. The same struct
    /// also fronts the `participant` rows inside `Standing` (with the
    /// detail-only fields empty).
    public struct Team: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let image: String
        public let slug: String
        public let url: String
        public let countryName: String
        public let countryID: String
        public let national: Bool
        /// Alternative names / nicknames (e.g. "The Gunners").
        public let aka: [String]
        public let fixtures: [MatchSummary]
        public let results: [MatchSummary]
        public let tables: [League]
        public let fetchedAt: String

        public init(
            id: String = "", name: String = "",
            image: String = "", slug: String = "",
            url: String = "",
            countryName: String = "", countryID: String = "",
            national: Bool = false,
            aka: [String] = [],
            fixtures: [MatchSummary] = [],
            results: [MatchSummary] = [],
            tables: [League] = [],
            fetchedAt: String = ""
        ) {
            self.id = id; self.name = name
            self.image = image; self.slug = slug
            self.url = url
            self.countryName = countryName; self.countryID = countryID
            self.national = national
            self.aka = aka
            self.fixtures = fixtures; self.results = results
            self.tables = tables
            self.fetchedAt = fetchedAt
        }
    }
}

// MARK: - Match Update (SSE)

extension WasmClient.LiveScore {
    /// Lifecycle trigger of a `MatchUpdate` SSE delta. Raw values mirror
    /// the `LivescoreMatchUpdateType` proto so unknown values from a
    /// newer backend fall back to `.unspecified`.
    public enum MatchUpdateType: Int, Sendable, Equatable {
        case unspecified = 0
        case matchSoon = 1
        case matchStart = 2
        case goal = 3
        case halftime = 4
        case matchEnd = 5
        case statusChange = 6
    }

    /// One side of a `MatchUpdate` carrying the team identity and the
    /// score before/after the delta. `oldScore == newScore` for non-goal
    /// deltas (status changes, kickoff, halftime, full-time).
    public struct MatchUpdateSide: Sendable, Equatable {
        public let teamID: String
        public let teamName: String
        public let teamLogoURL: String
        public let oldScore: Int
        public let newScore: Int

        public init(
            teamID: String = "", teamName: String = "", teamLogoURL: String = "",
            oldScore: Int = 0, newScore: Int = 0
        ) {
            self.teamID = teamID; self.teamName = teamName
            self.teamLogoURL = teamLogoURL
            self.oldScore = oldScore; self.newScore = newScore
        }
    }

    /// A single live-events delta surfaced by `liveMatchEvents()`.
    /// `competition*` fields are flattened the same way `MatchSummary`
    /// flattens them — the full standings/stats payload of the underlying
    /// proto is intentionally dropped (deltas don't need it).
    public struct MatchUpdate: Sendable, Equatable, Identifiable {
        public let id: String
        public let home: MatchUpdateSide
        public let away: MatchUpdateSide
        public let competitionID: String
        public let competitionName: String
        public let competitionImage: String
        public let competitionRegion: String
        public let oldStatus: MatchStatus
        public let newStatus: MatchStatus
        public let eventType: MatchUpdateType
        public let url: String
        /// Decoded from the proto's `datetime` (UNIX seconds).
        public let kickoff: Date

        public init(
            id: String = "",
            home: MatchUpdateSide = MatchUpdateSide(),
            away: MatchUpdateSide = MatchUpdateSide(),
            competitionID: String = "",
            competitionName: String = "",
            competitionImage: String = "",
            competitionRegion: String = "",
            oldStatus: MatchStatus = .unspecified,
            newStatus: MatchStatus = .unspecified,
            eventType: MatchUpdateType = .unspecified,
            url: String = "",
            kickoff: Date = Date(timeIntervalSince1970: 0)
        ) {
            self.id = id
            self.home = home; self.away = away
            self.competitionID = competitionID
            self.competitionName = competitionName
            self.competitionImage = competitionImage
            self.competitionRegion = competitionRegion
            self.oldStatus = oldStatus; self.newStatus = newStatus
            self.eventType = eventType
            self.url = url; self.kickoff = kickoff
        }
    }

    /// Connection-aware payload yielded by `liveMatchEvents()`. Emits
    /// `.connected` once when the SSE connection opens, then `.update(_)`
    /// per `match-update` delta. Consumers use `.connected` to clear a
    /// "reconnecting" banner during a quiet period — an open-but-idle
    /// stream would otherwise look identical to a still-disconnected one.
    public enum LiveEvent: Sendable, Equatable {
        case connected
        case update(MatchUpdate)
    }
}
