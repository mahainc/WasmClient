@preconcurrency import FlowKit
import Foundation
import WasmClient

#if canImport(Darwin)
    import Darwin
#endif

// MARK: - Delegate

internal final class WasmDelegate: NSObject, WasmInstanceDelegate, @unchecked Sendable {
    private(set) var engine: TaskWasmProtocol?
    private(set) var isStarted = false
    private var isStarting = false
    private var actionCache: [String: [WaTAction]] = [:]
    private var actionsLoadTask: Task<Void, Error>?
    private let actionsLoadLock = NSLock()
    private var providerRotationIndex: [String: Int] = [:]
    private var logger: (@Sendable (String) -> Void)?
    private var stateContinuations: [UUID: AsyncStream<WasmClient.EngineState>.Continuation] = [:]
    private var lastState: WasmClient.EngineState = .stopped
    private let stateLock = NSLock()
    private var startContinuation: CheckedContinuation<Void, Swift.Error>?
    private var startTimeoutTask: Task<Void, Never>?
    private var engineDidReachRunning = false
    private let runningLock = NSLock()
    private var _expectedVersionProvider: (@Sendable () async throws -> String?)?
    private let providerLock = NSLock()

    func setExpectedVersionProvider(_ provider: (@Sendable () async throws -> String?)?) {
        providerLock.withLock { _expectedVersionProvider = provider }
    }

    private func currentExpectedVersionProvider() -> (@Sendable () async throws -> String?)? {
        providerLock.withLock { _expectedVersionProvider }
    }

    private var initializedProviders: Set<String> = []
    private let initLock = NSLock()

    func markProviderInitialized(_ providerID: String) {
        initLock.withLock { _ = initializedProviders.insert(providerID) }
    }

    func isProviderInitialized(_ providerID: String) -> Bool {
        initLock.withLock { initializedProviders.contains(providerID) }
    }

    private var _userName: String = ""
    private let userNameLock = NSLock()

    func setUserName(_ name: String) {
        userNameLock.withLock { _userName = name }
    }

    func userName() -> String {
        userNameLock.withLock { _userName }
    }

    private func markRunning() {
        runningLock.withLock { engineDidReachRunning = true }
    }

    private func isRunning() -> Bool {
        runningLock.withLock { engineDidReachRunning }
    }

    private func clearRunning() {
        runningLock.withLock { engineDidReachRunning = false }
    }

    func addStateContinuation(
        id: UUID,
        _ continuation: AsyncStream<WasmClient.EngineState>.Continuation
    ) {
        let replay: WasmClient.EngineState = stateLock.withLock {
            stateContinuations[id] = continuation
            return lastState
        }
        continuation.yield(replay)
    }

    func removeStateContinuation(id: UUID) {
        stateLock.withLock {
            _ = stateContinuations.removeValue(forKey: id)
        }
    }

    private func yieldState(_ state: WasmClient.EngineState) {
        let snapshot: [AsyncStream<WasmClient.EngineState>.Continuation] = stateLock.withLock {
            lastState = state
            return Array(stateContinuations.values)
        }
        for continuation in snapshot {
            continuation.yield(state)
        }
    }

    // MARK: - WasmInstanceDelegate
    // Matches flow-kit-example's WasmEngine.stateChanged.

    func stateChanged(state: EngineState) {
        logger?("Engine state: \(state)")
        let mapped: WasmClient.EngineState
        switch state {
            case .running:
                mapped = .running
                markRunning()
                let (continuation, timeout) = runningLock.withLock {
                    let continuation = startContinuation
                    startContinuation = nil
                    let timeoutTask = startTimeoutTask
                    startTimeoutTask = nil
                    return (continuation, timeoutTask)
                }
                timeout?.cancel()
                continuation?.resume()
            case .reload:
                return
            case .updating(let progress):
                mapped = .updating(progress)
            default:
                logger?("Unmapped FlowKit state \(state) — defaulting to .stopped")
                mapped = .stopped
        }
        yieldState(mapped)
    }

    // MARK: - Engine Lifecycle

