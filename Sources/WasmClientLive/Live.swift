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
            setExpectedVersionProvider: { provider in
                Task { await actor.setExpectedVersionProvider(provider) }
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
            searchPhotos: { query, provider, page, perPage in
                try await actor.searchPhotos(query: query, provider: provider, page: page, perPage: perPage)
            },
            photoVisualSearch: { imageURL, provider, page, perPage in
                try await actor.photoVisualSearch(imageURL: imageURL, provider: provider, page: page, perPage: perPage)
            },
            listMedia: { query, provider, page, perPage in
                try await actor.listMedia(query: query, provider: provider, page: page, perPage: perPage)
            },
            homeDesign: { actionID, args in
                try await actor.homeDesign(actionID: actionID, args: args)
            },
            homeDesignStatus: { taskID, actionID in
                try await actor.homeDesignStatus(taskID: taskID, actionID: actionID)
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
            webpageLeagues: {
                try await actor.webpageLeagues()
            },
            webpageCompetitions: {
                try await actor.webpageCompetitions()
            },
            webpageTeams: {
                try await actor.webpageTeams()
            },
            webpage: { url in
                try await actor.webpage(url: url)
            },
            highlightPages: { competition, team, feed in
                try await actor.highlightPages(competition: competition, team: team, feed: feed)
            },
            upcoming: {
                try await actor.upcoming()
            }
        )
    }()
}
