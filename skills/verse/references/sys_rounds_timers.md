---
description: "Round flow & timers — the game state machine (phase functions chained by events), custom timer devices with typed events, and real delta-time loops with GetSimulationElapsedTime"
metadata:
  order: 25
  label: "Game systems — rounds, phases & timers"
  default_enabled: false
  load_condition: "Building match/round flow, game phases/state machine, countdowns, or a custom timer with events"
---

## Rounds, phases & timers

Names below are generic — a round game usually alternates an **active** phase and a
**hold** phase; rename to fit your mode.

### The game state machine (phase functions + events)

Instead of a formal state enum, the match is a chain of **phase functions**, each of
which sets up its phase, starts a timer, and the timer's finished-event calls the
next phase. `OnBegin` bootstraps; loops run in `spawn`:

```verse
match_controller := class(creative_device):
    var RoundStarted : logic = false
    var EndingStarted : logic = false

    StartRound<public>(InstigatorAgent : ?agent) : void =
        set RoundStarted = true
        if (Level := ActiveLevel?):
            Level.StartBarrierDevice.Disable()
            RoundTimers.RoundTimer.Reset(); RoundTimers.RoundTimer.Start()
            spawn{ RoundTimerLoop() }          # HUD countdown loop
            StartActivePhase(InstigatorAgent)   # → enter first sub-phase

    StartHoldPhase<public>(InstigatorAgent : ?agent) : void =
        if (EndingStarted = true): return       # guard: don't chain past the end
        RoundTimers.HoldPhaseTimer.Reset(); RoundTimers.HoldPhaseTimer.Start()
        for (Event : PhaseChangedEvent): Event()    # notify subscribers
        spawn{ HoldPhaseLoop() }
        # StartActivePhase will be called again when this phase's timer ends
```

Principles that keep this manageable:

- **One function per phase** (`StartRound` → `StartActivePhase` → `StartHoldPhase` →
  … → ending → results). Each does setup + start-timer; the timer's finished event
  advances to the next.
- **Boolean guards** (`RoundStarted`, `EndingStarted`) stop double-entry and stop
  chaining once the match ends.
- **`spawn` the per-phase loops** (movement, HUD tick, phase cycling) so they run
  concurrently; a phase change flips a flag that lets the loop `break`.
- Snapshot teams into arrays (`TeamA`, `TeamB`) at round start and drive the phase
  from those (see `sys_teams`).

Store round-scoped devices in `struct<concrete>` bundles so one `@editable` exposes
them all (`round_timers`, `team_a_devices`, `team_b_devices`).

### Custom timer device

A reusable countdown/count-up device with `@editable` config, per-player HUD, and a
**typed event bus** (same pattern as `sys_player_data`):

```verse
timer_started  <public> := type{_(CurrentTime : float):void}
timer_finished <public> := type{_(FinalTime : float):void}

custom_timer_device := class(creative_device):
    @editable var TimerDuration : float = 15.0
    @editable CountDown : logic = true
    var IsRunning <public> : logic = false
    var CurrentTime : float = 0.0
    var TimerFinishedEvents <private> : []timer_finished = array{}

    SubscribeTimerFinished<public>(Event : timer_finished) : void =
        set TimerFinishedEvents += array{Event}
```

Consumers wire phase advancement to the finished event:
`RoundTimers.HoldPhaseTimer.SubscribeTimerFinished(OnHoldPhaseDone)`.

### Real delta-time loops

Time a loop off the wall clock with `GetSimulationElapsedTime()` and subtract a
delta each tick — don't assume `Sleep` is exact:

```verse
RunTimer()<suspends> : void =
    if (RunTimerIsRunning?): return          # single-instance guard
    set RunTimerIsRunning = true
    var LastTime : float = GetSimulationElapsedTime()
    loop:
        if (IsRunning = false): break         # external stop
        if (CountDown? and CurrentTime <= 0.0):
            for (Event : TimerFinishedEvents): Event(CurrentTime)   # fire, then
            set IsRunning = false; break                            # stop
        Now := GetSimulationElapsedTime()
        set CurrentTime -= (Now - LastTime)   # advance by real delta
        set LastTime = Now
        UpdateTimerUI()
        Sleep(0.0)                            # yield one frame — required
```

Patterns to copy:

- **Single-instance guard** (`RunTimerIsRunning`) so `Start()` twice doesn't run two
  loops.
- **Fire the finished event, then set `IsRunning = false` and `break`.**
- **`Sleep(0.0)` every iteration** to yield — a loop with no yield hangs the game
  (see `async`).
- Only fire per-second events when `Floor[CurrentTime]` changes
  (`LastSecondFired`) to avoid spamming subscribers every frame.

### Countdowns you don't need to hand-roll

For simple waits, the Fortnite `timer_device` (from the digest) has
`Start`/`SuccessEvent`. Use the custom device when you need per-player HUD, count-up,
or your own event payloads; use the built-in when a plain countdown will do.
