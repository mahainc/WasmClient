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

    func webpageTeams() async throws -> [WasmClient.LiveScore.WebPage] {
        try await webpageList(type: .teams)
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
        let list: LivescoreUpcomingMatchList
        do {
            list = try LivescoreUpcomingMatchList(unpackingAny: task.value)
        } catch {
            logger("lsUpcoming unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreUpcomingMatchList.protoMessageName) error=\(error)")
            throw error
        }
        return list.matches.map(mapUpcoming)
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
        let list: LivescoreUpcomingMatchList
        do {
            list = try LivescoreUpcomingMatchList(unpackingAny: task.value)
        } catch {
            logger("lsScores(date=\(date ?? "nil")) unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreUpcomingMatchList.protoMessageName) error=\(error)")
            throw error
        }
        return list.matches.map(mapUpcoming)
    }

    private func mapUpcoming(_ m: LivescoreUpcomingMatch) -> WasmClient.LiveScore.UpcomingMatch {
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

    private func mapWebPage(_ p: LivescoreWebPage) -> WasmClient.LiveScore.WebPage {
        WasmClient.LiveScore.WebPage(
            id: p.id, image: p.image, title: p.title,
            subtitle: p.subtitle, url: p.url
        )
    }
}
