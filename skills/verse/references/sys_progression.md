---
description: "XP & level progression — persistable level data, editable level thresholds, the level manager, progress bar, level-up detection, effects and analytics"
metadata:
  order: 24
  label: "Game systems — XP & levels"
  default_enabled: false
  load_condition: "Building XP, levels, ranks with thresholds, level-up rewards/effects, or a progress bar HUD"
---

## XP & level progression

Names below are generic — adapt them to your game.

### The three data shapes

```verse
# 1. Persistent — what's saved per player
player_level := class<final><persistable>:
    TotalLevelXP <public> : int = 0
    CurrentLevelIndex <public> : int = 0

# 2. Config — one row per level, edited in UEFN
player_level_threshold := class<concrete>():
    @editable ThresholdXP : int = 0
    @editable LevelName : string = "Default Level"
    @editable LevelIcon : ?texture = false
```

The device holds `@editable Levels : []player_level_threshold` — designers fill the
ladder (threshold XP + name + icon per level) with no code.

### Awarding & removing XP

XP lives in the persistable table; add/remove through the persistence manager
(rebuild + store). After changing XP, **re-sync the HUD**:

```verse
AddPlayerTotalLevelXP<public>(LevelXP : int) : void =
    if (MyAgent?):
        ProgressionSaveService.AddPlayerTotalLevelXP(MyAgent, LevelXP)
        SyncLevelAndProgress()
```

Guard against deranking on removal — clamp to the current level's threshold so
losing XP never drops a rank (`RemovePlayerTotalLevelXP` in the file).

### Threshold math: XP → level

Walk the threshold array to find the current level, and compute progress to the
next:

```verse
GetCurrentLevelNumber<public>(XP : int) : int =
    for (Index := 0..LevelData.Length - 2):
        if (XP >= LevelData[Index].ThresholdXP and XP < LevelData[Index + 1].ThresholdXP):
            return Index
    if (LevelData.Length > 0, XP >= LevelData[LevelData.Length - 1].ThresholdXP):
        return LevelData.Length - 1
    return 0

# progress % toward next level
LevelPercents := ((LevelXP - CurrentThreshold) * 1.0) / ((NextThreshold - CurrentThreshold) * 1.0) * 100.0
```

Clamp the percent to `0.0 .. 99.99` and treat "at last index" as **MAX** (no next
threshold to divide by).

### Level-up detection, effects & analytics

Track the last level you displayed; when the computed level rises, that's a
level-up — fire the effect and analytics once:

```verse
if (CurrentLevelIndex > LastRecordedLevel):
    set LastRecordedLevel = CurrentLevelIndex
    TriggerAnalyticsForLevel(CurrentLevelIndex)
    if (Effect := LevelUpEffect?, A := MyAgent?):
        Effect.Pickup(A)                    # visual_effect_powerup_device
```

Handle the "just hit max level" case separately so the bar shows `MAX` and you
don't keep re-firing.

### Progress-bar HUD

A progress bar is a `color_block` whose width you scale by the percent:

```verse
var LevelProgressBar : color_block = color_block{ DefaultColor := color{R := 1.0, G := 0.84, B := 0.0} }

UpdateProgressBar(Percent : float) : void =
    BarWidth := (Percent / 100.0) * 300.0
    LevelProgressBar.SetDesiredSize(vector2{ X := BarWidth, Y := 15.0 })
```

Text + icon update via `text_block.SetText(Message(...))` and
`texture_block.SetImage(...)`; the level name/icon come from the matched
`player_level_threshold`. See `ui` for laying the HUD out.

### Wiring (device → per-player manager)

Exact pattern — concrete manager ref, Subscribe by function name, catch already
joined, then config → HUD on the manager:

```verse
progression_manager_device := class(creative_device):
    @editable PlayerManager : player_manager = player_manager{}
    @editable LevelUpEffect : visual_effect_powerup_device = visual_effect_powerup_device{}
    @editable Levels : []player_level_threshold = array{}

    OnBegin<override>()<suspends> : void =
        PlayerManager.SubscribePlayerConnected(OnPlayerJoined)
        InitializeAllPlayerLevels()

    InitializeAllPlayerLevels() : void =
        Agents := Self.GetPlayspace().GetPlayers()
        for (Agent : Agents):
            if (CPlayer := PlayerManager.GetGamePlayer(Agent)?):
                OnPlayerJoined(CPlayer)

    OnPlayerJoined(GamePlayer : game_player) : void =
        GamePlayer.Services.ProgressionManager.SetLevelUpEffect(LevelUpEffect)
        GamePlayer.Services.ProgressionManager.SetLevelData(Levels)
        GamePlayer.Services.ProgressionManager.ShowHUD(GamePlayer.MyAgent)
```

`OnPlayerJoined` signature must match `player_connected_to_game`. Award XP from
gameplay via `GetGamePlayer` → `Services.ProgressionManager.Add…` — never by
reaching into the weak_map from random devices. Full flow: `sys_architecture`.
