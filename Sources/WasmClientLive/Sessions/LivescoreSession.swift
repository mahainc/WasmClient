@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

extension WasmActor {

    // MARK: - Webpage

    private func webpageList(
        type: LivescoreWebPageType,
        extraArgs: [String: Google_Protobuf_Value] = [:]
    ) async throws -> [WasmClient.LiveScore.Entry] {
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
        return list.pages.map(mapEntry)
    }

    func webpageLeagues() async throws -> [WasmClient.LiveScore.Entry] {
        try await webpageList(type: .leagues)
    }

    /// Server-filtered competitions catalog. `q` runs a full-text filter on
    /// name + region; `limit`/`offset` drive offset-based pagination — caller
    /// should stop when a response returns fewer than `limit` rows.
    func webpageCompetitions(
        q: String? = nil,
        limit: Int64? = nil,
        offset: Int64? = nil
    ) async throws -> [WasmClient.LiveScore.Entry] {
        var args: [String: Google_Protobuf_Value] = [:]
        if let q, !q.isEmpty { args["q"] = Google_Protobuf_Value(stringValue: q) }
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }
        if let offset { args["offset"] = Google_Protobuf_Value(numberValue: Double(offset)) }
        return try await webpageList(type: .competitions, extraArgs: args)
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
    ) async throws -> [WasmClient.LiveScore.Entry] {
        var args: [String: Google_Protobuf_Value] = [:]
        if let q, !q.isEmpty { args["q"] = Google_Protobuf_Value(stringValue: q) }
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }
        if let offset { args["offset"] = Google_Protobuf_Value(numberValue: Double(offset)) }
        if let competitionId, !competitionId.isEmpty {
            args["competition_id"] = Google_Protobuf_Value(stringValue: competitionId)
        }
        return try await webpageList(type: .teams, extraArgs: args)
    }

    func webpage(url: String) async throws -> [WasmClient.LiveScore.Entry] {
        try await webpageList(type: .page, extraArgs: ["url": Google_Protobuf_Value(stringValue: url)])
    }

    func webpageDiscovers() async throws -> [WasmClient.LiveScore.Entry] {
        try await webpageList(type: .discovers)
    }

    // MARK: - Single-item lookups (id-filtered)

    /// Fetch one competition by numeric Scorebat id. Returns the matching
    /// `Entry` (with composed embed URL) or nil when the backend doesn't
    /// know it.
    func webpageCompetition(id: String) async throws -> WasmClient.LiveScore.Entry? {
        try await webpageList(
            type: .competitions,
            extraArgs: ["id": Google_Protobuf_Value(stringValue: id)]
        ).first
    }

    /// Fetch one team by numeric Scorebat id. Returns the matching
    /// `Entry` or nil when the backend doesn't know it.
    func webpageTeam(id: String) async throws -> WasmClient.LiveScore.Entry? {
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
    ) async throws -> [WasmClient.LiveScore.Entry] {
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
        q: String? = nil,
        competitionID: String? = nil,
        teamID: String? = nil
    ) async throws -> [WasmClient.LiveScore.Entry] {
        var args: [String: Google_Protobuf_Value] = [:]
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }
        if let offset { args["offset"] = Google_Protobuf_Value(numberValue: Double(offset)) }
        if let q, !q.isEmpty { args["q"] = Google_Protobuf_Value(stringValue: q) }
        if let competitionID, !competitionID.isEmpty {
            args["competition_id"] = Google_Protobuf_Value(stringValue: competitionID)
        }
        if let teamID, !teamID.isEmpty {
            args["team_id"] = Google_Protobuf_Value(stringValue: teamID)
        }
        return try await webpageList(type: .news, extraArgs: args)
    }

    // MARK: - Upcoming

    func upcoming() async throws -> [WasmClient.LiveScore.MatchSummary] {
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
            venue: mapVenue(p.venue),
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
            between: h.between.map(mapMatchSummary)
        )
    }

    private func mapTeamH2H(_ t: LivescoreTeamH2H) -> WasmClient.LiveScore.TeamH2H {
        WasmClient.LiveScore.TeamH2H(
            teamID: t.team.id,
            teamName: t.team.name,
            teamLogoURL: t.team.image,
            form: t.form.map(mapMatchSummary),
            recentCoach: t.recentCoach
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

    func scoresByDate(date: String?) async throws -> [WasmClient.LiveScore.MatchSummary] {
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

    private func mapMatchSummary(_ m: LivescoreMatchSummary) -> WasmClient.LiveScore.MatchSummary {
        WasmClient.LiveScore.MatchSummary(
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

    private func mapEntry(_ p: LivescoreWebPage) -> WasmClient.LiveScore.Entry {
        WasmClient.LiveScore.Entry(
            id: p.id, image: p.image, title: p.title,
            subtitle: p.subtitle, url: p.url, datetime: p.datetime,
            videos: p.videos.map(mapVideo)
        )
    }

    // MARK: - Competition Detail

    /// Enriched competition payload (standings, stats, fixtures, top
    /// scorers/assists). Backed by `lsCompetitionDetail` → `LivescoreCompetition`
    /// proto. Independent of the WebPage flow.
    func competitionDetail(id: String) async throws -> WasmClient.LiveScore.Competition {
        let instance = try await readyEngine()
        let action = try await instance.action(
            for: WasmClient.ActionID.lsCompetitionDetail.rawValue,
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
        let proto: LivescoreCompetition
        do {
            proto = try LivescoreCompetition(unpackingAny: task.value)
        } catch {
            logger("lsCompetitionDetail(id=\(id)) unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreCompetition.protoMessageName) error=\(error)")
            throw error
        }
        return mapCompetition(proto)
    }

    // MARK: - Team Detail

    /// Enriched team payload (aka, fixtures, results, tables). Backed by
    /// `lsTeamDetail` → `LivescoreTeam` proto. Independent of the WebPage flow.
    func teamDetail(id: String) async throws -> WasmClient.LiveScore.Team {
        let instance = try await readyEngine()
        let action = try await instance.action(
            for: WasmClient.ActionID.lsTeamDetail.rawValue,
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
        let proto: LivescoreTeam
        do {
            proto = try LivescoreTeam(unpackingAny: task.value)
        } catch {
            logger("lsTeamDetail(id=\(id)) unpack failed: typeURL='\(task.value.typeURL)' expected=\(LivescoreTeam.protoMessageName) error=\(error)")
            throw error
        }
        return mapTeam(proto)
    }

    // MARK: - Live Match Events (SSE)

    /// Open the `/soccer/events` SSE stream and yield each `MatchUpdate`
    /// delta as it arrives. Mirrors `chatStream`'s SSE plumbing — mints a
    /// `requestID`, installs an `AsyncifyWasmInternal.installSSEChunkHandler`
    /// for that id, then launches a detached Task to drive
    /// `engine.create(action:args:requestID:)`. The stream runs until the
    /// consumer cancels it (drops the `AsyncStream` / cancels the iterating
    /// task); the underlying wasm task stays `Processing` for the life of
    /// the connection.
    func liveMatchEvents() async -> AsyncStream<WasmClient.LiveScore.LiveEvent> {
        let log = logger
        let instance: any TaskWasmProtocol
        do {
            instance = try await readyEngine()
        } catch {
            log("liveMatchEvents: engine not ready — \(error)")
            return AsyncStream { $0.finish() }
        }
        guard let engine = instance as? TaskWasmEngine else {
            log("liveMatchEvents: engine type is not TaskWasmEngine")
            return AsyncStream { $0.finish() }
        }
        let action: WaTAction
        do {
            action = try await engine.action(
                for: WasmClient.ActionID.lsLiveEvents.rawValue,
                strategy: .roundRobin
            )
        } catch {
            log("liveMatchEvents: action resolve failed — \(error)")
            return AsyncStream { $0.finish() }
        }

        let requestID = UUID().uuidString
        return AsyncStream { continuation in
            AsyncifyWasmInternal.installSSEChunkHandler(for: requestID) { chunk in
                guard let data = chunk.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      (json["event"] as? String) == "match-update",
                      let b64 = json["data"] as? String,
                      let protoBytes = Data(base64Encoded: b64),
                      let update = try? LivescoreMatchUpdate(serializedBytes: protoBytes)
                else { return }
                continuation.yield(.update(Self.mapMatchUpdate(update)))
            }

            // `create` returns on the FIRST task status from the SSE executor
            // (`.processing`, after the connection opens) while real chunks keep
            // arriving via the `sse_chunk` host import for the life of the
            // stream. The pump must hold open past that early return — otherwise
            // `continuation.finish()` runs immediately, `onTermination` removes
            // the chunk handler, and every subsequent SSE event is silently
            // dropped. Cancelled via `onTermination` → `pump.cancel()`.
            let pump = Task.detached {
                do {
                    let task = try await engine.create(action: action, args: [:], requestID: requestID)
                    if task.status == .processing {
                        // Connection is open — surface it so the consumer can
                        // clear "reconnecting" UI before any chunk arrives.
                        continuation.yield(.connected)
                        while !Task.isCancelled {
                            try await Task.sleep(nanoseconds: 1_000_000_000)
                        }
                    }
                } catch {
                    log("liveMatchEvents: create failed — \(error)")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                pump.cancel()
                AsyncifyWasmInternal.removeSSEChunkHandler(for: requestID)
            }
        }
    }

    // MARK: - Competition / Team / MatchUpdate mappers

    private func mapCompetition(_ p: LivescoreCompetition) -> WasmClient.LiveScore.Competition {
        WasmClient.LiveScore.Competition(
            id: String(p.id),
            name: p.name,
            image: p.image,
            region: p.region,
            slug: p.slug,
            seasonID: Int(p.seasonID),
            country: mapCountry(p.country),
            url: p.url,
            fixtures: p.fixtures.map(mapMatchSummary),
            standings: p.standings.map(mapStanding),
            stats: mapCompetitionStats(p.stats),
            fetchedAt: p.fetchedAt
        )
    }

    private func mapCountry(_ c: LivescoreCountry) -> WasmClient.LiveScore.Country {
        WasmClient.LiveScore.Country(
            id: c.id, name: c.name,
            iso2: c.iso2, iso3: c.iso3,
            fifaName: c.fifaName,
            continentName: c.continentName, continentCode: c.continentCode,
            imagePath: c.imagePath
        )
    }

    private func mapVenue(_ v: LivescoreVenue) -> WasmClient.LiveScore.Venue {
        WasmClient.LiveScore.Venue(
            id: v.id, name: v.name,
            city: v.city, country: mapCountry(v.country),
            capacity: Int(v.capacity), imageURL: v.imageURL,
            surface: v.surface,
            latitude: v.latitude, longitude: v.longitude,
            address: v.address
        )
    }

    private func mapStanding(_ s: LivescoreStanding) -> WasmClient.LiveScore.Standing {
        WasmClient.LiveScore.Standing(
            position: Int(s.position),
            points: Int(s.points),
            goalsDiff: Int(s.goalsDiff),
            groupName: s.groupName,
            form: s.form,
            teamID: s.participant.id,
            teamName: s.participant.name,
            teamLogoURL: s.participant.image,
            all: mapStandingRecord(s.all)
        )
    }

    private func mapStandingRecord(_ r: LivescoreStandingRecord) -> WasmClient.LiveScore.StandingRecord {
        WasmClient.LiveScore.StandingRecord(
            played: Int(r.played),
            win: Int(r.win),
            draw: Int(r.draw),
            loss: Int(r.lose),
            goalsFor: Int(r.goalsFor),
            goalsAgainst: Int(r.goalsAgainst)
        )
    }

    private func mapCompetitionStats(_ s: LivescoreCompetitionStats) -> WasmClient.LiveScore.CompetitionStats {
        WasmClient.LiveScore.CompetitionStats(
            matches: Int(s.matches),
            goals: Int(s.goals),
            homeWins: Int(s.homeWins),
            awayWins: Int(s.awayWins),
            draws: Int(s.draws),
            cleanSheets: Int(s.cleanSheets),
            biggestWins: s.biggestWins.map(mapMatchSummary),
            commonScorelines: s.commonScorelines.map(mapCompetitionScoreline),
            topScorers: s.topScorers.map(mapTopscorer),
            topAssists: s.topAssists.map(mapTopscorer)
        )
    }

    private func mapCompetitionScoreline(_ s: LivescoreCompetitionScoreline) -> WasmClient.LiveScore.CompetitionScoreline {
        WasmClient.LiveScore.CompetitionScoreline(
            count: Int(s.count),
            score1: Int(s.score1),
            score2: Int(s.score2)
        )
    }

    private func mapTopscorer(_ t: LivescoreTopscorer) -> WasmClient.LiveScore.Topscorer {
        WasmClient.LiveScore.Topscorer(
            position: Int(t.position),
            total: Int(t.total),
            player: WasmClient.LiveScore.Player(id: t.player.id, name: t.player.name),
            teamID: t.team.id,
            teamName: t.team.name,
            teamLogoURL: t.team.image
        )
    }

    private func mapTeam(_ t: LivescoreTeam) -> WasmClient.LiveScore.Team {
        WasmClient.LiveScore.Team(
            id: t.id,
            name: t.name,
            image: t.image,
            slug: t.slug,
            url: t.url,
            countryName: t.countryName,
            countryID: t.countryID,
            national: t.national,
            aka: t.aka,
            fixtures: t.fixtures.map(mapMatchSummary),
            results: t.results.map(mapMatchSummary),
            tables: t.tables.map(mapLeague),
            fetchedAt: t.fetchedAt
        )
    }

    private func mapLeague(_ l: LivescoreLeague) -> WasmClient.LiveScore.League {
        WasmClient.LiveScore.League(
            id: l.id, name: l.name, countryID: l.countryID
        )
    }

    private static func mapMatchUpdate(_ u: LivescoreMatchUpdate) -> WasmClient.LiveScore.MatchUpdate {
        WasmClient.LiveScore.MatchUpdate(
            id: String(u.id),
            home: mapMatchUpdateSide(u.home),
            away: mapMatchUpdateSide(u.away),
            competitionID: String(u.competition.id),
            competitionName: u.competition.name,
            competitionImage: u.competition.image,
            competitionRegion: u.competition.region,
            oldStatus: WasmClient.LiveScore.MatchStatus(rawValue: u.oldStatus.rawValue) ?? .unspecified,
            newStatus: WasmClient.LiveScore.MatchStatus(rawValue: u.newStatus.rawValue) ?? .unspecified,
            eventType: WasmClient.LiveScore.MatchUpdateType(rawValue: u.eventType.rawValue) ?? .unspecified,
            url: u.url,
            kickoff: Date(timeIntervalSince1970: TimeInterval(u.datetime))
        )
    }

    private static func mapMatchUpdateSide(_ s: LivescoreMatchUpdateSide) -> WasmClient.LiveScore.MatchUpdateSide {
        WasmClient.LiveScore.MatchUpdateSide(
            teamID: s.team.id,
            teamName: s.team.name,
            teamLogoURL: s.team.image,
            oldScore: Int(s.oldScore),
            newScore: Int(s.newScore)
        )
    }
}
