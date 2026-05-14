import Foundation

// MARK: - Match Status

extension WasmClient {
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

// MARK: - Livescore Upcoming

extension WasmClient {
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

extension WasmClient {
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
