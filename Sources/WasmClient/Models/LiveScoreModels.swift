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

// MARK: - Livescore Upcoming

extension WasmClient.LiveScore {
    /// A single upcoming match returned by `lsUpcoming` / `lsScores`. Mirrors
    /// the `LivescoreUpcomingMatch` proto, with the UNIX `datetime` field
    /// decoded to a `Date` so consumers don't deal with the raw integer.
    public struct UpcomingMatch: Sendable, Equatable, Identifiable {
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

// MARK: - Livescore Webpage

extension WasmClient.LiveScore {
    /// A webpage entry returned by `lsWebpage`. Mirrors `LivescoreWebPage`
    /// proto from FlowKit. The same type backs every `WebPageType` variant
    /// (leagues, competitions, teams, page, discovers, videos, news).
    public struct WebPage: Sendable, Equatable, Identifiable {
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

        public init(
            id: String = "", image: String = "", title: String = "",
            subtitle: String = "", url: String = ""
        ) {
            self.id = id; self.image = image; self.title = title
            self.subtitle = subtitle; self.url = url
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
        public let summary: UpcomingMatch
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
            summary: UpcomingMatch,
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

        public var isEmpty: Bool { id.isEmpty && name.isEmpty }

        public init(id: String = "", name: String = "") {
            self.id = id; self.name = name
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
        public let between: [UpcomingMatch]

        public var isEmpty: Bool {
            home.form.isEmpty && away.form.isEmpty && between.isEmpty
        }

        public init(
            home: TeamH2H = TeamH2H(), away: TeamH2H = TeamH2H(),
            between: [UpcomingMatch] = []
        ) {
            self.home = home; self.away = away; self.between = between
        }
    }

    public struct TeamH2H: Sendable, Equatable, Identifiable {
        public let teamID: String
        public let teamName: String
        public let teamLogoURL: String
        public let form: [UpcomingMatch]
        public let recentCoach: String

        public var id: String { teamID }

        public init(
            teamID: String = "", teamName: String = "", teamLogoURL: String = "",
            form: [UpcomingMatch] = [], recentCoach: String = ""
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
