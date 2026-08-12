# AIArt provider selection & failover

Read this only when touching `Sessions/AIArt.swift`'s `generateAIArt` / provider
resolution, or when investigating a `missing runware data entry` (or any
unprovisioned-provider) generation failure.

## Contract

Callers just want a result — they must not need to know which provider serves it.
`generateAIArt` upholds that even when the engine would otherwise pick a broken provider.

## The problem it guards

`WasmDelegate.resolveAction(preferredProvider: nil)` returns `actions[0]` — the first
*registered* provider, with **zero capability check**. FlowKit's own `ProviderStrategy`
(default `.roundRobin`, persisted Rust-side) is likewise **not capability-aware**. So when
a `provider_id` is empty and an unprovisioned provider (e.g. a `runware` entry with **no
ListModels/catalogue row**) sits at the front of the list, it gets dispatched and the guest
throws `Code=500 "missing runware data entry"`.

This reproduced on app905 **devices** (not simulators — sims had a warm/correct wasm cache
and a different registration order). Cross-reference: app905's
`.claude/skills/modcar-content-manifest-wiring/runware-error-root-cause.md`.

## The fix (shipped in tag `3.0.3`, commit `ee9f449`)

`generateAIArt` does what FlowKit does not offer as a single call:

1. `resolveAllActions` — get every candidate provider for the action.
2. Rank best-first (pure, unit-tested `WasmActor.providerFailoverOrder(...)`): explicit
   `provider_id` → providers backed by a ListModels catalogue row for the mode → the rest.
3. Run in order, **failing over provider-by-provider** on error.

Single result, and cheap: the next provider is only tried when the previous one actually
throws. `AIArtProviderFailoverTests` covers the ranking core (FlowKit-free, runs without
the engine).

## Why not just "let FlowKit handle it"

FlowKit ≥ `1.2.63-…-ffi` exposes method-name dispatch (`run(method:providerId:args:)`,
`action(for:strategy:)`, `runMerged(…strategy:)`) and the flow-kit example app uses it —
but `ProviderStrategy` has **no `.capable`/`has-model` case**. The only native strategy that
tolerates a broken provider is `.merge`, which runs **all** providers concurrently
("failures are silently skipped") — unacceptable for a paid, single-result image generation
(N× cost, N results to pick from). So the Swift-side capability filter is the correct layer
*today*.

## When this can be deleted

Retire the rank+failover and collapse to a plain `run(method:…)` once EITHER holds:

1. **flow-kit** adds a capability-aware `ProviderStrategy` (e.g. `.firstCapable`, filtering
   by ListModels) so the engine self-selects a provisioned provider, OR
2. **backend/guest provisioning** guarantees an unprovisioned provider is never *registered*
   for an action — then even `.roundRobin` is safe.

Both are **out of scope for this package** (flow-kit Rust / backend). Until one lands,
`generateAIArt` stays as-is.

## Scope

This is the *only* session with catalogue-rank + failover. `Suggest` walks all providers in
registration order (no catalogue rank); every other session takes `actions[0]` or
round-robin — acceptable because they don't hit the provisioned-vs-registered mismatch AIArt
does.
