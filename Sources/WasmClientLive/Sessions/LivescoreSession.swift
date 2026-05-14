@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Livescore (Webpage only)

extension WasmActor {

    // MARK: - Webpage

    private func webpageList(
        type: LivescoreWebPageType,
        extraArgs: [String: Google_Protobuf_Value] = [:]
    ) async throws -> [WasmClient.WebPage] {
        let instance = try await readyEngine()
        let action = try await instance.action(for: WasmClient.ActionID.lsWebpage.rawValue, strategy: .roundRobin)
        var args: [String: Google_Protobuf_Value] = [
            "type": Google_Protobuf_Value(numberValue: Double(type.rawValue)),
        ]
        for (k, v) in extraArgs { args[k] = v }
        let task = try await instance.create(action: action, args: args)
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

    func webpageLeagues() async throws -> [WasmClient.WebPage] {
        try await webpageList(type: .leagues)
    }

    func webpageCompetitions() async throws -> [WasmClient.WebPage] {
        try await webpageList(type: .competitions)
    }

    func webpageTeams() async throws -> [WasmClient.WebPage] {
        try await webpageList(type: .teams)
    }

    func webpage(url: String) async throws -> [WasmClient.WebPage] {
        try await webpageList(type: .page, extraArgs: ["url": Google_Protobuf_Value(stringValue: url)])
    }

    func webpageDiscovers() async throws -> [WasmClient.WebPage] {
        try await webpageList(type: .discovers)
    }

    // MARK: - Videos (Scorebat highlights via WebPageType.videos = 6)

    func webpageVideos(
        videoType: String? = nil,
        competitionID: Int64? = nil,
        teamID: Int64? = nil,
        q: String? = nil,
        page: Int64? = nil,
        pageSize: Int64? = nil
    ) async throws -> [WasmClient.WebPage] {
        var args: [String: Google_Protobuf_Value] = [:]
        if let videoType { args["video_type"] = Google_Protobuf_Value(stringValue: videoType) }
        if let competitionID {
            args["competition_id"] = Google_Protobuf_Value(numberValue: Double(competitionID))
        }
        if let teamID { args["team_id"] = Google_Protobuf_Value(numberValue: Double(teamID)) }
        if let q { args["q"] = Google_Protobuf_Value(stringValue: q) }
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
    ) async throws -> [WasmClient.WebPage] {
        var args: [String: Google_Protobuf_Value] = [:]
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }
        if let offset { args["offset"] = Google_Protobuf_Value(numberValue: Double(offset)) }
        if let q { args["q"] = Google_Protobuf_Value(stringValue: q) }
        return try await webpageList(type: .news, extraArgs: args)
    }

    // MARK: - Upcoming

    func upcoming() async throws -> [WasmClient.UpcomingMatch] {
        let instance = try await readyEngine()
        let action = try await instance.action(for: WasmClient.ActionID.lsUpcoming.rawValue, strategy: .roundRobin)
        let args: [String: Google_Protobuf_Value] = [:]
        let task = try await instance.create(action: action, args: args)
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

    func scoresByDate(date: String?) async throws -> [WasmClient.UpcomingMatch] {
        let instance = try await readyEngine()
        let action = try await instance.action(for: WasmClient.ActionID.lsScores.rawValue, strategy: .roundRobin)
        var args: [String: Google_Protobuf_Value] = [:]
        if let date { args["date"] = Google_Protobuf_Value(stringValue: date) }
        let task = try await instance.create(action: action, args: args)
        let taskStatus = task.status
        guard taskStatus == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(taskStatus)")
        }
        let list: LivescoreUpcomingMatchList
        do {
            list = try LivescoreUpcomingMatchList(unpackingAny: task.value)
        } catch {
            logger("lsScores unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreUpcomingMatchList.protoMessageName) error=\(error)")
            throw error
        }
        return list.matches.map(mapUpcoming)
    }

    private func mapUpcoming(_ m: LivescoreUpcomingMatch) -> WasmClient.UpcomingMatch {
        WasmClient.UpcomingMatch(
            id: String(m.id),
            homeTeam: m.team1Name, awayTeam: m.team2Name,
            homeLogoURL: m.team1Logo, awayLogoURL: m.team2Logo,
            kickoff: Date(timeIntervalSince1970: TimeInterval(m.datetime)),
            competitionID: String(m.competitionID),
            homeScore: Int(m.score1), awayScore: Int(m.score2),
            status: WasmClient.MatchStatus(rawValue: m.status.rawValue) ?? .unspecified,
            embedURL: m.url,
            competitionImage: m.competitionImage,
            competitionName: m.competitionName,
            competitionRegion: m.competitionRegion
        )
    }

    private func mapWebPage(_ p: LivescoreWebPage) -> WasmClient.WebPage {
        WasmClient.WebPage(
            id: p.id, image: p.image, title: p.title,
            subtitle: p.subtitle, url: p.url
        )
    }
}
