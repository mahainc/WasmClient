@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

extension WasmActor {

    // MARK: - Webpage

    private func webpageList(
        type: LivescoreWebPageType,
        extraArgs: [String: Google_Protobuf_Value] = [:]
    ) async throws -> [WasmClient.LiveScore.WebPage] {
        let instance = try await readyEngine()
        let action = try await instance.action(for: WasmClient.ActionID.lsWebpage.rawValue, strategy: .roundRobin)
        var args: [String: Google_Protobuf_Value] = [
            "type": Google_Protobuf_Value(numberValue: Double(type.rawValue)),
        ]
        for (k, v) in extraArgs { args[k] = v }
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value
        let taskStatus = task.status
        guard taskStatus == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(taskStatus)")
        }
        let list: LivescoreWebPageList
        do {
            list = try LivescoreWebPageList(unpackingAny: task.value)
        } catch {
            logger("lsWebpage(type=\(type)) unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreWebPageList.protoMessageName) error=\(error)")
            throw error
        }
        return list.pages.map(mapWebPage)
    }

    func webpageLeagues() async throws -> [WasmClient.LiveScore.WebPage] {
        try await webpageList(type: .leagues)
    }

    func webpageCompetitions() async throws -> [WasmClient.LiveScore.WebPage] {
        try await webpageList(type: .competitions)
    }

    /// Server-filtered teams catalog. `q` runs a full-text filter on
    /// name + region; `limit`/`offset` drive offset-based pagination —
    /// caller should stop when a response returns fewer than `limit`
    /// rows. `competitionId` narrows the catalog to teams that played
    /// in the given competition (slug-form id, e.g.
    /// "competition/england-premier-league").
    func webpageTeams(
        q: String? = nil,
        limit: Int64? = nil,
        offset: Int64? = nil,
        competitionId: String? = nil
    ) async throws -> [WasmClient.LiveScore.WebPage] {
        var args: [String: Google_Protobuf_Value] = [:]
        if let q, !q.isEmpty { args["q"] = Google_Protobuf_Value(stringValue: q) }
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }
        if let offset { args["offset"] = Google_Protobuf_Value(numberValue: Double(offset)) }
        if let competitionId, !competitionId.isEmpty {
            args["competition_id"] = Google_Protobuf_Value(stringValue: competitionId)
        }
        return try await webpageList(type: .teams, extraArgs: args)
    }

    func webpage(url: String) async throws -> [WasmClient.LiveScore.WebPage] {
        try await webpageList(type: .page, extraArgs: ["url": Google_Protobuf_Value(stringValue: url)])
    }

    func webpageDiscovers() async throws -> [WasmClient.LiveScore.WebPage] {
        try await webpageList(type: .discovers)
    }

    // MARK: - Single-item lookups (id-filtered)

    /// Fetch one competition by numeric Scorebat id. Returns the matching
    /// `WebPage` (with composed embed URL) or nil when the backend doesn't
    /// know it.
    func webpageCompetition(id: String) async throws -> WasmClient.LiveScore.WebPage? {
        try await webpageList(
            type: .competitions,
            extraArgs: ["id": Google_Protobuf_Value(stringValue: id)]
        ).first
    }

    /// Fetch one team by numeric Scorebat id. Returns the matching
    /// `WebPage` or nil when the backend doesn't know it.
    func webpageTeam(id: String) async throws -> WasmClient.LiveScore.WebPage? {
        try await webpageList(
            type: .teams,
            extraArgs: ["id": Google_Protobuf_Value(stringValue: id)]
        ).first
    }

    // MARK: - Videos (Scorebat highlights via WebPageType.videos = 6)

    func webpageVideos(
        videoType: String? = nil,
        competitionID: String? = nil,
        teamID: String? = nil,
        q: String? = nil,
        page: Int64? = nil,
        pageSize: Int64? = nil
    ) async throws -> [WasmClient.LiveScore.WebPage] {
        var args: [String: Google_Protobuf_Value] = [:]
        if let videoType, !videoType.isEmpty {
            args["video_type"] = Google_Protobuf_Value(stringValue: videoType)
        }
        if let competitionID, !competitionID.isEmpty {
            args["competition_id"] = Google_Protobuf_Value(stringValue: competitionID)
        }
        if let teamID, !teamID.isEmpty {
            args["team_id"] = Google_Protobuf_Value(stringValue: teamID)
        }
        if let q, !q.isEmpty {
            args["q"] = Google_Protobuf_Value(stringValue: q)
        }
        if let page { args["page"] = Google_Protobuf_Value(numberValue: Double(page)) }
        if let pageSize {
            args["page_size"] = Google_Protobuf_Value(numberValue: Double(pageSize))
        }
        return try await webpageList(type: .videos, extraArgs: args)
    }

    // MARK: - News (soccer feed via WebPageType.news = 7)

    func webpageNews(
        limit: Int64? = nil,
        offset: Int64? = nil,
        q: String? = nil
    ) async throws -> [WasmClient.LiveScore.WebPage] {
        var args: [String: Google_Protobuf_Value] = [:]
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }
        if let offset { args["offset"] = Google_Protobuf_Value(numberValue: Double(offset)) }
        if let q { args["q"] = Google_Protobuf_Value(stringValue: q) }
        return try await webpageList(type: .news, extraArgs: args)
    }

    // MARK: - Upcoming

    func upcoming() async throws -> [WasmClient.LiveScore.UpcomingMatch] {
        let instance = try await readyEngine()
        let action = try await instance.action(for: WasmClient.ActionID.lsUpcoming.rawValue, strategy: .roundRobin)
        let args: [String: Google_Protobuf_Value] = [:]
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value
        let taskStatus = task.status
        guard taskStatus == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(taskStatus)")
        }
        let list: LivescoreMatchSummaryList
        do {
            list = try LivescoreMatchSummaryList(unpackingAny: task.value)
        } catch {
            logger("lsUpcoming unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreMatchSummaryList.protoMessageName) error=\(error)")
            throw error
        }
        return list.matches.map(mapMatchSummary)
    }

    // MARK: - Match Detail

    /// Enriched match payload (events, lineups, statistics, predictions,
    /// referee, venue, h2h, highlight videos). Backed by `lsMatchDetail` →
    /// `LivescoreMatch` proto. Independent of the WebPage flow.
    func matchDetail(id: String) async throws -> WasmClient.LiveScore.Match {
        let instance = try await readyEngine()
        let action = try await instance.action(
            for: WasmClient.ActionID.lsMatchDetail.rawValue,
            strategy: .roundRobin
        )
        let args: [String: Google_Protobuf_Value] = [
            "id": Google_Protobuf_Value(stringValue: id),
        ]
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value
        let taskStatus = task.status
        guard taskStatus == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(taskStatus)")
        }
        let proto: LivescoreMatch
        do {
            proto = try LivescoreMatch(unpackingAny: task.value)
        } catch {
            logger("lsMatchDetail(id=\(id)) unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreMatch.protoMessageName) error=\(error)")
            throw error
        }
        return mapMatch(proto)
    }

    private func mapMatch(_ p: LivescoreMatch) -> WasmClient.LiveScore.Match {
        WasmClient.LiveScore.Match(
            summary: mapMatchSummary(p.match_),
            events: p.events.map(mapMatchEvent),
            lineups: mapLineups(p.lineup),
            statistics: p.statistics.map(mapStatistic),
            refereeName: p.referee.name,
            venue: WasmClient.LiveScore.Venue(id: p.venue.id, name: p.venue.name),
            predictions: p.predictions.map(mapPrediction),
            h2h: mapH2H(p.h2H),
            videos: p.videos.map(mapVideo)
        )
    }

    private func mapMatchEvent(_ e: LivescoreMatchEvent) -> WasmClient.LiveScore.MatchEvent {
        WasmClient.LiveScore.MatchEvent(
            playerID: e.playerID,
            playerName: e.playerName,
            participantID: e.participantID,
            minute: Int(e.minute),
            eventType: WasmClient.LiveScore.EventType(rawValue: e.eventType.rawValue) ?? .unspecified,
            typeRaw: e.typeRaw,
            relatedPlayerID: e.relatedPlayerID,
            relatedPlayerName: e.relatedPlayerName
        )
    }

    private func mapLineups(_ l: LivescoreLineups) -> WasmClient.LiveScore.Lineups {
        WasmClient.LiveScore.Lineups(
            home: mapTeamLineup(l.home),
            away: mapTeamLineup(l.away)
        )
    }

    private func mapTeamLineup(_ t: LivescoreTeamLineup) -> WasmClient.LiveScore.TeamLineup {
        WasmClient.LiveScore.TeamLineup(
            teamID: t.team.id,
            teamName: t.team.name,
            teamLogoURL: t.team.image,
            formation: t.formation,
            startXi: t.startXi.map(mapLineupRow),
            substitutes: t.substitutes.map(mapLineupRow),
            coachName: t.coach.name
        )
    }

    private func mapLineupRow(_ r: LivescoreLineup) -> WasmClient.LiveScore.Lineup {
        WasmClient.LiveScore.Lineup(
            playerID: r.playerID,
            playerName: r.playerName,
            jerseyNumber: Int(r.jerseyNumber),
            position: WasmClient.LiveScore.PlayerPosition(rawValue: r.position.rawValue) ?? .unspecified,
            isSubstitute: r.isSubstitute
        )
    }

    private func mapStatistic(_ s: LivescoreFixtureStatistic) -> WasmClient.LiveScore.FixtureStatistic {
        WasmClient.LiveScore.FixtureStatistic(
            typeName: s.typeName,
            location: s.location,
            statType: WasmClient.LiveScore.StatType(rawValue: s.statType.rawValue) ?? .unspecified,
            valueInt: s.hasValueInt ? Int(s.valueInt) : nil,
            valueString: s.hasValueString ? s.valueString : nil
        )
    }

    private func mapPrediction(_ pred: LivescorePrediction) -> WasmClient.LiveScore.Prediction {
        WasmClient.LiveScore.Prediction(
            typeID: pred.typeID,
            typeName: pred.typeName,
            homePercent: pred.percent.home,
            drawPercent: pred.percent.draw,
            awayPercent: pred.percent.away
        )
    }

    private func mapH2H(_ h: LivescoreH2H) -> WasmClient.LiveScore.H2H {
        WasmClient.LiveScore.H2H(
            home: mapTeamH2H(h.home),
            away: mapTeamH2H(h.away),
            between: h.between.map(mapUpcomingMatch)
        )
    }

    private func mapTeamH2H(_ t: LivescoreTeamH2H) -> WasmClient.LiveScore.TeamH2H {
        WasmClient.LiveScore.TeamH2H(
            teamID: t.team.id,
            teamName: t.team.name,
            teamLogoURL: t.team.image,
            form: t.form.map(mapUpcomingMatch),
            recentCoach: t.recentCoach
        )
    }

    /// Map the standalone `LivescoreUpcomingMatch` proto (used for H2H form
    /// + previous meetings list rows) into the public `UpcomingMatch` shape.
    /// `LivescoreUpcomingMatch` has flat fields (team1Name, team1Logo, …)
    /// rather than the nested `home`/`away`/`competition` sub-messages on
    /// `LivescoreMatchSummary`, so this mapper differs from `mapMatchSummary`.
    private func mapUpcomingMatch(_ m: LivescoreUpcomingMatch) -> WasmClient.LiveScore.UpcomingMatch {
        WasmClient.LiveScore.UpcomingMatch(
            id: String(m.id),
            homeTeam: m.team1Name, awayTeam: m.team2Name,
            homeLogoURL: m.team1Logo, awayLogoURL: m.team2Logo,
            kickoff: Date(timeIntervalSince1970: TimeInterval(m.datetime)),
            competitionID: String(m.competitionID),
            homeScore: Int(m.score1), awayScore: Int(m.score2),
            status: WasmClient.LiveScore.MatchStatus(rawValue: m.status.rawValue) ?? .unspecified,
            embedURL: m.url,
            competitionImage: m.competitionImage,
            competitionName: m.competitionName,
            competitionRegion: m.competitionRegion
        )
    }

    private func mapVideo(_ v: LivescoreVideo) -> WasmClient.LiveScore.Video {
        WasmClient.LiveScore.Video(
            id: v.id, title: v.title, embed: v.embed,
            sourceID: v.sourceID, source: v.source,
            sourceURL: v.sourceURL, image: v.image
        )
    }

    // MARK: - Scores by date

    func scoresByDate(date: String?) async throws -> [WasmClient.LiveScore.UpcomingMatch] {
        let instance = try await readyEngine()
        let action = try await instance.action(for: WasmClient.ActionID.lsScores.rawValue, strategy: .roundRobin)
        var args: [String: Google_Protobuf_Value] = [:]
        if let date { args["date"] = Google_Protobuf_Value(stringValue: date) }
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value
        let taskStatus = task.status
        guard taskStatus == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(taskStatus)")
        }
        let list: LivescoreMatchSummaryList
        do {
            list = try LivescoreMatchSummaryList(unpackingAny: task.value)
        } catch {
            logger("lsScores(date=\(date ?? "nil")) unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreMatchSummaryList.protoMessageName) error=\(error)")
            throw error
        }
        return list.matches.map(mapMatchSummary)
    }

    private func mapMatchSummary(_ m: LivescoreMatchSummary) -> WasmClient.LiveScore.UpcomingMatch {
        WasmClient.LiveScore.UpcomingMatch(
            id: String(m.id),
            homeTeam: m.home.name, awayTeam: m.away.name,
            homeLogoURL: m.home.image, awayLogoURL: m.away.image,
            kickoff: Date(timeIntervalSince1970: TimeInterval(m.datetime)),
            competitionID: String(m.competition.id),
            homeScore: Int(m.score1), awayScore: Int(m.score2),
            status: WasmClient.LiveScore.MatchStatus(rawValue: m.status.rawValue) ?? .unspecified,
            embedURL: m.url,
            competitionImage: m.competition.image,
            competitionName: m.competition.name,
            competitionRegion: m.competition.region
        )
    }

    private func mapWebPage(_ p: LivescoreWebPage) -> WasmClient.LiveScore.WebPage {
        WasmClient.LiveScore.WebPage(
            id: p.id, image: p.image, title: p.title,
            subtitle: p.subtitle, url: p.url
        )
    }
}
