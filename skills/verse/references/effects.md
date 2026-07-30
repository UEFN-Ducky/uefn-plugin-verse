---
description: "Effect specifiers (<suspends> <decides> <transacts> <computes> <localizes> …), the failure model, <decides> functions called with [], and option handling"
metadata:
  order: 6
  label: "Effects, failure & options"
  default_enabled: false
  load_condition: "Choosing effect specifiers for a function, calling a failable [] function, or handling options (?t, X?, option{})"
---

## Effects, failure & options

An effect in `<>` after a function's parameter list declares **what the function
is allowed to do**. The compiler enforces them, so pick the narrowest that fits.

### Effect specifiers

| Effect | Means | Example |
|--------|-------|---------|
| `<suspends>` | **Async** — may `Sleep`/`Await`, runs across time. See the `async` reference. | `OnBegin<override>()<suspends>`, `GameLoop()<suspends>` |
| `<decides>` | **Can fail** — must be *called in a failure context*; on failure it rolls back. Reads like a query that might not have an answer. | Implicit in `[]` calls like `Map[Key]`, `player[Agent]`, `Floor[Hours]` |
| `<transacts>` | Runs inside a transaction (rollback-safe); can be used where state may be rolled back. Most pure-ish getters/mutators use this. | `TakeDamage(...)<transacts>`, `GetCurrency(...)<transacts>` |
| `<computes>` | **Pure** — deterministic, no side effects, no world reads. |  |
| `<converges>` | Guaranteed to terminate. |  |
| `<localizes>` | Produces a localizable `message` (for on-screen text). | `Message<localizes>(String : string):message="{String}"` |
| `<constructor>` | Function builds an instance via an archetype body. | `MakePlayerWallet<constructor>(…) := player_wallet:` |

Access specifiers live in the same `<>` slot: `<public> <private> <internal>
<protected>`, plus `<override> <final> <native>`. Order them after the name:

```verse
RunPrizeSelection<private>(Agent : agent)<suspends> : void = …
GetTotalPlayTime<public>(Agent : ?agent)<transacts> : float = …
```

### The failure model — `<decides>` and `[]`

Verse has no exceptions. Instead, some expressions **fail** (produce nothing) and
that failure *chooses a branch*. A `<decides>` function is one that can fail; you
**invoke it with square brackets** `[]` inside a failure context:

```verse
Player.IsActive[]                 # <decides> — succeeds or fails the branch
Floor[Hours]                      # <decides> float→int, binds on success
if (Value := Floor[Hours]):
    set TempHours = Value
```

Container access is failable in the same way:

```verse
AllPlayers[Agent]                 # map lookup — fails if key absent
Buttons[Index]                    # array index — fails if out of range
YPR[0]                            # tuple/array element
```

A **failure context** is the only place a failable expression may run:
`if (…)`, `for (…)`, the `if:` block head, a `[]`-indexed subexpression, or the
body of another `<decides>`/`<transacts>` function that propagates the failure.

```verse
if (RandomSpawner := AllPlayerSpawners[GetRandomInt(0, AllPlayerSpawners.Length - 1)]):
    Teleport(RandomSpawner)       # only runs if the index succeeded
```

Writing a failable lookup **outside** a failure context is the most common
compile error — wrap it in `if`.

### Options — `?t`

An option is "a value or nothing": type `?t`, empty literal `false`.

```verse
var CurrentTarget : ?spawned_enemy_prop = false   # start empty
set CurrentTarget = option{Prop}                   # wrap a value
if (Target := CurrentTarget?):                     # unwrap; branch only if present
    Fire(Target)
```

- `?t` — option type. `?agent`, `?fort_character`, `?player_manager`.
- `false` — the empty option.
- `option{X}` — build an option holding `X`.
- `X?` — unwrap; **fails** (in a failure context) if empty. `Agent?`,
  `CurrentNavPoint?`.
- `@editable MaybePlayerManager <public> : ?player_manager = false` — an optional
  editor reference the designer may leave unset; unwrap with `?` before use.

### Returning success/failure from your own function

Give it `<decides>` and let the body's failable expressions decide, or return a
`logic`. Returning `logic` for yes/no with `<transacts>` is a common, simple choice:

```verse
MapContains(Map : [int]logic, Key : int)<transacts> : logic =
    if (Map[Key]?) then return true else return false
```

For a true `<decides>` query you'd omit the bool and just let the lookup fail,
then call it with `[]`.

### Choosing effects — quick guide

- Waits on time or events → `<suspends>`.
- Pure read that can't fail → `<computes>` (or nothing).
- Read/mutate that should be rollback-safe → `<transacts>`.
- A query that might have no answer → `<decides>`, call with `[]`.
- Produces on-screen text → `<localizes>` returning `message`.
