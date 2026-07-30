---
description: "Writable Island Settings ToyOptions keys by category — matchmaking, teams, spawn, movement, vitals, inventory, game flow, social"
metadata:
  order: 1
  label: "Property categories"
  default_enabled: false
  load_condition: "Picking which Island Settings / Experience Settings keys to change (max players, teams, spawn, movement, ammo, HUD)"
---

# Island Settings — writable key categories

Only keys that `inspect_creative_device` reports with a real `type` (not `readonly_override`) can be set via `set_creative_device_fields`. Confirm on the live device — Epic adds/renames options over time.

## Matchmaking & session (CORE)

`MaxPlayers` — **must equal Player Spawn Pad count** when `SpawnLocation` = `SpawnPads` (see `session_setup`).

Also: `MatchmakingType`, `MatchmakingPrivacy`, `CreativeMatchmakingPrivacy`, `bUseCustomMatchmakingSettings`, `Matchmaking_MaxPlayersPerSession`, `Matchmaking_MaxSocialPartySize`, `Matchmaking_MaxTeamCount`, `Matchmaking_MaxTeamSize`, `Matchmaking_MinPlayers`, `Matchmaking_OvertimePlayerTarget`, `Matchmaking_QueueMainDuration`, `Matchmaking_QueueOvertimeDuration`, `MMSBackfill`, `SocialJoining`, `TeamFillOption`, `TeamSize`, `bForceStartAtMaxPlayers`, `ForceStartDelay`

## Starting class (CORE)

`DefaultClassIdentifier` → `{"class_type": "NoClass", "class_slot": 1}`  
`RevertToDefaultClassAt` — `GameEnd` | `RoundEnd` | `PlayerDeath` | `Never`

## Teams

`Teams` (struct), `TeamSize`, `TeamRotation`, `TeamVisualsDeterminedAt`, `UITeamColors`, `bAllowFriendlyFire`, `bAllowTeamIndicators`, `bAllTeamsMustFinish`, `JoinInProgressBehavior`, `JoinInProgressAssignedTeam`, `bJoinInProgressAssignedTeamOverride`, `KeepSpectatorsInTeamChat`

## Spawn / respawn / post-game spawn

`SpawnLocation`, `SpawnPadSelection`, `SpawnLimit`, `SpawnImmunityTime`, `bOverrideSpawnImmunityTime`, `bOnlyAllowRespawnIfSpawnPadsFound`, `AfterLastSpawnGoTo`, `PostGameSpawnLocation`, `PostGameType`

## Movement / locomotion

`LocomotionPreset`, `MovementSpeedTunings`, `bAllowSprinting`, `bAllowSliding`, `bAllowMantling`, `bAllowVaulting`, `bAllowWallKick`, `bAllowWallScramble`, `bAllowBoostedJump`, `bAllowHurdleOverJumpableObjects`, `bAllowSlideKick`, `bAllowFlightSprinting`, `bFlyEnable`, `FlyingSpeedPreset`, `bGliderRedeployable`, `MaxSprintingSpeedMultiplier`, `MaxSprintingJumpMultiplier`, `EnergyMax`, `EnergyCostOnJump`, `EnergyRechargeAmount`, `EnergyRechargeDelay`, `SprintingEnergyCostPerSecond`, `ShouldPauseEnergyUseOnFalling`, `MantlingMinimumHeight`, `MantlingMinimumHeightInWater`

## Vitals / combat

`MaxHealth`, `MaxShields`, `StartingHealthPercentage`, `StartingShieldPercentage`, `AllowHealthRecharge`, `AllowShieldRecharge`, `bAllowOvershield`, `OvershieldMax`, `HealthRecharge*`, `ShieldRecharge*`, `OvershieldRecharge*`, `bFallDamageV2`, `FallDamageType`, `Fall Damage Capping`, `GrapplerFallDamageImmunity`, `bInvincibility`, `bInvincibilityEnabled`, `DownButNotOut`, `bImpulseOnHit`, `bVehicleImpactsDamageObjects`, `bVehicleImpactsDamageVehicles`

## Inventory / resources / cheats

`bInfiniteAmmo`, `bInfiniteMagazineAmmo`, `bInfiniteConsumables`, `bInfiniteCharges`, `bInfiniteDurability`, `bInfiniteGold`, `bInfiniteBuildingResources`, `bInfiniteWorldResources`, `bInfiniteLoadedEnergy`, `bInfiniteReserveEnergy`, `bNoCooldowns`, `bNoCooldownsAfterSwap`, `bDisplayEmptyAmmoSlots`, `CustomInventoryConfiguration`, `bDisableHarvestSlot`

## Game flow / HUD / end conditions

`TotalRounds`, `GameWinCondition`, `GameEndCallout`, `GameStartCountdown`, `AutoStart`, `TimerDirection`, `RoundTimeLimit`, `EliminationsToEnd`, `AIEnemyEliminationsToEnd`, `ObjectivesToEnd`, `CollectItemsToEnd`, `CollectItemCount`, `StatToEnd`, `StatValueToEnd`, `bLastStandingEndsGame`, `bEndGameOnMatchPointWin`, `bFastestTimeWin`, `bDisplayScoreboard`, `bDisplayOverviewMap`, `MapScreenDisplay`, `HUDInfoType`, `ShowTopCenterScoreHUD`, `bShowIndividualScores`, `PostGameType`, `VictorySound`, `DefeatSound`, `VictoryAnimation`, `PublishedIslandCodeDisplay`

## Social / audio

`VoiceChat`, `TextChatScope`, `bIsProximityChatEnabled`, `ProximityChatDistanceInMeters`, `BubbleChat`, `BubbleChatStyle`, `BubbleChatMaximumRange`, `BubbleMinimumLifetime`, `BubbleMaximumLifetime`, `OccludeBubble`, `bDisableSquadQuickChat`, `EnableJam`

## Persistence (edit / playtest)

`PersistenceBehaviorEditSession`, `PersistenceBehaviorPlaytestSession` — enums `ImportLiveData` | `SimulateNewUser`

## Struct shapes (common)

```
Teams / AfterLastSpawnGoTo:
  {"team_type": "FreeForAll", "team_index": 1}

DefaultClassIdentifier:
  {"class_type": "NoClass", "class_slot": 1}
```
