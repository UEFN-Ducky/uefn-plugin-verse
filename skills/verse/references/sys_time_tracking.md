---
description: "Session & playtime tracking — persistable login timestamps, epoch-seconds vs simulation clock, join/leave session lifecycle, offline-elapsed calculation, and formatted duration display"
metadata:
  order: 32
  label: "Game systems — session & playtime tracking"
  default_enabled: false
  load_condition: "Tracking playtime, first/last login, session duration, offline elapsed time, or real-world timestamps across sessions"
---

## Session & playtime tracking

Track when a player first joined, when they last left, and how long they have
played. Names below are generic — adapt them to your game. **Wiring follows the
same player-manager bus as every other system** (`sys_architecture`,
`sys_player_data`). Persistence uses the shared table (`persistence`).

### Two clocks — pick the right one

| Clock | Survives sessions? | Use for |
|-------|--------------------|---------|
| Simulation elapsed time | No — resets every session | In-session deltas (timers, tick accrual) |
| Epoch seconds (real-world) | Yes — wall-clock time | Login timestamps, offline elapsed, total playtime |

Search the digest for the epoch-seconds API. Store that float in persistable
fields — never store simulation elapsed time if you need it after leave/rejoin.

### Layers (same five-part shape)

```
persistable player_time_data          → nested in shared game_player_table
time_save_service              → rebuild-and-store helpers
player_time_tracker (class<unique>)    → field on game_player_services
player_time_tracker_device             → @editable PlayerManager; Subscribe connected + removed
```

### Persistable time record

```verse
player_time_data := class<final><persistable>:
    FirstLoginTime <public> : float = 0.0    # 0.0 = never set (new player)
    LastLoginTime  <public> : float = 0.0
    TotalPlayTime  <public> : float = 0.0
```

Update helpers must copy **every** other nested field on the shared table (see
`persistence` carry-all rule). Persistence writes use the standard guard:

```verse
if:
    RealAgent := Agent?
    Player := player[RealAgent]
    Player.IsActive[]
    OldTable := PlayerStatsMap[Player]
then:
    NewTimeData := player_time_data{ … }
    if (set PlayerStatsMap[Player] = UpdatePlayerTimeData(OldTable, NewTimeData)):
        {}
```

### Per-player manager

```verse
player_time_tracker := class<unique>():
    var MyAgent <public> : ?agent = false
    var SessionActive : logic = false
    var SessionStartTime : float = 0.0
    var TimeSaveService <public> : time_save_service = time_save_service{}
```

Lives as a field on `game_player_services`. Session flags are in-memory only;
login / totals go through the persistence manager.

### Join — InitializeTimeTracking (after bus fires)

Called from the device's `OnPlayerJoined`, which only runs **after** the manager
has `Init`'d the player (persist row exists):

1. `set MyAgent = option{Agent}`
2. Read the persistable table (`player[Agent]`, `IsActive[]`, `PlayerStatsMap`)
3. If `FirstLoginTime = 0.0` → new player: set first **and** last login to now
4. If returning → **do not** overwrite `LastLoginTime` yet (offline math needs it)
5. `StartSession(Now)` — set `SessionActive`, `SessionStartTime`

```verse
InitializeTimeTracking<public>(Agent : agent) : void =
    set MyAgent = option{Agent}
    if:
        Player := player[Agent]
        Player.IsActive[]
        PlayerStats := PlayerStatsMap[Player]
    then:
        Now := GetSecondsSinceEpoch()          # digest: confirm exact name
        if (PlayerStats.PlayerTimeData.FirstLoginTime = 0.0):
            TimeSaveService.SetFirstLoginTime(MyAgent, Now)
            TimeSaveService.SetLastLoginTime(MyAgent, Now)
        # else: leave LastLoginTime alone until offline math finishes
        StartSession(Now)
```

### Offline elapsed (before stamping new last-login)

Run **before** writing the new `LastLoginTime`. Full ordered recipe (TimeTracker
→ calc → collect modal → EconomyManager → stamp): see **`sys_generators`**
offline section. Collect UI: **`sys_ui_menus`**.

```verse
ElapsedRaw := Now - TimeTracker.GetLastLoginTime()
Elapsed := Min(Max(0.0, ElapsedRaw), MaxOfflineSeconds)
# …grant rewards from Elapsed (or show collect popup)…
TimeSaveService.SetLastLoginTime(MyAgent, Now)
```

### Leave — EndSession (from removed bus)

```verse
EndSession<public>() : void =
    if (SessionActive? and MyAgent?):
        Now := GetSecondsSinceEpoch()
        SessionDuration := Now - SessionStartTime
        TimeSaveService.AddTotalPlayTime(MyAgent, SessionDuration)
        TimeSaveService.SetLastLoginTime(MyAgent, Now)
        set SessionActive = false
```

Manager fires remove subscribers **before** dropping the map entry — so
`EndSession` still has a valid `game_player`.

### Placed device wiring (exact pattern)

Same as wallet / level: concrete `@editable` manager ref; pass handlers by name
into Subscribe; handler signature matches the bus type.

```verse
player_time_tracker_device := class(creative_device):
    @editable PlayerManager : player_manager = player_manager{}

    OnBegin<override>()<suspends> : void =
        PlayerManager.SubscribePlayerConnected(OnPlayerJoined)
        PlayerManager.SubscribePlayerRemoved(OnPlayerLeft)

    OnPlayerJoined(GamePlayer : game_player) : void =
        GamePlayer.Services.TimeTracker.InitializeTimeTracking(GamePlayer.GetAgent())

    OnPlayerLeft(GamePlayer : game_player) : void =
        GamePlayer.Services.TimeTracker.EndSession()
```

Also walk already-joined players in `OnBegin` if other systems do (Subscribe alone
can miss a race) — see `sys_architecture` `InitializeAllAlreadyJoined`.

Gameplay / offline payout never talks to the persist map directly from random
devices — look up `GetGamePlayer`, then call `Services.TimeTracker`.

### Formatted duration

Keep raw seconds in persistence; format only for HUD. Expose raw and formatted
getters on the manager. Current session = `Now - SessionStartTime` while
active, else `0.0`.

### Gotchas

- **Simulation clock ≠ offline clock.**
- **Last-login ordering** — overwrite only after offline math.
- **`FirstLoginTime = 0.0` sentinel** — never treat a real epoch as zero.
- **Bus after Init** — time init assumes the weak_map row already exists.
- **Carry-all helpers** — omitting time fields in another system's `Update…`
  wipes playtime on the next wallet/XP save (`persistence`).
- Confirm epoch API with `search_verse_digest`.
