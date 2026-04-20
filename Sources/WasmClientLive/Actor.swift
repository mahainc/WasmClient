@preconcurrency import FlowKit
import Foundation
import WasmClient

#if canImport(Darwin)
import Darwin
#endif

// MARK: - Delegate

/// Bridges FlowKit's TaskWasmEngine lifecycle to the actor.
/// Implements WasmInstanceDelegate to receive engine state changes —
/// the engine requires a delegate to be set BEFORE start() to fully initialize.
internal final class WasmDelegate: NSObject, WasmInstanceDelegate, @unchecked Sendable {
    private(set) var engine: TaskWasmProtocol?
    private(set) var isStarted = false
    /// True while ensureStarted() is actively building the engine.
    private var isStarting = false
    /// Cached actions keyed by action ID — populated after engine stabilises.
    private var actionCache: [String: [WaTAction]] = [:]
    /// Per-action round-robin counter for `resolveNextAction`.
    private var providerRotationIndex: [String: Int] = [:]
    private var logger: (@Sendable (String) -> Void)?
    /// Continuations for all active engine state observers.
    private var stateContinuations: [UUID: AsyncStream<WasmClient.EngineState>.Continuation] = [:]
    /// Continuation waiting for the engine to reach .running state.
    private var startContinuation: CheckedContinuation<Void, Swift.Error>?
    /// Timeout task for start continuation — cancelled on success.
    private var startTimeoutTask: Task<Void, Never>?
    /// Set to true when stateChanged(.running) fires. Thread-safe via lock.
    private var engineDidReachRunning = false
    private let runningLock = NSLock()
    /// Host-supplied closure returning the wasm version the app expects.
    /// Consulted inside `ensureStarted` before `TaskWasm.default()`; a mismatch
    /// with `AsyncifyWasm.currentVersionID` triggers `AsyncifyWasm.resetDownloads()`.
    /// Persists across `resetEngine()` — registered once at app launch.
    private var expectedVersionProvider: (@Sendable () async throws -> String?)?

    func setExpectedVersionProvider(_ provider: (@Sendable () async throws -> String?)?) {
        expectedVersionProvider = provider
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

    func addStateContinuation(id: UUID, _ continuation: AsyncStream<WasmClient.EngineState>.Continuation) {
        stateContinuations[id] = continuation
    }

    func removeStateContinuation(id: UUID) {
        stateContinuations.removeValue(forKey: id)
    }

    private func yieldState(_ state: WasmClient.EngineState) {
        for continuation in stateContinuations.values {
            continuation.yield(state)
        }
    }

    // MARK: - WasmInstanceDelegate
    // Matches flow-kit-example's WasmEngine.stateChanged.

    func stateChanged(state: AsyncWasm.EngineState) {
        logger?("Engine state: \(state)")
        let mapped: WasmClient.EngineState
        switch state {
        case .running:
            mapped = .running
            markRunning()
            let (continuation, timeout) = runningLock.withLock {
                let c = startContinuation
                startContinuation = nil
                let t = startTimeoutTask
                startTimeoutTask = nil
                return (c, t)
            }
            timeout?.cancel()
            continuation?.resume()
        case .reload:
            mapped = .starting
        default:
            mapped = .stopped
        }
        yieldState(mapped)
    }

    // MARK: - Engine Lifecycle

    /// Build and start the engine. Uses CheckedContinuation to wait for the
    /// delegate's `.running` callback instead of polling. Eagerly discovers
    /// action providers as part of the start flow.
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
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            if let engine, isStarted { return engine }
            throw WasmClient.Error.engineInitFailed
        }

        isStarting = true
        self.logger = logger

