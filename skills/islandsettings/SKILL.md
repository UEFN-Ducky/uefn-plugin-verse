---
source_plugin_id: verse
name: islandsettings
description: "UEFN Island Settings — CORE gameplay session setup: MaxPlayers, starting class, teams, spawn rules. ALWAYS pair MaxPlayers with one Player Spawn Pad per slot. Use when setting up a game for N players, changing max players, starting class, matchmaking, or Device_ExperienceSettings."
license: Ducky Source-Available License v1.0
metadata:
  label: UEFN Island Settings
  version: 5
  author: UEFN-Ducky
  copyright: Copyright 2026 UEFN-Ducky
  allow_redistribute: false
  managed_by: uefn-ducky
---

# UEFN Island Settings — CORE session setup

**CRITICAL — editor mutations are SERIAL:** spawn pads / Creative field sets —
one heavy MCP call → wait → next. Never parallel `spawn_actor` for N pads in
one turn. Details: `skill_read_subskill("uefn", "batch_commands")`.

Island Settings (`Device_ExperienceSettings_V2_UEFN_C`) is **where you configure the game for players** — not a side device. This is the source of truth for:

- **How many players** (`MaxPlayers` + matchmaking caps)
- **Starting class** (`DefaultClassIdentifier`)
- **Teams / friendly fire**
- **Where they spawn** (`SpawnLocation` = `SpawnPads` for pad-based games)
- Movement, vitals, inventory, win conditions, voice/chat

| | |
|--|--|
| **Class** | `Device_ExperienceSettings_V2_UEFN_C` |
| **Typical label** | `IslandSettings0` |
| **Kind** | `creative_device` |

Not a Verse device. Never use `inspect_verse_device` / `wire_verse_device_ref`.

## CRITICAL — MaxPlayers ↔ spawn pads

When the island uses spawn pads (`SpawnLocation` = `SpawnPads`):

> **`MaxPlayers = N` requires N Player Spawn Pads in the level.**

Setting max players alone is incomplete. Players beyond the pad count cannot join/spawn correctly.

| MaxPlayers | Required pads |
|------------|---------------|
| 4 | 4× `BP_Creative_Player_Spawner_Prop` |
| 8 | 8 pads |
| 16 | 16 pads |

**Always do both** when sizing a session:

1. Count pads: `find_devices(label_filter="Spawn", class_filter="Player_Spawner")`
2. Set Island Settings: `MaxPlayers` (+ usually `Matchmaking_MaxPlayersPerSession`) to that count (or place more pads first)
3. If pads < MaxPlayers → **place more pads** (or lower MaxPlayers). Never leave a mismatch.

Pad asset (append `_C`): search `Player_Spawner` → typically  
`/Game/Creative/Devices/PlayerSpawner/BP_Creative_Player_Spawner_Prop.BP_Creative_Player_Spawner_Prop_C`  
Label them `Player 1 Spawn Pad` … `Player N Spawn Pad`. Never scale pads — move/rotate only.

If a Verse player-manager has `AllPlayerSpawners`, wire after placement: `wire_player_spawners("<manager>")`.

## Tools

| Job | Tool |
|-----|------|
| Find Island Settings | `find_devices(label_filter="Island", class_filter="ExperienceSettings")` |
| Count spawn pads | `find_devices(label_filter="Spawn", class_filter="Player_Spawner")` |
| Read / write settings | `inspect_creative_device` / `set_creative_device_fields` |
| Wire pads → manager | `wire_player_spawners("<manager_label>")` |

## Session setup golden path (N players)

```
ping
find_devices(label_filter="Spawn", class_filter="Player_Spawner")   # count = P
find_devices(label_filter="Island", class_filter="ExperienceSettings")
inspect_creative_device(
  actor_path="IslandSettings0",
  keys=["MaxPlayers", "Matchmaking_MaxPlayersPerSession", "SpawnLocation", "SpawnPadSelection"],
)

# If P < N: spawn (N-P) more Player Spawn Pads via spawn_actor(..., label=..., folder="Hub/Spawners"), then save
# Then:
set_creative_device_fields(actor_path="IslandSettings0", fields={
  "MaxPlayers": N,
  "Matchmaking_MaxPlayersPerSession": N,
  "SpawnLocation": "SpawnPads",
  "SpawnPadSelection": "Random",          # or NearTeammates for team games
  "DefaultClassIdentifier": {"class_type": "NoClass", "class_slot": 1},
  "Teams": {"team_type": "FreeForAll", "team_index": 1},
}, save_level=true)

# Optional: wire_player_spawners("MyPlayerManager")
# Verify: pad count == MaxPlayers
```

**Inspect gotcha:** param is `actor_path` (Outliner label works as the value) — never `label=`. Always pass `keys=[…]` for Island Settings — the full ToyOptions dump is huge.

## Core keys (session)

| Intent | Key |
|--------|-----|
| Player cap | `MaxPlayers` |
| Matchmaking cap | `Matchmaking_MaxPlayersPerSession` (keep ≥ / = MaxPlayers) |
| Starting class | `DefaultClassIdentifier` → `{"class_type":"NoClass"\|…, "class_slot":N}` |
| Spawn mode | `SpawnLocation` (`SpawnPads` for pad games) |
| Pad pick | `SpawnPadSelection` |
| Teams | `Teams`, `TeamSize`, `bAllowFriendlyFire` |
| Force full lobby | `bForceStartAtMaxPlayers`, `ForceStartDelay` |

## Hard rules

1. **Island Settings first for session rules** — MaxPlayers, class, teams, spawn — before tuning cosmetics.
2. **Pad count == MaxPlayers** when using SpawnPads. Check every time you change either.
3. **Inspect before write.** Skip `readonly_override` keys (see `scoped_readonly`).
4. **One Island Settings device** — configure the existing one; do not spawn a duplicate.
5. **Never scale** Island Settings or spawn pads.

## Load when needed

- Full session checklist → `skill_read_subskill("islandsettings", "session_setup")`
- Key categories → `skill_read_subskill("islandsettings", "categories")`
- Recipes → `skill_read_subskill("islandsettings", "recipes")`
- Scoped readonly → `skill_read_subskill("islandsettings", "scoped_readonly")`
