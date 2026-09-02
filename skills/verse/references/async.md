---
description: "Async vs synchronous Verse — what <suspends> means, structured concurrency (sync / race / rush / branch vs spawn), Sleep/Await, event subscriptions, and the rules for calling async code"
metadata:
  order: 5
  label: "Async & structured concurrency — suspends, sync, race, rush, branch, spawn"
  default_enabled: false
  load_condition: "Anything time-based or event-driven — loops with Sleep, spawn, branch, race, sync, rush, Await, waiting on events, or 'is this function async?'"
---

## Async vs synchronous — the `<suspends>` model

**The one rule that decides everything: a function is async iff it carries the
`<suspends>` effect.** Async code can pause (across frames/seconds) and resume;
sync code runs to completion in a single instant.

### What is async (`<suspends>`)

A `<suspends>` function may `Sleep`, `Await` events, and call other `<suspends>`
functions. It is how time passes.

```verse
OnBegin<override>()<suspends> : void =        # the entry point IS async
    Trigger.TriggeredEvent.Subscribe(OnActivated)
    branch{ GameLoop() }                      # background loop tied to OnBegin's scope

GameLoop()<suspends> : void =
    loop:
        Sleep(1.0)                            # pauses ~1 second, then resumes
        Tick()
```

| Call | Does |
|------|------|
| `Sleep(Seconds : float)<suspends>` | Pause this coroutine for N seconds. `Sleep(0.0)` yields one frame. |
| `SomeEvent.Await()` | Block until the event fires once. `GetPlayspace().PlayerRemovedEvent().Await()` |
| `spawn{ F() }` | Start `F` as an **independent** task; lifetime is **not** tied to the caller. |
| `branch{ F() }` / `branch:` | Start `F` in the background; **cancelled when the enclosing scope exits**. |
| `sync:` | Run every block concurrently; completes when **all** finish; evaluates to a tuple of their results. |
| `race:` | Run every block concurrently; completes when the **first** finishes; **cancels** the rest. |
| `rush:` | Run every block concurrently; completes when the **first** finishes; the rest **keep running** in the background. |

### What is NOT async

Plain functions and those marked `<transacts>` / `<computes>` are synchronous —
they **cannot** `Sleep` or `Await`, and they return in the same instant.

```verse
TakeDamage<public>(Damage : float)<transacts> : logic = …   # sync, rollback-safe
GetCount<public>()<transacts> : int = Count                 # sync getter
BuyWithCurrency(Agent : agent) : void = …                   # sync event handler
```

Event **handlers** you pass to `.Subscribe` are ordinary (sync) functions. If a
handler needs to wait, it starts an async task (below).

### The calling rules (this is where compiles fail)

1. A `<suspends>` call is only legal **inside another `<suspends>` context** — or
   inside a `spawn{}` / `branch{}` / `sync:` / `race:` / `rush:` block.
2. A `<suspends>` call can never sit in a failure context (`if (…)` head, `[]`).
3. To kick off async work from a **sync** function (like a subscribe handler), wrap
   it in `spawn`:

```verse
OnPlayerAdded(NewAgent : agent) : void =        # sync handler…
    spawn{ StartMouseTracking(NewAgent) }       # …launches async work
```

4. `OnBegin<override>()<suspends>` is your async root — start persistent loops
   from there.

### Structured concurrency — the four blocks

Structured concurrency guarantees that every concurrent operation started inside a
block is **managed and cleaned up before the block exits**. Prefer it over
fire-and-forget `spawn` whenever the work belongs to a scope.

**`sync:` — wait for all**

```verse
StartBossFight()<suspends> : void =
    sync:
        CloseArenaDoors()          # 3 s
        RevealBossAnimation()      # ~4 s
        PlayIntroMusic()           # 4 s
    EnableBossAI()                 # runs only after all three finished
    Print("Fight!")
```

`sync` evaluates to a tuple of each block's result if you need them.

**`race:` — first one wins, the rest are cancelled**

```verse
BoardGame()<suspends> : void =
    race:
        AwaitPlayerLeftGameEvent()   # if this finishes first…
        PlayBoardGame()              # …this is cancelled mid-way
    CleanUpGame()
```

The canonical use is "do X forever, but stop the instant Y happens".

**`rush:` — first one wins, the rest keep going**

```verse
SaveProgress(P : player)<suspends> : void =
    rush:
        SaveToLocal(P)
        SaveToCloud(P)               # still completes in the background
    ShowSavedNotification()          # shown as soon as the faster save finished
```

**`branch:` — background task owned by the scope**

```verse
RunRound()<suspends> : void =
    branch:
        HudCountdownLoop()           # cancelled automatically when RunRound returns
    RoundEndedEvent.Await()
```

### `spawn` vs `branch` — pick by lifetime

| | `spawn{}` | `branch{}` |
|--|-----------|------------|
| Lifetime | Independent of the caller; keeps running after the function returns | Bound to the enclosing scope; cancelled when it exits |
| Callable from | sync **or** async code | `<suspends>` code only |
| Use for | Handlers that must start async work; device-lifetime loops from `OnBegin` | Loops and watchers that belong to one phase, round, menu, or player session |

Inside a `<suspends>` function, default to `branch`. Reach for `spawn` only when the
task must outlive the current scope or when you are in a sync handler. A `spawn`
returns a `task(t)` you can `Await`; it has **no** `Cancel()` — use `race` or
`branch` when you need cancellation.

### Subscribing to events (the async trigger surface)

`.Subscribe(Handler)` registers a sync handler; the event calls it later. Two
shapes appear, depending on the API — an event **field** vs an event **accessor
method** `()`:

```verse
Button.InteractedWithEvent.Subscribe(BuyWithCurrency)        # device event field
Spawner.SpawnedEvent.Subscribe(OnPlayerAdded)                # payload: agent
GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerJoined)  # playspace: method() then .Subscribe; payload: player
FortChar.EliminatedEvent().Subscribe(OnEliminated)
```

Which form (field vs `()` method) and which payload type an event uses comes from
the **digest** — look it up. The handler's parameter must match the payload exactly
(`SpawnedEvent` gives `agent`; `PlayerAddedEvent()` gives `player`;
`input_trigger_device.ReleasedEvent` gives `tuple(agent, float)`). `.Subscribe`
returns a `cancelable`; keep it if you plan to `Cancel()` later.

### Passing extra data into a handler

`.Subscribe` handlers get a fixed signature. To smuggle in extra context, use a
small wrapper class: a `<unique>` class that stores `ExtraData` plus your
`OutputFunc`, and exposes an `InputFunc(Agent : agent)` (the subscribe shape) that
calls `OutputFunc(Agent, ExtraData)`. Subscribe with the wrapper's `InputFunc`. The
`subscribe_helpers` template pack ships these.

### Anti-patterns

| Wrong | Right |
|-------|-------|
| `Sleep` / `Await` in a non-`<suspends>` function | Add `<suspends>`, or move it into `spawn{}` / `branch{}` |
| Calling a `<suspends>` fn directly from a sync handler | `spawn{ AsyncFn() }` |
| `loop:` with no `Sleep`/`Await` | Yield every iteration (`Sleep(0.0)` at minimum) |
| Expecting a value back from `spawn` | `sync`/`race`, or `Await` the task / an event |
| Storing a `spawn` task to cancel it later | `race` against a stop event, or `branch` inside the owning scope |
| `spawn` for a per-round/per-menu loop | `branch` so it dies with the scope |
| Guessing `.SomeEvent` vs `.SomeEvent()` or its payload type | Check the event's shape in the digest |
