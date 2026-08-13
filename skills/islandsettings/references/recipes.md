---
description: "Common Island Settings recipes — FFA deathmatch, co-op PvE, BR-style inventory, solo playtest, no building"
metadata:
  order: 2
  label: "Recipes"
  default_enabled: false
  load_condition: "Applying a preset or recipe to Island Settings (FFA, co-op, BR inventory, playtest, no building)"
---

# Island Settings recipes

Inspect first; only set keys that are writable. Adjust numbers for the island.

**Every recipe that sets `MaxPlayers` assumes matching Player Spawn Pads** (`count == MaxPlayers` when `SpawnLocation` = `SpawnPads`). See `session_setup`.

## Solo / small playtest

```
# Requires 4 Player Spawn Pads in the level
set_creative_device_fields(actor_path="<label>", fields={
  "MaxPlayers": 4,
  "Matchmaking_MaxPlayersPerSession": 4,
  "MatchmakingType": "Off",
  "Matchmaking_MinPlayers": 1,
  "bForceStartAtMaxPlayers": false,
  "Teams": {"team_type": "FreeForAll", "team_index": 1},
  "DefaultClassIdentifier": {"class_type": "NoClass", "class_slot": 1},
  "TotalRounds": 1,
  "SpawnLocation": "SpawnPads",
}, save_level=true)
```

## Free-for-all deathmatch (respawn)

```
set_creative_device_fields(actor_path="<label>", fields={
  "Teams": {"team_type": "FreeForAll", "team_index": 1},
  "bAllowFriendlyFire": false,
  "bLastStandingEndsGame": false,
  "SpawnLocation": "SpawnPads",
  "SpawnPadSelection": "Random",
  "SpawnImmunityTime": 5.0,
  "bDisplayScoreboard": true,
  "VoiceChat": "All",
}, save_level=true)
```

## Co-op / same-team PvE

```
set_creative_device_fields(actor_path="<label>", fields={
  "Teams": {"team_type": "TeamIndex", "team_index": 1},
  "TeamSize": "Dynamic",
  "bAllowFriendlyFire": false,
  "bAllowTeamIndicators": true,
  "VoiceChat": "Team",
  "TextChatScope": "Team",
  "GameEndCallout": "Cooperative",
}, save_level=true)
```

## BR-style inventory + movement (common UEFN default)

```
set_creative_device_fields(actor_path="<label>", fields={
  "LocomotionPreset": "Current BR",
  "MovementSpeedTunings": "Ch 5 Movement",
  "CustomInventoryConfiguration": "/Script/ItemizationCoreRuntime.ItemizationConfigurationAsset'/Itemization/BRStyle/ItemizationConfiguration_BRStyle.ItemizationConfiguration_BRStyle'",
  "MaxHealth": 100.0,
  "MaxShields": 100.0,
  "StartingShieldPercentage": 0.0,
  "bFallDamageV2": true,
}, save_level=true)
```

## Infinite resources playtest

```
set_creative_device_fields(actor_path="<label>", fields={
  "bInfiniteAmmo": true,
  "bInfiniteMagazineAmmo": true,
  "bInfiniteConsumables": true,
  "bInfiniteBuildingResources": true,
  "bNoCooldowns": true,
}, save_level=true)
```

## Published session caps (example 16)

```
# Requires 16 Player Spawn Pads — place them first if you only have fewer
set_creative_device_fields(actor_path="<label>", fields={
  "MaxPlayers": 16,
  "Matchmaking_MaxPlayersPerSession": 16,
  "Matchmaking_MaxTeamCount": 16,
  "Matchmaking_MaxTeamSize": 16,
  "Matchmaking_MaxSocialPartySize": 16,
  "MatchmakingPrivacy": "Public",
  "SocialJoining": "Enabled",
  "SpawnLocation": "SpawnPads",
}, save_level=true)
```

After any recipe: re-inspect the keys you set; if a key comes back `readonly_override`, stop and tell the user. Confirm `find_devices(…Player_Spawner)` count == `MaxPlayers`.
