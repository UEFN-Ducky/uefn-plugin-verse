---
description: "Teams — the team collection API, reading/assigning a player's team, per-team counts and iteration, and role/team-based game logic"
metadata:
  order: 28
  label: "Game systems — teams & roles"
  default_enabled: false
  load_condition: "Building team-based or role-based logic — assigning teams, counting per team, team scoring, or per-team behavior"
---

## Teams & roles

Teams come from the playspace's **team collection**. Confirm exact member names in
the digest (`search_verse_digest("team")`) — the shapes below are the common API.

### The team collection

```verse
TeamCollection := GetPlayspace().GetTeamCollection()   # fort_team_collection
AllTeams := TeamCollection.GetTeams()                  # []team
```

Reads that can fail use `[]` (failure context):

```verse
if (MyTeam := TeamCollection.GetTeam[Agent]):          # this agent's team
    Members := TeamCollection.GetAgents[MyTeam]        # []agent on that team
```

### A player's team number

Map a team to a stable index by finding it in the teams array:

```verse
GetTeamNumber(Agent : agent)<transacts> : int =
    TeamCollection := GetPlayspace().GetTeamCollection()
    if (AgentsTeam := TeamCollection.GetTeam[Agent]):
        for (TeamNumber -> Team : TeamCollection.GetTeams()):
            if (AgentsTeam = Team):
                return TeamNumber
    return -1
```

Compare teams with `=` inside a failure context (`if (AgentsTeam = Team):`).

### Assigning teams

Move a player onto a team (failable — guard it):

```verse
if (Target := TeamCollection.GetTeams()[TeamIndex]):
    if (TeamCollection.AddToTeam[Agent, Target]):
        # assigned
```

For designer-driven role assignment, a `team_selector` / `class_and_team_selector`
device is often simpler — expose it as `@editable` and call its change method.

### Per-team counts & iteration

Snapshot counts by walking players once — handy for a scoreboard or win check:

```verse
CountPerTeam()<transacts> : [team]int =
    TeamCollection := GetPlayspace().GetTeamCollection()
    var Counts : [team]int = map{}
    for (Agent : GetPlayspace().GetPlayers()):
        if (T := TeamCollection.GetTeam[Agent]):
            Current := if (C := Counts[T]) then C else 0
            if (set Counts[T] = Current + 1) {}
    return Counts
```

### Role-based game logic (generic teams/roles)

Snapshot each team/role into its own array at round start, then drive behavior from
those arrays (see `sys_rounds_timers`):

```verse
var TeamA : []agent = array{}
var TeamB : []agent = array{}

AssignRoles(Players : []agent) : void =
    for (Index -> P : Players):
        if (Index < Players.Length / 2):
            set TeamA += array{P};  ConfigureAsTeamA(P)
        else:
            set TeamB += array{P};  ConfigureAsTeamB(P)
```

Give each side a `struct<concrete>` bundle of its devices (`team_a_devices`,
`team_b_devices` — granters, spawn selectors, HUD messages) so one `@editable`
exposes them (see `devices`).

### Team scoring & win conditions

Track team score in a `[team]int` (or `[int]int` keyed by team number) rather than
per player when the objective is team-wide; combine with `sys_scoring` for
individual stats. Check a win by comparing counts/scores after each scoring event
or on a timer tick:

```verse
if (A := Counts[TeamA], B := Counts[TeamB], A = 0):
    EndRound(WinningSide := TeamB)
```

### Gotchas

- Every team read (`GetTeam[]`, `GetAgents[]`, `AddToTeam[]`) is failable — call in
  `if`/`for`.
- Team **count** is fixed by the island settings; don't assume more teams than are
  configured.
- Re-snapshot team arrays each round; players join, leave, and swap.
- Confirm `GetTeamCollection`, `GetTeam`, `GetAgents`, `AddToTeam` signatures in the
  digest — don't guess.
