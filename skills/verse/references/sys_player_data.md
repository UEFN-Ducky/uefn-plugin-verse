---
description: "Game player data & the player registry — the [agent]game_player map, join/leave lifecycle, the typed custom event bus (type{_()}), and elimination handling"
metadata:
  order: 21
  label: "Game systems — game player data & events"
  default_enabled: false
  load_condition: "Tracking per-player data, handling join/leave/elimination, or building a custom event/subscribe system"
---

## Game player data & the event bus

A single **player manager** device is the owner of per-player state and the hub
other systems subscribe to. Type names below are generic — adapt to your game.

### The registry map

Players live in an `[agent]game_player` map — agent is the key you get from
every event:

```verse
var AllPlayers <private> : [agent]game_player = map{}

GetAllGamePlayers<public>()<transacts> : [agent]game_player = AllPlayers
GetGamePlayer<public>(Agent : agent)<transacts> : ?game_player =
    if (MyPlayer := AllPlayers[Agent]): option{MyPlayer} else: false
```

### Join lifecycle (three entry points, one handler)

Cover **all** ways a player appears: engine join, spawner, and players already
present when the device starts.

```verse
OnBegin<override>()<suspends> : void =
    GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)          # 1. joins
    for (Spawner : AllPlayerSpawners):
        Spawner.SpawnedEvent.Subscribe(OnPlayerAdded)                  # 2. spawns
    spawn{ AddAllPlayersAfterDelay() }                                 # 3. already in

AddAllPlayersAfterDelay<public>()<suspends> : void =
    Sleep(5.0)
    for (PlayerInfo : Self.GetPlayspace().GetPlayers()):
        OnPlayerAdded(PlayerInfo)

OnPlayerAdded<public>(NewAgent : agent) : void =
    spawn{ OnPlayerAddedLoop(NewAgent) }        # sync handler → spawn async work
```

`OnPlayerAddedLoop` **dedupes** (skip if already in the map), creates the
`game_player`, stores it, `Init`s it, fires the connected event, then subscribes
to that character's elimination event (see below).

**Mandatory order inside the loop:**

1. `if (Existing := AllPlayers[NewAgent])` → skip
2. `NewGamePlayer : game_player = game_player{ MyAgent := NewAgent }`
3. `if (set AllPlayers[NewAgent] = NewGamePlayer):` — map write is failable
4. `NewGamePlayer.Init(NewAgent)` — creates the persist `weak_map` row
5. `for (ConnectEvent : PlayerConnectedToGame): ConnectEvent(NewGamePlayer)`
6. Only then: optional `FortChar.EliminatedEvent().Subscribe(...)`

Never fire the bus before `Init`. Never mutate managers from the manager —
system devices react to the bus.

### How system devices hook the bus (exact)

```verse
# On the system device — NOT on game_player
@editable PlayerManager : player_manager = player_manager{}

OnBegin<override>()<suspends> : void =
    PlayerManager.SubscribePlayerConnected(OnPlayerJoined)
    # catch players already registered (race with manager startup)
    Agents := Self.GetPlayspace().GetPlayers()
    for (Agent : Agents):
        if (CPlayer := PlayerManager.GetGamePlayer(Agent)?):
            OnPlayerJoined(CPlayer)

OnPlayerJoined(GamePlayer : game_player) : void =
    # signature MUST match player_connected_to_game
    GamePlayer.Services.YourManager.SetConfig(…)
    GamePlayer.Services.YourManager.ShowHUD(GamePlayer.MyAgent)
```

Pass the function by name into `SubscribePlayerConnected` — the type is
`type{_(GamePlayer : game_player):void}`. A mismatched parameter list will not
compile. Full backbone: `sys_architecture`.

### Leave lifecycle — rebuild the map without the key

Maps aren't mutated in place to remove a key; build a new map filtering the
leaver, then swap:

```verse
OnPlayerRemoved<private>(OutAgent : agent) : void =
    if (Leaving := AllPlayers[OutAgent]):
        for (RemoveEvent : PlayerRemovedFromGame):
            RemoveEvent(Leaving)                        # notify systems first
        var TempAllPlayers : [agent]game_player = map{}
        for (Key -> Value : AllPlayers, Key <> OutAgent):
            set TempAllPlayers = ConcatenateMaps(TempAllPlayers, map{Key => Value})
        set AllPlayers = TempAllPlayers
```

(A per-session score map drops entries the same way, with `if (set NewMap[A] = …)`.)
**Always drop per-player entries on leave** or maps leak across a session.

> **Session maps only.** This rebuild-without-key pattern is for **session** maps
> (`AllPlayers`, per-session scores). **Never** apply it to the persistence
> `weak_map` (`PlayerStatsMap`) — removing a persist key breaks saves. See
> `persistence`.

### The typed custom event bus

The project rolls its own pub/sub so any number of systems can react to a moment.
Three pieces:

**1. A callback type** — `type{_(params):void}`:

```verse
player_connected_to_game <public> := type{_(GamePlayer : game_player):void}
elimination_event        <public> := type{_(EliminatedPlayer : agent, EliminatingPlayer : ?agent):void}
```

**2. A subscriber array + a `Subscribe` method** on the manager:

```verse
var PlayerConnectedToGame <private> : []player_connected_to_game = array{}
SubscribePlayerConnected<public>(ConnectEvent : player_connected_to_game) : void =
    set PlayerConnectedToGame += array{ConnectEvent}
```

**3. Fire it** by looping the subscribers:

```verse
for (ConnectEvent : PlayerConnectedToGame):
    ConnectEvent(NewGamePlayer)
```

Use this bus whenever more than one system must react (connect, disconnect,
alive, eliminated). A subscriber is just a function with the matching signature:
`OnPlayerJoined(GamePlayer : game_player) : void`.

### Elimination handling

Subscribe per character on join, then translate the engine's
`elimination_result` into your bus event:

```verse
FortChar.EliminatedEvent().Subscribe(OnEliminated)

OnEliminated<private>(Result : elimination_result) : void =
    Eliminated := Result.EliminatedCharacter
    if (EliminatorFC := Result.EliminatingCharacter?, KillerAgent := EliminatorFC.GetAgent[]):
        if (VictimAgent := Eliminated.GetAgent[], not KillerAgent = VictimAgent):
            for (Event : EliminationEvents):
                Event(VictimAgent, option{KillerAgent})     # PvP kill
    # environment/self kill → fire with `false` for the eliminator
```

Scoring, killstreaks, and respawn logic subscribe to `EliminationEvents` rather
than touching the character API directly.

### The per-player object

`game_player` (`class<unique>`) stores the agent, character, small session
fields (e.g. killstreak), and the `Services` bundle. `Init` **only**
calls the persistence manager to ensure the shared table exists — it does not
push `@editable` config or show HUDs. Those happen in each manager device's
`OnPlayerJoined`. `<unique>` makes `var` state stick by identity. Add small
fields on `game_player`; add bigger managers/trackers as fields on `game_player_services`
(`struct`) — see `sys_architecture`.
