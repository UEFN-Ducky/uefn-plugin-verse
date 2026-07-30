---
description: "Analytics & accolades — submitting tracked events per player, organizing analytics/accolade devices into bundles, and firing from gameplay milestones"
metadata:
  order: 31
  label: "Game systems — analytics & accolades"
  default_enabled: false
  load_condition: "Adding analytics/telemetry events, tracking funnels/milestones, or awarding accolades/XP for actions"
---

## Analytics & accolades

Analytics record **what players do** (funnels, retention, economy sinks);
accolades **reward** an action (XP/score popups). Both are devices you fire from
gameplay. Confirm member names in the digest (`search_verse_digest("analytics")`,
`search_verse_digest("accolade")`). Names below are generic.

### The two devices

```verse
@editable PurchaseAnalytics : analytics_device = analytics_device{}   # .Submit(Agent)
@editable PurchaseAccolade  : accolades_device = accolades_device{}   # .Award(Agent)
```

- `analytics_device.Submit(Agent)` — logs one occurrence of that event for the
  player. Each *distinct event you want to measure* is its own placed
  `analytics_device`.
- `accolades_device.Award(Agent)` — grants the accolade's reward (XP/score) to the
  player and shows its popup.

### Fire from the moment it happens

Put the call at the gameplay milestone, right where the outcome is decided:

```verse
BuyItem(Agent : agent) : void =
    # …charge currency, grant item…
    PurchaseAnalytics.Submit(Agent)      # measure the purchase
    PurchaseAccolade.Award(Agent)        # reward it
```

Other natural fire points: player connected, objective completed, level reached,
elimination, round won. Hook them off the events you already have (see
`sys_player_data` for the elimination/connected bus).

### Organize events into a bundle

One event = one device, so you accumulate many. Group them in a `struct<concrete>`
(or a config class) so a single `@editable` exposes the whole set and passing them
around is one field (see `devices`):

```verse
analytics_events := struct<concrete>():
    @editable PlayerJoined   : analytics_device = analytics_device{}
    @editable ItemPurchased  : analytics_device = analytics_device{}
    @editable ObjectiveDone  : analytics_device = analytics_device{}
    @editable PlayerEliminated : analytics_device = analytics_device{}

analytics_by_level := struct<concrete>():
    @editable LevelReached : []analytics_device = array{}    # one per level milestone
```

Fire a milestone by index from the array:

```verse
TrackLevelReached(Agent : agent, Level : int) : void =
    if (Device := AnalyticsByLevel.LevelReached[Level]):
        Device.Submit(Agent)
```

### A tiny tracking helper on the manager

Centralize so gameplay code calls one method instead of touching devices directly:

```verse
Track<public>(Event : analytics_device, Agent : agent) : void =
    Event.Submit(Agent)

TrackAndReward<public>(Event : analytics_device, Reward : accolades_device, Agent : agent) : void =
    Event.Submit(Agent)
    Reward.Award(Agent)
```

### What to measure (funnel thinking)

- **Onboarding funnel**: joined → first objective → first purchase → first level-up.
  One analytics device per step tells you where players drop.
- **Economy**: currency earned vs spent events, per sink — to balance prices.
- **Engagement**: rounds played, session milestones, retention triggers.
- **Rewards**: pair the meaningful ones with an `accolades_device` so the player
  feels the progress you're tracking.

### Gotchas

- `Submit`/`Award` take an `agent` — resolve `?agent` with `?` first, and don't
  assume the handler's agent is still valid; guard with `if` when in doubt.
- One event per `analytics_device` — don't reuse one device for several distinct
  events or the data blurs together.
- Fire once per occurrence (watch loops/retries so you don't double-count).
- Analytics and accolade device APIs come from the digest — verify `Submit` /
  `Award` and any config there.
