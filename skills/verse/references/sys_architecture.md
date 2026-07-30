---
description: "The backbone for building ANY player-driven game system — manager device + game_player + manager bundle + weak_map, and how the pieces plug together"
metadata:
  order: 20
  label: "Game systems — architecture backbone"
  default_enabled: false
  load_condition: "Designing or extending any game system (score, economy, progression, stats…) — how player_manager, game_player, Services and persistence fit together"
---

## Game systems — the architecture backbone

Player-driven features (economy, progression, playtime, inventory, score, HUD)
are all built from the **same five parts** and the **same call order**. Learn this
shape once and you can add any new manager the same way. Type names below are
generic — adapt them to your game, but **do not invent a different wiring order**.

### Naming convention (AAA-style — not everything is a “system”)

Prefer role suffixes used in shipped games. Verse types stay `snake_case`; fields
can be PascalCase for readability:

| Role | Suffix | Use for |
|------|--------|---------|
| Owns a domain, mutates state | **Manager** | inventory, economy, progression, spawn, audio, input |
| Observes / accumulates over time | **Tracker** | playtime, achievements, analytics streaks |
| Orchestrates a match/flow | **Controller** | match/round flow, HUD presentation |
| Persists / loads data | **Service** | save / load of the shared player table |

Examples: `inventory_manager`, `progression_manager`, `economy_manager`,
`player_time_tracker`, `match_controller`, `save_service`, `hud_controller`,
`input_manager`, `ui_menu_controller`, `minigame_controller`,
`building_unlock_manager`, `prop_spawn_manager` (see matching `sys_*` refs).
The per-player bundle is `game_player.Services` (`game_player_services`) — not
“PlayerSystems”.

Do **not** use `fortnite_` in type names — those tokens collide with engine /
locked APIs. Use `game_player`.

**Any canvas that must show on screen:** invent layouts with `sys_canvas_cookbook`,
wire ShowHUD with `sys_hud_template`, interactive shops/popups with `sys_ui_menus`.

### The five parts

```
1. player_manager  (creative_device)   — one registry: [agent]game_player, join/leave, event bus
2. game_player   (class<unique>)      — one object per player; holds Services
3. game_player_services (struct)       — bundle of every per-player manager
4. <your>_manager   (class<unique>)      — runtime logic + HUD (lives in the bundle)
5. <your>_manager_device (creative_device) — placed device: @editable config → configures each player's manager
   (+ persistence: a <persistable> nested in the shared weak_map table — see `persistence`)
```

### Exact programming flow (follow this order)

```
Island start
  │
  ├─ player_manager.OnBegin
  │     Subscribe playspace PlayerAdded / PlayerRemoved
  │     Subscribe each player_spawner SpawnedEvent → same OnPlayerAdded
  │     spawn{ AddAllPlayersAfterDelay }   # Sleep, then GetPlayers → OnPlayerAdded
  │
  └─ each manager_device.OnBegin
        PlayerManager.SubscribePlayerConnected(OnPlayerJoined)   # exact signature
        [optional] SubscribePlayerRemoved(OnPlayerLeft)          # time / cleanup
        InitializeAll…()  # walk GetPlayers → GetGamePlayer? → OnPlayerJoined

Player appears (join / spawn / delayed catch-up)
  │
  OnPlayerAdded(Agent)                # sync
    spawn{ OnPlayerAddedLoop(Agent) } # async body
      │
      ├─ if already in AllPlayers → return (dedupe)
      ├─ NewCP := game_player{ MyAgent := Agent }
      ├─ if (set AllPlayers[Agent] = NewCP):     # map write is failable — must be in if
      │     NewCP.Init(Agent)
      │       └─ PersistenceManager.InitializePlayer(option{Agent})
      │            └─ ensure weak_map row exists (create empty table if new)
      │     for each ConnectSubscriber: ConnectSubscriber(NewCP)   # bus fire
      │     (then optional: FortChar.EliminatedEvent subscribe)
      │
      └─ each system OnPlayerJoined(NewCP) runs from the bus:
            1. push @editable config into NewCP.Services.YourManager
            2. init that system's persisted state / HUD
            (config BEFORE init — never the reverse)

Player leaves
  OnPlayerRemoved(Agent)
    if (CP := AllPlayers[Agent]):
      fire Remove subscribers with CP     # systems flush first (e.g. EndSession)
      rebuild AllPlayers without Agent    # ConcatenateMaps filter — no in-place delete
```

