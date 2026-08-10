---
description: "Custom chrome-less Verse buttons — whole-card/row hit targets, hover + controller focus (SetFocus), locked-but-focusable cards, shared ui_buttons pattern"
metadata:
  order: 36
  label: "Game systems — custom buttons & controller UI"
  default_enabled: false
  load_condition: "Building custom Verse UI buttons, whole-card/row click targets, hover chrome, gamepad/controller navigation, SetFocus, or ui_buttons.verse"
---

## Custom buttons & controller UI

**Default for any interactive Verse canvas with custom chrome** (painted cards,
list rows, modals, tabs). Layout still comes from `sys_canvas_cookbook`;
open/close lifetime from `sys_ui_menus` — but the **clickable widget type is
this file**, not bare `button_loud`.

Stock `button_loud` / `button_quiet` / `button_regular` are OK only for plain
text CTAs with Epic chrome. They look wrong for whole-card/row UIs and teach
nothing about hover/lock/selected skins.

### What UI to make (exact type)

Use a **chrome-less native** `/UnrealEngine.com/Temporary/UI` `button` whose
`button_slot.Widget` is your painted card (overlay of `color_block` border/fill
+ content). Skin is 100% Verse widgets — **not** a Widget Blueprint unless the
project already has a real Assets-digest WBP class.

```
button
  └─ button_slot
       └─ overlay  (the card)
            ├─ color_block  border
            ├─ color_block  fill
            └─ content OR centered text_block
```

Prefer a project shared module (e.g. `Content/Verse/ui_buttons.verse`) when
present: factories like `MakeUiButton` / `MakeUiLabelButton` plus named style
helpers. If missing, copy the pattern into the project (do not invent a second
parallel API per screen).

### Why this exists

- Mouse clicks work on any `button`; **gamepad does not** until something is
  focused via `player_ui.SetFocus`.
- Epic forum “turn on Is Focusable on the WBP root” only applies when the
  `button{}` wraps a **Widget Blueprint**. Pure Verse skins have no IsFocusable
  flag — the native `button` itself is the focusable element.
- Digest: `SetFocus` may be called **before** `AddWidget`; focus applies after
  mount. Target must be focusable or the call is a no-op.

### Recipe A — label button (text CTA)

```verse
using { /UnrealEngine.com/Temporary/UI }
using { /Fortnite.com/UI }

# Prefer MakeUiLabelButton(PrimaryStyle(), "CONFIRM") when a shared module exists.
Ui := MakeUiLabelButton(PrimaryStyle(), "CONFIRM")
if (set Owners[Ui.Btn] = Agent) {}
Ui.Btn.OnClick().Subscribe(OnConfirmClicked)
# put Ui.Btn into the canvas tree
```

### Recipe B — whole-card / whole-row button

Paint content first, wrap with `MakeUiButton(Style, Content)`:

```verse
CardBody := stack_box:
    Orientation := orientation.Vertical
    Slots := array:
        stack_box_slot{Widget := TitleTB}
        stack_box_slot{Widget := SubTB}
CardBtn := MakeUiButton(CardStyle(), CardBody)
CardBtn.Btn.OnClick().Subscribe(OnCardClicked)
# canvas_slot / stack_box_slot Widget := CardBtn.Btn
```

**Hit-overlay variant** (painted chrome underneath, transparent full-size
`button` on top): keep visual `color_block`s as siblings;
`button.SetWidget(button_slot{ Widget := color_block{ DefaultOpacity := 0.0, … } })`
fills the region so the whole card/row is the click/focus target.

### Show path checklist (HARD — controller)

Every interactive screen:

1. Build canvas + buttons.
2. **`PlayerUI.SetFocus(FirstMeaningfulBtn)`** — selected row/card if known,
   else first button, else close/confirm.
3. **`PlayerUI.AddWidget(Canvas, player_ui_slot{ InputMode := ui_input_mode.All })`**
4. Subscribe `OnClick` (and map `button → agent` / index).
5. On **every canvas rebuild** (filter change, soft-replace): SetFocus again
   before AddWidget.
