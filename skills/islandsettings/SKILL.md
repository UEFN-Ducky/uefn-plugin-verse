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

1. Count pads with nested Epic `unreal__*` Creative device tools (Player Spawn Pad / Player_Spawner)
2. Set Island Settings `MaxPlayers` (+ usually `Matchmaking_MaxPlayersPerSession`) to that count (or place more pads first)
3. If pads < MaxPlayers → **place more pads** via Epic device tools (or lower MaxPlayers). Never leave a mismatch.

Pad asset (append `_C`): search `Player_Spawner` → typically  
`/Game/Creative/Devices/PlayerSpawner/BP_Creative_Player_Spawner_Prop.BP_Creative_Player_Spawner_Prop_C`  
Label them `Player 1 Spawn Pad` … `Player N Spawn Pad`. Never scale pads — move/rotate only.

If a Verse player-manager has `AllPlayerSpawners`, wire after placement: `wire_player_spawners("<manager>")`.

## Tools

| Job | Tool |
|-----|------|
| Find Island Settings / spawn pads | nested Epic `unreal__*` Creative device tools |
| Read / write Island Settings | nested Epic `unreal__*` (not `inspect_creative_device`) |
| Wire pads → manager | `wire_player_spawners("<manager_label>")` |

## Session setup golden path (N players)

```
ducky_get_status   # epic_mcp_online must be true; else recites Epic setup steps
# Census spawn pads + Island Settings via nested Epic unreal__* device tools
# If P < N: place (N-P) more Player Spawn Pads via Epic device tools, then save
# Set MaxPlayers / Matchmaking_MaxPlayersPerSession to N via Epic device tools
# Optional: wire_player_spawners("MyPlayerManager")
# Verify: pad count == MaxPlayers
```

Epic Python toolsets speak **XYZ**. Prefer nested Epic device tools over Ducky `spawn_actor` for Player Spawn Pads. If Epic MCP is down, stop — do not use `find_devices` / `inspect_creative_device` / `set_creative_device_fields`.

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
