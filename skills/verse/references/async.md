---
description: "Async vs synchronous Verse — what <suspends> means, spawn/race/sync, Sleep/Await, event subscriptions, and the rules for calling async code"
metadata:
  order: 5
  label: "Async vs sync — suspends, spawn, race, Sleep"
  default_enabled: false
  load_condition: "Anything time-based or event-driven — loops with Sleep, spawn, race, Await, waiting on events, or 'is this function async?'"
---

## Async vs synchronous — the `<suspends>` model

**The one rule that decides everything: a function is async iff it carries the
`<suspends>` effect.** Async code can pause (across frames/seconds) and resume;
sync code runs to completion in a single instant.

### What is async (`<suspends>`)

A `<suspends>` function may `Sleep`, `Await` events, and call other `<suspends>`
functions. It's how time passes.

```verse
OnBegin<override>()<suspends> : void =        # the entry point IS async
    Trigger.TriggeredEvent.Subscribe(OnActivated)
    spawn{ GameLoop() }

GameLoop()<suspends> : void =                 # a custom async routine
    loop:
        Sleep(1.0)                            # pauses ~1 second, then resumes
        Tick()
```

Async building blocks (all require a `<suspends>` context):

| Call | Does |
|------|------|
| `Sleep(Seconds : float)` | Pause this coroutine for N seconds, then continue. `Sleep(0.0)` yields one frame. |
| `SomeEvent.Await()` | Block until the event fires once, then continue. `GetPlayspace().PlayerRemovedEvent().Await()` |
| `spawn{ AsyncFn() }` | Start `AsyncFn` as a **new independent coroutine** and keep going immediately (fire-and-forget). |
| `race:` | Run several async blocks in parallel; **first to finish wins**, the rest are cancelled. |
| `sync:` | Run several async blocks in parallel; wait for **all** to finish. |

### What is NOT async

Plain functions and those marked `<transacts>` / `<computes>` are synchronous —
they **cannot** `Sleep` or `Await`, and they return in the same instant.

```verse
TakeDamage<public>(Damage : float)<transacts> : logic = …   # sync, rollback-safe
GetCount<public>()<transacts> : int = Count                 # sync getter
BuyWithCurrency(Agent : agent) : void = …                   # sync event handler
```

Event **handlers** you pass to `.Subscribe` are ordinary (sync) functions —
`OnPlayerAdded(Player : player) : void`. If a handler needs to wait, it `spawn`s
an async routine (below).

### The calling rules (this is where compiles fail)

1. A `<suspends>` call is only legal **inside another `<suspends>` context** — or
   inside a `spawn{ }` / `race:` / `sync:` block.
2. To kick off async work from a **sync** function (like a subscribe handler),
   wrap it in `spawn`:

```verse
OnPlayerAdded(Player : player) : void =        # sync handler…
    spawn{ StartMouseTracking(Player) }        # …launches async work
```

3. `OnBegin<override>()<suspends>` is your async root — start persistent loops
   from there with `spawn`.

### `spawn` — background coroutines

Each `spawn` is independent and runs concurrently. The project uses this to run
several loops at once:

```verse
OnBegin<override>()<suspends> : void =
    spawn{ GameLoop() }
    spawn{ SpawningLoop() }
    spawn{ MovementLoop() }
```

`spawn` returns immediately; it does **not** wait for the block. Don't rely on a
spawned result — if you need the value, `Await` an event it fires or use `race`/`sync`.

### `race:` — first one wins, cancel the rest

The canonical use is "do X forever, but stop the instant Y happens":

```verse
race:
    loop:                                       # branch A: track forever
        Sleep(0.0)
        UpdateCameraTargetFromMouse(FC)
    GetPlayspace().PlayerRemovedEvent().Await()  # branch B: player left
# whichever finishes first cancels the other; execution continues here
```

Each top-level statement under `race:` is one competing branch.

### `sync:` — wait for all (language-standard)

```verse
sync:
    LoadPartA()
    LoadPartB()
# continues only after BOTH finish
```

(`race`/`spawn`/`loop`/`Sleep`/`Await` are the everyday set; `sync`, `rush`, and
`branch` are the same family from the standard library if you need "all",
"start-and-detach with a result", or "fork" semantics.)

### Subscribing to events (the async trigger surface)

`.Subscribe(Handler)` registers a sync handler; the event calls it later. Two
shapes appear, depending on the API — a plain event **field** vs an event
**accessor method** `()`:

```verse
Button.InteractedWithEvent.Subscribe(BuyWithCurrency)        # device event field
Spawner.SpawnedEvent.Subscribe(OnPlayerAdded)
GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)   # playspace: method() then .Subscribe
FortChar.EliminatedEvent().Subscribe(OnEliminated)
```

Which form (field vs `()` method) an event uses comes from the **digest** — look
it up, don't guess. `.Subscribe` returns a `cancelable`; keep it if you plan to
`Cancel()` later.

### Passing extra data into a handler

`.Subscribe` handlers get a fixed signature (usually `(agent)` or `(?agent)`). To
smuggle in extra context, use a small wrapper class: a `<unique>` class that stores
`ExtraData` plus your `OutputFunc`, and exposes an `InputFunc(Agent : agent)` (the
right subscribe shape) that calls `OutputFunc(Agent, ExtraData)`. Subscribe with the
wrapper's `InputFunc`. Build these once as generic helpers and reuse them.

### Anti-patterns

| Wrong | Right |
|-------|-------|
| `Sleep` / `Await` in a non-`<suspends>` function | Add `<suspends>`, or move it into a `spawn{}` |
| Calling a `<suspends>` fn directly from a sync handler | `spawn{ AsyncFn() }` |
| `loop:` with no `Sleep`/`Await` | Yield every iteration (`Sleep(0.0)` at minimum) |
| Expecting a value back from `spawn` | `race`/`sync`, or `Await` an event it raises |
| Guessing `.SomeEvent` vs `.SomeEvent()` | Check the event's shape in the digest |