    func ensureStarted(logger: @escaping @Sendable (String) -> Void) async throws -> TaskWasmProtocol {
        #if canImport(Darwin)
            signal(SIGPIPE, SIG_IGN)
        #endif

        // Fast path — already started.
        if let engine, isStarted { return engine }

        // Another call is already starting — poll-wait for it to finish.
        if isStarting {
            logger("Engine start in progress — waiting...")
            while isStarting {
                try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            }
            if let engine, isStarted { return engine }
            throw WasmClient.Error.engineInitFailed
        }

        isStarting = true
        self.logger = logger

        do {
            let cachedID = AsyncifyWasmCompat.currentVersionID

            // Ask the host for the expected wasm version. nil / throw = no-op policy.
            var expectedID: String?
            if let provider = currentExpectedVersionProvider() {
                do {
                    expectedID = try await provider()
                } catch {
                    logger("Expected-version provider threw \(error.localizedDescription) — skipping update check")
                }
            }

            switch (cachedID, expectedID) {
                case (nil, _):
                    logger("No cached wasm version — resetting downloads to force fresh download")
                    AsyncifyWasmCompat.resetDownloads(wasmDir: nil, provider: nil)
                case let (.some(cached), .some(expected)) where cached != expected:
                    logger("Wasm version mismatch (cached=\(cached), expected=\(expected)) — resetting downloads")
                    AsyncifyWasmCompat.resetDownloads(wasmDir: nil, provider: nil)
                case let (.some(cached), _):
                    logger("Using cached wasm version: \(cached)")
            }

            // Direct async calls — exactly like flow-kit-example's WasmEngine.load()
            logger("Building engine via FlowKit.default()...")
            yieldState(.starting)
            var instance = try await FlowKit.default()
            instance.premium = false
            instance.delegate = self

            logger("Starting engine (delegate set)...")
            try await instance.start()
            logger("Engine start() returned, waiting for .running state...")

            // Wait for the delegate's .running callback via CheckedContinuation
            // instead of polling. Timeout after 30s.
            if !isRunning() {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
                    let alreadyRunning = runningLock.withLock {
                        engineDidReachRunning
                    }
                    if alreadyRunning {
                        continuation.resume()
                        return
                    }
                    // L4: [weak self] so a cancelled start doesn't pin the delegate for 30s.
                    let timeoutTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 30_000_000_000)
                        guard let self else { return }
                        let pending = self.runningLock.withLock { () -> CheckedContinuation<Void, Swift.Error>? in
                            let continuation = self.startContinuation
                            self.startContinuation = nil
                            return continuation
                        }
                        pending?.resume(throwing: WasmClient.Error.engineInitFailed)
                    }
                    // L2: set both fields under one lock so they clear together atomically.
                    runningLock.withLock {
                        self.startContinuation = continuation
                        self.startTimeoutTask = timeoutTask
                    }
                }
            }
            logger("Engine reached .running via delegate callback")

            self.engine = instance
            self.isStarted = true
            self.isStarting = false
            yieldState(.running)

            // Eagerly discover actions as part of start flow
            try? await ensureActionsLoaded(logger: logger)

            logger("Engine ready")
            return instance
        } catch {
            self.isStarting = false
            yieldState(.failed(error.localizedDescription))
            logger("Engine start failed: \(error.localizedDescription)")
            throw error
        }
    }

    func ensureActionsLoaded(logger: @escaping @Sendable (String) -> Void) async throws {
        if !actionCache.isEmpty { return }

        let task: Task<Void, Error> = actionsLoadLock.withLock {
            if let existing = actionsLoadTask { return existing }
            let new = Task<Void, Error> { [weak self] in
                guard let self else { return }
                try await self.performActionsLoad(logger: logger)
            }
            actionsLoadTask = new
            return new
        }

        defer { actionsLoadLock.withLock { actionsLoadTask = nil } }
        try await task.value
    }

    private func performActionsLoad(logger: @escaping @Sendable (String) -> Void) async throws {
        guard let engine else { throw WasmClient.Error.engineNotStarted }

        logger("Discovering action providers...")
        var cache: [String: [WaTAction]] = [:]
        for attempt in 1...60 {  // 60 × 500ms = 30s
            do {
                let all = try await engine.actions()
                if !all.actions.isEmpty {
                    for action in all.actions {
                        cache[action.id, default: []].append(action)
                    }
                    logger("Actions available after \(attempt) poll(s)")
                    break
                }
            } catch { logger("Poll \(attempt)/60: \(error)") }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        if !cache.isEmpty {
            actionCache = cache
            for (id, actions) in cache {
                logger("  \(id): \(actions.map(\.provider).joined(separator: ", "))")
            }
            logger("Cached \(cache.count) action types")
        } else {
            logger("warning: no action providers registered after 30s")
        }
    }

    func refreshActions(logger: @escaping @Sendable (String) -> Void) async throws {
        guard let engine else { throw WasmClient.Error.engineNotStarted }
        var previousCount = 0
        for attempt in 1...15 {  // 15 × 2s = 30s max
            let allActions = try await engine.actions()
            let currentCount = allActions.actions.count
            var cache: [String: [WaTAction]] = [:]
            for action in allActions.actions {
                cache[action.id, default: []].append(action)
            }
            if !cache.isEmpty {
                actionCache = cache
            }
            logger("Refresh poll \(attempt): \(cache.count) types, \(currentCount) providers")
            // Stable when count matches previous poll and is non-zero
            if currentCount > 0 && currentCount == previousCount {
                logger("Provider count stabilized at \(currentCount)")
                break
            }
            previousCount = currentCount
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    private func ensureActionAvailable(
        actionID: String,
        logger: @escaping @Sendable (String) -> Void
    ) async throws {
        if actionCache[actionID]?.isEmpty == false { return }
        // First call on an empty cache — run the normal discovery poll.
        if actionCache.isEmpty {
            try await ensureActionsLoaded(logger: logger)
            if actionCache[actionID]?.isEmpty == false { return }
        }
        for attempt in 1...10 {  // 10 × 500ms = up to 5s
            guard let engine else { throw WasmClient.Error.engineNotStarted }
            let all = try await engine.actions()
            if !all.actions.isEmpty {
                var cache: [String: [WaTAction]] = [:]
                for action in all.actions {
                    cache[action.id, default: []].append(action)
                }
                actionCache = cache
                if cache[actionID]?.isEmpty == false {
                    logger("action '\(actionID)' available after refresh poll \(attempt)")
                    return
                }
            }
            logger("action '\(actionID)' missing — refresh poll \(attempt)/10")
            try await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    func resolveAction(
        actionID: String,
        preferredProvider: String? = nil,
        logger: @escaping @Sendable (String) -> Void
    ) async throws -> WaTAction {
        try await ensureActionAvailable(actionID: actionID, logger: logger)
        guard let actions = actionCache[actionID], !actions.isEmpty else {
            throw WasmClient.Error.noProviderFound(action: actionID)
        }
        if let preferred = preferredProvider,
            let match = actions.first(where: { $0.provider == preferred })
        {
            return match
        }
        return actions[0]
    }

    func resolveAllActions(
        actionID: String,
        logger: @escaping @Sendable (String) -> Void
    ) async throws -> [WaTAction] {
        try await ensureActionAvailable(actionID: actionID, logger: logger)
        guard let actions = actionCache[actionID], !actions.isEmpty else {
            throw WasmClient.Error.noProviderFound(action: actionID)
        }
        return actions
    }

    func resolveNextAction(
        actionID: String,
        logger: @escaping @Sendable (String) -> Void
    ) async throws -> WaTAction {
        try await ensureActionAvailable(actionID: actionID, logger: logger)
        guard let actions = actionCache[actionID], !actions.isEmpty else {
            throw WasmClient.Error.noProviderFound(action: actionID)
        }
        let current = providerRotationIndex[actionID] ?? 0
        let index = current % actions.count
        let picked = actions[index]
        providerRotationIndex[actionID] = (index + 1) % actions.count
        logger("\(actionID) → provider: \(picked.provider) (\(index + 1)/\(actions.count))")
        return picked
    }

    func resetEngine() {
        engine = nil
        isStarted = false
        isStarting = false
        clearRunning()
        actionCache = [:]
        providerRotationIndex = [:]
        initLock.withLock { initializedProviders.removeAll() }
        let (pending, timeout) = runningLock.withLock {
            let continuation = startContinuation
            startContinuation = nil
            let timeoutTask = startTimeoutTask
            startTimeoutTask = nil
            return (continuation, timeoutTask)
        }
        timeout?.cancel()
        pending?.resume(throwing: CancellationError())
        yieldState(.stopped)
    }

    func allActions() -> [WaTAction] {
        actionCache.values.flatMap { $0 }
    }
}

// MARK: - Actor

actor WasmActor {
    nonisolated let delegate = WasmDelegate()
    let logger: @Sendable (String) -> Void
    var isResumingPendingTasks: Bool = false

    var streamGate: Task<Void, Never>?

    // MARK: - Init

    init(
        logger: @escaping @Sendable (String) -> Void = { message in
            #if DEBUG
                print("[WasmClient]: \(message)")
            #endif
        }
    ) {
        self.logger = logger
    }

    // MARK: - Engine Lifecycle

    func readyEngine() async throws -> TaskWasmProtocol {
        try await delegate.ensureStarted(logger: logger)
    }

    func funnelEngine() async throws -> WasmClient.EngineHandle {
        WasmClient.EngineHandle(try await readyEngine())
    }

    func start() async throws {
        _ = try await readyEngine()
    }

    func observeEngineState() -> AsyncStream<WasmClient.EngineState> {
        let id = UUID()
        // L6: EngineState is latest-wins — a slow consumer only needs the newest value.
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            delegate.addStateContinuation(id: id, continuation)
            continuation.onTermination = { [weak delegate] _ in
                delegate?.removeStateContinuation(id: id)
            }
        }
    }

    func reset() async throws {
        delegate.resetEngine()
    }

    func restart() async throws {
        delegate.resetEngine()
        _ = try await readyEngine()
    }

    func engineVersion() -> String? {
        AsyncifyWasmCompat.currentVersionID
    }

    func resetDownloads() {
        AsyncifyWasmCompat.resetDownloads(wasmDir: nil, provider: nil)
    }

    nonisolated func setExpectedVersionProvider(_ provider: (@Sendable () async throws -> String?)?) {
        delegate.setExpectedVersionProvider(provider)
    }

    nonisolated func setUserName(_ name: String) {
        delegate.setUserName(name)
    }

    func warmUp() async {
        do {
            _ = try await readyEngine()
        } catch {
            logger("Warm-up failed (non-fatal): \(error.localizedDescription)")
        }
    }

    func refreshActions() async throws {
        try await delegate.refreshActions(logger: logger)
    }

    func availableActions() async throws -> [WasmClient.ActionInfo] {
        if !delegate.isStarted {
            _ = try await readyEngine()
        }
        if delegate.allActions().isEmpty {
            try await delegate.ensureActionsLoaded(logger: logger)
        }
        return delegate.allActions().map { Self.mapActionInfo($0) }
    }

    static func mapActionInfo(_ action: WaTAction) -> WasmClient.ActionInfo {
        let providerName = action.metadata.fields["provider_name"]?.stringValue ?? ""
        let sortedKeys = action.sortedArgs
        let args: [WasmClient.ActionArg] = action.args.map { key, arg in
            let name = arg.name.isEmpty ? key : arg.name
            let isRequired = arg.hasValidator && arg.validator.required
            let kind: WasmClient.ActionArg.ArgKind
            if arg.hasValidator, case .media = arg.validator.data {
                kind = .media
            } else if arg.hasValidator, case .string(let stringValidator) = arg.validator.data {
                if stringValidator.hasRegex, let values = Self.regexValues(stringValidator.regex), !values.isEmpty {
                    kind = .picker(
                        values: values,
                        defaultValue: stringValidator.hasDefault ? stringValidator.default : (values.first ?? "")
                    )
                } else {
                    kind = .text(defaultValue: stringValidator.hasDefault ? stringValidator.default : "")
                }
            } else {
                kind = .text(defaultValue: "")
            }
            return WasmClient.ActionArg(key: key, name: name, isRequired: isRequired, kind: kind)
        }
        return WasmClient.ActionInfo(
            actionID: action.id,
            provider: action.provider,
            name: action.name,
            providerName: providerName,
            args: args,
            sortedArgKeys: sortedKeys
        )
    }

    private static func regexValues(_ pattern: String) -> [String]? {
        guard pattern.hasPrefix("^("), pattern.hasSuffix(")$") else { return nil }
        let inner = String(pattern.dropFirst(2).dropLast(2))
        let values = inner.components(separatedBy: "|")
        return values.isEmpty ? nil : values
    }
}