6. Modal with **zero** focusable buttons → use `InputMode.None` (`.All` soft-locks
   the gamepad). Never leave `.All` up after close.

```verse
ShowMenu(Agent : agent) : void =
    if (Player := player[Agent], PlayerUI := GetPlayerUI[Player]):
        Hide(Agent)
        Canvas := Builder.CreateCanvas()
        PlayerUI.SetFocus(Builder.ConfirmBtn)   # BEFORE AddWidget
        PlayerUI.AddWidget(Canvas, player_ui_slot{ InputMode := ui_input_mode.All })
```

### Hover / focus visuals

Native `button` exposes:

- `OnClick()`
- `HighlightEvent()` / `UnhighlightEvent()` — fire for mouse hover **and**
  gamepad focus

Wire both to skin updates (`Hot = true/false` → `ApplyVisual`). Selected state
is separate (`SetSelected(logic)`).

**Locked cards stay focusable.** Dim the fill (`SetOpacity(0.55)` literals) and
swap to lock colours — do **NOT** call `Btn.SetEnabled(false)` (D-pad would skip
them). When `Locked` and (`Hot` or `Selected`), still light the selection border
so the player can see they are ON the locked card.

### Selected / comparison traps (Verse)

| Trap | Fix |
|------|-----|
| `SetSelected(A = B)` — `=` is `decides` | `var Flag : logic = false` then `if (A = B): set Flag = true` then `SetSelected(Flag)` |
| Style factory as class field default | Divergent (3582) — use a **literal** `ui_btn_style{…}` default |
| `FillOpacity : float` then `SetOpacity(Style.FillOpacity)` | Constrained 0..1 — pass **literals** only (`0.55`, `1.0`) |
| `ConcatenateMaps` on `[button]T` | Key widens to `widget` — use `if (set Keep[B] = V) {}` |
| Custom `float01` type alias for opacity | Incompatible with digest constraint — don't |

### Button maps

```verse
var Owners : [button]agent = map{}
var SelectButtons : [button]int = map{}

if (set Owners[Ui.Btn] = Agent) {}
if (set SelectButtons[Ui.Btn] = Index) {}

OnClicked(WM : widget_message) : void =
    if (Btn := button[WM.Source], Agent := Owners[Btn], Idx := SelectButtons[Btn]):
        Handle(Agent, Idx)
```

### UMG / WBP exception (only if you really use a WBP skin)

1. Root User Widget: **Is Focusable = true**, set Desired Focus Widget.
2. Wrap with Verse `button{ Slot := button_slot{ Widget := MyWBP{} } }`.
3. Still call `SetFocus` on the Verse `button` (or the WBP if that is what you
   add). Types must exist in the Assets digest — never invent `WB_*` classes.

### Do / don’t

| Do | Don’t |
|----|--------|
| Native `button` + painted `button_slot` content | Nested “select” mini-buttons under a card |
| `SetFocus` before every interactive `AddWidget` | Assume first button auto-focuses on gamepad |
| `HighlightEvent` for hover + controller | Mouse-only hover hacks |
| Locked = dim chrome, still focusable | `SetEnabled(false)` on locked cards |
| Opacity literals | `float` fields into `SetOpacity` |
| `if (set Map[Btn] = …)` for `[button]` maps | `ConcatenateMaps` that widens to `[widget]` |
| One shared button helper module | One-off button classes per screen |

### Codegen (if the project generates Verse UI)

Generated modal show wrappers should emit
`PlayerUI.SetFocus(Builder.<FirstBtn>)` before `AddWidget` when a button is
bound; buttonless modals should use `InputMode.None`. Keep a small assert in
your codegen tests if you have them.

### Related

- Layouts: `sys_canvas_cookbook`
- Modal lifetime / `.All`: `sys_ui_menus` (read this file first for the button type)
- HUD (non-interactive): `sys_hud_template` + `InputMode.None`
- UMG path: `umg_widgets` / `umg_verse_field_events`
