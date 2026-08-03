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
                actor.setExpectedVersionProvider(provider)
            },
            setUserName: { name in
                actor.setUserName(name)
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
            funnelEngine: {
                try await actor.funnelEngine()
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
            chatModels: { offset, limit, keyword, category in
                try await actor.chatModels(
                    offset: offset,
                    limit: limit,
                    keyword: keyword,
                    category: category
                )
            },
            chatSend: { config, messages in
                try await actor.chatSend(config: config, messages: messages)
            },
            chatStream: { config, messages in
                try await actor.chatStream(config: config, messages: messages)
            },
            createChatModel: { providerID, input in
                try await actor.createChatModel(providerID: providerID, input: input)
            },
            initializeChatProvider: { providerID, userName in
                try await actor.initializeChatProvider(providerID: providerID, userName: userName)
            },
            completion: { config, messages in
                try await actor.completion(config: config, messages: messages)
            },
            listProviders: {
                try await actor.listProviders()
            },
            authProvider: { providerID in
                try await actor.authProvider(providerID: providerID)
            },
            listVoices: { providerID, keyword, offset, limit in
                try await actor.listVoices(
                    providerID: providerID,
                    keyword: keyword,
                    offset: offset,
                    limit: limit
                )
            },
            createVoice: { providerID, name, audio, gender, visibility in
                try await actor.createVoice(
                    providerID: providerID,
                    name: name,
                    audio: audio,
                    gender: gender,
                    visibility: visibility
                )
            },
            deleteVoice: { providerID, voiceID in
                try await actor.deleteVoice(providerID: providerID, voiceID: voiceID)
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
            readOutLoud: { text, voice, providerID in
                try await actor.readOutLoud(text: text, voice: voice, providerID: providerID)
            },
            ttsVoices: { providerID, modelID in
                try await actor.ttsVoices(providerID: providerID, modelID: modelID)
            },
            generateAIArt: { request in
                try await actor.generateAIArt(request)
            },
            listAIArtStyles: { kind in
                try await actor.listAIArtStyles(kind: kind)
            },
            loadAIArtModelCatalog: { mode in
                try await actor.loadAIArtModelCatalog(mode: mode)
            },
            submitAIArtVideo: { request in
                try await actor.submitAIArtVideo(request)
            },
            getAIArtVideoStatus: { videoID in
                try await actor.getAIArtVideoStatus(videoID: videoID)
            },
            pollAIArtVideo: { videoID, interval, onUpdate in
                try await actor.pollAIArtVideo(
                    videoID: videoID,
                    interval: interval,
                    onUpdate: onUpdate
                )
            },
            listPendingTasks: {
                await actor.listPendingTasks()
            },
            observePendingTasks: {
                await actor.observePendingTasks()
            },
            observeTaskCreated: {
                await actor.observeTaskCreated()
            },
            removePendingTask: { taskID in
                await actor.removePendingTask(taskID: taskID)
            },
            clearPendingTasks: {
                await actor.clearPendingTasks()
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
            homeDesignRequest: { request, onProgress in
                try await actor.homeDesignRequest(request, onProgress: onProgress)
            },
            homeDecorStyles: { processType in
                try await actor.homeDecorStyles(processType: processType)
            },
            homeDecorRoomTypes: { processType in
                try await actor.homeDecorRoomTypes(processType: processType)
            },
            homeDecorColorPalettes: { processType in
                try await actor.homeDecorColorPalettes(processType: processType)
            },
            homeDecorSurfaceTypes: { processType in
                try await actor.homeDecorSurfaceTypes(processType: processType)
            },
            homeDecorStyleSelections: { processType in
                try await actor.homeDecorStyleSelections(processType: processType)
            },
            autoSuggestion: { image in
                try await actor.autoSuggestion(image: image)
            },
            enhance: { image, zoomFactor in
                try await actor.enhance(image: image, zoomFactor: zoomFactor)
            },
            removeBackground: { image in
                try await actor.removeBackground(image: image)
            },
            erase: { image, sessionID, maskBrush, maskObjects in
                try await actor.erase(
                    image: image,
                    sessionID: sessionID,
                    maskBrush: maskBrush,
                    maskObjects: maskObjects
                )
            },
            skinBeauty: { image in
                try await actor.skinBeauty(image: image)
            },
            sky: { image in
                try await actor.sky(image: image)
            },
            categorizeClothes: { image in
                try await actor.categorizeClothes(image: image)
            },
            tryOn: { modelImage, clothImage in
                try await actor.tryOn(modelImage: modelImage, clothImage: clothImage)
            },
            webpageLeagues: {
                try await actor.webpageLeagues()
            },
            webpageCompetitions: { query, limit, offset in
                try await actor.webpageCompetitions(q: query, limit: limit, offset: offset)
            },
            webpageTeams: { query, limit, offset, competitionID in
                try await actor.webpageTeams(
                    q: query,
                    limit: limit,
                    offset: offset,
                    competitionID: competitionID
                )
            },
            webpage: { url in
                try await actor.webpage(url: url)
            },
            webpageDiscovers: {
                try await actor.webpageDiscovers()
            },
            webpageCompetition: { id in
                try await actor.webpageCompetition(id: id)
            },
            webpageTeam: { id in
                try await actor.webpageTeam(id: id)
            },
            webpageVideos: { videoType, competitionID, teamID, query, page, pageSize in
                try await actor.webpageVideos(
                    videoType: videoType,
                    competitionID: competitionID,
                    teamID: teamID,
                    q: query,
                    page: page,
                    pageSize: pageSize
                )
            },
            webpageNews: { limit, offset, query, competitionID, teamID in
                try await actor.webpageNews(
                    limit: limit,
                    offset: offset,
                    q: query,
                    competitionID: competitionID,
                    teamID: teamID
                )
            },
            upcoming: {
                try await actor.upcoming()
            },
            scoresByDate: { date in
                try await actor.scoresByDate(date: date)
            },
            matchDetail: { id in
                try await actor.matchDetail(id: id)
            },
            competitionDetail: { id in
                try await actor.competitionDetail(id: id)
            },
            teamDetail: { id in
                try await actor.teamDetail(id: id)
            },
            liveMatchEvents: {
                await actor.liveMatchEvents()
            },
            submitSurvey: { questions, answers in
                try await actor.submitSurvey(questions: questions, answers: answers)
            },
            setNotification: { enabled, firebaseToken, firebaseUID, liveActivityToken, liveActivityAttributesType in
                try await actor.setNotification(
                    enabled: enabled,
                    firebaseToken: firebaseToken,
                    firebaseUID: firebaseUID,
                    liveActivityToken: liveActivityToken,
                    liveActivityAttributesType: liveActivityAttributesType
                )
            },
            getNotificationSettings: {
                try await actor.getNotificationSettings()
            },
            notificationSubscribe: { entity, id, enabled in
                try await actor.notificationSubscribe(entity: entity, id: id, enabled: enabled)
            },
            reportLiveActivityToken: { entity, entityID, laToken in
                try await actor.reportLiveActivityToken(
                    entity: entity,
                    entityID: entityID,
                    laToken: laToken
                )
            }
        )
    }()
}