**Race rule:** a system device may start before the manager has registered anyone.
That is why every system does **both** `SubscribePlayerConnected` **and** an
`InitializeAll…` walk. If `GetGamePlayer` fails during the walk, do nothing —
the bus will deliver `OnPlayerJoined` later.

### Specifier rules (do not mix these up)

| Kind | Specifier | Why |
|------|-----------|-----|
| `game_player`, each `*_manager` | `class<unique>` | Mutable per-player identity; `set` on the stored instance sticks |
| Systems bundle | `struct` | Pure composition of manager instances |
| Designer config row (`@editable` array element) | `class<concrete>` | Editable in Details; not persistable |
| Saved nested data | `class<final><persistable>` | Every field defaulted; nest inside the shared table |
| Event callback | `type{_(Args…):void}` | Typed bus; Subscribe takes a function with **that exact** signature |

### 1. Registry + typed bus (on the manager)

```verse
player_connected_to_game <public> := type{_(GamePlayer : game_player):void}
player_removed_from_game <public> := type{_(GamePlayer : game_player):void}

player_manager := class(creative_device):
    @editable AllPlayerSpawners <private> : []player_spawner_device = array{}
    var AllPlayers <private> : [agent]game_player = map{}
    var PlayerConnectedToGame <private> : []player_connected_to_game = array{}
    var PlayerRemovedFromGame <private> : []player_removed_from_game = array{}

    OnBegin<override>()<suspends> : void =
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerRemoved)
        for (Index -> Spawner : AllPlayerSpawners):
            Spawner.SpawnedEvent.Subscribe(OnPlayerAdded)
        spawn{ AddAllPlayersAfterDelay() }

    SubscribePlayerConnected<public>(ConnectEvent : player_connected_to_game) : void =
        set PlayerConnectedToGame += array{ConnectEvent}

    SubscribePlayerRemoved<public>(RemoveEvent : player_removed_from_game) : void =
        set PlayerRemovedFromGame += array{RemoveEvent}

    GetGamePlayer<public>(Agent : agent)<transacts> : ?game_player =
        if (MyPlayer := AllPlayers[Agent]):
            return option{MyPlayer}
        else:
            return false
```

**Bus rules:**
- Declare the type with `type{_(…):void}` — not a class, not a lambda type you invent.
- `Subscribe…` appends with `set Arr += array{Callback}`.
- Fire with `for (Cb : Arr): Cb(Args)`.
- The handler you pass (`OnPlayerJoined`) **must** match the type's parameter list
  exactly (`GamePlayer : game_player`), or it will not compile.

### 2. Join body (dedupe → store → Init → fire)

```verse
OnPlayerAdded<public>(NewAgent : agent) : void =
    spawn{ OnPlayerAddedLoop(NewAgent) }

OnPlayerAddedLoop<private>(NewAgent : agent)<suspends> : void =
    if (PlayerExists := AllPlayers[NewAgent]):
        # already registered — skip
    else:
        NewGamePlayer : game_player = game_player{ MyAgent := NewAgent }
        if (set AllPlayers[NewAgent] = NewGamePlayer):
            NewGamePlayer.Init(NewAgent)
            for (ConnectEvent : PlayerConnectedToGame):
                ConnectEvent(NewGamePlayer)
```

**Order is mandatory:** map insert → `Init` (creates persist row) → fire bus.
Firing before `Init` means subscribers read an empty / missing weak_map entry.

### 3. Per-player object + systems bundle

```verse
game_player_services := struct():
    SaveService <public> : save_service = save_service{}
    ProgressionManager <public> : progression_manager = progression_manager{}
    EconomyManager <public> : economy_manager = economy_manager{}
    InventoryManager <public> : inventory_manager = inventory_manager{}
    TimeTracker <public> : player_time_tracker = player_time_tracker{}
    # add YourManager / QuestManager / AchievementTracker / … here

game_player := class<unique>():
    MyAgent <public> : agent
    Services <public> : game_player_services = game_player_services{}

    Init(Agent : agent) : void =
        Services.SaveService.InitializePlayer(option{Agent})
```

