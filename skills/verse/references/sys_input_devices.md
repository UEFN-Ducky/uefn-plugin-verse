---
description: "Input devices — input_trigger_device Register/Unregister, Pressed/Released, held-key repeat, and when to use Creative triggers vs UI buttons"
metadata:
  order: 36
  label: "Game systems — input devices (InputManager)"
  default_enabled: false
  load_condition: "Wiring input_trigger_device, Register/Unregister per agent, held movement keys, or choosing UI buttons vs Creative input triggers"
---

## Input devices — InputManager territory

Creative **input triggers** route hardware/keybinds to Verse **without** capturing
the UI. Interactive menus use Verse buttons instead (`sys_ui_menus`). Confirm
member names with `search_verse_digest`.

### Decision tree

| Need | Approach | InputMode on canvas |
|------|----------|---------------------|
| Click shop / collect / tabs | `button_loud` on canvas | `ui_input_mode.All` |
| Move piece, hold-to-spawn, hotkey exit | `input_trigger_device` | HUD/board often `.None` |
| World interact (enter station) | `button_device.InteractedWithEvent` | n/a |

Never mix: do not expect UI buttons to work on a `.None` canvas, and do not
expect input triggers to replace modal clicks.

### input_trigger_device pattern

```verse
@editable MoveLeft : input_trigger_device = input_trigger_device{}
@editable MoveRight : input_trigger_device = input_trigger_device{}
@editable ActionConfirm : input_trigger_device = input_trigger_device{}

OnBegin<override>()<suspends> : void =
    MoveLeft.PressedEvent.Subscribe(OnLeftPressed)
    MoveLeft.ReleasedEvent.Subscribe(OnLeftReleased)
    # … same for other triggers
```

### Register / Unregister per agent

Triggers are shared devices; **register** the agent when their session starts and
**unregister** on exit / leave / game-over:

```verse
StartSession(Agent : agent) : void =
    MoveLeft.Register(Agent)
    MoveRight.Register(Agent)
    ActionConfirm.Register(Agent)

EndSession(Agent : agent) : void =
    MoveLeft.Unregister(Agent)
    MoveRight.Unregister(Agent)
    ActionConfirm.Unregister(Agent)
```

Route the event to the correct per-player instance via
`PlayerManager.GetGamePlayer(Agent)` or an `[agent]minigame_instance` map
(`sys_minigame_overlay`).

### Held-key repeat

```verse
var MovingLeft : logic = false
var LastMoveTime : float = 0.0
MoveRepeatDelay : float = 0.15

OnLeftPressed(Agent : agent) : void =
    set MovingLeft = true
    TryMoveLeft(Agent)                    # immediate step

OnLeftReleased(Agent : agent) : void =
    set MovingLeft = false

# inside your Sleep game loop:
if (MovingLeft?):
    Now := GetSimulationElapsedTime()
    if (Now - LastMoveTime >= MoveRepeatDelay):
        TryMoveLeft(Agent)
        set LastMoveTime = Now
```

### Hold-to-spawn / continuous action

Same idea: Pressed starts `spawn{ ContinuousLoop(Agent) }`; Released sets a
`logic` flag the loop checks to `break`. Used by prop spawners
(`sys_spawning`).

### Gotchas

- Forgetting `Unregister` leaks input to agents who left the minigame.
- Subscribing once in `OnBegin` is enough; Register only enables that agent.
- Confirm `Register` / `Unregister` / event names in the digest — do not invent.
