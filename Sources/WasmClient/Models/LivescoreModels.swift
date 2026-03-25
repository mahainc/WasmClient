import Foundation

// MARK: - Livescore

extension WasmClient {
    /// Livescore API endpoint selector (raw values match proto `LivescoreEndpoint`).
    public enum LivescoreEndpoint: Int, Sendable {
        case livescores = 1
        case fixtures = 2
        case leagues = 3
        case standings = 4
        case teams = 5
        case players = 6
        case topscorers = 7
        case predictions = 8
        case odds = 9
        case news = 10
        case h2h = 11
        case meta = 12
        case expected = 13
    }

    /// A football fixture.
    public struct Fixture: Sendable, Equatable, Identifiable {
        public let id: String
        public let homeTeam: String
        public let awayTeam: String
        public let homeScore: Int?
        public let awayScore: Int?
        public let status: String
        public let date: String
        public let league: String
        public let round: String

        public init(
            id: String = "", homeTeam: String = "", awayTeam: String = "",
            homeScore: Int? = nil, awayScore: Int? = nil, status: String = "",
            date: String = "", league: String = "", round: String = ""
        ) {
            self.id = id
            self.homeTeam = homeTeam
            self.awayTeam = awayTeam
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.status = status
            self.date = date
            self.league = league
            self.round = round
        }
    }

    /// A league.
    public struct League: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let country: String
        public let logo: String
        public let type: String

        public init(id: String = "", name: String = "", country: String = "", logo: String = "", type: String = "") {
            self.id = id; self.name = name; self.country = country; self.logo = logo; self.type = type
        }
    }

    /// A team.
    public struct Team: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let logo: String
        public let country: String

        public init(id: String = "", name: String = "", logo: String = "", country: String = "") {
            self.id = id; self.name = name; self.logo = logo; self.country = country
        }
    }

    /// A standing entry.
    public struct Standing: Sendable, Equatable {
        public let rank: Int
        public let teamID: String
        public let teamName: String
        public let points: Int
        public let played: Int
        public let won: Int
        public let drawn: Int
        public let lost: Int
        public let goalsFor: Int
        public let goalsAgainst: Int

        public init(
            rank: Int = 0, teamID: String = "", teamName: String = "",
            points: Int = 0, played: Int = 0, won: Int = 0, drawn: Int = 0,
            lost: Int = 0, goalsFor: Int = 0, goalsAgainst: Int = 0
        ) {
            self.rank = rank; self.teamID = teamID; self.teamName = teamName
            self.points = points; self.played = played; self.won = won; self.drawn = drawn
            self.lost = lost; self.goalsFor = goalsFor; self.goalsAgainst = goalsAgainst
        }
    }

    /// A player.
    public struct Player: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let position: String
        public let nationality: String
        public let photo: String

        public init(id: String = "", name: String = "", position: String = "", nationality: String = "", photo: String = "") {
            self.id = id; self.name = name; self.position = position; self.nationality = nationality; self.photo = photo
        }
    }

    /// A highlight video.
    public struct Highlight: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let title: String
        public let videoURL: String
        public let thumbnailURL: String
        public let competition: String
        public let date: String

        public init(
            id: UUID = UUID(), title: String = "", videoURL: String = "",
            thumbnailURL: String = "", competition: String = "", date: String = ""
        ) {
            self.id = id; self.title = title; self.videoURL = videoURL
            self.thumbnailURL = thumbnailURL; self.competition = competition; self.date = date
        }
    }
}
