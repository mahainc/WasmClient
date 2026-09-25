# The team-identity triple is duplicated six times in `LiveScore`

`teamID` / `teamName` / `teamLogoURL` — one idea, "which team is this" — is
declared verbatim in six structs in `Sources/WasmClient/Models/LiveScore.swift`:

| Struct | Line | What it adds on top of the triple |
|---|---|---|
| `MatchSummarySide` | 50 | `score` |
| `TeamLineup` | 286 | `formation`, `startXi`, `substitutes`, `coachName` |
| `TeamH2H` | 447 | `form`, `recentCoach` |
| `Topscorer` | 550 | `position`, `total`, `player` |
| `Standing` | 604 | `position`, `points`, `goalsDiff`, `groupName`, `form`, `all` |
| `MatchUpdateSide` | 819 | `oldScore`, `newScore` |

Every one of the six carries a different payload, so the *difference* is real —
what repeats is only the identity.

## Why it is written down instead of fixed

`clean-code` raised it as **G5** while `MatchSummarySide` was being added (the
sixth copy). Five copies already existed and none of them was touched by that
change, so adding the sixth followed the file's own convention rather than
breaking it — which is CC7/G24, and is the reason the finding was excepted
rather than fixed there.

The fix is not local. Collapsing the triple into a `TeamRef { id, name, logoURL }`
reshapes all six structs and every reader of those fields:

```
$ grep -rn '\.teamID\|\.teamName\|\.teamLogoURL\|teamID:\|teamName:\|teamLogoURL:' \
    Sources/ --include='*.swift' | grep -v Protos | wc -l
93
```

Plus four call sites in the `sport-now` app, which pins this package exactly.
That is a package-wide refactor and a major version of its own, not a rider on
an unrelated change.

## What doing it would look like

```swift
public struct TeamRef: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let logoURL: String
}

public struct MatchSummarySide: Sendable, Equatable, Identifiable {
    public let team: TeamRef
    public let score: Int
    public var id: String { team.id }
}
```

Note the field names would move from `teamID`/`teamName`/`teamLogoURL` to
`team.id`/`team.name`/`team.logoURL` — the `team` prefix stops earning its keep
once the type says it. That rename is most of the 93 sites.

Worth deciding together with it: whether the mappers in
`Sources/WasmClientLive/Sessions/LiveScore.swift` should gain a single
`mapTeamRef(_ t: LivescoreTeam)`, which six call sites there would share.