        do {
            Self.installWasmBinaryIfNeeded(logger: logger)

            let cachedID = AsyncifyWasm.currentVersionID

            // Ask the host for the expected wasm version. nil / throw = no-op policy.
            var expectedID: String? = nil
            if let provider = expectedVersionProvider {
                do {
                    expectedID = try await provider()
                } catch {
                    logger("Expected-version provider threw \(error.localizedDescription) — skipping update check")
                }
            }

            switch (cachedID, expectedID) {
            case (nil, _):
                logger("No cached wasm version — resetting downloads to force fresh download")
                AsyncifyWasm.resetDownloads()
            case let (.some(cached), .some(expected)) where cached != expected:
                logger("Wasm version mismatch (cached=\(cached), expected=\(expected)) — resetting downloads")
                AsyncifyWasm.resetDownloads()
            case let (.some(cached), _):
                logger("Using cached wasm version: \(cached)")
            }

            // Direct async calls — exactly like flow-kit-example's WasmEngine.load()
            logger("Building engine via TaskWasm.default()...")
            yieldState(.starting)
            var instance = try await TaskWasm.default()
            instance.premium = true
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
                    runningLock.withLock {
                        self.startContinuation = continuation
                    }

                    self.startTimeoutTask = Task {
                        try? await Task.sleep(nanoseconds: 30_000_000_000)
                        let pending = self.runningLock.withLock { () -> CheckedContinuation<Void, Swift.Error>? in
                            let c = self.startContinuation
                            self.startContinuation = nil
                            return c
                        }
                        pending?.resume(throwing: WasmClient.Error.engineInitFailed)
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

            return instance
        } catch {
            self.isStarting = false
            yieldState(.failed(error.localizedDescription))
            logger("Engine start failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Poll the engine for action providers. Called lazily on first
    /// resolveAction() or explicitly via refreshActions().
    func ensureActionsLoaded(logger: @escaping @Sendable (String) -> Void) async throws {
        guard actionCache.isEmpty else { return }
        guard let engine else { throw WasmClient.Error.engineNotStarted }

        logger("Discovering action providers...")
        var cache: [String: [WaTAction]] = [:]
        for attempt in 1...60 { // 60 × 500ms = 30s
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

    /// Re-poll the engine for available actions. Waits for the provider count
    /// to stabilize (same count on two consecutive polls) to catch late-registering
    /// providers like Banana/Replicate/FalAI/Runware.
    func refreshActions(logger: @escaping @Sendable (String) -> Void) async throws {
        guard let engine else { throw WasmClient.Error.engineNotStarted }
        var previousCount = 0
        for attempt in 1...15 { // 15 × 2s = 30s max
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

    /// Copy the bundled raw `base.wasm` from WasmClientLive's SPM resource bundle
    /// into the app's Documents directory. FlowKit's `TaskWasm.default()` checks
    /// `Bundle.main` for the wasm binary; consumers that don't manually place it
    /// there can rely on this copy as a fallback if FlowKit also checks Documents.
    ///
    /// This is a best-effort operation — if it fails, the consumer must include
    /// `base.wasm` in their app target's Copy Bundle Resources phase.
    private static func installWasmBinaryIfNeeded(logger: @escaping @Sendable (String) -> Void) {
        // Already in Bundle.main — nothing to do.
        if Bundle.main.url(forResource: "base", withExtension: "wasm") != nil {
            logger("base.wasm found in Bundle.main")
            return
        }

        // Locate bundled copy inside WasmClientLive's SPM resource bundle.
        guard let sourceURL = Bundle.module.url(forResource: "base", withExtension: "wasm") else {
            logger("warning: base.wasm not found in WasmClientLive resources")
            return
        }

        // Copy to Documents — FlowKit may check here for cached/downloaded binaries.
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docs.appending(path: "base.wasm")

        if fm.fileExists(atPath: destURL.path()) { return }

        do {
            try fm.copyItem(at: sourceURL, to: destURL)
            logger("Installed base.wasm to Documents/")
        } catch {
            logger("warning: failed to install base.wasm — \(error.localizedDescription)")
        }
    }

    /// Resolve an action — lazily discovers providers on first call.
    /// When `preferredProvider` is given, selects the action from that provider
    /// (matching flow-kit-example's pattern of using the same provider across
    /// scan/describe/visualSearch/shopping). Falls back to first available.
    func resolveAction(
        actionID: String,
        preferredProvider: String? = nil,
        logger: @escaping @Sendable (String) -> Void
    ) async throws -> WaTAction {
        if actionCache.isEmpty {
            try await ensureActionsLoaded(logger: logger)
        }
        guard let actions = actionCache[actionID], !actions.isEmpty else {
            throw WasmClient.Error.noProviderFound(action: actionID)
        }
        if let preferred = preferredProvider,
           let match = actions.first(where: { $0.provider == preferred }) {
            return match
        }
        return actions[0]
    }

    /// Return all providers registered for a given action ID.
    func resolveAllActions(
        actionID: String,
        logger: @escaping @Sendable (String) -> Void
    ) async throws -> [WaTAction] {
        if actionCache.isEmpty {
            try await ensureActionsLoaded(logger: logger)
        }
        guard let actions = actionCache[actionID], !actions.isEmpty else {
            throw WasmClient.Error.noProviderFound(action: actionID)
        }
        return actions
    }

    /// Resolve the next provider for an action using round-robin rotation.
    /// Mirrors flow-kit-example's `ProviderSettings.selectedAction(for:)` default
    /// `.roundRobin` strategy — each call returns the next provider in the cached
    /// order, cycling back to the first after reaching the end. In-memory state;
    /// not persisted across process launches.
    func resolveNextAction(
        actionID: String,
        logger: @escaping @Sendable (String) -> Void
    ) async throws -> WaTAction {
        if actionCache.isEmpty {
            try await ensureActionsLoaded(logger: logger)
        }
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

    /// Reset the engine — clear all cached state.
    func resetEngine() {
        engine = nil
        isStarted = false
        isStarting = false
        clearRunning()
        actionCache = [:]
        providerRotationIndex = [:]
        let (pending, timeout) = runningLock.withLock {
            let c = startContinuation
            startContinuation = nil
            let t = startTimeoutTask
            startTimeoutTask = nil
            return (c, t)
        }
        timeout?.cancel()
        pending?.resume(throwing: CancellationError())
        yieldState(.stopped)
    }

    /// All cached actions flattened.
    func allActions() -> [WaTAction] {
        actionCache.values.flatMap { $0 }
    }
}

// MARK: - Actor

/// Plain actor that manages WASM engine lifecycle and business logic via the delegate.
/// All methods are serialized by the actor — no concurrent WASM engine access.
actor WasmActor {
    let delegate = WasmDelegate()
    let logger: @Sendable (String) -> Void

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
        let engine = try await delegate.ensureStarted(logger: logger)
        logger("Engine ready")
        return engine
    }

    func start() async throws {
        _ = try await readyEngine()
    }

    func observeEngineState() -> AsyncStream<WasmClient.EngineState> {
        let id = UUID()
        return AsyncStream { continuation in
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
        AsyncifyWasm.currentVersionID
    }

    func resetDownloads() {
        AsyncifyWasm.resetDownloads()
    }

    func setExpectedVersionProvider(_ provider: (@Sendable () async throws -> String?)?) {
        delegate.setExpectedVersionProvider(provider)
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

    /// Map a FlowKit WaTAction to our ActionInfo, extracting arg metadata.
    static func mapActionInfo(_ action: WaTAction) -> WasmClient.ActionInfo {
        let providerName = action.metadata.fields["provider_name"]?.stringValue ?? ""
        let sortedKeys = action.sortedArgs
        let args: [WasmClient.ActionArg] = action.args.map { key, arg in
            let name = arg.name.isEmpty ? key : arg.name
            let isRequired = arg.hasValidator && arg.validator.required
            let kind: WasmClient.ActionArg.ArgKind
            if arg.hasValidator, case .media(_) = arg.validator.data {
                kind = .media
            } else if arg.hasValidator, case .string(let s) = arg.validator.data {
                if s.hasRegex, let values = Self.regexValues(s.regex), !values.isEmpty {
                    kind = .picker(values: values, defaultValue: s.hasDefault ? s.default : (values.first ?? ""))
                } else {
                    kind = .text(defaultValue: s.hasDefault ? s.default : "")
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

    /// Parse regex pattern `^(val1|val2|...)$` into values array.
    private static func regexValues(_ pattern: String) -> [String]? {
        guard pattern.hasPrefix("^("), pattern.hasSuffix(")$") else { return nil }
        let inner = String(pattern.dropFirst(2).dropLast(2))
        let values = inner.components(separatedBy: "|")
        return values.isEmpty ? nil : values
    }
}
