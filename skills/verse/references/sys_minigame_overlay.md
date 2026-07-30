---
description: "Overlay minigames — per-agent instance map, stasis, dynamic canvas grid, input_trigger movement, game loop, cleanup"
metadata:
  order: 38
  label: "Game systems — overlay minigame / grid board (MinigameController)"
  default_enabled: false
  load_condition: "Building an on-screen overlay or grid minigame — dynamic color_block cells, stasis, input triggers, per-player game instances"
---

## Overlay minigame — MinigameController

A full-screen (or panel) game that runs **on the UI** while the character is
frozen in the world. Layout cells: `sys_canvas_cookbook` dynamic board. Input:
`sys_input_devices`. Names are generic.

### Pieces

```
minigame_device (creative_device)
  @editable PlayerManager, EnterButton, input_trigger_devices…
  var Games : [agent]minigame_instance = map{}

minigame_instance (class<unique> or concrete+unique)
  grid state, canvas, piece state, GameLoop
```

### Enter / exit

1. Player hits world `button_device` → create instance if under `MaxConcurrent`.
2. `PutInStasis` + optional `Hide()` on `fort_character` (confirm digest APIs).
3. Build canvas, `AddWidget(..., ui_input_mode.None)`.
4. `Register` movement/exit input triggers for that agent.
5. `spawn{ GameLoop() }`.
6. Exit trigger / game-over → unregister, `RemoveWidget`, clear cells,
   `ReleaseFromStasis`, `Show()` character, drop map entry.

### Dynamic grid on canvas

```verse
# After AddWidget of root canvas:
InitializeCells() : void =
    for (Row := 0..Rows - 1):
        for (Col := 0..Cols - 1):
            Block := color_block{ DefaultDesiredSize := vector2{X := CellW, Y := CellH} }
            Slot := canvas_slot:
                Anchors := CellAnchors(Col, Row)   # map grid → normalized rect
                Widget := Block
            MyCanvas.AddWidget(Slot)
            # store Block in GridBlocks[Row][Col] if you mutate later
```

Falling / active piece: separate `[]color_block` added/removed each tick.
Locked board: rebuild cell widgets or update colors — prefer minimal rebuilds.

### Game loop

```verse
GameLoop<private>()<suspends> : void =
    loop:
        if (not Playing?):
            break
        Sleep(TickSeconds)          # e.g. 0.05
        ApplyHeldMovement()         # flags from input_trigger Pressed/Released
        StepGravityOrLogic()
        RefreshPieceDisplay()
```

### Cross-mode cleanup

Expose `KickPlayerOut(Agent)` / `KickAllPlayersOut()` so other modes (match
start) can eject minigame players. On `PlayerRemoved`, always cleanup that agent’s
instance.

### Gotchas

- Capacity: refuse enter when `Games` length >= max.
- `.None` + input triggers — not UI buttons — for movement.
- Unregister inputs even on crash paths / leave.
- Confirm stasis / Hide / AddWidget cell APIs in the digest.
