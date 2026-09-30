---
description: "UMG gamepad focus — IsFocusable, explicit navigation, SetFocus before AddWidget, InputMode.None when nothing is focusable"
metadata:
  order: 71
  label: "UMG navigation"
  default_enabled: false
  load_condition: "Gamepad or controller focus on a UMG menu or Custom Button"
---

## UMG navigation

Verse `button_loud` / `button_quiet` / `button_regular` are focusable and play Fortnite sounds. A UMG Custom Button (`UIFrameworkCustomButtonWidget`) needs `IsFocusable` or it only takes the mouse.

Set explicit navigation (up / down / left / right) when the buttons are not in a single stack the designer can auto-wrap. `list_bindable_properties` shows `IsFocusable` and `SetUserFocus`.

Device rules, same as Verse menus:

1. `PlayerUI.SetFocus` on the first control **before** `AddWidget`.
2. Menus: `player_ui_slot{ InputMode := ui_input_mode.All }`.
3. HUD with no click: `ui_input_mode.None`.
4. A modal with zero focusable widgets must use `InputMode.None`. `.All` with nothing to focus soft-locks the gamepad.

One widget instance per player. Focus the instance you just added, not a shared widget.
