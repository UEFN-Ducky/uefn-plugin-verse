---
description: "Common Island Settings recipes — FFA deathmatch, co-op PvE, BR-style inventory, solo playtest, no building"
metadata:
  order: 2
  label: "Recipes"
  default_enabled: false
  load_condition: "Applying a preset or recipe to Island Settings (FFA, co-op, BR inventory, playtest, no building)"
---

**Tool order (HARD):** 1) Official UEFN MCP first (`ducky_get_status` → `epic_mcp_online` → nested `unreal__*`). 2) Ducky listener second. 3) `execute_python` LAST — never a placement path, even if Epic and listener failed. Map: `skill_read_subskill("uefn", "epic_mcp")`.

# Island Settings recipes

Read with Epic `GetDeviceProperties` first; only set keys that are writable. Adjust numbers for the island.

**Every recipe that sets `MaxPlayers` assumes matching Player Spawn Pads** (`count == MaxPlayers` when `SpawnLocation` = `SpawnPads`). See `session_setup`.

**Pattern for every recipe** — Epic `ValkyrieToolset.DeviceToolset`, one property per call, wait for each result:

```
unreal__describe_toolset(toolset_name="ValkyrieToolset.DeviceToolset")   # once — read the exact argument names, never invent them
unreal__call_tool(toolset_name="ValkyrieToolset.DeviceToolset", tool_name="GetDeviceProperties", arguments={…})  # IslandSettings0: which keys are writable
unreal__call_tool(toolset_name="ValkyrieToolset.DeviceToolset", tool_name="SetDeviceProperty",  arguments={…})  # one key from the recipe block
# … repeat SetDeviceProperty for each remaining key …
save_current_level()   # once, after the whole recipe — never save_level=true inside other calls
```

Epic down or erroring twice → degrade to the closest Ducky tool and finish (see `session_setup`); never stop mid-task.

## Solo / small playtest

```
# Requires 4 Player Spawn Pads in the level
# IslandSettings0 → one SetDeviceProperty per key below (pattern above), wait between calls
keys = {
  "MaxPlayers": 4,
  "Matchmaking_MaxPlayersPerSession": 4,
  "MatchmakingType": "Off",
  "Matchmaking_MinPlayers": 1,
  "bForceStartAtMaxPlayers": false,
  "Teams": {"team_type": "FreeForAll", "team_index": 1},
  "DefaultClassIdentifier": {"class_type": "NoClass", "class_slot": 1},
  "TotalRounds": 1,
  "SpawnLocation": "SpawnPads",
}
save_current_level()   # once, after the whole recipe
```

## Free-for-all deathmatch (respawn)

```
# IslandSettings0 → one SetDeviceProperty per key below (pattern above), wait between calls
keys = {
  "Teams": {"team_type": "FreeForAll", "team_index": 1},
  "bAllowFriendlyFire": false,
  "bLastStandingEndsGame": false,
  "SpawnLocation": "SpawnPads",
  "SpawnPadSelection": "Random",
  "SpawnImmunityTime": 5.0,
  "bDisplayScoreboard": true,
  "VoiceChat": "All",
}
save_current_level()   # once, after the whole recipe
```

## Co-op / same-team PvE

```
# IslandSettings0 → one SetDeviceProperty per key below (pattern above), wait between calls
keys = {
  "Teams": {"team_type": "TeamIndex", "team_index": 1},
  "TeamSize": "Dynamic",
  "bAllowFriendlyFire": false,
  "bAllowTeamIndicators": true,
  "VoiceChat": "Team",
  "TextChatScope": "Team",
  "GameEndCallout": "Cooperative",
}
save_current_level()   # once, after the whole recipe
```

## BR-style inventory + movement (common UEFN default)

Required for custom Armory / owned-weapon hotbar
(`skill_read_subskill("verse", "sys_owned_weapons")`). Without
`CustomInventoryConfiguration`, Verse grant can succeed and the player still
cannot shoot.

```
# IslandSettings0 → one SetDeviceProperty per key below (pattern above), wait between calls
keys = {
  "LocomotionPreset": "Current BR",
  "MovementSpeedTunings": "Ch 5 Movement",
  "CustomInventoryConfiguration": "/Script/ItemizationCoreRuntime.ItemizationConfigurationAsset'/Itemization/BRStyle/ItemizationConfiguration_BRStyle.ItemizationConfiguration_BRStyle'",
  "MaxHealth": 100.0,
  "MaxShields": 100.0,
  "StartingShieldPercentage": 0.0,
  "bFallDamageV2": true,
}
save_current_level()   # once, after the whole recipe
```

## Infinite resources playtest

```
# IslandSettings0 → one SetDeviceProperty per key below (pattern above), wait between calls
keys = {
  "bInfiniteAmmo": true,
  "bInfiniteMagazineAmmo": true,
  "bInfiniteConsumables": true,
  "bInfiniteBuildingResources": true,
  "bNoCooldowns": true,
}
save_current_level()   # once, after the whole recipe
```

## Published session caps (example 16)

```
# Requires 16 Player Spawn Pads — place them first if you only have fewer
# IslandSettings0 → one SetDeviceProperty per key below (pattern above), wait between calls
keys = {
  "MaxPlayers": 16,
  "Matchmaking_MaxPlayersPerSession": 16,
  "Matchmaking_MaxTeamCount": 16,
  "Matchmaking_MaxTeamSize": 16,
  "Matchmaking_MaxSocialPartySize": 16,
  "MatchmakingPrivacy": "Public",
  "SocialJoining": "Enabled",
  "SpawnLocation": "SpawnPads",
}
save_current_level()   # once, after the whole recipe
```

After any recipe: re-read the keys you set with Epic `GetDeviceProperties`; if a key comes back `readonly_override`, stop and tell the user. Confirm Player Spawn Pad count (Epic DeviceToolset query, or `get_all_actors(label_filter="Spawn Pad", limit=500)`) == `MaxPlayers`.
