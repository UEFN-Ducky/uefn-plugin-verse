---
description: "Interactive UI menus — modal popups, shops, collect screens with ui_input_mode.All, button_loud, open/close, ButtonToAgent map"
metadata:
  order: 37
  label: "Game systems — UI menus & modals (UIMenuController)"
  default_enabled: false
  load_condition: "Building interactive Verse UI — shops, collect popups, pickers, tabbed menus with button clicks and ui_input_mode.All"
---

## UI menus & modals — UIMenuController

Interactive screens **capture** player input. Layouts come from
`sys_canvas_cookbook` (modal, shop list, tabs). Show/hide wiring mirrors
`sys_hud_template` but uses `ui_input_mode.All`.

### Modal recipe

1. Build canvas: full-screen dim `color_block` + centered panel + title/body +
   `button_loud` actions (cookbook **modal**).
2. Show:

```verse
ShowMenu(Agent : agent) : void =
    if (Player := player[Agent], PlayerUI := GetPlayerUI[Player]):
        set MenuCanvas = BuildMenuCanvas()
        PlayerUI.AddWidget(MenuCanvas, player_ui_slot{ InputMode := ui_input_mode.All })
        # map buttons → agent so click handlers know who clicked
        if (set ButtonToAgent[ConfirmButton] = Agent) {}
```

3. Close (restore control):

```verse
CloseMenu(Agent : agent) : void =
    if (Player := player[Agent], PlayerUI := GetPlayerUI[Player]):
        PlayerUI.RemoveWidget(MenuCanvas)
        set MenuCanvas = canvas{}
```

Never leave `.All` widgets up after the menu is done — the player stays trapped.

### Buttons

```verse
var ConfirmButton : button_loud = button_loud{}
# after creating the button widget, subscribe (confirm exact API in digest):
ConfirmButton.OnClick().Subscribe(OnConfirmClicked)

OnConfirmClicked(WM : widget_message) : void =
    if (Agent := ButtonToAgent[ConfirmButton]):
        HandleConfirm(Agent)
        CloseMenu(Agent)
```

Keep `var ButtonToAgent : [button_loud]agent = map{}` (or rebuild the map when
showing). Some projects use a helper that passes extra ints — search digest /
`helpers` patterns; do not invent signatures.

### Shop menu

Cookbook **panel + vertical shop lines**. Each buy button →
`GetGamePlayer` → `EconomyManager` check/charge → granter → `SyncShopUI` /
close. HUD feedback via `hud_message_device` optional (`sys_economy`).

### Collect / offline popup

Show calculated earnings text; Confirm credits `EconomyManager` then closes.
Used after offline calc (`sys_generators` offline section). Do **not** auto-grant
if you want an explicit Collect click.

### Input-mode / picker menus

Same modal pattern; on choice call another controller (e.g. camera input mode).
Optional open hotkey via `input_trigger_device` (`sys_input_devices`) while the
menu itself stays `.All`.

### Passive HUD vs menu

| | HUD (`sys_hud_template`) | Menu (this file) |
|--|--------------------------|------------------|
| InputMode | `.None` | `.All` |
| Buttons | none | `button_loud` / tabs |
| Lifetime | often whole session | open → act → close |

### Gotchas

- Visibility checklist still applies (`sys_canvas_cookbook`).
- Stacking two `.All` menus without removing the first confuses input.
- Look up buyer with `GetGamePlayer` — never assume the click agent is registered.
