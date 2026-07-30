---
description: "How to declare classes, structs, enums, interfaces — every specifier, members, methods, subclassing, parametric types"
metadata:
  order: 3
  label: "Classes, structs, enums & specifiers"
  default_enabled: false
  load_condition: "Creating or subclassing a class/struct/enum/interface, or unsure which class specifier (<concrete>/<unique>/<final>/<persistable>) to use"
---

## Classes, structs, enums, interfaces

Everything here matches the project's own `Verse/**` files — the shapes below
compile. **API type names still come from the digests**, only the *syntax* is here.

### The definition operator

A type is a name bound with `:=` to a `class`/`struct`/`enum`/`interface`/`module`
body. The body is `:` + indent, **or** `{ … }` braces — both are valid Verse.

```verse
my_thing := class:            # indent style
    Field : int = 0

my_thing := class{ Field : int = 0 }   # brace style — same thing
```

### class — the specifier menu

```verse
name <accessor> := class<spec><spec>(Superclass, Interface…):
    <members>
```

Specifiers and what each buys you:

| Specifier | Meaning / when to use |
|-----------|-----------------------|
| `class(creative_device)` | **A placed device.** Subclass of `creative_device`; gets `OnBegin`, shows in UEFN with `@editable` fields. `player_manager := class(creative_device):` |
| `class(tag)` | A **tag** for `GetCreativeObjectsWithTag` / prop queries. Empty body: `collectable_coins := class(tag){}` |
| `class()` / `class:` | Plain class — a helper/manager you `new` yourself. `save_service := class():` |
| `<concrete>` | **Every field has a default**, so it can be made with `{}` and used as an `@editable` struct or array element. `tower_data := class<concrete>():` |
| `<unique>` | **Reference identity** — instances are distinct and comparable/allocated; needed for stateful helper objects. `game_player := class<unique>():` |
| `<final>` | Cannot be subclassed. Pair with `<persistable>`. |
| `<persistable>` | Instances can be stored in a `weak_map` and survive between sessions. **Must** be `<final>` and hold only persistable data. `player_level := class<final><persistable>:` → see the `persistence` reference. |
| `<abstract>` | Cannot be instantiated directly — only subclassed. |
| `<transacts>` | Instances are usable inside `<transacts>` contexts (rollback-safe). Combines as `class<concrete><unique><transacts>()`. |

Specifiers stack: `mini_game_instance := class<concrete><unique><transacts>():`.

### Members: data & methods

```verse
top_hud_system := class<unique>():
    # immutable field, has a default → part of a <concrete> archetype
    MaxCount : int = 10
    # mutable field — reassign later with `set`
    var Count : int = 0
    # @editable → shows in the UEFN Details panel (device classes only)
    @editable Trigger : trigger_device = trigger_device{}
    # method: Name<access>(params)<effects> : ret = body
    Bump<public>() : void = set Count = Count + 1
    GetCount<public>()<transacts> : int = return Count
```

- Access specifiers: `<public> <private> <internal> <protected>` (default is
  most-restrictive within the module). Put them right after the name:
  `AddKill<public>(): void = …`.
- `var` = mutable; without `var` the field is a constant. `@editable var Price : int = 100`
  is both editor-exposed **and** mutable.
- One-line methods: `ResetKills<public>(): void = set KillCount = 0`.

### Instantiating (the archetype `{ … }`)

Make an instance by writing the type name then `{ FieldName := Value, … }`. Fields
with defaults may be omitted:

```verse
point{X := 1.0, Y := 2.0}       # set fields
player_level{}                  # all-default (needs every field defaulted)
texture_block{ DefaultImage := Textures.T_Empty }   # override one field
```

Containers use the same form: `array{}`, `map{}`, `array{A, B}`.

### `<constructor>` functions (custom makers)

A function that returns a fresh instance can be a `<constructor>`; it uses the
archetype body form (`:= type:`), which lets it set fields positionally:

```verse
MakePlayerWallet<constructor>(OldWallet: player_wallet, NewCurrencies: []currency_data) <transacts> := player_wallet:
    Currencies := NewCurrencies
    # …carry over other fields from OldWallet
```

For most helper "make a copy with one field changed" cases a plain `<transacts>`
function that returns `type{ … }` is enough — reserve `<constructor>` for when you
want the archetype body form.

### struct — value type

`struct` is a **value** (copied on assignment, no identity). Use it to group
`@editable` device refs or plain data. Same specifier `<concrete>` applies.

```verse
leaderboard_entry := struct:
    Name : string
    Score : int

prop_game_timers <public> := struct<concrete>():
    @editable HubTimer <public> : timer_device = timer_device{}
    @editable GameTimer <public> : timer_device = timer_device{}
```

class vs struct: pick **struct** for plain grouped data/config passed by value;
pick **class** when you need identity (`<unique>`), inheritance, persistence, or
it's a device (`creative_device`).

### enum

```verse
game_phase := enum{ Warmup, Active, Ended }
team := enum{ Red, Blue }
```

Refer to a case as `game_phase.Active`. Match with `case` (see the
`control_flow` reference).

### interface (language-standard)

```verse
healer := interface:
    Heal(Agent : agent) : void

medic := class(healer):
    Heal<override>(Agent : agent) : void = # …
```

A class lists a superclass first, then any interfaces, in the `class(…)` parens.
Override an inherited/interface method with `<override>` — exactly how devices
override `OnBegin`.

### Parametric types (generics)

A type or function can take a `type` parameter — useful for reusable event
wrappers that carry extra data:

```verse
wrapper_agent(t : type) := class():
    ExtraData : t
    OutputFunc : tuple(agent, t) -> void
    InputFunc(Agent : agent) : void = OutputFunc(Agent, ExtraData)
```

`where t : type` on a function does the same inline.

### Subclassing a device — the canonical entry point

```verse
my_device := class(creative_device):
    @editable Trigger : trigger_device = trigger_device{}
    OnBegin<override>()<suspends>:void =
        Trigger.TriggeredEvent.Subscribe(OnActivated)
    OnActivated(Agent : ?agent):void =
        if (A := Agent?):
            Print("triggered")
```

See the `devices` reference for `@editable`, events, and agents/players; the
`async` reference for what `<suspends>` unlocks.
