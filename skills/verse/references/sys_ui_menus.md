---
description: "Interactive UI menus — modal popups, shops, collect screens with ui_input_mode.All, open/close, ButtonToAgent map (custom/controller buttons → sys_custom_buttons)"
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

**Whole-card / row / hover / gamepad:** load **`sys_custom_buttons` first**.
That file is the default button type (chrome-less native `button` + `SetFocus`).
Use stock `button_loud` / `button_quiet` only for plain text CTAs with Epic
chrome — not for painted cards/rows.

### Modal recipe

1. Build canvas: full-screen dim `color_block` + centered panel + title/body +
   action buttons (cookbook **modal**). Prefer `MakeUiLabelButton` /
   `MakeUiButton` from `sys_custom_buttons` (or project `ui_buttons.verse`).
2. Show — **SetFocus before AddWidget** (required for controller):

```verse
ShowMenu(Agent : agent) : void =
    if (Player := player[Agent], PlayerUI := GetPlayerUI[Player]):
        set MenuCanvas = BuildMenuCanvas()
        PlayerUI.SetFocus(ConfirmButton)   # or ConfirmUi.Btn — BEFORE AddWidget
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
Modal with **no** focusable buttons → `InputMode.None` (else gamepad soft-lock).

### Buttons

Default: chrome-less native `button` — see **`sys_custom_buttons`**.

Simple text CTA only:

```verse
var ConfirmButton : button_loud = button_loud{}
ConfirmButton.OnClick().Subscribe(OnConfirmClicked)
# still: PlayerUI.SetFocus(ConfirmButton) before AddWidget

OnConfirmClicked(WM : widget_message) : void =
    if (Agent := ButtonToAgent[ConfirmButton]):
        HandleConfirm(Agent)
        CloseMenu(Agent)
```

Keep `var ButtonToAgent : [button]agent = map{}` (or `[button_loud]agent` for
stock CTAs). Rebuild with `if (set …) {}` — avoid `ConcatenateMaps` on button
keys (widens to `widget`).

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
| InputMode | `.None` | `.All` (+ `SetFocus`) |
| Buttons | none | `sys_custom_buttons` (or plain `button_loud` CTA) |
| Lifetime | often whole session | open → act → close |

### Gotchas

- Visibility checklist still applies (`sys_canvas_cookbook`).
- Stacking two `.All` menus without removing the first confuses input.
- Look up buyer with `GetGamePlayer` — never assume the click agent is registered.
- Gamepad dead without `SetFocus` — see `sys_custom_buttons`.
