---
description: "Verse language reference — types, effects, control flow, classes, concurrency"
metadata:
  order: 2
  label: "Verse syntax reference"
  default_enabled: false
  load_condition: "Writing non-trivial Verse — control flow, classes/structs, options/failure, or concurrency"
---

## Verse syntax reference (cheat-sheet)

Language syntax below is stable. **API names, types, and signatures are not here —
confirm those in the `digests` reference**, and let `workspace_list_verse_errors`
catch mistakes.

This is the one-page quick reference. For depth, load the topic file: **`classes`**
(specifiers, members, subclassing), **`control_flow`** (if/for/loop/case),
**`async`** (suspends/spawn/race/Sleep — async vs not), **`effects`**
(failure/options), **`devices`** (`@editable`/events/agents), **`datatypes`**
(containers/math), **`persistence`** (weak_map), **`ui`** (canvas/widgets),
**`modules`** (using/module layout).

### Bindings & mutation
- `X := expr` — immutable definition (type inferred).
- `X : t = expr` — typed constant; `var X : t = expr` — mutable, reassign with `set X = expr`.
- Compare with `=` (equal) and `<>` (not equal) inside a failure context, e.g. `if (A = B):`.

### Types
- Scalars: `int`, `float`, `logic` (`true`/`false`), `string`, `char`, `void`, `any`.
- `[]t` array, `[k]v` map, `?t` option, `tuple(a, b)`. Array index and `Map[Key]` are **failable**.
- `option`: empty `false`, or a value; unwrap with `X?` (fails if empty). Build with `option{X}`.

### Effects (on a function, in `<>`)
`<suspends>` async · `<decides>` can fail (must be called in a failure context) ·
`<transacts>` rollback-safe · `<computes>` pure. Access: `<public> <private> <internal>
<protected>`; also `<override> <final> <native> <constructor>`.

### Control flow (blocks are `:` + indent, or `{ …; … }`)
```verse
if (Cond):
    DoThing()
else:
    DoOther()

for (Item : Collection):
    Print("{Item}")

for (I := 0..9):        # inclusive range
    Use(I)

loop:
    if (Done?):
        break
```
- `case (X):` with `Pattern => expr` branches and `_ =>` default.
- `return X` exits a function; string interpolation is `"{Expr}"`.

### Classes / structs / enums / interfaces
```verse
my_widget := class:
    var Count : int = 0
    Bump():void = set Count = Count + 1

point := struct:
    X : float
    Y : float

team := enum { Red, Blue }

healer := interface:
    Heal(Agent : agent):void
```
- Subclass a device: `my_device := class(creative_device):`. Instantiate: `point{X := 1.0, Y := 2.0}`.
- UEFN entry point is `OnBegin<override>()<suspends>:void =` on a `creative_device`.
- `@editable Field : trigger_device = trigger_device{}` exposes a Details-panel device ref (wire it in UEFN, or with `wire_verse_device_ref` when online).

### Concurrency (inside a `<suspends>` context)
- `spawn { AsyncFn() }` — fire-and-forget a `<suspends>` call.
- `sync { A(); B() }` (run all, wait for the last) · `race { A(); B() }` (first to finish wins) · `rush`, `branch`.
- `Sleep(Seconds : float)<suspends>` waits. Subscribe to events: `Device.SomeEvent.Subscribe(Handler)` — event and handler shapes come from the digest.
