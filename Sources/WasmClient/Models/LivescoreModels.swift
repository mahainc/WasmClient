import Foundation

// MARK: - Livescore Upcoming

extension WasmClient {
    /// A single upcoming match returned by `lsUpcoming`. Mirrors the
    /// `LivescoreUpcomingMatch` proto, with the UNIX `datetime` field decoded
    /// to a `Date` so consumers don't deal with the raw integer.
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
        /// 0 before kickoff; only meaningful when `status != "-"`.
        public let homeScore: Int
        public let awayScore: Int
        /// `"-"` until kickoff; otherwise live/finished status text.
        public let status: String
        /// Scorebat embed URL: `scorebat.com/embed/matchview/{id}`.
        public let embedURL: String

        public init(
            id: String, homeTeam: String, awayTeam: String,
            homeLogoURL: String, awayLogoURL: String,
            kickoff: Date, competitionID: String,
            homeScore: Int, awayScore: Int,
            status: String, embedURL: String
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
        }
    }
}

// MARK: - Livescore Webpage

extension WasmClient {
    /// A webpage entry returned by `lsWebpage` (and historically by `lsHighlights`
    /// with the `feed` arg). Mirrors `LivescoreWebPage` proto from FlowKit.
    public struct WebPage: Sendable, Equatable, Identifiable {
        /// Slug identifier (e.g. "team/real-madrid", "competition/england-premier-league").
        public let id: String
        /// Thumbnail / logo URL for list display.
        public let image: String
        /// Primary label (league name, team name, match title).
        public let title: String
        /// Secondary label (country, date, competition).
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
