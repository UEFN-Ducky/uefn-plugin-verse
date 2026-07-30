---
description: "CORE Island Settings session setup — MaxPlayers must match Player Spawn Pad count; starting class, teams, spawn location checklist"
metadata:
  order: 0
  label: "Session setup (MaxPlayers + pads)"
  default_enabled: true
  load_condition: "Setting up a game for N players, changing MaxPlayers, starting class, spawn pads, or core Island Settings session rules"
---

# Session setup — Island Settings + spawn pads

This is **core gameplay setup**. Island Settings decides who can play and how they enter; spawn pads are the physical slots.

## The invariant

```
SpawnLocation == SpawnPads  ⇒  count(Player Spawn Pads) == MaxPlayers
```

Also keep matchmaking aligned:

```
Matchmaking_MaxPlayersPerSession == MaxPlayers   (usual)
Matchmaking_MaxTeamCount / MaxTeamSize consistent with Teams + TeamSize
```

**Wrong:** set `MaxPlayers` to 16 with 8 pads → last 8 players have nowhere to spawn.  
**Right:** place 16 pads **or** set MaxPlayers to 8.

## Checklist (copy and tick)

```
Session setup:
- [ ] Target player count N agreed
- [ ] find_devices(Spawn / Player_Spawner) → pad count P
- [ ] If P < N: place (N-P) pads, label Player (P+1)…N Spawn Pad
- [ ] If P > N and unused pads are intentional: OK; else remove or raise N
- [ ] Island Settings: MaxPlayers = N
- [ ] Island Settings: Matchmaking_MaxPlayersPerSession = N (if matchmaking used)
- [ ] Island Settings: SpawnLocation = SpawnPads
- [ ] Island Settings: DefaultClassIdentifier set (starting class)
- [ ] Island Settings: Teams / TeamSize / friendly fire set
- [ ] Optional: wire_player_spawners on Verse player manager
- [ ] save_current_level / save_level=true
- [ ] Re-count: P == MaxPlayers
```

## Starting class

```
DefaultClassIdentifier: {"class_type": "NoClass", "class_slot": 1}
```

`class_type` / slot must match classes you actually defined on the island. Inspect first for allowed shapes. `RevertToDefaultClassAt` controls when players snap back (`GameEnd`, `RoundEnd`, `PlayerDeath`, `Never`).

## Placing pads for N players

```
search_assets(search="Player_Spawner", limit=5)
# spawn N times (or N-P more), ~200–400 uu apart — ONE spawn_actor per call
spawn_actor(
  asset_path="…/BP_Creative_Player_Spawner_Prop.BP_Creative_Player_Spawner_Prop_C",
  location=[x, y, z],
  select=false,
)
set_actor_label(..., label="Player K Spawn Pad")   # K = 1…N
```

Never change pad **scale**. Team games: set each pad's team via `inspect_creative_device` / `set_creative_device_fields` on that pad after placement.

## Verse managers

If a device has `@editable AllPlayerSpawners : []player_spawner_device`:

```
wire_player_spawners("MyPlayerManager")
# or wire_player_spawners("MyPlayerManager", spawn_pad_paths=["Player 1 Spawn Pad", …])
```

Island Settings MaxPlayers and the wired pad list must still agree.

## Core keys quick map

| Setup question | Island Settings key |
|----------------|---------------------|
| How many players? | `MaxPlayers` |
| Queue size? | `Matchmaking_MaxPlayersPerSession` |
| What class at start? | `DefaultClassIdentifier` |
| Spawn on pads? | `SpawnLocation` = `SpawnPads` |
| Which pad? | `SpawnPadSelection` |
| Team mode? | `Teams`, `TeamSize`, `bAllowFriendlyFire` |
| Wait for full lobby? | `bForceStartAtMaxPlayers`, `ForceStartDelay` |
| Join mid-game? | `JoinInProgressBehavior` |
