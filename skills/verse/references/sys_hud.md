---
description: "Per-player HUD management — the [agent]canvas widget map, add/remove/refresh, input modes, live text/image updates, and where to own HUD state"
metadata:
  order: 30
  label: "Game systems — per-player HUD management"
  default_enabled: false
  load_condition: "Managing on-screen HUD across many players — showing/hiding/updating widgets per player, input modes, or live-updating text/bars"
---

## Per-player HUD management

UI is **per player** — each player has their own screen. Building the widget tree
is in the `ui` reference; this is about **owning and updating** HUD across everyone
in the match.

### Get a player's UI

`GetPlayerUI[]` is failable — always guard it:

```verse
if (Player := player[Agent], PlayerUI := GetPlayerUI[Player]):
    PlayerUI.AddWidget(MyCanvas, player_ui_slot{ InputMode := ui_input_mode.None })
```

Input modes decide whether the widget captures input:

| `ui_input_mode` | Use |
|-----------------|-----|
| `.None` | pure HUD — never steals input (scoreboards, timers, bars) |
| `.All` | interactive menus/buttons that need clicks |

Default HUD to `.None`; only use `.All` for menus, and remove them when done so the
player regains control.

### Track widgets per player

Keep a map of who currently has a given widget so you can update or remove it later.
This is the core HUD-management pattern:

```verse
var PlayerCanvases : [agent]canvas = map{}

ShowFor<public>(Agent : agent) : void =
    if (Player := player[Agent], PlayerUI := GetPlayerUI[Player]):
        NewCanvas := BuildCanvas()
        PlayerUI.AddWidget(NewCanvas, player_ui_slot{ InputMode := ui_input_mode.None })
        if (set PlayerCanvases[Agent] = NewCanvas): {}

RemoveFor<public>(Agent : agent) : void =
    if (Player := player[Agent], PlayerUI := GetPlayerUI[Player], Old := PlayerCanvases[Agent]):
        PlayerUI.RemoveWidget(Old)
        var NewMap : [agent]canvas = map{}          # drop the entry
        for (A -> C : PlayerCanvases, A <> Agent):
            if (set NewMap[A] = C) {}
        set PlayerCanvases = NewMap
```

**Remove a player's widgets on leave** (subscribe to the player-removed event) or
the map leaks and you leak references to their canvases.

### Two ways to update: mutate vs rebuild

| Update | How | Use when |
|--------|-----|----------|
| **Mutate the leaf** (preferred) | keep the `text_block`/`color_block` as a field and call `SetText` / `SetImage` / `SetDesiredSize` | value changed, layout didn't (scores, timers, bars) |
| **Rebuild the canvas** | `RemoveWidget(Old)` → build new → `AddWidget` → store | the number/shape of rows changed (leaderboard rows) |

Prefer mutation — it's cheaper and flicker-free:

```verse
TimerText.SetText(Message("{Seconds}"))                 # live text
ScoreText.SetText(Message("{Score}"))
ProgressBar.SetDesiredSize(vector2{ X := Pct/100.0*300.0, Y := 15.0 })   # bar fill
IconBlock.SetImage(NewTexture)                          # swap image
```

Rebuild only when the structure changes (see `sys_scoring` for the leaderboard
rebuild). To refresh **everyone**, iterate the map:

```verse
UpdateAll() : void =
    for (Agent -> _ : PlayerCanvases):
        RefreshFor(Agent)
```

### Where HUD state lives

- **Per-player HUD** (level bar, wallet, personal timer, inventory bag): own it in
  that player's `<unique>` manager inside `game_player.Services` — invent layout
  with **`sys_canvas_cookbook`**, copy ShowHUD from **`sys_hud_template`**.
  Interactive shops/popups: **`sys_ui_menus`**.
- **Shared/broadcast HUD** (a leaderboard everyone sees, a global round timer): own
  a single manager with the `[agent]canvas` map and push updates to all viewers.

### Showing HUD to players already in

When a HUD device starts, players may already be in the match — show to them too,
not just future joiners:

```verse
OnBegin<override>()<suspends> : void =
    Manager.SubscribePlayerConnected(OnPlayerJoined)     # future joiners
    for (Agent : GetPlayspace().GetPlayers()):           # already-present
        ShowFor(Agent)
```

### Gotchas

- `GetPlayerUI[]`, `player[Agent]`, and map reads are all failable — guard every
  one.
- Don't rebuild a whole canvas every frame; mutate the leaves.
- Always `RemoveWidget` before dropping a stored canvas, and drop the map entry on
  leave.
- Use `.None` for HUD so you don't trap the player's input.
