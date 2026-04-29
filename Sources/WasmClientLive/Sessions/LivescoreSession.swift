@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Livescore (Webpage only)

extension WasmActor {

    // MARK: - Webpage

    /// `LivescoreWebPageType` enum (server side): 1=leagues, 2=competitions,
    /// 3=teams, 4=page (URL-targeted).
    private func webpageList(type: Int, url: String? = nil) async throws -> [WasmClient.WebPage] {
        let instance = try await readyEngine()
        let action = try await instance.action(for: WasmClient.ActionID.lsWebpage.rawValue, strategy: .roundRobin)
        var args: [String: Google_Protobuf_Value] = [
            "type": Google_Protobuf_Value(numberValue: Double(type)),
        ]
        if let url { args["url"] = Google_Protobuf_Value(stringValue: url) }
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
        try await webpageList(type: 1)
    }

    func webpageCompetitions() async throws -> [WasmClient.WebPage] {
        try await webpageList(type: 2)
    }

    func webpageTeams() async throws -> [WasmClient.WebPage] {
        try await webpageList(type: 3)
    }

    func webpage(url: String) async throws -> [WasmClient.WebPage] {
        try await webpageList(type: 4, url: url)
    }

    // MARK: - Highlights

    func highlightPages(
        competition: String? = nil,
        team: String? = nil,
        feed: String? = nil
    ) async throws -> [WasmClient.WebPage] {
        let instance = try await readyEngine()
        let action = try await instance.action(for: WasmClient.ActionID.lsHighlights.rawValue, strategy: .roundRobin)
        var args: [String: Google_Protobuf_Value] = [:]
        if let competition { args["competition"] = Google_Protobuf_Value(stringValue: competition) }
        if let team { args["team"] = Google_Protobuf_Value(stringValue: team) }
        if let feed { args["feed"] = Google_Protobuf_Value(stringValue: feed) }
        let task = try await instance.create(action: action, args: args)
        let taskStatus = task.status
        guard taskStatus == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(taskStatus)")
        }
        let list: LivescoreWebPageList
        do {
            list = try LivescoreWebPageList(unpackingAny: task.value)
        } catch {
            logger("lsHighlights unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreWebPageList.protoMessageName) error=\(error)")
            throw error
        }
        return list.pages.map(mapWebPage)
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

    private func mapUpcoming(_ m: LivescoreUpcomingMatch) -> WasmClient.UpcomingMatch {
        WasmClient.UpcomingMatch(
            id: String(m.id),
            homeTeam: m.team1Name, awayTeam: m.team2Name,
            homeLogoURL: m.team1Logo, awayLogoURL: m.team2Logo,
            kickoff: Date(timeIntervalSince1970: TimeInterval(m.datetime)),
            competitionID: String(m.competitionID),
            homeScore: Int(m.score1), awayScore: Int(m.score2),
            status: m.status, embedURL: m.url
        )
    }

    private func mapWebPage(_ p: LivescoreWebPage) -> WasmClient.WebPage {
        WasmClient.WebPage(
            id: p.id, image: p.image, title: p.title,
            subtitle: p.subtitle, url: p.url
        )
    }
}
