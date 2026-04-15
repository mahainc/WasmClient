@preconcurrency import FlowKit
import Dependencies
import Foundation
import WasmClient

// MARK: - Dependency Key

extension WasmClient: DependencyKey {
    public static let liveValue: WasmClient = {
        let actor = WasmActor()
        return Self(
            start: {
                try await actor.start()
            },
            observeEngineState: {
                await actor.observeEngineState()
            },
            reset: {
                try await actor.reset()
            },
            restart: {
                try await actor.restart()
            },
            engineVersion: {
                await actor.engineVersion()
            },
            resetDownloads: {
                await actor.resetDownloads()
            },
            warmUp: {
                await actor.warmUp()
            },
            availableActions: {
                try await actor.availableActions()
            },
            refreshActions: {
                try await actor.refreshActions()
            },
            scan: { imageData, category, language in
                try await actor.scan(imageData: imageData, category: category, language: language)
            },
            describe: { imageURL, category, language, provider in
                try await actor.describe(imageURL: imageURL, category: category, language: language, provider: provider)
            },
            visualSearch: { imageURL, provider in
                try await actor.visualSearch(imageURL: imageURL, provider: provider)
            },
            shopping: { query, provider in
                try await actor.shopping(query: query, provider: provider)
            },
            uploadImage: { imageData in
                try await actor.uploadImage(imageData: imageData)
            },
            uploadFile: { filePath, filename in
                try await actor.uploadFile(filePath: filePath, filename: filename)
            },
            chatModels: {
                try await actor.chatModels()
            },
            chatSend: { config, messages in
                try await actor.chatSend(config: config, messages: messages)
            },
            chatStream: { config, messages in
                try await actor.chatStream(config: config, messages: messages)
            },
            musicDiscover: { category, continuation in
                try await actor.musicDiscover(category: category, continuation: continuation)
            },
            musicDetails: { trackID in
                try await actor.musicDetails(trackID: trackID)
            },
            musicTracks: { listID, continuation in
                try await actor.musicTracks(listID: listID, continuation: continuation)
            },
            musicSearch: { query, continuation in
                try await actor.musicSearch(query: query, continuation: continuation)
            },
            musicLyrics: { trackID in
                try await actor.musicLyrics(trackID: trackID)
            },
            musicRelated: { trackID, continuation in
                try await actor.musicRelated(trackID: trackID, continuation: continuation)
            },
            musicSuggestions: { query in
                try await actor.musicSuggestions(query: query)
            },
            suggest: { systemPrompt, imageURL in
                try await actor.suggest(systemPrompt: systemPrompt, imageURL: imageURL)
            },
            aiartGenerate: { actionID, args in
                try await actor.aiartGenerate(actionID: actionID, args: args)
            },
            aiartStyles: { actionID in
                try await actor.aiartStyles(actionID: actionID)
            },
            searchPhotos: { query, page, perPage in
                try await actor.searchPhotos(query: query, page: page, perPage: perPage)
            },
            photoVisualSearch: { imageURL, page, perPage in
                try await actor.photoVisualSearch(imageURL: imageURL, page: page, perPage: perPage)
            },
            listMedia: { query, page, perPage in
                try await actor.listMedia(query: query, page: page, perPage: perPage)
            },
            homeDesign: { actionID, args in
                try await actor.homeDesign(actionID: actionID, args: args)
            },
            homeDesignStatus: { taskID in
                try await actor.homeDesignStatus(taskID: taskID)
            },
            autoSuggestion: { image, cacheDir in
                try await actor.autoSuggestion(image: image, cacheDir: cacheDir)
            },
            enhance: { image, cacheDir, zoomFactor in
                try await actor.enhance(image: image, cacheDir: cacheDir, zoomFactor: zoomFactor)
            },
            removeBackground: { image, cacheDir in
                try await actor.removeBackground(image: image, cacheDir: cacheDir)
            },
            erase: { cacheDir, image, sessionId, maskBrush, maskObjects in
                try await actor.erase(
                    cacheDir: cacheDir, image: image, sessionId: sessionId,
                    maskBrush: maskBrush, maskObjects: maskObjects
                )
            },
            skinBeauty: { image, cacheDir in
                try await actor.skinBeauty(image: image, cacheDir: cacheDir)
            },
            sky: { image, cacheDir in
                try await actor.sky(image: image, cacheDir: cacheDir)
            },
            categorizeClothes: { image, cacheDir in
                try await actor.categorizeClothes(image: image, cacheDir: cacheDir)
            },
            tryOn: { cacheDir, image, modelId, clothType, clothId in
                try await actor.tryOn(
                    cacheDir: cacheDir, image: image, modelId: modelId,
                    clothType: clothType, clothId: clothId
                )
            },
            tryOnStatus: { taskID in
                try await actor.tryOnStatus(taskID: taskID)
            },
            livescores: { type in
                try await actor.livescores(type: type)
            },
            fixtures: { date in
                try await actor.fixtures(date: date)
            },
            fixture: { id in
                try await actor.fixture(id: id)
            },
            headToHead: { team1, team2 in
                try await actor.headToHead(team1: team1, team2: team2)
            },
            leagues: {
                try await actor.leagues()
            },
            searchLeagues: { query in
                try await actor.searchLeagues(query: query)
            },
            standings: { seasonID in
                try await actor.standings(seasonID: seasonID)
            },
            searchTeams: { query in
                try await actor.searchTeams(query: query)
            },
            team: { id in
                try await actor.team(id: id)
            },
            searchPlayers: { query in
                try await actor.searchPlayers(query: query)
            },
            player: { id in
                try await actor.player(id: id)
            },
            league: { id in
                try await actor.league(id: id)
            },
            topscorers: { seasonID in
                try await actor.topscorers(seasonID: seasonID)
            },
            predictions: { fixtureID in
                try await actor.predictions(fixtureID: fixtureID)
            },
            odds: { fixtureID, type in
                try await actor.odds(fixtureID: fixtureID, type: type)
            },
            expectedGoals: { fixtureID, type in
                try await actor.expectedGoals(fixtureID: fixtureID, type: type)
            },
            news: { seasonID, type in
                try await actor.news(seasonID: seasonID, type: type)
            },
            highlights: { competition, team in
                try await actor.highlights(competition: competition, team: team)
            }
        )
    }()
}