`Init` only ensures the shared persist table exists. **Manager config and HUD
are not done here** — each manager device does that in `OnPlayerJoined`.

### 4. Manager device wiring (exact pattern — copy this)

Non-optional `@editable` ref to the manager (default constructed), subscribe the
function by name, then catch already-joined players:

```verse
your_manager_device := class(creative_device):
    @editable PlayerManager : player_manager = player_manager{}
    @editable ConfigRows : []your_config = array{}     # class<concrete> rows

    OnBegin<override>()<suspends> : void =
        PlayerManager.SubscribePlayerConnected(OnPlayerJoined)
        InitializeAllAlreadyJoined()

    InitializeAllAlreadyJoined() : void =
        Agents := Self.GetPlayspace().GetPlayers()
        for (Agent : Agents):
            if (CPlayer := PlayerManager.GetGamePlayer(Agent)?):
                OnPlayerJoined(CPlayer)
            # else: not in registry yet — bus will deliver later

    OnPlayerJoined(GamePlayer : game_player) : void =
        GamePlayer.Services.YourManager.SetConfig(ConfigRows)
        GamePlayer.Services.YourManager.ShowHUD(GamePlayer.MyAgent)
```

**Do not** use `?player_manager` + a separate "active" var unless you have a
hard reason — the established pattern is a concrete `@editable` device ref.

If the system must flush on leave (playtime, offline stamp), also:

```verse
PlayerManager.SubscribePlayerRemoved(OnPlayerLeft)

OnPlayerLeft(GamePlayer : game_player) : void =
    GamePlayer.Services.YourManager.EndSession()
```

### 5. Persistence write guard (every manager uses this)

```verse
if:
    RealAgent := Agent?
    Player := player[RealAgent]
    Player.IsActive[]
    OldTable := PlayerStatsMap[Player]
then:
    # build NewNested …
    if (set PlayerStatsMap[Player] = UpdateYourField(OldTable, NewNested)):
        {}  # saved
```

Every failable step stays in the `if:` / `if (` head. Partial table rebuilds must
**copy every nested field** — see `persistence`.

### Recipe: adding a brand-new manager

1. **Persistable** (if needed): `class<final><persistable>` nested in the shared
   table + an `Update…` helper that copies **all** other fields.
2. **Manager**: `your_manager := class<unique>():` — add a field on
   `game_player_services`.
3. **Device**: `your_manager_device := class(creative_device):` with
   `@editable PlayerManager : player_manager = player_manager{}` and config;
   `OnBegin` → `SubscribePlayerConnected(OnPlayerJoined)` + `InitializeAll…`.
4. **OnPlayerJoined**: config first, then init/HUD on
   `GamePlayer.Services.YourManager`.
5. **Gameplay calls**: look up via the manager, then call the manager:

```verse
if (CPlayer := MyPlayerManager.GetGamePlayer(Agent)?):
    CPlayer.Services.YourManager.DoThing()
```

### Getting a player's system from anywhere

```verse
if (CPlayer := MyPlayerManager.GetGamePlayer(Agent)?):
    CPlayer.Services.EconomyManager.RemoveCurrency("Coins", 100)
# or
AllPlayers := MyPlayerManager.GetAllGamePlayers()
if (MyPlayer := AllPlayers[Agent]):
    MyPlayer.Services.ProgressionManager.AddPlayerTotalLevelXP(50)
```

Never hold a long-lived bare `agent` assumption that the game_player still
exists — always look up (or subscribe) through the manager.

Deep-dives: `sys_player_data`, `sys_economy`, `sys_progression`,
`sys_time_tracking`, `sys_inventory`, `sys_canvas_cookbook`, `sys_hud_template`,
`sys_ui_menus`, `sys_input_devices`, `sys_minigame_overlay`, `sys_buildings`,
`sys_generators`, `sys_spawning`, `persistence`.
